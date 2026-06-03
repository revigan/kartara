import 'dart:convert';
import 'cart_item.dart';

class OrderModel {
  final String id;
  final List<CartItem> items;
  final String status;
  final DateTime orderDate;
  final String recipientName;
  final String recipientPhone;
  final String shippingAddress;
  final String paymentMethod;
  final double subtotal;
  final double shippingFee;
  final double discount;
  final double totalInvoice;

  // Courier tracking properties
  final String courierName;
  final String courierVehicle;
  final double courierRating;
  final int etaMinutes;

  // Enhanced shipping fields (Phase 2)
  final String courierService;     // "Reguler", "Ekspres"
  final String courierEta;         // "2-3 hari", "1-3 jam"
  final String trackingNumber;     // "KTR-XXXXXXXX"
  final String postalCode;         // "59411"
  final String destinationCity;    // "Semarang, Jawa Tengah"
  final double courierProgress;    // 0.0 - 1.0

  OrderModel({
    required this.id,
    required this.items,
    required this.status,
    required this.orderDate,
    required this.recipientName,
    required this.recipientPhone,
    required this.shippingAddress,
    required this.paymentMethod,
    required this.subtotal,
    required this.shippingFee,
    required this.discount,
    required this.totalInvoice,
    this.courierName = 'Kartara Instant',
    this.courierVehicle = 'Honda Vario - H 4821 AJ',
    this.courierRating = 4.8,
    this.etaMinutes = 25,
    this.courierService = 'Reguler',
    this.courierEta = '1-3 hari',
    this.trackingNumber = '',
    this.postalCode = '',
    this.destinationCity = '',
    this.courierProgress = 0.3,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items.map((item) => item.toJson()).toList(),
      'status': status,
      'orderDate': orderDate.toIso8601String(),
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'shippingAddress': shippingAddress,
      'paymentMethod': paymentMethod,
      'subtotal': subtotal,
      'shippingFee': shippingFee,
      'discount': discount,
      'totalInvoice': totalInvoice,
      'courierName': courierName,
      'courierVehicle': courierVehicle,
      'courierRating': courierRating,
      'etaMinutes': etaMinutes,
      'courierService': courierService,
      'courierEta': courierEta,
      'trackingNumber': trackingNumber,
      'postalCode': postalCode,
      'destinationCity': destinationCity,
      'courierProgress': courierProgress,
    };
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'];
    List<CartItem> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems.map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } else if (rawItems is String) {
      final List decoded = jsonDecode(rawItems);
      parsedItems = decoded.map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }

    return OrderModel(
      id: json['id'] as String? ?? '',
      items: parsedItems,
      status: json['status'] as String? ?? 'pending',
      orderDate: json['orderDate'] != null
          ? DateTime.parse(json['orderDate'] as String)
          : DateTime.now(),
      recipientName: json['recipientName'] as String? ?? '',
      recipientPhone: json['recipientPhone'] as String? ?? '',
      shippingAddress: json['shippingAddress'] as String? ?? '',
      paymentMethod: json['paymentMethod'] as String? ?? '',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      shippingFee: (json['shippingFee'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      totalInvoice: (json['totalInvoice'] as num?)?.toDouble() ?? 0.0,
      courierName: json['courierName'] as String? ?? 'Kartara Instant',
      courierVehicle: json['courierVehicle'] as String? ?? 'Honda Vario - H 4821 AJ',
      courierRating: (json['courierRating'] as num?)?.toDouble() ?? 4.8,
      etaMinutes: json['etaMinutes'] as int? ?? 25,
      courierService: json['courierService'] as String? ?? 'Reguler',
      courierEta: json['courierEta'] as String? ?? '1-3 hari',
      trackingNumber: json['trackingNumber'] as String? ?? '',
      postalCode: json['postalCode'] as String? ?? '',
      destinationCity: json['destinationCity'] as String? ?? '',
      courierProgress: (json['courierProgress'] as num?)?.toDouble() ?? 0.3,
    );
  }

  OrderModel copyWith({
    String? id,
    List<CartItem>? items,
    String? status,
    DateTime? orderDate,
    String? recipientName,
    String? recipientPhone,
    String? shippingAddress,
    String? paymentMethod,
    double? subtotal,
    double? shippingFee,
    double? discount,
    double? totalInvoice,
    String? courierName,
    String? courierVehicle,
    double? courierRating,
    int? etaMinutes,
    String? courierService,
    String? courierEta,
    String? trackingNumber,
    String? postalCode,
    String? destinationCity,
    double? courierProgress,
  }) {
    return OrderModel(
      id: id ?? this.id,
      items: items ?? this.items,
      status: status ?? this.status,
      orderDate: orderDate ?? this.orderDate,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      subtotal: subtotal ?? this.subtotal,
      shippingFee: shippingFee ?? this.shippingFee,
      discount: discount ?? this.discount,
      totalInvoice: totalInvoice ?? this.totalInvoice,
      courierName: courierName ?? this.courierName,
      courierVehicle: courierVehicle ?? this.courierVehicle,
      courierRating: courierRating ?? this.courierRating,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      courierService: courierService ?? this.courierService,
      courierEta: courierEta ?? this.courierEta,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      postalCode: postalCode ?? this.postalCode,
      destinationCity: destinationCity ?? this.destinationCity,
      courierProgress: courierProgress ?? this.courierProgress,
    );
  }

  /// Generate nomor resi dari ID order
  String get generatedTrackingNumber =>
      trackingNumber.isNotEmpty ? trackingNumber : 'KTR-${id.substring(0, 8).toUpperCase()}';

  /// ETA dalam format string (prioritaskan courierEta, fallback ke etaMinutes)
  String get displayEta =>
      courierEta.isNotEmpty ? courierEta : '$etaMinutes Menit';

  bool get isShipped =>
      status == 'dikirim' || status == 'shipped' || status == 'dalam perjalanan';
  bool get isCompleted => status == 'completed' || status == 'selesai';
  bool get canTrackMap => isShipped || isCompleted;
}
