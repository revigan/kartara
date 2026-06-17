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
  
  // Custom message history list
  List<ChatMessage> _messages = [];
  final List<Map<String, String>> _conversationHistory = [];

  Future<void> _loadChatHistory() async {
    final authState = ref.read(authProvider);
    final phone = authState.currentUser?.phone ?? 'guest';
    final prefs = await SharedPreferences.getInstance();

    final messagesJsonStr = prefs.getString('assistant_messages_$phone');
    final historyJsonStr = prefs.getString('assistant_history_$phone');

    if (messagesJsonStr != null && historyJsonStr != null) {
      try {
        final List decodedMessages = jsonDecode(messagesJsonStr);
        final List decodedHistory = jsonDecode(historyJsonStr);

        setState(() {
          _messages = decodedMessages
              .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          _conversationHistory.clear();
          _conversationHistory.addAll(decodedHistory.map((h) => Map<String, String>.from(h)));
        });
        _scrollToBottom();
        return;
      } catch (e) {
        debugPrint('Error loading chat history: $e');
      }
    }

    // Default initialization if no history is found
    setState(() {
      _messages = [
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
      _conversationHistory.clear();
      _conversationHistory.add({
        'role': 'assistant',
        'content': 'Hai! Saya Asisten Kartara. Ada yang bisa saya bantu? 😊',
      });
    });
  }

  Future<void> _saveChatHistory() async {
    final authState = ref.read(authProvider);
    final phone = authState.currentUser?.phone ?? 'guest';
    final prefs = await SharedPreferences.getInstance();

    final messagesJsonStr = jsonEncode(_messages.map((m) => m.toJson()).toList());
    final historyJsonStr = jsonEncode(_conversationHistory);

    await prefs.setString('assistant_messages_$phone', messagesJsonStr);
    await prefs.setString('assistant_history_$phone', historyJsonStr);
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
    _loadChatHistory();
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
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFF9E9E9E), size: 22),
            tooltip: 'Hapus riwayat chat',
            onPressed: () => _showClearDialog(context),
          ),
        ],
      ),
      body: Column(
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
                if (msg.sender == 'user') {
                  return _buildUserBubble(msg.text, msg.timestamp);
                } else if (msg.sender == 'assistant') {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAssistantBubble(msg.text, msg.timestamp),
                      if (msg.order != null) _buildOrderTrackingCard(msg.order!),
                      if (msg.suggestions != null && msg.suggestions!.isNotEmpty)
                        _buildSuggestionChips(msg.suggestions!),
                    ],
                  );
                } else if (msg.sender == 'assistant_options') {
                  return _buildVerticalOptionsPanel();
                } else if (msg.sender == 'assistant_products') {
                  return _buildHorizontalProductsPanel(msg.products ?? []);
                }
                return const SizedBox();
              },
            ),
          ),

          // 2. Typing indicator (animated dots)
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
    );
  }

  void _showClearDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Riwayat Chat?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Seluruh percakapan dengan Asisten Kartara akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0430E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(ctx);
              final authState = ref.read(authProvider);
              final phone = authState.currentUser?.phone ?? 'guest';
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('assistant_messages_$phone');
              await prefs.remove('assistant_history_$phone');
              setState(() {
                _messages = [
                  ChatMessage(id: 'init', sender: 'assistant', text: 'Hai! Saya Asisten Kartara. Ada yang bisa saya bantu? 😊', timestamp: DateTime.now(), suggestions: ['Rekomendasi terlaris ⭐', 'Cek promo hari ini 🎉', 'Info ongkir 🚚']),
                  ChatMessage(id: 'init_opts', sender: 'assistant_options', text: '', timestamp: DateTime.now()),
                ];
                _conversationHistory.clear();
              });
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
}
