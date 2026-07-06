import 'package:flutter/material.dart';
import '../utils/formatter.dart';
import 'custom_pull_to_refresh.dart';

class DashboardTab extends StatelessWidget {
  final String driverName;
  final double driverBalance;
  final bool isOnline;
  final bool isLoading;
  final bool isRefreshing;
  final bool isDarkMode;
  final List<dynamic> historyOrders;
  final Map<String, dynamic>? activeOrder;
  final Color titleColor;
  final Color subTitleColor;
  final Color cardBg;
  final Color dividerColor;
  
  final Future<void> Function() onRefresh;
  final ValueChanged<bool> onOnlineChanged;
  final VoidCallback onActiveOrderTap;

  const DashboardTab({
    super.key,
    required this.driverName,
    required this.driverBalance,
    required this.isOnline,
    required this.isLoading,
    required this.isRefreshing,
    required this.isDarkMode,
    required this.historyOrders,
    required this.activeOrder,
    required this.titleColor,
    required this.subTitleColor,
    required this.cardBg,
    required this.dividerColor,
    required this.onRefresh,
    required this.onOnlineChanged,
    required this.onActiveOrderTap,
  });

  @override
  Widget build(BuildContext context) {
    final completedOrdersCount = historyOrders.where((o) => o['status'] == 'completed').length;
    final totalEarnings = historyOrders
        .where((o) => o['status'] == 'completed')
        .map((o) => double.tryParse(o['driver_fare']?.toString() ?? '0') ?? 0.0)
        .fold(0.0, (sum, item) => sum + item);

    return CustomPullToRefresh(
      isRefreshing: isRefreshing,
      onRefresh: onRefresh,
      subTitleColor: subTitleColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: Column(
          children: [
            // 1. Profile and Online/Offline Toggle Header Card (Styled as a premium Elevated Blue Card)
            Card(
              margin: const EdgeInsets.only(left: 20, right: 20, top: 16),
              elevation: 6,
              shadowColor: const Color(0xFF1E3A8A).withOpacity(0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Premium Dark Blue Gradient Background (Spans full height dynamically)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)], // Dark Navy Slate to Indigo Blue
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    // Subtle transparent design overlapping circles (matching uploaded image aesthetics)
                    Positioned(
                      right: -40,
                      top: -40,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.04),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 20,
                      bottom: -60,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.02),
                        ),
                      ),
                    ),
                    // Blue Card content elements
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.white.withOpacity(0.12),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      driverName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.account_balance_wallet_rounded, color: Colors.amber, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          isOnline 
                                              ? 'Saldo: Rp ${formatPrice(driverBalance.toString().split('.')[0])}'
                                              : 'Offline - Saldo Terkunci',
                                          style: const TextStyle(
                                            color: Colors.amber, // Clear Gold Text on Blue Card is highly readable
                                            fontSize: 14, 
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 18),
                          Divider(color: Colors.white.withOpacity(0.08)),
                          const SizedBox(height: 6),
                          
                          // Online/Offline Toggle Switch Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isOnline ? Colors.greenAccent : Colors.white24,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isOnline ? 'ONLINE & SIAP MENERIMA ORDER' : 'OFFLINE (TIDAK AKTIF)',
                                    style: TextStyle(
                                      color: isOnline ? Colors.greenAccent : Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.amber),
                                    )
                                  : Switch(
                                      value: isOnline,
                                      activeColor: Colors.greenAccent,
                                      activeTrackColor: Colors.green.withOpacity(0.2),
                                      inactiveThumbColor: Colors.white30,
                                      inactiveTrackColor: Colors.white10,
                                      onChanged: onOnlineChanged,
                                    ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 2. Active Order Banner / Dropcard (Pulsing card)
            if (isOnline && activeOrder != null && activeOrder!['status'] == 'accepted') ...[
              GestureDetector(
                onTap: onActiveOrderTap,
                child: Container(
                  margin: const EdgeInsets.only(left: 20, right: 20, top: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)], // Dark Blue Gradient
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.15),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.amber, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PESANAN SEDANG BERJALAN',
                              style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tarif: Rp ${formatPrice(activeOrder!['price'].toString().split('.')[0])} (${activeOrder!['payment_type'] == 'qris' ? 'QRIS' : 'Tunai'})',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ke: ${activeOrder!['destination']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 3. Stats and Overview Content
            if (!isOnline) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.power_settings_new_rounded,
                        size: 64,
                        color: subTitleColor.withOpacity(0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Anda Sedang Offline',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Aktifkan switch Online di atas untuk mulai menerima pesanan ojek.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: subTitleColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Stats Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 90,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: isDarkMode
                              ? const LinearGradient(
                                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [Colors.white, Color(0xFFF8FAFC)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: dividerColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDarkMode ? 0.15 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ORDER SELESAI',
                              style: TextStyle(
                                color: subTitleColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$completedOrdersCount',
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        height: 90,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: isDarkMode
                              ? const LinearGradient(
                                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [Colors.white, Color(0xFFF8FAFC)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: dividerColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDarkMode ? 0.15 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PENDAPATAN',
                              style: TextStyle(
                                color: subTitleColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rp ${formatPrice(totalEarnings.toStringAsFixed(0))}',
                              style: TextStyle(
                                color: isDarkMode ? Colors.greenAccent : Colors.green.shade800,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Status Active Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isDarkMode
                      ? const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFEFF6FF), Colors.white],
                        ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDarkMode ? dividerColor : const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.wifi_tethering_rounded,
                        color: Colors.green,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sistem WiroJek Aktif',
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Aplikasi siap menerima pesanan masuk secara real-time. Tetap online untuk mendapatkan orderan terdekat.',
                            style: TextStyle(
                              color: subTitleColor,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }
}
