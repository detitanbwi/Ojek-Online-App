import 'package:flutter/material.dart';
import '../utils/formatter.dart';
import 'custom_pull_to_refresh.dart';

class HistoryTab extends StatelessWidget {
  final bool isOnline;
  final bool isDarkMode;
  final bool loadingHistory;
  final bool isRefreshing;
  final List<dynamic> historyOrders;
  final Color titleColor;
  final Color subTitleColor;
  final Color cardBg;
  final Color dividerColor;

  final Future<void> Function() onRefresh;
  final ValueChanged<Map<String, dynamic>> onOrderTap;

  const HistoryTab({
    super.key,
    required this.isOnline,
    required this.isDarkMode,
    required this.loadingHistory,
    required this.isRefreshing,
    required this.historyOrders,
    required this.titleColor,
    required this.subTitleColor,
    required this.cardBg,
    required this.dividerColor,
    required this.onRefresh,
    required this.onOrderTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOnline) {
      return Center(
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
              'Aktifkan switch Online di Dashboard untuk memuat riwayat order.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subTitleColor.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return CustomPullToRefresh(
      isRefreshing: isRefreshing,
      onRefresh: onRefresh,
      subTitleColor: subTitleColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DAFTAR RIWAYAT ORDERAN',
                  style: TextStyle(color: subTitleColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
                if (loadingHistory)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: titleColor),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            loadingHistory && historyOrders.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: CircularProgressIndicator(color: Colors.amber),
                  ),
                )
              : historyOrders.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Text('Belum ada riwayat orderan.', style: TextStyle(color: subTitleColor.withOpacity(0.5))),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: historyOrders.length,
                    itemBuilder: (context, index) {
                      final order = historyOrders[index];
                      final bool isCompleted = order['status'] == 'completed';
                      final bool isCancelled = order['status'] == 'cancelled' || order['status'] == 'rejected';
                      
                      // Dynamic Gradient background for History Cards
                      final cardGradient = isDarkMode
                          ? const LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Colors.white, Color(0xFFF8FAFC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            );

                      // Price text color: vibrant amber in dark mode, readable deep brown-amber in light mode
                      final Color priceColor = isDarkMode ? const Color(0xFFFFB000) : const Color(0xFFB45309);

                      return GestureDetector(
                        onTap: () => onOrderTap(Map<String, dynamic>.from(order)),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: cardGradient,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: dividerColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDarkMode ? 0.12 : 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Status Icon
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isCompleted 
                                    ? Colors.green.withOpacity(0.1) 
                                    : (isCancelled ? Colors.red.withOpacity(0.1) : Colors.amber.withOpacity(0.1)),
                                child: Icon(
                                  isCompleted 
                                      ? Icons.check 
                                      : (isCancelled ? Icons.close : Icons.access_time),
                                  color: isCompleted 
                                      ? Colors.green 
                                      : (isCancelled ? Colors.redAccent : Colors.amber),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              
                              // Text Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Order #${order['id']} - ${order['service_type'] == 'wiro_car' ? 'WiroCar' : 'WiroRide'} (${order['payment_type'] == 'qris' ? 'QRIS' : 'Tunai'})',
                                      style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Ke: ${order['destination']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: subTitleColor, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Price
                              Text(
                                  'Rp ${formatPrice(order['price'].toString().split('.')[0])}',
                                style: TextStyle(color: priceColor, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
