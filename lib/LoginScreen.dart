import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'CustomerScreen.dart';
import 'CustomerRegisterScreen.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _driverEmailController = TextEditingController();
  final TextEditingController _driverPasswordController = TextEditingController();
  final TextEditingController _customerEmailController = TextEditingController();
  final TextEditingController _customerPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isDriverRole = true; // Selector variable
  final String backendUrl = 'https://ojek.wirodev.com/api';
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _isDriverRole ? 0 : 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _driverEmailController.dispose();
    _driverPasswordController.dispose();
    _customerEmailController.dispose();
    _customerPasswordController.dispose();
    super.dispose();
  }

  void _login() async {
    final email = _isDriverRole ? _driverEmailController.text.trim() : _customerEmailController.text.trim();
    final password = _isDriverRole ? _driverPasswordController.text.trim() : _customerPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan password wajib diisi!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (!_isDriverRole) {
      // Real Login for Customer
      try {
        final response = await http.post(
          Uri.parse('$backendUrl/customer/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
          }),
        );

        final result = jsonDecode(response.body);

        if (response.statusCode == 200 && result['success'] == true) {
          final data = result['data'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_logged_in', true);
          await prefs.setString('role', 'customer');
          await prefs.setString('customer_name', data['name']);
          await prefs.setString('customer_email', data['email']);
          await prefs.setInt('customer_id', data['id']);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CustomerScreen()),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'] ?? 'Login gagal.'), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      return;
    }

    // Normal Login for Driver
    final playerId = OneSignal.User.pushSubscription.id ?? '';

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/driver/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'onesignal_player_id': playerId,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['success'] == true) {
        final data = result['data'];
        final dbId = 'DRV-' + data['id'].toString().padLeft(4, '0');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('role', 'driver');
        await prefs.setString('driver_name', data['name']);
        await prefs.setString('driver_phone', data['phone']);
        await prefs.setString('driver_email', data['email']);
        await prefs.setString('driver_id', dbId);
        await prefs.setBool('is_online', true);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DriverHomePage()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Login gagal.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildFormContent({required bool isDriver}) {
    final Color accentColor = isDriver ? const Color(0xFF002B93) : const Color(0xFFCC5900);
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isDriver ? 'MASUK DRIVER PORTAL' : 'MASUK CUSTOMER PORTAL',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Demo mode login hint section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade800, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Akun Demo Pengembangan:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (isDriver) ...[
                  Text('• wiro@sableng.com (Wiro Sableng)', style: TextStyle(fontSize: 10.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600)),
                  Text('• bento@wirojek.com (Bento)', style: TextStyle(fontSize: 10.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600)),
                ] else ...[
                  Text('• angga@example.com (Angga)', style: TextStyle(fontSize: 10.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600)),
                  Text('• dewi@example.com (Dewi Puspita)', style: TextStyle(fontSize: 10.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 4),
                Text('Password: password123', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: isDriver ? _driverEmailController : _customerEmailController,
            style: const TextStyle(color: Colors.black87),
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: isDriver ? 'Email Driver' : 'Email Customer',
              labelStyle: const TextStyle(color: Colors.black45, fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black12)),
              prefixIcon: const Icon(Icons.email_outlined, color: Colors.black45),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: isDriver ? _driverPasswordController : _customerPasswordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: Colors.black45, fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black12)),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.black45),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.black45,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    isDriver ? 'Masuk Sekarang' : 'Masuk Customer',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
          ),
          
          if (!isDriver) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CustomerRegisterScreen()),
                );
              },
              child: RichText(
                text: const TextSpan(
                  text: 'Belum punya akun? ',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                  children: [
                    TextSpan(
                      text: 'Daftar Customer',
                      style: TextStyle(color: Color(0xFFCC5900), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 60),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo-transparent.png', height: 120, fit: BoxFit.contain),
                const SizedBox(height: 24),
                
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Role Selector Buttons
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_isDriverRole) return;
                                  setState(() => _isDriverRole = true);
                                  _pageController.animateToPage(0, duration: const Duration(milliseconds: 250), curve: Curves.decelerate);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _isDriverRole ? const Color(0xFF002B93) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'DRIVER',
                                    style: TextStyle(
                                      color: _isDriverRole ? Colors.white : Colors.black54,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (!_isDriverRole) return;
                                  setState(() => _isDriverRole = false);
                                  _pageController.animateToPage(1, duration: const Duration(milliseconds: 250), curve: Curves.decelerate);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !_isDriverRole ? const Color(0xFFCC5900) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'CUSTOMER',
                                    style: TextStyle(
                                      color: !_isDriverRole ? Colors.white : Colors.black54,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // PageView container with fixed height
                      SizedBox(
                        height: 425,
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _isDriverRole = index == 0;
                            });
                          },
                          children: [
                            _buildFormContent(isDriver: true),
                            _buildFormContent(isDriver: false),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
