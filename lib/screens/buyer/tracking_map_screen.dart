import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/order.dart';

class TrackingMapScreen extends StatefulWidget {
  final OrderModel order;

  const TrackingMapScreen({super.key, required this.order});

  @override
  State<TrackingMapScreen> createState() => _TrackingMapScreenState();
}

class _TrackingMapScreenState extends State<TrackingMapScreen> {
  late final MapController _mapController;
  Timer? _pollingTimer;

  // Jepara Coordinates
  final LatLng _shopLocation = const LatLng(-6.5888, 110.6686); // UMKM Hub Jepara
  final LatLng _buyerLocation = const LatLng(-6.5925, 110.6780); // Buyer Home
  late LatLng _courierLocation;

  double _courierProgress = 0.3; // Progress from shop (0.0) to buyer (1.0)
  late String _status;
  late final String _courierName;
  late final String _courierVehicle;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _status = widget.order.status.toLowerCase();

    // Map names based on chosen courier
    final courierProp = widget.order.courierName.isNotEmpty ? widget.order.courierName : 'Kartara Instant';
    if (courierProp.contains('J&T')) {
      _courierName = 'Rudi Santoso';
      _courierVehicle = 'Honda Supra Fit (H 4521 C)';
    } else if (courierProp.contains('JNE')) {
      _courierName = 'Budi Wijaya';
      _courierVehicle = 'Yamaha Mio Soul (H 8792 AP)';
    } else {
      _courierName = 'Ahmad Faisal';
      _courierVehicle = 'Honda Vario 160 (H 2931 KP)';
    }

    // Set initial courier position based on progress
    _updateCourierPosition();

    // Start 5-second polling if order is active (shipped or processing)
    if (_status == 'shipped' || _status == 'dikirim' || _status == 'dalam perjalanan' || _status == 'diproses' || _status == 'processing') {
      _startLiveTracking();
    } else if (_status == 'completed' || _status == 'selesai') {
      _courierProgress = 1.0;
      _updateCourierPosition();
    }
  }

  void _updateCourierPosition() {
    // Interpolate coordinate between shop and buyer home based on progress
    final lat = _shopLocation.latitude + (_buyerLocation.latitude - _shopLocation.latitude) * _courierProgress;
    final lng = _shopLocation.longitude + (_buyerLocation.longitude - _shopLocation.longitude) * _courierProgress;
    setState(() {
      _courierLocation = LatLng(lat, lng);
    });
  }

  void _startLiveTracking() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;

      setState(() {
        // Move courier 8% closer to destination every 5 seconds
        if (_courierProgress < 1.0) {
          _courierProgress += 0.08;
          if (_courierProgress >= 1.0) {
            _courierProgress = 1.0;
            _status = 'completed'; // auto-complete tracking
            timer.cancel();
          }
          _updateCourierPosition();
          
          // Animate map camera to focus on courier
          _mapController.move(_courierLocation, 15.0);
        }
      });
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C2C2C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lacak Pengiriman',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
            ),
            Text(
              'Invoice: #${widget.order.id}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B5E52)),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 1. Interactive OpenStreetMap Leaflet Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _courierLocation,
              initialZoom: 14.5,
              minZoom: 10,
              maxZoom: 18,
            ),
            children: [
              // Tile Layer using standard OpenStreetMap
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kartara.app',
              ),
              // Polyline route between shop and buyer home
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [_shopLocation, _buyerLocation],
                    strokeWidth: 4.0,
                    color: const Color(0xFFC0430E).withOpacity(0.6),
                    borderColor: const Color(0xFFC0430E),
                    borderStrokeWidth: 1.0,
                  ),
                ],
              ),
              // Markers Layer
              MarkerLayer(
                markers: [
                  // Shop Marker (Origin)
                  Marker(
                    point: _shopLocation,
                    width: 45,
                    height: 45,
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)]),
                      child: const Icon(Icons.store, color: Color(0xFFC0430E), size: 24),
                    ),
                  ),
                  // Buyer Marker (Destination)
                  Marker(
                    point: _buyerLocation,
                    width: 45,
                    height: 45,
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)]),
                      child: const Icon(Icons.home, color: Colors.blue, size: 24),
                    ),
                  ),
                  // Live Courier Marker
                  Marker(
                    point: _courierLocation,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: const BoxDecoration(color: Color(0xFFC0430E), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))]),
                      child: const Icon(Icons.motorcycle, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Courier Detail Float Card
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(color: Color(0xFFFFF0E6), shape: BoxShape.circle),
                        child: const Icon(Icons.person, color: Color(0xFFC0430E), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _courierName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _courierVehicle,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF6B5E52)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _status == 'completed' ? const Color(0xFFE5F9E7) : const Color(0xFFFFF0E6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _status == 'completed' ? 'Tiba' : 'Pengantaran',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _status == 'completed' ? Colors.green : const Color(0xFFC0430E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Color(0xFFE0D5C7)),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFC0430E)),
                      const SizedBox(width: 6),
                      Text(
                        _status == 'completed' ? 'Pesanan Anda telah tiba!' : 'Estimasi Tiba: 12 Menit',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
                      ),
                      const Spacer(),

                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Menghubungi kurir via WhatsApp...')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          elevation: 0,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Hubungi', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
