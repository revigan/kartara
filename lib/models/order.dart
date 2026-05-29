import 'dart:convert';
import 'cart_item.dart';

class OrderModel {
  final String id;
  final List<CartItem> items;
  final String status; // 'pending', 'diproses', 'dikirim', 'selesai'
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
    this.courierName = 'Budi Santoso',
    this.courierVehicle = 'Honda Vario - H 4821 AJ',
    this.courierRating = 4.8,
    this.etaMinutes = 25,
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
      courierName: json['courierName'] as String? ?? 'Budi Santoso',
      courierVehicle: json['courierVehicle'] as String? ?? 'Honda Vario - H 4821 AJ',
      courierRating: (json['courierRating'] as num?)?.toDouble() ?? 4.8,
      etaMinutes: json['etaMinutes'] as int? ?? 25,
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
    );
  }
}
