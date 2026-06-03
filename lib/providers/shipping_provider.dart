import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/shipping_service.dart';
import '../widgets/shipping_cost_card.dart';

// ── State ─────────────────────────────────────────────────────────────────

class ShippingState {
  final bool isLoading;
  final List<ShippingCourier> couriers;
  final ShippingCourier? selectedCourier;
  final String? destination;
  final int? distanceKm;
  final String? zone;
  final String? zoneLabel;
  final String source; // 'biteship_api', 'smart_calculation', 'error', 'idle'
  final String? error;

  const ShippingState({
    this.isLoading = false,
    this.couriers = const [],
    this.selectedCourier,
    this.destination,
    this.distanceKm,
    this.zone,
    this.zoneLabel,
    this.source = 'idle',
    this.error,
  });

  double get selectedFee => selectedCourier?.fee ?? 0.0;
  bool get hasResult => couriers.isNotEmpty;
  bool get isBiteshipLive => source == 'biteship_api';

  ShippingState copyWith({
    bool? isLoading,
    List<ShippingCourier>? couriers,
    ShippingCourier? selectedCourier,
    bool clearSelectedCourier = false,
    String? destination,
    int? distanceKm,
    String? zone,
    String? zoneLabel,
    String? source,
    String? error,
    bool clearError = false,
  }) {
    return ShippingState(
      isLoading: isLoading ?? this.isLoading,
      couriers: couriers ?? this.couriers,
      selectedCourier: clearSelectedCourier ? null : (selectedCourier ?? this.selectedCourier),
      destination: destination ?? this.destination,
      distanceKm: distanceKm ?? this.distanceKm,
      zone: zone ?? this.zone,
      zoneLabel: zoneLabel ?? this.zoneLabel,
      source: source ?? this.source,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────

class ShippingNotifier extends StateNotifier<ShippingState> {
  final ShippingService _service;

  ShippingNotifier(this._service) : super(const ShippingState());

  Future<void> calculateShipping({
    required String address,
    required String postalCode,
    int totalWeight = 1000,
  }) async {
    if (address.trim().isEmpty || postalCode.trim().isEmpty) return;

    state = state.copyWith(
      isLoading: true,
      clearSelectedCourier: true,
      clearError: true,
    );

    final result = await _service.calculateShipping(
      address: address,
      postalCode: postalCode,
      totalWeight: totalWeight,
    );

    if (result.success && result.couriers.isNotEmpty) {
      state = state.copyWith(
        isLoading: false,
        couriers: result.couriers,
        selectedCourier: result.couriers.first,
        destination: result.destination,
        distanceKm: result.distanceKm,
        zone: result.zone,
        zoneLabel: result.zoneLabel,
        source: result.source,
        clearError: true,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        couriers: [],
        source: 'error',
        error: result.error ?? 'Gagal menghitung ongkir. Coba lagi.',
      );
    }
  }

  void selectCourier(ShippingCourier courier) {
    state = state.copyWith(selectedCourier: courier);
  }

  void reset() {
    state = const ShippingState();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────

final shippingServiceProvider = Provider<ShippingService>((ref) {
  return ShippingService();
});

final shippingProvider = StateNotifierProvider<ShippingNotifier, ShippingState>((ref) {
  return ShippingNotifier(ref.read(shippingServiceProvider));
});
