import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class QrisPaymentPage extends StatefulWidget {
  final String orderId;
  final String price;
  final String apiUrl;

  const QrisPaymentPage({
    super.key,
    required this.orderId,
    required this.price,
    required this.apiUrl,
  });

  @override
  State<QrisPaymentPage> createState() => _QrisPaymentPageState();
}

class _QrisPaymentPageState extends State<QrisPaymentPage> {
  bool _isLoading = true;
  String? _qrCodeUrl;
  String? _midtransOrderId;
  String? _errorMessage;
  Timer? _statusCheckTimer;
  bool _isChecking = false;
  bool _paymentSuccess = false;

  @override
  void initState() {
    super.initState();
    generateQris();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> generateQris() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${widget.apiUrl}/driver/order/charge-qris'),
        body: {'order_id': widget.orderId},
      );

      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['success'] == true) {
        setState(() {
          _qrCodeUrl = result['data']['qr_code_url'];
          _midtransOrderId = result['data']['midtrans_order_id'];
          _isLoading = false;
        });
        
        // Start auto-polling for payment status every 3 seconds
        startStatusChecking();
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Gagal membuat tagihan QRIS.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error koneksi: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void startStatusChecking() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isChecking && !_paymentSuccess) {
        checkPaymentStatus();
      }
    });
  }

  Future<void> checkPaymentStatus() async {
    _isChecking = true;
    try {
      final response = await http.post(
        Uri.parse('${widget.apiUrl}/driver/order/check-payment'),
        body: {'order_id': widget.orderId},
      );

      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['success'] == true) {
        if (result['status'] == 'settlement' || result['status'] == 'capture') {
          _statusCheckTimer?.cancel();
          setState(() {
            _paymentSuccess = true;
          });
          
          // Auto transition back to home after showing success
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              // Pop back to home screen and return true to indicate success
              Navigator.pop(context, true);
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error polling payment status: $e");
    } finally {
      _isChecking = false;
    }
  }

  Future<void> simulatePaymentSuccess() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${widget.apiUrl}/driver/order/simulate-payment'),
        body: {'order_id': widget.orderId},
      );

      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['success'] == true) {
        _statusCheckTimer?.cancel();
        setState(() {
          _paymentSuccess = true;
          _isLoading = false;
        });
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal memicu simulasi.')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void openSimulatorAndCopy() async {
    if (_qrCodeUrl == null) return;
    
    // Copy the QR Code URL to clipboard
    await Clipboard.setData(ClipboardData(text: _qrCodeUrl!));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL QR Code disalin! Silakan tempelkan di simulator.'),
          backgroundColor: Colors.indigo,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        title: const Text('Pembayaran QRIS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isLoading) ...[
                const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Menyiapkan QRIS Midtrans...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ] else if (_paymentSuccess) ...[
                const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 100),
                const SizedBox(height: 24),
                const Text(
                  'PEMBAYARAN LUNAS!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Orderan selesai. Mengarahkan kembali ke dashboard...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ] else if (_errorMessage != null) ...[
                const Icon(Icons.error_outline, color: Colors.roseAccent, size: 80),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: generateQris,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Coba Lagi'),
                ),
              ] else ...[
                // Main QR View
                const Text(
                  'TUNJUKKAN QRIS KEPADA PENUMPANG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total Tagihan: Rp ${widget.price}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // QRIS Box Container
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.network(
                          _qrCodeUrl!,
                          width: 250,
                          height: 250,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox(
                              width: 250,
                              height: 250,
                              child: Center(
                                child: Text('Gagal memuat gambar QR', style: TextStyle(color: Colors.black54)),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Powered by Midtrans Sandbox',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 8,
                      height: 8,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Menunggu pembayaran... (Auto-Check aktif)',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Action Buttons
                ElevatedButton.icon(
                  onPressed: openSimulatorAndCopy,
                  icon: const Icon(Icons.copy),
                  label: const Text('Salin URL QR Code Simulator'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.08),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                ElevatedButton(
                  onPressed: simulatePaymentSuccess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: const Text(
                    'ANGGAP SELESAI (Simulasi Sukses)',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
