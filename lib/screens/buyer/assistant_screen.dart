import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import '../../providers/app_state.dart';
import '../../providers/auth_provider.dart';
import '../../models/product.dart';
import '../../models/order.dart';
import 'order_tracking_screen.dart';

// Simple ChatMessage model for assistant screen
class ChatMessage {
  final String id;
  final String sender;
  final String text;
  final DateTime timestamp;
  final List<Product>? products;
  final OrderModel? order;
  final List<String>? suggestions;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.products,
    this.order,
    this.suggestions,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'products': products?.map((p) => p.toJson()).toList(),
      'order': order?.toJson(),
      'suggestions': suggestions,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      sender: json['sender'] as String? ?? '',
      text: json['text'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
      products: json['products'] != null
          ? (json['products'] as List).map((p) => Product.fromJson(Map<String, dynamic>.from(p))).toList()
          : null,
      order: json['order'] != null
          ? OrderModel.fromJson(Map<String, dynamic>.from(json['order']))
          : null,
      suggestions: json['suggestions'] != null
          ? List<String>.from(json['suggestions'])
          : null,
    );
  }
}

// ─── ChatSession model ───────────────────────────────────────────────────────
class ChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime lastMessageAt;
  int messageCount;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastMessageAt,
    required this.messageCount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'lastMessageAt': lastMessageAt.toIso8601String(),
        'messageCount': messageCount,
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Sesi Chat',
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
        messageCount: json['messageCount'] as int? ?? 0,
      );
}

// AI Backend Service
class AIBackendService {
  late final Dio _dio;
  final String baseUrl;

