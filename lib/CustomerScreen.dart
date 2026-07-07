import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/home_tab.dart';
import 'LoginScreen.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  int _selectedIndex = 0;
  String _customerName = "Angga";
  String _customerEmail = "angga@example.com";
  bool _isDarkMode = true; // State for theme mode

  @override
  void initState() {
    super.initState();
    _loadCustomerInfo();
  }

  void _loadCustomerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customerName = prefs.getString('customer_name') ?? "Angga";
      _customerEmail = prefs.getString('customer_email') ?? "angga@example.com";
      _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    });
  }

  void _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await prefs.setBool('is_dark_mode', _isDarkMode);
  }

  void _performLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode;
    
    // Dynamically set system status bar overlay for readability
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    ));

    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

    final List<Widget> tabs = [
      HomeTab(isDarkMode: _isDarkMode),
      _buildPlaceholderTab(Icons.history, "Aktivitas", "Riwayat pemesanan WiroRide & WiroCar Anda akan muncul di sini."),
      _buildPlaceholderTab(Icons.local_offer, "Promo & Diskon", "Ada diskon kilat 24% menantimu di tab Promo hari ini! Gunakan kode WIRO24."),
      _buildProfileTab(),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: IndexedStack(
        index: _selectedIndex,
        children: tabs,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            labelTextStyle: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return TextStyle(
                  color: isDark ? const Color(0xFFCC5900) : const Color(0xFF002B93),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                );
              }
              return TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 12,
              );
            }),
            iconTheme: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return IconThemeData(
                  color: isDark ? const Color(0xFFCC5900) : const Color(0xFF002B93),
                  size: 24,
                );
              }
              return IconThemeData(
                color: isDark ? Colors.white60 : Colors.black45,
                size: 24,
              );
            }),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          backgroundColor: isDark ? const Color(0xFF151B2C) : Colors.white,
          indicatorColor: isDark
              ? const Color(0xFFCC5900).withOpacity(0.2)
              : const Color(0xFF002B93).withOpacity(0.12),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Aktivitas',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_offer_outlined),
              selectedIcon: Icon(Icons.local_offer),
              label: 'Promo',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(IconData icon, String title, String subtitle) {
    final isDark = _isDarkMode;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: const Color(0xFF002B93).withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    final isDark = _isDarkMode;
    final bgCard = isDark ? const Color(0xFF151B2C) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Color(0xFF002B93),
                child: Icon(Icons.person, color: Colors.white, size: 44),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _customerName,
                style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                _customerEmail,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            const SizedBox(height: 32),

            // Theme Settings Card Toggle (Adaptive Light / Dark Mode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withOpacity(0.12)),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  color: isDark ? Colors.amber : Colors.orange,
                ),
                title: Text(
                  'Tema Gelap',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Switch(
                  value: isDark,
                  onChanged: (value) => _toggleTheme(),
                  activeColor: const Color(0xFFCC5900),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withOpacity(0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INFORMASI PENGGUNA',
                    style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, color: Colors.grey),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nama Lengkap', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(_customerName, style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined, color: Colors.grey),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Alamat Email', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(_customerEmail, style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _performLogout,
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
                  Text('Keluar Akun', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
