import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class ShippingCourier {
  final String name;
  final double fee;
  final String desc;
  final String eta;
  final bool recommended;
  final String? tag;

  ShippingCourier({
    required this.name,
    required this.fee,
    required this.desc,
    required this.eta,
    this.recommended = false,
    this.tag,
  });

  factory ShippingCourier.fromJson(Map<String, dynamic> json) {
    return ShippingCourier(
      name: json['name'] ?? 'Kurir Pengiriman',
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      desc: json['desc'] ?? '',
      eta: json['eta'] ?? '',
      recommended: json['recommended'] == true,
      tag: json['tag'] as String?,
    );
  }
}

class ShippingCostCard extends StatelessWidget {
  final List<ShippingCourier> couriers;
  final ShippingCourier? selectedCourier;
  final ValueChanged<ShippingCourier> onCourierSelected;
  final String? destinationInfo;
  final int? distanceKm;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String source; // 'biteship_api', 'smart_calculation', 'idle'

  const ShippingCostCard({
    super.key,
    required this.couriers,
    required this.selectedCourier,
    required this.onCourierSelected,
    this.destinationInfo,
    this.distanceKm,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.source = 'smart_calculation',
  });

  String _formatRupiah(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return _buildLoadingShimmer();
    if (errorMessage != null) return _buildErrorState();
    return _buildContent();
  }

  // ── Loading Shimmer ────────────────────────────────────────────────────

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8E0D8),
      highlightColor: const Color(0xFFFAF7F2),
      child: Column(
        children: List.generate(
          2,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  // ── Error State ───────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCEC7)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: Color(0xFFC0430E), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  errorMessage!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFC0430E)),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFC0430E)),
                label: const Text('Coba Lagi', style: TextStyle(fontSize: 12, color: Color(0xFFC0430E))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFC0430E)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Main Content ──────────────────────────────────────────────────────

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info destinasi + source badge
        if (destinationInfo != null || distanceKm != null || source != 'idle') ...[
          _buildDestinationBanner(),
          const SizedBox(height: 10),
        ],

        // Empty state
        if (couriers.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0D5C7)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFC0430E), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tidak ada opsi pengiriman. Cek kode pos Anda.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B5E52)),
                  ),
                ),
              ],
            ),
          ),

        // Courier options
        ...couriers.map((courier) => _buildCourierOption(courier)),
      ],
    );
  }

  Widget _buildDestinationBanner() {
    final bool isBiteship = source == 'biteship_api';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isBiteship ? const Color(0xFFEFF8FF) : const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBiteship ? const Color(0xFFBFDFFF) : const Color(0xFFFFDEC0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isBiteship ? Icons.verified_rounded : Icons.location_on,
            color: isBiteship ? Colors.blue[700] : const Color(0xFFC0430E),
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              destinationInfo != null && distanceKm != null
                  ? '$destinationInfo · $distanceKm km dari Jepara'
                  : destinationInfo ?? '$distanceKm km dari Jepara',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B5E52)),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isBiteship ? Colors.blue[100] : const Color(0xFFFFF0E6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isBiteship ? '✓ Biteship' : '🧮 Estimasi',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isBiteship ? Colors.blue[800] : const Color(0xFFC0430E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourierOption(ShippingCourier courier) {
    final isSelected = selectedCourier?.name == courier.name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () => onCourierSelected(courier),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFFF0E6)
                : courier.recommended
                    ? const Color(0xFFFFFBF7)
                    : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFC0430E)
                  : courier.recommended
                      ? const Color(0xFFFFBD8A)
                      : const Color(0xFFE0D5C7),
              width: isSelected ? 2 : (courier.recommended ? 1.5 : 1),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFC0430E).withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  key: ValueKey(isSelected),
                  color: isSelected ? const Color(0xFFC0430E) : const Color(0xFFA89A8C),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            courier.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? const Color(0xFFC0430E) : const Color(0xFF2C2C2C),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (courier.tag != null) ...[
                          const SizedBox(width: 6),
                          _buildTag(courier.tag!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      courier.desc,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B5E52)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatRupiah(courier.fee),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFFC0430E) : const Color(0xFF2C2C2C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String tag) {
    final isCheapest = tag.contains('Termurah');
    final isPopular = tag.contains('Terpopuler');
    final isBest = tag.contains('Terbaik');
    Color bg;
    Color fg;
    if (isCheapest) {
      bg = const Color(0xFFE5F9E7);
      fg = const Color(0xFF166534);
    } else if (isPopular) {
      bg = const Color(0xFFE8F0FE);
      fg = const Color(0xFF1E5B99);
    } else if (isBest) {
      bg = const Color(0xFFFFF0E6);
      fg = const Color(0xFFC0430E);
    } else {
      bg = const Color(0xFFEEEEEE);
      fg = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        tag,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
