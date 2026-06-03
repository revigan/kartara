import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';
import '../models/tracking_info.dart';
import '../services/tracking_service.dart';

// ── Tracking Info Provider (per orderId) ─────────────────────────────────

final trackingServiceProvider = Provider<TrackingService>((ref) {
  return TrackingService();
});

/// FutureProvider per orderId — fetch tracking info sekali saat load
final orderTrackingProvider =
    FutureProvider.family<OrderTrackingInfo?, String>((ref, orderId) async {
  if (orderId.isEmpty) return null;
  final service = ref.read(trackingServiceProvider);
  return service.getOrderTracking(orderId);
});

// ── Live Courier Location (polling 5 detik) ──────────────────────────────

class CourierLocationState {
  final LatLng? position;
  final double progress;
  final String source;
  final bool isPolling;
  final bool isCompleted;

  const CourierLocationState({
    this.position,
    this.progress = 0.3,
    this.source = 'idle',
    this.isPolling = false,
    this.isCompleted = false,
  });

  CourierLocationState copyWith({
    LatLng? position,
    double? progress,
    String? source,
    bool? isPolling,
    bool? isCompleted,
  }) {
    return CourierLocationState(
      position: position ?? this.position,
      progress: progress ?? this.progress,
      source: source ?? this.source,
      isPolling: isPolling ?? this.isPolling,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class CourierLocationNotifier extends StateNotifier<CourierLocationState> {
  final TrackingService _service;
  Timer? _timer;
  String? _currentOrderId;

  // Default initial position (toko Jepara)
  static const LatLng _origin = LatLng(-6.5888, 110.6686);

  CourierLocationNotifier(this._service) : super(const CourierLocationState());

  void startPolling(String orderId, {LatLng? initialPosition}) {
    if (_currentOrderId == orderId && state.isPolling) return;

    _currentOrderId = orderId;
    _timer?.cancel();

    state = state.copyWith(
      position: initialPosition ?? _origin,
      isPolling: true,
      source: 'starting',
    );

    // Langsung fetch sekali, lalu poll tiap 5 detik
    _fetchLocation();

    _timer = Timer.periodic(AppConfig.courierPollingInterval, (_) {
      if (!mounted) return;
      _fetchLocation();
    });
  }

  Future<void> _fetchLocation() async {
    if (_currentOrderId == null) return;
    try {
      final data = await _service.getCourierLocation(_currentOrderId!);
      if (!mounted) return;

      if (data == null) return;

      if (data.isCompleted) {
        stopPolling(completed: true);
        return;
      }

      state = state.copyWith(
        position: LatLng(data.lat, data.lng),
        progress: data.progress,
        source: data.source,
        isCompleted: false,
      );
    } catch (e) {
      debugPrint('CourierLocationNotifier: fetch error — $e');
    }
  }

  void stopPolling({bool completed = false}) {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(
      isPolling: false,
      isCompleted: completed,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Provider per orderId — live courier location dengan polling
final courierLocationProvider = StateNotifierProvider.family<
    CourierLocationNotifier, CourierLocationState, String>((ref, orderId) {
  return CourierLocationNotifier(ref.read(trackingServiceProvider));
});