  AIBackendService({String? customBaseUrl})
      : baseUrl = customBaseUrl ?? AppConfig.baseUrl {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: AppConfig.defaultHeaders,
    ));
  }

  Future<Map<String, dynamic>> sendMessage({
    required String message,
    required List<Map<String, String>> conversationHistory,
    required String userId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/chat',
        data: {
          'message': message,
          'conversationHistory': conversationHistory,
          'userId': userId,
        },
      );
      return response.data;
    } catch (e) {
      debugPrint('Error sending message to AI backend: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendQuickReply({
    required String action,
    required String userId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/chat/quick-reply',
        data: {
          'action': action,
          'userId': userId,
        },
      );
      return response.data;
    } catch (e) {
      debugPrint('Error sending quick reply to AI backend: $e');
      rethrow;
    }
  }
}

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen>
    with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _hasText = false;
  late final AIBackendService _aiService;
  late AnimationController _typingAnimController;
  late AnimationController _pulseController;
  
  // ─── State ──────────────────────────────────────────────────────────────────
  List<ChatMessage> _messages = [];
  final List<Map<String, String>> _conversationHistory = [];

  // Multi-session state
  List<ChatSession> _sessions = [];
  String _activeSessionId = '';
  bool _isHistoryOpen = false;

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  String get _uid => ref.read(authProvider).currentUser?.uid ?? 'guest';

  String _generateSessionId() =>
      'session_${DateTime.now().millisecondsSinceEpoch}';

  String _generateTitle(String firstUserMsg) {
    final t = firstUserMsg.trim();
    return t.isEmpty ? 'Sesi Chat' : (t.length > 38 ? '${t.substring(0, 38)}…' : t);
  }

  List<ChatMessage> _makeWelcomeMessages() => [
        ChatMessage(
          id: 'msg_init_1',
          sender: 'assistant',
          text: 'Hai! Saya Asisten Kartara. Ada yang bisa saya bantu? 😊',
          timestamp: DateTime.now(),
        ),
        ChatMessage(
          id: 'msg_init_2',
          sender: 'assistant_options',
          text: '',
          timestamp: DateTime.now(),
        ),
      ];

  // ─── Storage keys ────────────────────────────────────────────────────────────
  String _keySessionsList(String uid) => 'chat_sessions_$uid';
  String _keyMessages(String uid, String sid) => 'chat_messages_${uid}_$sid';
  String _keyConvo(String uid, String sid) => 'chat_convo_${uid}_$sid';

  // ─── Load / Init ─────────────────────────────────────────────────────────────
  Future<void> _loadSessions() async {
    final uid = _uid;
    final prefs = await SharedPreferences.getInstance();

    // ── Migrate from old single-session key (phone-based) ──
    final authState = ref.read(authProvider);
    final phone = authState.currentUser?.phone ?? '';
    if (phone.isNotEmpty) {
      final oldMsg = prefs.getString('assistant_messages_$phone');
      final oldHist = prefs.getString('assistant_history_$phone');
      final newSessKey = _keySessionsList(uid);
      if (oldMsg != null && prefs.getString(newSessKey) == null) {
        final migratedId = _generateSessionId();
        await prefs.setString(_keyMessages(uid, migratedId), oldMsg);
        if (oldHist != null) {
          await prefs.setString(_keyConvo(uid, migratedId), oldHist);
        }
        final session = ChatSession(
          id: migratedId,
          title: 'Riwayat Lama',
          createdAt: DateTime.now(),
          lastMessageAt: DateTime.now(),
          messageCount: 0,
        );
        await prefs.setString(newSessKey, jsonEncode([session.toJson()]));
        await prefs.remove('assistant_messages_$phone');
        await prefs.remove('assistant_history_$phone');
      }
    }

    // ── Load sessions list ──
    final sessionsStr = prefs.getString(_keySessionsList(uid));
    if (sessionsStr != null) {
      try {
        final decoded = jsonDecode(sessionsStr) as List;
        _sessions = decoded
            .map((s) => ChatSession.fromJson(Map<String, dynamic>.from(s)))
            .toList()
          ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      } catch (_) {
        _sessions = [];
      }
    }

    if (_sessions.isEmpty) {
      await _createNewSession(prefs: prefs, uid: uid);
    } else {
      _activeSessionId = _sessions.first.id;
      await _loadSessionMessages(prefs: prefs, uid: uid, sid: _activeSessionId);
    }
  }

  Future<void> _loadSessionMessages({
    required SharedPreferences prefs,
    required String uid,
    required String sid,
  }) async {
    final msgStr = prefs.getString(_keyMessages(uid, sid));
    final convStr = prefs.getString(_keyConvo(uid, sid));
    if (msgStr != null) {
      try {
        final decoded = jsonDecode(msgStr) as List;
        setState(() {
          _messages = decoded
              .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          _conversationHistory.clear();
          if (convStr != null) {
            final convDecoded = jsonDecode(convStr) as List;
            _conversationHistory.addAll(
              convDecoded.map((h) => Map<String, String>.from(h)),
            );
          }
        });
        _scrollToBottom();
        return;
      } catch (e) {
        debugPrint('Error loading session messages: $e');
      }
    }
    // Fallback: show welcome
    setState(() {
      _messages = _makeWelcomeMessages();
      _conversationHistory.clear();
      _conversationHistory.add({
        'role': 'assistant',
        'content': 'Hai! Saya Asisten Kartara. Ada yang bisa saya bantu? 😊',
      });
    });
  }

  Future<void> _createNewSession({SharedPreferences? prefs, String? uid}) async {
    prefs ??= await SharedPreferences.getInstance();
    uid ??= _uid;
    final sid = _generateSessionId();
    final now = DateTime.now();
    final session = ChatSession(
      id: sid,
      title: 'Sesi Baru',
      createdAt: now,
      lastMessageAt: now,
      messageCount: 0,
    );
    _sessions.insert(0, session);
    // Trim to max 20 sessions
    if (_sessions.length > 20) {
      final removed = _sessions.removeLast();
      await prefs.remove(_keyMessages(uid, removed.id));
      await prefs.remove(_keyConvo(uid, removed.id));
    }
    _activeSessionId = sid;
    await _saveSessionsList(prefs: prefs, uid: uid);
    setState(() {
      _messages = _makeWelcomeMessages();
      _conversationHistory.clear();
      _conversationHistory.add({
        'role': 'assistant',
        'content': 'Hai! Saya Asisten Kartara. Ada yang bisa saya bantu? 😊',
      });
    });
  }

  Future<void> _switchSession(String sid) async {
    if (sid == _activeSessionId) return;
    _activeSessionId = sid;
    // Move selected to front of list
    final idx = _sessions.indexWhere((s) => s.id == sid);
    if (idx > 0) {
      final s = _sessions.removeAt(idx);
      _sessions.insert(0, s);
    }
    final prefs = await SharedPreferences.getInstance();
    await _loadSessionMessages(prefs: prefs, uid: _uid, sid: sid);
  }

  Future<void> _deleteSession(String sid) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uid;
    _sessions.removeWhere((s) => s.id == sid);
    await prefs.remove(_keyMessages(uid, sid));
    await prefs.remove(_keyConvo(uid, sid));
    await _saveSessionsList(prefs: prefs, uid: uid);
    if (sid == _activeSessionId) {
      if (_sessions.isNotEmpty) {
        _activeSessionId = _sessions.first.id;
        await _loadSessionMessages(prefs: prefs, uid: uid, sid: _activeSessionId);
      } else {
        await _createNewSession(prefs: prefs, uid: uid);
      }
    } else {
      setState(() {});
    }
  }

  // ─── Save ────────────────────────────────────────────────────────────────────
  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uid;
    final sid = _activeSessionId;

    // Trim to 200 messages max (keep welcome messages)
    List<ChatMessage> toSave = _messages;
    if (toSave.length > 200) toSave = toSave.sublist(toSave.length - 200);

    await prefs.setString(
        _keyMessages(uid, sid), jsonEncode(toSave.map((m) => m.toJson()).toList()));
    await prefs.setString(
        _keyConvo(uid, sid), jsonEncode(_conversationHistory));

    // Update session metadata
    final idx = _sessions.indexWhere((s) => s.id == sid);
    if (idx >= 0) {
      _sessions[idx].lastMessageAt = DateTime.now();
      _sessions[idx].messageCount = toSave.length;
      // Auto-title from first user message
      if (_sessions[idx].title == 'Sesi Baru' || _sessions[idx].title == 'Sesi Chat') {
        final firstUser = toSave.firstWhere(
            (m) => m.sender == 'user',
            orElse: () => ChatMessage(id: '', sender: '', text: '', timestamp: DateTime.now()));
        if (firstUser.text.isNotEmpty) {
          _sessions[idx].title = _generateTitle(firstUser.text);
        }
      }
      await _saveSessionsList(prefs: prefs, uid: uid);
    }
  }

  Future<void> _saveSessionsList({required SharedPreferences prefs, required String uid}) async {
    await prefs.setString(
        _keySessionsList(uid), jsonEncode(_sessions.map((s) => s.toJson()).toList()));
  }

  @override
  void initState() {
    super.initState();
    _aiService = AIBackendService();
    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _inputController.addListener(() {
      final has = _inputController.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _loadSessions();
  }

  @override
  void dispose() {
    _typingAnimController.dispose();
    _pulseController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(String text) async {
    if (text.trim().isEmpty) return;

    final authState = ref.read(authProvider);
    final userId = authState.currentUser?.uid ?? authState.currentUser?.phone ?? 'guest';

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'user',
        text: text,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });
    _inputController.clear();
    _scrollToBottom();

    // Add to conversation history
    _conversationHistory.add({
      'role': 'user',
      'content': text,
    });

    await _saveChatHistory();

    try {
      // Call AI backend
      final response = await _aiService.sendMessage(
        message: text,
        conversationHistory: _conversationHistory,
        userId: userId,
      );

      if (!mounted) return;

      final aiText = response['response'] as String? ?? 'Maaf, saya tidak dapat memproses permintaan Anda.';
      final productsData = response['products'] as List? ?? [];
      
      // Convert products data to Product objects
      final List<Product> products = productsData.map((p) {
        return Product(
          id: p['id'] ?? '',
          name: p['name'] ?? '',
          sellerName: p['sellerName'] ?? '',
          price: (p['price'] as num?)?.toDouble() ?? 0.0,
          originalPrice: (p['originalPrice'] as num?)?.toDouble() ?? 0.0,
          imageUrl: p['imageUrl'] ?? '',
          category: p['category'] ?? 'Udang',
          rating: (p['rating'] as num?)?.toDouble() ?? 4.8,
          reviewsCount: p['reviewsCount'] ?? 0,
          weight: p['weight'] ?? 250,
          description: p['description'] ?? '',
          characteristics: (p['characteristics'] as List?)?.map((e) => e.toString()).toList() ?? [],
          stock: p['stock'] ?? 0,
        );
      }).toList();

      OrderModel? order;
      final orderData = response['order'] as Map<String, dynamic>?;
      if (orderData != null) {
        order = OrderModel(
          id: orderData['id'] ?? '',
          status: orderData['status'] ?? 'pending',
          recipientName: orderData['buyerName'] ?? '',
          recipientPhone: orderData['buyerPhone'] ?? '',
          shippingAddress: orderData['shippingAddress'] ?? '',
          paymentMethod: orderData['paymentMethod'] ?? 'Midtrans',
          subtotal: (orderData['subtotal'] as num?)?.toDouble() ?? 0.0,
          shippingFee: (orderData['shippingFee'] as num?)?.toDouble() ?? 0.0,
          discount: (orderData['discount'] as num?)?.toDouble() ?? 0.0,
          totalInvoice: (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0,
          orderDate: DateTime.now(),
          items: [],
        );
      }

      final suggestions = response['suggestions'] != null
          ? List<String>.from(response['suggestions'])
          : <String>[];

      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'assistant',
          text: aiText,
          timestamp: DateTime.now(),
          order: order,
          suggestions: suggestions.isNotEmpty ? suggestions : null,
        ));
        
        // Add products if available
        if (products.isNotEmpty) {
          _messages.add(ChatMessage(
            id: 'products_${DateTime.now().millisecondsSinceEpoch}',
            sender: 'assistant_products',
            text: '',
            timestamp: DateTime.now(),
            products: products,
          ));
        }
      });


      // Add to conversation history
      _conversationHistory.add({
        'role': 'assistant',
        'content': aiText,
      });

      _scrollToBottom();
      await _saveChatHistory();
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'assistant',
          text: 'Maaf, saya sedang mengalami gangguan. Pastikan backend server berjalan di ${_aiService.baseUrl} 🙏',
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      await _saveChatHistory();
    }
  }

  void _handleQuickReply(String action, String displayText) async {
    final authState = ref.read(authProvider);
    final userId = authState.currentUser?.uid ?? authState.currentUser?.phone ?? 'guest';

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'user',
        text: displayText,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });
    _scrollToBottom();
    await _saveChatHistory();

    try {
      // Call AI backend quick reply
      final response = await _aiService.sendQuickReply(
        action: action,
        userId: userId,
      );

      if (!mounted) return;

      final aiText = response['response'] as String? ?? 'Maaf, saya tidak dapat memproses permintaan Anda.';
      final productsData = response['products'] as List? ?? [];
      
      // Convert products data to Product objects
      final List<Product> products = productsData.map((p) {
        return Product(
          id: p['id'] ?? '',
          name: p['name'] ?? '',
          sellerName: p['sellerName'] ?? '',
          price: (p['price'] as num?)?.toDouble() ?? 0.0,
          originalPrice: (p['originalPrice'] as num?)?.toDouble() ?? 0.0,
          imageUrl: p['imageUrl'] ?? '',
          category: p['category'] ?? 'Udang',
          rating: (p['rating'] as num?)?.toDouble() ?? 4.8,
          reviewsCount: p['reviewsCount'] ?? 0,
          weight: p['weight'] ?? 250,
          description: p['description'] ?? '',
          characteristics: (p['characteristics'] as List?)?.map((e) => e.toString()).toList() ?? [],
          stock: p['stock'] ?? 0,
        );
      }).toList();

      OrderModel? order;
      final orderData = response['order'] as Map<String, dynamic>?;
      if (orderData != null) {
        order = OrderModel(
          id: orderData['id'] ?? '',
          status: orderData['status'] ?? 'pending',
          recipientName: orderData['buyerName'] ?? '',
          recipientPhone: orderData['buyerPhone'] ?? '',
          shippingAddress: orderData['shippingAddress'] ?? '',
          paymentMethod: orderData['paymentMethod'] ?? 'Midtrans',
          subtotal: (orderData['subtotal'] as num?)?.toDouble() ?? 0.0,
          shippingFee: (orderData['shippingFee'] as num?)?.toDouble() ?? 0.0,
          discount: (orderData['discount'] as num?)?.toDouble() ?? 0.0,
          totalInvoice: (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0,
          orderDate: DateTime.now(),
          items: [],
        );
      }

      final suggestions2 = response['suggestions'] != null
          ? List<String>.from(response['suggestions'])
          : <String>[];

      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'assistant',
          text: aiText,
          timestamp: DateTime.now(),
          order: order,
          suggestions: suggestions2.isNotEmpty ? suggestions2 : null,
        ));
        
        // Add products if available
        if (products.isNotEmpty) {
          _messages.add(ChatMessage(
            id: 'products_${DateTime.now().millisecondsSinceEpoch}',
            sender: 'assistant_products',
            text: '',
            timestamp: DateTime.now(),
            products: products,
          ));
        }
      });


      _scrollToBottom();
      await _saveChatHistory();
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'assistant',
          text: 'Maaf, saya sedang mengalami gangguan. Pastikan backend server berjalan di ${_aiService.baseUrl} 🙏',
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      await _saveChatHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final navNotifier = ref.read(navigationProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F2),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1A1A), size: 18),
          onPressed: () => navNotifier.changeBuyerTab(0),
        ),
        title: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFF0E6),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC0430E).withOpacity(0.15 + _pulseController.value * 0.2),
                      blurRadius: 8 + _pulseController.value * 6,
                      spreadRadius: _pulseController.value * 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.smart_toy_outlined, color: Color(0xFFC0430E), size: 20),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Asisten Kartara',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
            ),
          ],
        ),
        actions: [
          // Tombol History
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Color(0xFFC0430E), size: 22),
            tooltip: 'Riwayat Chat',
            onPressed: () => setState(() => _isHistoryOpen = !_isHistoryOpen),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFF9E9E9E), size: 22),
            tooltip: 'Hapus sesi ini',
            onPressed: () => _showClearDialog(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Message Thread
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    // Date separator
                    Widget? separator;
                    if (index == 0 ||
                        !_isSameDay(_messages[index - 1].timestamp, msg.timestamp)) {
                      separator = _buildDateSeparator(msg.timestamp);
                    }
                    Widget msgWidget;
                    if (msg.sender == 'user') {
                      msgWidget = _buildUserBubble(msg.text, msg.timestamp);
                    } else if (msg.sender == 'assistant') {
                      msgWidget = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAssistantBubble(msg.text, msg.timestamp),
                          if (msg.order != null) _buildOrderTrackingCard(msg.order!),
                          if (msg.suggestions != null && msg.suggestions!.isNotEmpty)
                            _buildSuggestionChips(msg.suggestions!),
                        ],
                      );
                    } else if (msg.sender == 'assistant_options') {
                      msgWidget = _buildVerticalOptionsPanel();
                    } else if (msg.sender == 'assistant_products') {
                      msgWidget = _buildHorizontalProductsPanel(msg.products ?? []);
                    } else {
                      msgWidget = const SizedBox();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (separator != null) separator,
                        msgWidget,
                      ],
                    );
                  },
                ),
              ),

              // 2. Typing indicator
              if (_isTyping)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 34, height: 34,
                        decoration: const BoxDecoration(color: Color(0xFFFFF0E6), shape: BoxShape.circle),
                        child: const Icon(Icons.smart_toy_outlined, color: Color(0xFFC0430E), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFFFE0CC)),
                        ),
                        child: AnimatedBuilder(
                          animation: _typingAnimController,
                          builder: (context, _) => Row(
                            children: List.generate(3, (i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color.lerp(
                                  const Color(0xFFC0430E).withOpacity(0.3),
                                  const Color(0xFFC0430E),
                                  i == 0 ? _typingAnimController.value
                                      : i == 1 ? (_typingAnimController.value + 0.3).clamp(0.0, 1.0)
                                      : (_typingAnimController.value + 0.6).clamp(0.0, 1.0),
                                ),
                              ),
                            )),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 3. Input bar
              _buildInputBar(),
            ],
          ),

          // History Drawer Overlay
          if (_isHistoryOpen) _buildHistoryDrawer(),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Sesi Ini?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Percakapan pada sesi ini akan dihapus. Sesi lain tidak terpengaruh.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC0430E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteSession(_activeSessionId);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  // User Message bubble
  Widget _buildUserBubble(String text, DateTime timestamp) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE05A20), Color(0xFFC0430E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(color: Color(0x30C0430E), blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
            ),
            const SizedBox(height: 3),
            Text(
              '${timestamp.hour.toString().padLeft(2,'0')}:${timestamp.minute.toString().padLeft(2,'0')}',
              style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA)),
            ),
          ],
        ),
      ),
    );
  }

  // Assistant Message bubble with simple markdown rendering
  Widget _buildAssistantBubble(String text, DateTime timestamp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: const BoxDecoration(color: Color(0xFFFFF0E6), shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_outlined, color: Color(0xFFC0430E), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(color: const Color(0xFFFFE0CC), width: 1),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: _buildMarkdownText(text),
                ),
                const SizedBox(height: 3),
                Text(
                  '${timestamp.hour.toString().padLeft(2,'0')}:${timestamp.minute.toString().padLeft(2,'0')}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildMarkdownText(String text) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.startsWith('• ') || line.startsWith('- ')) {
          final content = line.substring(2);
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Color(0xFFC0430E), fontWeight: FontWeight.bold)),
                Expanded(child: _buildInlineMarkdown(content)),
              ],
            ),
          );
        } else if (RegExp(r'^\d+\.').hasMatch(line)) {
          final dot = line.indexOf('.');
          final num = line.substring(0, dot + 1);
          final content = line.substring(dot + 1).trim();
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$num ', style: const TextStyle(color: Color(0xFFC0430E), fontWeight: FontWeight.bold, fontSize: 13)),
                Expanded(child: _buildInlineMarkdown(content)),
              ],
            ),
          );
        } else if (line.isEmpty) {
          return const SizedBox(height: 6);
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: _buildInlineMarkdown(line),
          );
        }
      }).toList(),
    );
  }

  Widget _buildInlineMarkdown(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start),
            style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 13, height: 1.4)));
      }
      spans.add(TextSpan(text: match.group(1),
          style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 13, height: 1.4, fontWeight: FontWeight.bold)));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd),
          style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 13, height: 1.4)));
    }
    return RichText(text: TextSpan(children: spans));
  }

  // Suggestion chips shown after assistant messages
  Widget _buildSuggestionChips(List<String> suggestions) {
    return Container(
      margin: const EdgeInsets.only(left: 44, bottom: 14, top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: suggestions.map((s) => GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _handleQuickReply(s, s);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFC0430E).withOpacity(0.5)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0,2))],
            ),
            child: Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFFC0430E), fontWeight: FontWeight.w600)),
          ),
        )).toList(),
      ),
    );
  }

  // Custom Robot avatar next to message bubbles
  Widget _buildRobotAvatar() {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: Color(0xFFFFF0E6),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Orange circular head framework
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFC0430E), width: 2.5),
              shape: BoxShape.circle,
            ),
          ),
          // Clean lower-half background overlap
          Positioned(
            bottom: 6,
            child: Container(width: 26, height: 10, color: const Color(0xFFFFF0E6)),
          ),
          // Inner Dark robot monitor
          Container(
            width: 22,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF4DEEEA), shape: BoxShape.circle)),
                Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF4DEEEA), shape: BoxShape.circle)),
              ],
            ),
          ),
          // Antenna top
          Positioned(
            top: 2,
            child: Container(width: 2, height: 5, color: const Color(0xFFC0430E)),
          ),
          Positioned(
            top: 0,
            child: Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFC0430E), shape: BoxShape.circle)),
          ),
        ],
      ),
    );
  }

  // Vertical stacked options list as shown in Screenshot 2
  Widget _buildVerticalOptionsPanel() {
    return Container(
      margin: const EdgeInsets.only(left: 52, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOutlineOption('🚚 Cek Ongkir'),
          const SizedBox(height: 8),
          _buildOutlineOption('📦 Lacak Pesanan'),
          const SizedBox(height: 8),
          _buildOutlineOption('Rekomendasi oleh-oleh'),
          const SizedBox(height: 8),
          _buildOutlineOption('Produk favorit'),
          const SizedBox(height: 8),
          _buildOutlineOption('Promo hari ini'),
          const SizedBox(height: 12),
          _buildBlueActionPill('Bicarakan hal lain, yuk!'),
        ],
      ),
    );
  }

  Widget _buildOrderTrackingCard(OrderModel order) {
    Color statusColor = const Color(0xFFC0430E);
    String statusLabel = order.status.toUpperCase();
    final s = order.status.toLowerCase();
    if (s == 'pending') { statusColor = Colors.orange; statusLabel = '⏳ Menunggu Pembayaran'; }
    else if (s == 'paid') { statusColor = Colors.blue; statusLabel = '✅ Sudah Dibayar'; }
    else if (s == 'diproses' || s == 'processing') { statusColor = Colors.purple; statusLabel = '🔧 Sedang Diproses'; }
    else if (s == 'dikirim' || s == 'shipped') { statusColor = Colors.indigo; statusLabel = '🚚 Dalam Pengiriman'; }
    else if (s == 'selesai' || s == 'completed') { statusColor = Colors.green; statusLabel = '✅ Selesai'; }

    return Container(
      margin: const EdgeInsets.only(left: 52, bottom: 12, right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFDDCC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, color: Color(0xFFC0430E), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Invoice #${order.id}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
          ),
          if (order.courierName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('🚚 ${order.courierName} · ETA: ${order.displayEta}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B5E52))),
          ],
          if (order.generatedTrackingNumber.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('📦 Resi: ${order.generatedTrackingNumber}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B5E52))),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderTrackingScreen(order: order),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC0430E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              icon: const Icon(Icons.map_outlined, color: Colors.white, size: 16),
              label: const Text(
                'Buka Detail & Peta Tracking',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlineOption(String title) {
    String action = '';
    if (title == 'Rekomendasi oleh-oleh') {
      action = 'rekomendasi_kerupuk';
    } else if (title == 'Produk favorit') {
      action = 'produk_terlaris';
    } else if (title == 'Promo hari ini') {
      action = 'promo_hari_ini';
    } else if (title == '🚚 Cek Ongkir') {
      action = 'cek_ongkir';
    } else if (title == '📦 Lacak Pesanan') {
      action = 'lacak_pesanan';
    }
    
    return GestureDetector(
      onTap: () => action.isNotEmpty ? _handleQuickReply(action, title) : _handleSend(title),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC0430E)),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }

  Widget _buildBlueActionPill(String title) {
    return GestureDetector(
      onTap: () => _handleQuickReply('cara_checkout', 'Cara checkout'),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E5B99),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalProductsPanel(List<Product> products) {
    if (products.isEmpty) return const SizedBox();
    return Container(
      height: 220,
      margin: const EdgeInsets.only(left: 44, bottom: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildRecommendationProductCard(product);
        },
      ),
    );
  }

  Widget _buildRecommendationProductCard(Product product) {
    final navNotifier = ref.read(navigationProvider.notifier);
    final cartNotifier = ref.read(cartProvider.notifier);
    final price = product.price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

    return GestureDetector(
      onTap: () => navNotifier.navigateToBuyer('detail', product: product),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFDDCC)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFFFF0E6),
                    child: const Icon(Icons.cookie, color: Color(0xFFC0430E), size: 30),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.sellerName,
                      style: const TextStyle(fontSize: 9, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(product.name,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Rp $price',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC0430E))),
                      GestureDetector(
                        onTap: product.stock <= 0 ? null : () {
                          cartNotifier.addToCart(product);
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${product.name} ditambahkan! 🛒'),
                              duration: const Duration(seconds: 1),
                              backgroundColor: const Color(0xFFC0430E),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        child: Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            color: product.stock <= 0 ? Colors.grey.shade300 : const Color(0xFFC0430E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 46, maxHeight: 110),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _hasText ? const Color(0xFFC0430E) : const Color(0xFFFFDDCC)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
              ),
              child: TextField(
                controller: _inputController,
                onSubmitted: _handleSend,
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Tanya Asisten Kartara...',
                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _hasText ? const Color(0xFFC0430E) : const Color(0xFFE0E0E0),
              shape: BoxShape.circle,
              boxShadow: _hasText ? [const BoxShadow(color: Color(0x40C0430E), blurRadius: 8, offset: Offset(0, 3))] : [],
            ),
            child: IconButton(
              onPressed: _hasText ? () { HapticFeedback.lightImpact(); _handleSend(_inputController.text); } : null,
              icon: Icon(Icons.send_rounded, color: _hasText ? Colors.white : Colors.grey.shade400, size: 20),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Date separator helper ────────────────────────────────────────────────
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    String label;
    if (d == today) {
      label = 'Hari ini';
    } else if (d == today.subtract(const Duration(days: 1))) {
      label = 'Kemarin';
    } else {
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      label = '${date.day} ${months[date.month]} ${date.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE0D8D0), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w500)),
          ),
          const Expanded(child: Divider(color: Color(0xFFE0D8D0), thickness: 1)),
        ],
      ),
    );
  }

  // ─── History Drawer ───────────────────────────────────────────────────────
  Widget _buildHistoryDrawer() {
    return GestureDetector(
      onTap: () => setState(() => _isHistoryOpen = false),
      child: Container(
        color: Colors.black.withOpacity(0.35),
        child: Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 300,
              height: double.infinity,
              color: Colors.white,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF8F4),
                        border: Border(bottom: BorderSide(color: Color(0xFFFFE0CC))),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.history_rounded, color: Color(0xFFC0430E), size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('Riwayat Chat',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Color(0xFF9E9E9E)),
                            onPressed: () => setState(() => _isHistoryOpen = false),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    // Tombol Sesi Baru
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: GestureDetector(
                        onTap: () async {
                          setState(() => _isHistoryOpen = false);
                          await _createNewSession();
                          _scrollToBottom();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC0430E),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 18),
                              SizedBox(width: 6),
                              Text('Sesi Baru',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFEEE8E0)),
                    // Daftar Sesi
                    Expanded(
                      child: _sessions.isEmpty
                          ? const Center(
                              child: Text('Belum ada riwayat chat',
                                  style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13)))
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: _sessions.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF0EAE4)),
                              itemBuilder: (context, i) {
                                final session = _sessions[i];
                                final isActive = session.id == _activeSessionId;
                                final dt = session.lastMessageAt;
                                final nowDt = DateTime.now();
                                String timeLabel;
                                if (_isSameDay(dt, nowDt)) {
                                  timeLabel = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                } else if (_isSameDay(dt, nowDt.subtract(const Duration(days: 1)))) {
                                  timeLabel = 'Kemarin';
                                } else {
                                  const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
                                  timeLabel = '${dt.day} ${months[dt.month]}';
                                }
                                return Material(
                                  color: isActive ? const Color(0xFFFFF0E6) : Colors.white,
                                  child: InkWell(
                                    onTap: () async {
                                      setState(() => _isHistoryOpen = false);
                                      await _switchSession(session.id);
                                      _scrollToBottom();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 8, height: 8,
                                            margin: const EdgeInsets.only(right: 10),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isActive ? const Color(0xFFC0430E) : const Color(0xFFDDD8D2),
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(session.title,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                                      color: isActive ? const Color(0xFFC0430E) : const Color(0xFF1A1A1A),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis),
                                                const SizedBox(height: 2),
                                                Text('$timeLabel · ${session.messageCount} pesan',
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFBBBBBB)),
                                            onPressed: () => showDialog(
                                              context: context,
                                              builder: (_) => AlertDialog(
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                title: const Text('Hapus sesi?',
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                content: Text('Sesi "${session.title}" akan dihapus.'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFFC0430E),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    ),
                                                    onPressed: () async {
                                                      Navigator.pop(context);
                                                      await _deleteSession(session.id);
                                                    },
                                                    child: const Text('Hapus', style: TextStyle(color: Colors.white)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
