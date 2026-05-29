import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  const ShippingCostCard({
    super.key,
    required this.couriers,
    required this.selectedCourier,
    required this.onCourierSelected,
    this.destinationInfo,
    this.distanceKm,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info jarak destinasi dari backend
        if (destinationInfo != null || distanceKm != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFDEC0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFFC0430E), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    destinationInfo != null && distanceKm != null
                        ? '$destinationInfo · $distanceKm km dari Jepara'
                        : destinationInfo ?? '$distanceKm km dari Jepara',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B5E52)),
                  ),
                ),
              ],
            ),
          ),
        ],

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

        ...couriers.map((courier) {
          final isSelected = selectedCourier?.name == courier.name;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: InkWell(
              onTap: () => onCourierSelected(courier),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
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
                      ? [BoxShadow(color: const Color(0xFFC0430E).withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? const Color(0xFFC0430E) : const Color(0xFFA89A8C),
                      size: 20,
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
                              // Badge tag dari backend
                              if (courier.tag != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: courier.tag!.contains('Termurah')
                                        ? const Color(0xFFE5F9E7)
                                        : courier.tag!.contains('Terpopuler')
                                            ? const Color(0xFFE8F0FE)
                                            : const Color(0xFFFFF0E6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    courier.tag!,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: courier.tag!.contains('Termurah')
                                          ? Colors.green[700]
                                          : courier.tag!.contains('Terpopuler')
                                              ? Colors.blue[700]
                                              : const Color(0xFFC0430E),
                                    ),
                                  ),
                                ),
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
        }),
      ],
    );
  }
}

