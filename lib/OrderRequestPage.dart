import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class OrderRequestPage extends StatefulWidget {
  final String orderId;
  final String origin;
  final String destination;
  final String price;
  final bool autoAccept;

  const OrderRequestPage({
    super.key,
    required this.orderId,
    required this.origin,
    required this.destination,
    required this.price,
    this.autoAccept = false,
  });

  @override
  State<OrderRequestPage> createState() => _OrderRequestPageState();
}

class _OrderRequestPageState extends State<OrderRequestPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  static const platform = MethodChannel('com.wirodev.ojol/intent');
  final String apiUrl = 'https://ojek.wirodev.com/api';

  Timer? _countdownTimer;
  int _secondsRemaining = 10;
  bool _actionPerformed = false;

  @override
  void initState() {
    super.initState();
    // Setup animation controller for pulsing alert ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.8,
      upperBound: 1.2,
    )..repeat(reverse: true);

    // Auto accept order if triggered from the notification banner "Ambil" button
    if (widget.autoAccept) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        acceptOrder();
      });
    }

    // Start 10 seconds auto-dismiss countdown
    startCountdown();
  }

  void startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _countdownTimer?.cancel();
            autoRejectOrder();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String formatPrice(String price) {
    final intVal = int.tryParse(price.replaceAll('.', ''));
    if (intVal == null) return price;
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return intVal.toString().replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  // Dismiss native notification bar alert
  void dismissNativeNotification() async {
    try {
      await platform.invokeMethod('dismissNotification', {'order_id': widget.orderId});
    } catch (e) {
      debugPrint("Failed to dismiss notification: $e");
    }
  }

  Future<void> sendStatusToBackend(String status) async {
    try {
      await http.post(
        Uri.parse('$apiUrl/driver/order/status'),
        body: {
          'order_id': widget.orderId,
          'status': status,
        },
      );
    } catch (e) {
      debugPrint("Error sending status to backend: $e");
    }
  }

  void acceptOrder() async {
    if (_actionPerformed) return;
    _actionPerformed = true;
    _countdownTimer?.cancel();
    
    dismissNativeNotification();
    await sendStatusToBackend('accepted');

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Order Diterima'),
          ],
        ),
        content: const Text('Anda telah berhasil mengambil orderan ini. Navigasi rute segera dimulai.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close order request page
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void declineOrder() async {
    if (_actionPerformed) return;
    _actionPerformed = true;
    _countdownTimer?.cancel();

    dismissNativeNotification();
    await sendStatusToBackend('rejected');

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void autoRejectOrder() async {
    if (_actionPerformed) return;
    _actionPerformed = true;

    dismissNativeNotification();
    await sendStatusToBackend('rejected');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order otomatis ditolak karena tidak direspon dalam 10 detik.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A), // Slate 900
              Color(0xFF1E293B), // Slate 800
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Scrollable content area containing the timer and the ride details card
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      // 1. Glowing countdown timer
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ScaleTransition(
                              scale: _pulseController,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.amber.withOpacity(0.2), width: 2),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                value: _secondsRemaining / 10.0,
                                strokeWidth: 4,
                                backgroundColor: Colors.white.withOpacity(0.08),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                              ),
                            ),
                            Text(
                              '$_secondsRemaining',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 2. Alert Header Title
                      const Text(
                        'ADA ORDERAN MASUK!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order ID: #${widget.orderId}',
                        style: TextStyle(
                          fontSize: 13, 
                          color: Colors.white.withOpacity(0.4),
                          fontWeight: FontWeight.w500
                        ),
                      ),
                      
                      const SizedBox(height: 28),

                      // 3. Address Route & Price Details Card (Glassmorphic design)
                      Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Connected route timeline layout
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left timeline connector
                                Column(
                                  children: [
                                    const SizedBox(height: 4),
                                    const Icon(Icons.my_location, color: Colors.greenAccent, size: 20),
                                    Container(
                                      width: 1.5,
                                      height: 65,
                                      margin: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: const BoxDecoration(
                                        color: Colors.white12,
                                      ),
                                    ),
                                    const Icon(Icons.location_on, color: Colors.redAccent, size: 22),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                // Right Address Texts
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Origin Address
                                      Text(
                                        'TITIK JEMPUT',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.3),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.origin,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 28), // Matches the height of connector line
                                      
                                      // Destination Address
                                      Text(
                                        'TITIK TUJUAN',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.3),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.destination,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            const Divider(color: Colors.white12, thickness: 1),
                            const SizedBox(height: 12),
                            
                            // Glowing Amber Net Fare Box
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.amber.shade700.withOpacity(0.12),
                                    Colors.amber.shade900.withOpacity(0.04),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.amber.shade700.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'TARIF BERSIH',
                                        style: TextStyle(
                                          color: Colors.amber.shade300,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Pendapatan bersih Anda',
                                        style: TextStyle(color: Colors.white38, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Rp ${formatPrice(widget.price)}',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Sticky bottom action buttons container (Decline & Swipe to accept)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.6),
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glassmorphic Swipe To Accept Button
                    SwipeButton(
                      text: "Geser ke kanan untuk Terima",
                      onSwipeComplete: acceptOrder,
                    ),
                    const SizedBox(height: 12),
                    // Elegant Reject button
                    TextButton(
                      onPressed: declineOrder,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      ),
                      child: Text(
                        'LEWATKAN PESANAN',
                        style: TextStyle(
                          fontSize: 13, 
                          fontWeight: FontWeight.w800, 
                          color: Colors.redAccent.withOpacity(0.8),
                          letterSpacing: 1.2
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Glassmorphic Swipe Button Widget
class SwipeButton extends StatefulWidget {
  final VoidCallback onSwipeComplete;
  final String text;
  
  const SwipeButton({
    super.key, 
    required this.onSwipeComplete, 
    required this.text
  });

  @override
  State<SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<SwipeButton> {
  double _position = 0.0;
  bool _isFinished = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxPosition = constraints.maxWidth - 58; // 58 is the button diameter (60 - padding)
        return Container(
          height: 60,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.emerald.withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.emerald.withOpacity(0.18)),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  widget.text,
                  style: const TextStyle(
                    color: Colors.emeraldAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Positioned(
                left: _position,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_isFinished) return;
                    setState(() {
                      _position += details.delta.dx;
                      if (_position < 0) _position = 0;
                      if (_position > maxPosition) _position = maxPosition;
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_isFinished) return;
                    if (_position >= maxPosition * 0.85) {
                      setState(() {
                        _position = maxPosition;
                        _isFinished = true;
                      });
                      widget.onSwipeComplete();
                    } else {
                      setState(() {
                        _position = 0;
                      });
                    }
                  },
                  child: Container(
                    width: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.emeraldAccent, Colors.teal],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.emerald.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
