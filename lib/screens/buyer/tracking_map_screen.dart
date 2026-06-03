import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/order.dart';
import '../../providers/tracking_provider.dart';
import '../../providers/app_state.dart';

// Koordinat toko UMKM Hub Jepara
const _origin = LatLng(-6.5888, 110.6686);

class TrackingMapScreen extends ConsumerStatefulWidget {
  final OrderModel order;

  const TrackingMapScreen({super.key, required this.order});

  @override
  ConsumerState<TrackingMapScreen> createState() => _TrackingMapScreenState();
}

class _TrackingMapScreenState extends ConsumerState<TrackingMapScreen> {
  final MapController _mapController = MapController();
  bool _isCentered = false;

  @override
  void initState() {
    super.initState();
    // Start polling jika order sedang dikirim
    if (widget.order.isShipped || widget.order.canTrackMap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(courierLocationProvider(widget.order.id).notifier).startPolling(
              widget.order.id,
              initialPosition: _origin,
            );
      });
    }
  }

  @override
  void dispose() {
    // Stop polling saat screen ditutup
    ref.read(courierLocationProvider(widget.order.id).notifier).stopPolling();
    super.dispose();
  }

  // Estimasi posisi tujuan berdasarkan nama kota dan kode pos
  LatLng get _destinationLatLng {
    final cityLower = widget.order.destinationCity.toLowerCase();
    
    // 1. Cek Kota
    if (cityLower.contains('malang')) return const LatLng(-7.9825, 112.6308);
    if (cityLower.contains('surabaya')) return const LatLng(-7.2575, 112.7521);
    if (cityLower.contains('jakarta')) return const LatLng(-6.2088, 106.8456);
    if (cityLower.contains('bandung')) return const LatLng(-6.9175, 107.6191);
    if (cityLower.contains('yogyakarta') || cityLower.contains('jogja')) return const LatLng(-7.7956, 110.3695);
    if (cityLower.contains('solo') || cityLower.contains('surakarta')) return const LatLng(-7.5697, 110.8315);
    if (cityLower.contains('denpasar') || cityLower.contains('bali')) return const LatLng(-8.6705, 115.2126);
    if (cityLower.contains('medan')) return const LatLng(3.5896, 98.6739);
    if (cityLower.contains('makassar')) return const LatLng(-5.1477, 119.4327);
    if (cityLower.contains('semarang')) return const LatLng(-6.9947, 110.4100);

    // 2. Cek Kode Pos (jika kota tidak ada di string)
    if (widget.order.postalCode.isNotEmpty) {
      final postal = widget.order.postalCode;
      if (postal.startsWith('65')) return const LatLng(-7.9825, 112.6308); // Malang
      if (postal.startsWith('50')) return const LatLng(-6.9947, 110.4100); // Semarang
      if (postal.startsWith('10')) return const LatLng(-6.1744, 106.8227); // Jakarta
      if (postal.startsWith('60')) return const LatLng(-7.2575, 112.7521); // Surabaya
      if (postal.startsWith('40')) return const LatLng(-6.9175, 107.6191); // Bandung
      if (postal.startsWith('55')) return const LatLng(-7.7956, 110.3695); // Yogyakarta
      if (postal.startsWith('57')) return const LatLng(-7.5697, 110.8315); // Solo
      if (postal.startsWith('80')) return const LatLng(-8.6705, 115.2126); // Denpasar
      if (postal.startsWith('20')) return const LatLng(3.5896, 98.6739); // Medan
      if (postal.startsWith('90')) return const LatLng(-5.1477, 119.4327); // Makassar
    }
    // Default: Semarang
    return const LatLng(-6.9947, 110.4100);
  }

  @override
  Widget build(BuildContext context) {
    final courierState = ref.watch(courierLocationProvider(widget.order.id));
    final courierPosition = courierState.position ?? _origin;

    // Auto-stop polling jika selesai
    if (courierState.isCompleted && courierState.isPolling) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(courierLocationProvider(widget.order.id).notifier).stopPolling(completed: true);
      });
    }

    // Center map ke kurir pertama kali
    if (!_isCentered && courierState.source != 'idle') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(courierPosition, 11.0);
          setState(() => _isCentered = true);
        }
      });
    }

    final progress = courierState.progress;
    final status = widget.order.status.toLowerCase();
    final isCompleted = status == 'selesai' || status == 'completed';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C2C2C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Lacak Pengiriman',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
        ),
        actions: [
          if (courierState.isPolling)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC0430E)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar linear pengiriman
          _buildProgressBar(progress, isCompleted),

          // Map section
          Expanded(
            child: Stack(
              children: [
                // OpenStreetMap
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: courierPosition,
                    initialZoom: 11,
                    minZoom: 7,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.kartara.app',
                    ),

                    // Route line (toko → kurir → tujuan)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [_origin, courierPosition, _destinationLatLng],
                          strokeWidth: 4.0,
                          color: const Color(0xFFC0430E).withValues(alpha: 0.7),
                          strokeJoin: StrokeJoin.round,
                        ),
                      ],
                    ),

                    // Markers
                    MarkerLayer(
                      markers: [
                        // Toko asal
                        Marker(
                          point: _origin,
                          width: 60,
                          height: 70,
                          child: _buildMarker(
                            icon: Icons.storefront_rounded,
                            label: 'Kartara Hub',
                            bg: const Color(0xFF1A1A1A),
                          ),
                        ),

                        // Tujuan pembeli
                        Marker(
                          point: _destinationLatLng,
                          width: 60,
                          height: 70,
                          child: _buildMarker(
                            icon: Icons.home_rounded,
                            label: 'Tujuan',
                            bg: const Color(0xFF166534),
                          ),
                        ),

                        // Posisi kurir (hanya jika tidak cancelled/pending)
                        if (!isCompleted && widget.order.canTrackMap)
                          Marker(
                            point: courierPosition,
                            width: 60,
                            height: 80,
                            child: Column(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC0430E),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFC0430E).withValues(alpha: 0.5),
                                        blurRadius: 12,
                                        spreadRadius: 3,
                                      )
                                    ],
                                  ),
                                  child: const Icon(Icons.motorcycle, color: Colors.white, size: 22),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.order.courierName.split(' ').first,
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Status badge di peta
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildStatusBadge(status, isCompleted)),
                ),

                // Legend
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: _buildLegend(),
                ),
              ],
            ),
          ),

          // Bottom panel info kurir
          _buildBottomPanel(context, isCompleted),
        ],
      ),

      // FAB: center ke posisi kurir
      floatingActionButton: widget.order.canTrackMap
          ? FloatingActionButton.small(
              backgroundColor: const Color(0xFFC0430E),
              onPressed: () => _mapController.move(courierPosition, 13.0),
              tooltip: 'Pusat ke Kurir',
              child: const Icon(Icons.my_location, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildProgressBar(double progress, bool isCompleted) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Jepara Hub 🏪', style: TextStyle(fontSize: 10, color: Color(0xFF6B5E52))),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC0430E)),
              ),
              const Text('Tujuan 🏠', style: TextStyle(fontSize: 10, color: Color(0xFF6B5E52))),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: isCompleted ? 1.0 : progress,
              backgroundColor: const Color(0xFFE0D5C7),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC0430E)),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isCompleted) {
    Color bg;
    String label;
    if (isCompleted) {
      bg = const Color(0xFF166534);
      label = '✅ Pesanan Selesai';
    } else if (status.contains('kirim') || status.contains('ship')) {
      bg = const Color(0xFF1A5276);
      label = '🚚 Dalam Perjalanan';
    } else if (status.contains('proses')) {
      bg = const Color(0xFFC0430E);
      label = '⚙️ Sedang Diproses';
    } else {
      bg = Colors.grey[700]!;
      label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMarker({required IconData icon, required String label, required Color bg}) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)]),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legendItem(Icons.storefront_rounded, const Color(0xFF1A1A1A), 'Toko Kartara'),
          const SizedBox(height: 4),
          _legendItem(Icons.motorcycle, const Color(0xFFC0430E), 'Posisi Kurir'),
          const SizedBox(height: 4),
          _legendItem(Icons.home_rounded, const Color(0xFF166534), 'Lokasi Tujuan'),
        ],
      ),
    );
  }

  Widget _legendItem(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF2C2C2C))),
      ],
    );
  }

  Widget _buildBottomPanel(BuildContext context, bool isCompleted) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: Color(0xFFFFF0E6), shape: BoxShape.circle),
                  child: const Icon(Icons.person, color: Color(0xFFC0430E)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.order.courierName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2C2C2C)),
                      ),
                      Text(
                        widget.order.courierVehicle,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B5E52)),
                      ),
                    ],
                  ),
                ),
                Text(
                  'ETA: ${widget.order.displayEta}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC0430E)),
                ),
              ],
            ),

            if (!isCompleted && widget.order.isShipped) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ref.read(ordersProvider.notifier).updateOrderStatus(widget.order.id, 'selesai');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Terima kasih! Pesanan telah ditandai selesai.'),
                          backgroundColor: Color(0xFF166534),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      Navigator.pop(context);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF166534),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text(
                    'Barang Sudah Diterima',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
