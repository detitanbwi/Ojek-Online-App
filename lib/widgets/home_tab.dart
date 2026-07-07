import 'package:flutter/material.dart';
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
                                "Banyuwangi, Indonesia",
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MapScreen(initialVehicleType: 'motor'),
                          ),
                        );
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MapScreen(initialVehicleType: 'mobil'),
                          ),
                        );
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
