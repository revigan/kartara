// Model data untuk informasi tracking pesanan Kartara.

class CourierLocationData {
  final double lat;
  final double lng;
  final double progress; // 0.0 - 1.0
  final String source; // 'real', 'simulated', 'completed'
  final String status;
  final DateTime updatedAt;

  const CourierLocationData({
    required this.lat,
    required this.lng,
    required this.progress,
    required this.source,
    required this.status,
    required this.updatedAt,
  });

  factory CourierLocationData.fromJson(Map<String, dynamic> json) {
    final locJson = json['location'] as Map<String, dynamic>? ?? json;
    return CourierLocationData(
      lat: (locJson['lat'] as num?)?.toDouble() ?? -6.5888,
      lng: (locJson['lng'] as num?)?.toDouble() ?? 110.6686,
      progress: (locJson['progress'] as num?)?.toDouble() ?? 0.3,
      source: locJson['source'] as String? ?? 'simulated',
      status: locJson['status'] as String? ?? 'unknown',
      updatedAt: DateTime.now(),
    );
  }

  bool get isCompleted => source == 'completed' || progress >= 1.0;
}

class TrackingTimelineEvent {
  final String title;
  final String description;
  final String timestamp;
  final bool isCompleted;
  final bool isActive;

  const TrackingTimelineEvent({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.isCompleted,
    required this.isActive,
  });

  factory TrackingTimelineEvent.fromJson(Map<String, dynamic> json) {
    return TrackingTimelineEvent(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}

class OrderTrackingInfo {
  final String orderId;
  final String status;
  final String buyerName;
  final String buyerPhone;
  final String shippingAddress;
  final double totalAmount;
  final double shippingFee;
  final double discount;
  final String paymentMethod;
  final String courierName;
  final String courierService;
  final String courierEta;
  final String trackingNumber;
  final String postalCode;
  final String destinationCity;
  final double courierProgress;
  final double? courierLatitude;
  final double? courierLongitude;
  final String created;
  final String updated;
  final String? paidAt;
  final List<TrackingTimelineEvent> timeline;

  const OrderTrackingInfo({
    required this.orderId,
    required this.status,
    required this.buyerName,
    required this.buyerPhone,
    required this.shippingAddress,
    required this.totalAmount,
    required this.shippingFee,
    required this.discount,
    required this.paymentMethod,
    required this.courierName,
    required this.courierService,
    required this.courierEta,
    required this.trackingNumber,
    required this.postalCode,
    required this.destinationCity,
    required this.courierProgress,
    this.courierLatitude,
    this.courierLongitude,
    required this.created,
    required this.updated,
    this.paidAt,
    required this.timeline,
  });

  factory OrderTrackingInfo.fromJson(Map<String, dynamic> json) {
    final tracking = json['tracking'] as Map<String, dynamic>? ?? json;
    final timelineRaw = tracking['timeline'] as List? ?? [];
    return OrderTrackingInfo(
      orderId: tracking['orderId'] as String? ?? '',
      status: tracking['status'] as String? ?? 'pending',
      buyerName: tracking['buyerName'] as String? ?? '',
      buyerPhone: tracking['buyerPhone'] as String? ?? '',
      shippingAddress: tracking['shippingAddress'] as String? ?? '',
      totalAmount: (tracking['totalAmount'] as num?)?.toDouble() ?? 0.0,
      shippingFee: (tracking['shippingFee'] as num?)?.toDouble() ?? 0.0,
      discount: (tracking['discount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: tracking['paymentMethod'] as String? ?? '',
      courierName: tracking['courierName'] as String? ?? 'Kartara Instant',
      courierService: tracking['courierService'] as String? ?? 'Reguler',
      courierEta: tracking['courierEta'] as String? ?? '1-3 hari',
      trackingNumber: tracking['trackingNumber'] as String? ?? '',
      postalCode: tracking['postalCode'] as String? ?? '',
      destinationCity: tracking['destinationCity'] as String? ?? '',
      courierProgress: (tracking['courierProgress'] as num?)?.toDouble() ?? 0.3,
      courierLatitude: (tracking['courierLatitude'] as num?)?.toDouble(),
      courierLongitude: (tracking['courierLongitude'] as num?)?.toDouble(),
      created: tracking['created'] as String? ?? '',
      updated: tracking['updated'] as String? ?? '',
      paidAt: tracking['paid_at'] as String?,
      timeline: timelineRaw
          .map((e) => TrackingTimelineEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isShipped => status == 'dikirim' || status == 'shipped';
  bool get isCompleted => status == 'selesai' || status == 'completed';
  bool get isCancelled => status == 'cancelled' || status == 'dibatalkan';
  bool get canTrackMap => isShipped || isCompleted;
}
