import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../MapScreen.dart';

class HomeTab extends StatefulWidget {
  final bool isDarkMode;

  const HomeTab({
    super.key,
    required this.isDarkMode,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  double _wiroRideScale = 1.0;
  double _wiroCarScale = 1.0;

  int? _activeOrderId;
  String? _activeOrderOrigin;
  String? _activeOrderDestination;
  int? _activeOrderPrice;
  String? _activeOrderStatus;
  double? _activeOrderDistance;

  String? _activeOrderDriverName;
  String? _activeOrderVehicle;
  String? _activeOrderPlate;
  String _userCity = "Menentukan lokasi...";

  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    _loadActiveOrder();
    _determineUserCity();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  void _determineUserCity() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _userCity = "Banyuwangi, Indonesia");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _userCity = "Banyuwangi, Indonesia");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _userCity = "Banyuwangi, Indonesia");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=10&addressdetails=1';
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'WirojekApp/1.0'
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];
        final city = address['city'] ?? address['town'] ?? address['municipality'] ?? address['county'] ?? address['state'] ?? 'Banyuwangi';
        setState(() {
          _userCity = "$city, Indonesia";
        });
      } else {
        setState(() => _userCity = "Banyuwangi, Indonesia");
      }
    } catch (e) {
      print("Error determining city: $e");
      setState(() => _userCity = "Banyuwangi, Indonesia");
    }
  }

  void _loadActiveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _activeOrderId = prefs.getInt('active_order_id');
      _activeOrderOrigin = prefs.getString('active_order_origin');
      _activeOrderDestination = prefs.getString('active_order_destination');
      _activeOrderPrice = prefs.getInt('active_order_price');
      _activeOrderStatus = prefs.getString('active_order_status');
      _activeOrderDistance = prefs.getDouble('active_order_distance');
      _activeOrderDriverName = prefs.getString('active_order_driver_name');
      _activeOrderVehicle = prefs.getString('active_order_driver_vehicle');
      _activeOrderPlate = prefs.getString('active_order_driver_plate');
    });

    if (_activeOrderId != null) {
      _startStatusChecking();
    } else {
      _statusCheckTimer?.cancel();
    }
  }

  void _startStatusChecking() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_activeOrderId == null) {
        timer.cancel();
        return;
      }
      try {
        final response = await http.get(Uri.parse('https://ojek.wirodev.com/api/customer/orders/$_activeOrderId/status'));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            final status = data['data']['status'];
            if (status == 'completed' || status == 'cancelled' || status == 'rejected') {
              timer.cancel();
              _clearActiveOrderPrefs();
            } else if (status == 'accepted') {
              final driver = data['data']['driver'];
              if (driver != null) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('active_order_status', 'accepted');
                await prefs.setString('active_order_driver_name', driver['name'] ?? 'Driver');
                await prefs.setString('active_order_driver_vehicle', driver['vehicle_type'] == 'motor' ? 'Honda Beat (Hitam)' : 'Toyota Avanza (Putih)');
                await prefs.setString('active_order_driver_plate', 'DK ${driver['id'] * 17} XY');
                _loadActiveOrder();
              }
            }
          }
        } else if (response.statusCode == 404) {
          timer.cancel();
          _clearActiveOrderPrefs();
        }
      } catch (e) {
        print("Error checking status: $e");
      }
    });
  }

  void _clearActiveOrderPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_order_id');
    await prefs.remove('active_order_origin');
    await prefs.remove('active_order_destination');
    await prefs.remove('active_order_price');
    await prefs.remove('active_order_status');
    await prefs.remove('active_order_distance');
    await prefs.remove('active_order_payment_type');
    await prefs.remove('active_order_driver_name');
    await prefs.remove('active_order_driver_vehicle');
    await prefs.remove('active_order_driver_plate');
    _loadActiveOrder();
  }



  String _formatRupiah(int amount) {
    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $formatted';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    // Palet Warna Identitas Wirojek
    const colorNavy = Color(0xFF002B93);
    const colorOrange = Color(0xFFCC5900);
    const colorPurple = Color(0xFF7C3AED);
    
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Card Colors (Bright adaptive colors)
    final bgRideCard = isDark ? const Color(0xFF0F1E36) : const Color(0xFFEFF6FF);
    final borderRideCard = isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE);
    
    final bgCarCard = isDark ? const Color(0xFF1E152A) : const Color(0xFFF5F3FF);
    final borderCarCard = isDark ? const Color(0xFF8B5CF6) : const Color(0xFFDDD6FE);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          // Reduced top padding from 20 to 10 to prevent pushing the content down
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================== 1. HEADER SECTION ====================
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo Wirojek - Compact size 40 with reduced margins
                  Image.asset(
                    isDark ? 'assets/logo-white.png' : 'assets/logo-transparent.png',
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  // Welcome text (with Expanded to prevent overflow)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Selamat Pagi, Angga",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                            fontFamily: 'Plus Jakarta Sans',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 13, color: colorOrange),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                _userCity,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: textSecondary,
                                  fontFamily: 'Plus Jakarta Sans',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // User Avatar
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colorNavy,
                    child: const Text(
                      "TA",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ==================== ACTIVE ORDER CARD ====================
              if (_activeOrderId != null) ...[
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MapScreen(initialVehicleType: 'motor'),
                      ),
                    ).then((_) => _loadActiveOrder());
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFCC5900).withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFCC5900).withOpacity(0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Pemesanan Aktif Berjalan",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontFamily: 'Plus Jakarta Sans',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Origin & Destination details
                        Row(
                          children: [
                            const Icon(Icons.circle, color: Color(0xFFCC5900), size: 10),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _activeOrderOrigin ?? '-',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0),
                          child: Icon(Icons.more_vert, size: 12, color: Colors.grey),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFF002B93), size: 12),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _activeOrderDestination ?? '-',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24, thickness: 1),
                        // Price & Driver details if matched
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Total Tarif",
                                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      _formatRupiah(_activeOrderPrice ?? 0),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFCC5900),
                                      ),
                                    ),
                                    if (_activeOrderDistance != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        "(${_activeOrderDistance!.toStringAsFixed(1)} km)",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white54 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            if (_activeOrderStatus == 'accepted' && _activeOrderDriverName != null)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _activeOrderDriverName!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_activeOrderVehicle!} • ${_activeOrderPlate!}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // ==================== 2. WIROJEK WALLET CARD ====================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [colorNavy, Color(0xFF0D1E4D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorNavy.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Saldo WiroWallet",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                                fontFamily: 'Plus Jakarta Sans',
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Rp 142.500",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Plus Jakarta Sans',
                              ),
                            ),
                          ],
                        ),
                        // QRIS Top Up Shortcut
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  "Top Up",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                )
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, color: Colors.white.withOpacity(0.6), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "Metode Pembayaran Default: Cash / Tunai",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontFamily: 'Plus Jakarta Sans',
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ==================== 3. GRID LAYANAN UTAMA ====================
              Text(
                "Pilih Layanan Wirojek",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
              const SizedBox(height: 14),
              
              Row(
                children: [
                  // Menu Item 1: WiroRide (Ojek Motor - Blue Theme)
                  Expanded(
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _wiroRideScale = 0.95),
                      onTapUp: (_) => setState(() => _wiroRideScale = 1.0),
                      onTapCancel: () => setState(() => _wiroRideScale = 1.0),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MapScreen(initialVehicleType: 'motor'),
                          ),
                        );
                        _loadActiveOrder();
                      },
                      child: Transform.scale(
                        scale: _wiroRideScale,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF15803D), // Rich dark green (Green 700)
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.35 : 0.15),
                                blurRadius: 14,
                                spreadRadius: 1,
                                offset: const Offset(0, 6),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 120,
                                  height: 90,
                                  decoration: const BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      'assets/images/wiro_ride.png',
                                      height: 90,
                                      width: 120,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.two_wheeler,
                                        color: Colors.white,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "WiroRide",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Plus Jakarta Sans',
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Ojek Motor Cepat",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Menu Item 2: WiroCar (Mobil Online - Purple Theme)
                  Expanded(
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _wiroCarScale = 0.95),
                      onTapUp: (_) => setState(() => _wiroCarScale = 1.0),
                      onTapCancel: () => setState(() => _wiroCarScale = 1.0),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MapScreen(initialVehicleType: 'mobil'),
                          ),
                        );
                        _loadActiveOrder();
                      },
                      child: Transform.scale(
                        scale: _wiroCarScale,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF15803D), // Rich dark green (Green 700)
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.35 : 0.15),
                                blurRadius: 14,
                                spreadRadius: 1,
                                offset: const Offset(0, 6),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 120,
                                  height: 90,
                                  decoration: const BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      'assets/images/wiro_car.png',
                                      height: 90,
                                      width: 120,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.directions_car,
                                        color: Colors.white,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "WiroCar",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Plus Jakarta Sans',
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Perjalanan Nyaman",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ==================== 4. PROMO SECTION INFO ====================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorOrange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.local_offer, color: colorOrange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Ada diskon kilat 24% menantimu di tab Promo hari ini!",
                        style: TextStyle(
                          fontSize: 12,
                          color: colorOrange,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
