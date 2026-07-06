import 'package:flutter/material.dart';
import '../utils/formatter.dart';
import 'custom_pull_to_refresh.dart';

class ProfileTab extends StatelessWidget {
  final String driverName;
  final String driverEmail;
  final String driverPhone;
  final double driverBalance;
  final String driverId;
  final bool isDarkMode;
  final bool isRefreshing;
  final Color titleColor;
  final Color subTitleColor;
  final Color cardBg;
  final Color dividerColor;

  final VoidCallback onLogoutTap;
  final Future<void> Function() onRefresh;

  const ProfileTab({
    super.key,
    required this.driverName,
    required this.driverEmail,
    required this.driverPhone,
    required this.driverBalance,
    required this.driverId,
    required this.isDarkMode,
    required this.isRefreshing,
    required this.titleColor,
    required this.subTitleColor,
    required this.cardBg,
    required this.dividerColor,
    required this.onLogoutTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPullToRefresh(
      isRefreshing: isRefreshing,
      onRefresh: onRefresh,
      subTitleColor: subTitleColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Header layout with driver avatar and ID Badge
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                  child: Icon(
                    Icons.person,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  driverName,
                  style: TextStyle(color: titleColor, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                // Driver ID Badge (Moved here to clear Dashboard card)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Driver ID: $driverId',
                    style: TextStyle(
                      color: isDarkMode ? Colors.amber : Colors.amber.shade900, 
                      fontSize: 13, 
                      fontWeight: FontWeight.w800, 
                      fontFamily: 'monospace'
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Profile Details Card Form (Read only with clean display)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INFORMASI AKUN',
                  style: TextStyle(color: subTitleColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
                const SizedBox(height: 24),
                
                // Details row-by-row
                buildDetailRow(Icons.person, 'Nama Lengkap', driverName, titleColor, subTitleColor),
                const SizedBox(height: 16),
                buildDetailRow(Icons.email, 'Alamat Email', driverEmail, titleColor, subTitleColor),
                const SizedBox(height: 16),
                buildDetailRow(Icons.phone, 'Nomor HP', driverPhone, titleColor, subTitleColor),
                const SizedBox(height: 16),
                buildDetailRow(Icons.account_balance_wallet, 'Saldo Dompet', 'Rp ' + formatPrice(driverBalance.toString().split('.')[0]), titleColor, subTitleColor),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Logout Button
          ElevatedButton(
            onPressed: onLogoutTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.1),
              foregroundColor: Colors.redAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, size: 20),
                SizedBox(width: 8),
                Text('Keluar dari Aplikasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget buildDetailRow(IconData icon, String label, String value, Color titleColor, Color subTitleColor) {
    return Row(
      children: [
        Icon(icon, color: subTitleColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: subTitleColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: titleColor, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}
