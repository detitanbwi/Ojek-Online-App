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
  final String apiUrl = 'http://192.168.1.16/ojek-online/WebAPI/public/api';

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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Adapt colors based on system dark/light theme
    final Color backgroundColor = isDark ? const Color(0xFF00113B) : Colors.grey[100]!;
    final Color cardColor = isDark ? const Color(0xFF0C2461) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF00113B);
    final Color subtitleColor = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Section - Header with pulsing ring and circular timer countdown
            Padding(
              padding: const EdgeInsets.only(top: 40.0),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ScaleTransition(
                        scale: _pulseController,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCC5900).withOpacity(isDark ? 0.2 : 0.1),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: (isDark ? const Color(0xFFCC5900) : Colors.orangeAccent).withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: CircularProgressIndicator(
                          value: _secondsRemaining / 10.0,
                          strokeWidth: 6,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                      ),
                      Text(
                        '$_secondsRemaining',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'ADA ORDERAN MASUK!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Order ID: #${widget.orderId}',
                    style: TextStyle(fontSize: 14, color: subtitleColor),
                  ),
                ],
              ),
            ),

            // Middle Section - Route and Price Details Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Card(
                color: cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: isDark ? 10 : 3,
                shadowColor: Colors.black26,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Origin Info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.my_location, color: Colors.green, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TITIK JEMPUT',
                                  style: TextStyle(color: subtitleColor.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.origin,
                                  style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(color: Colors.white10, thickness: 1, indent: 36),
                      ),
                      // Destination Info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, color: Colors.redAccent, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TITIK TUJUAN',
                                  style: TextStyle(color: subtitleColor.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.destination,
                                  style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Divider(color: Colors.black12, thickness: 1.5),
                      ),
                      // Price Info
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'TARIF BERSIH',
                              style: TextStyle(color: subtitleColor.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Rp ${formatPrice(widget.price)}',
                              style: const TextStyle(
                                color: Color(0xFFFF8C00),
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
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

            // Bottom Section - Swipe To Accept and Decline Button
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 40.0),
              child: Column(
                children: [
                  // Swipe To Accept Button
                  SwipeButton(
                    text: "Sapu kanan untuk Terima",
                    onSwipeComplete: acceptOrder,
                  ),
                  const SizedBox(height: 16),
                  // Decline Text Button
                  TextButton(
                    onPressed: declineOrder,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    ),
                    child: const Text(
                      'TOLAK PESANAN',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Swipe Button Widget
class SwipeButton extends StatefulWidget {
  final VoidCallback onSwipeComplete;
  final String text;
  const SwipeButton({super.key, required this.onSwipeComplete, required this.text});

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
        final double maxPosition = constraints.maxWidth - 60; // 60 is the button size
        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.green.withOpacity(0.35)),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  widget.text,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Positioned(
                left: _position,
                top: 1,
                bottom: 1,
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
                    width: 58,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 20,
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
