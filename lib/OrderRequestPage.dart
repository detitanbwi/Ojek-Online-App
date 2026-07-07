import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'QrisPaymentPage.dart';

class OrderRequestPage extends StatefulWidget {
  final String orderId;
  final String origin;
  final String destination;
  final String price;
  final bool autoAccept;
  final String? passengerName;
  final String? paymentType;
  final String? status;
  final String? adminFee;
  final String? driverFare;
  final String? serviceType;

  const OrderRequestPage({
    super.key,
    required this.orderId,
    required this.origin,
    required this.destination,
    required this.price,
    this.autoAccept = false,
    this.passengerName,
    this.paymentType,
    this.status,
    this.adminFee,
    this.driverFare,
    this.serviceType,
  });

  @override
  State<OrderRequestPage> createState() => _OrderRequestPageState();
}

class _OrderRequestPageState extends State<OrderRequestPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  static const platform = MethodChannel('com.wirodev.wirojek/intent');
  final String apiUrl = 'https://ojek.wirodev.com/api';

  Timer? _countdownTimer;
  int _secondsRemaining = 10;
  bool _actionPerformed = false;

  // Dynamic state loaded from init or backend
  String? _passengerName;
  String? _paymentType;
  String? _orderStatus;
  String? _serviceType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    _passengerName = widget.passengerName ?? 'Penumpang';
    _paymentType = widget.paymentType ?? 'cash';
    _orderStatus = widget.status ?? 'pending';
    _serviceType = widget.serviceType ?? 'wiro_ride';

    // Setup animation controller for pulsing alert ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.8,
      upperBound: 1.2,
    )..repeat(reverse: true);

    // Check backend status of the order to override any outdated local intents (e.g. after restart)
    checkActualStatus();

    // Only start countdown if order is still pending (incoming alert)
    if (_orderStatus == 'pending') {
      // Auto accept order if triggered from the notification banner "Ambil" button
      if (widget.autoAccept) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          acceptOrder();
        });
      }
      startCountdown();
    } else {
      _pulseController.stop();
    }
  }

  void checkActualStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('driver_phone');
    if (phone == null || phone.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/driver/order/active?phone=$phone'),
      );
      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['success'] == true && result['data'] != null) {
        final serverOrder = result['data'];
        if (serverOrder['id'].toString() == widget.orderId) {
          final serverStatus = serverOrder['status'];
          if (serverStatus == 'accepted' && mounted) {
            setState(() {
              _orderStatus = 'accepted';
              _paymentType = serverOrder['payment_type'];
              _passengerName = serverOrder['passenger_name'];
              _serviceType = serverOrder['service_type'];
            });
            _countdownTimer?.cancel();
            _pulseController.stop();
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking actual status: $e");
    }
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
    
    setState(() {
      _isLoading = true;
    });

    dismissNativeNotification();
    await sendStatusToBackend('accepted');

    setState(() {
      _isLoading = false;
      _actionPerformed = false;
      _orderStatus = 'accepted'; // Transition state to active details screen
    });
    _pulseController.stop();
  }

  void completeOrder() async {
    if (_actionPerformed) return;
    _actionPerformed = true;

    if (_paymentType == 'qris') {
      // Navigate to QRIS Payment Screen
      final bool? paymentSuccess = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => QrisPaymentPage(
            orderId: widget.orderId,
            price: formatPrice(widget.price),
            apiUrl: apiUrl,
          ),
        ),
      );

      if (paymentSuccess == true) {
        if (mounted) {
          showCompletionSuccess();
        }
      } else {
        // Payment was not completed or cancelled, let the driver retry
        setState(() {
          _actionPerformed = false;
        });
      }
    } else {
      // Cash payment completes immediately
      setState(() {
        _isLoading = true;
      });

      await sendStatusToBackend('completed');

      setState(() {
        _isLoading = false;
      });

      showCompletionSuccess();
    }
  }

  void showCompletionSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Order Selesai'),
          ],
        ),
        content: const Text('Orderan telah berhasil diselesaikan. Terima kasih!'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Return to home showing success
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
      Navigator.pop(context, false);
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
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPending = _orderStatus == 'pending';
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isPending 
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFF060B26), const Color(0xFF111827)],
          ),
        ),
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : Column(
                children: [
                  // Scrollable content area containing the timer and the ride details card
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          
                          if (isPending) ...[
                            // 1. Glowing countdown timer (for pending)
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
                          ] else ...[
                            // Header for completed, cancelled, or active order
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _orderStatus == 'completed'
                                      ? Icons.check_circle_rounded
                                      : (_orderStatus == 'cancelled' || _orderStatus == 'rejected'
                                          ? Icons.cancel_rounded
                                          : Icons.directions_car),
                                  color: _orderStatus == 'completed'
                                      ? Colors.greenAccent
                                      : (_orderStatus == 'cancelled' || _orderStatus == 'rejected'
                                          ? Colors.redAccent
                                          : Colors.greenAccent),
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _orderStatus == 'completed'
                                      ? 'ORDERAN SELESAI'
                                      : (_orderStatus == 'cancelled' || _orderStatus == 'rejected'
                                          ? 'ORDERAN DIBATALKAN'
                                          : 'PERJALANAN SEDANG BERLANGSUNG'),
                                  style: TextStyle(
                                    color: _orderStatus == 'completed'
                                        ? Colors.greenAccent
                                        : (_orderStatus == 'cancelled' || _orderStatus == 'rejected'
                                            ? Colors.redAccent
                                            : Colors.greenAccent),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          
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
                                const SizedBox(height: 16),

                                // Additional Details Card for Active Trip
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'PENUMPANG',
                                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _passengerName!,
                                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'LAYANAN',
                                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _serviceType == 'wiro_car' ? 'WiroCar' : 'WiroRide',
                                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'BAYAR',
                                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _paymentType == 'qris' ? 'QRIS' : 'Tunai',
                                            style: TextStyle(
                                              color: _paymentType == 'qris' ? Colors.indigoAccent.shade100 : Colors.greenAccent.shade100, 
                                              fontSize: 13, 
                                              fontWeight: FontWeight.bold
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Mid-trip Navigation and Payment switching buttons
                                if (_orderStatus == 'accepted') ...[
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            try {
                                              await platform.invokeMethod('openNavigation', {'destination': widget.destination});
                                            } catch (e) {
                                              debugPrint("Failed to launch maps navigation: $e");
                                            }
                                          },
                                          icon: const Icon(Icons.navigation_rounded, size: 16),
                                          label: const Text('Navigasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white.withOpacity(0.06),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            side: BorderSide(color: Colors.white.withOpacity(0.1)),
                                            elevation: 0,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            final nextType = _paymentType == 'qris' ? 'cash' : 'qris';
                                            setState(() {
                                              _paymentType = nextType;
                                            });
                                            // Sync payment type change to backend mid-trip
                                            http.post(
                                              Uri.parse('$apiUrl/driver/order/status'),
                                              body: {
                                                'order_id': widget.orderId,
                                                'status': _orderStatus!,
                                                'payment_type': nextType,
                                              },
                                            );
                                          },
                                          icon: Icon(_paymentType == 'qris' ? Icons.money : Icons.qr_code, size: 16),
                                          label: Text(_paymentType == 'qris' ? 'Bayar Tunai' : 'Bayar QRIS', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white.withOpacity(0.06),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            side: BorderSide(color: Colors.white.withOpacity(0.1)),
                                            elevation: 0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                const SizedBox(height: 24),
                                
                                // Fare Breakdown Card
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.amber.shade700.withOpacity(0.10),
                                        Colors.amber.shade900.withOpacity(0.03),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.amber.shade700.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    children: [
                                      // Customer pays
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'TARIF PENUMPANG',
                                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                                          ),
                                          Text(
                                            'Rp ${formatPrice(widget.price)}',
                                            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                      if (widget.adminFee != null && widget.adminFee!.isNotEmpty && widget.adminFee != '0') ...[
                                        const SizedBox(height: 10),
                                        // Admin deduction
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'POTONGAN ADMIN',
                                              style: TextStyle(color: Colors.redAccent.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                                            ),
                                            Text(
                                              '- Rp ${formatPrice(widget.adminFee!)}',
                                              style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Divider(color: Colors.white.withOpacity(0.07), thickness: 1),
                                        const SizedBox(height: 12),
                                      ],
                                      // Driver net earning
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'PENDAPATANMU',
                                                  style: TextStyle(color: Colors.amber.shade300, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                                ),
                                                const Text(
                                                  'Setelah potongan admin',
                                                  style: TextStyle(color: Colors.white38, fontSize: 9),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Rp ${formatPrice(widget.driverFare ?? widget.price)}',
                                            style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.w900),
                                          ),
                                        ],
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
                  
                  // Sticky bottom action buttons container (Decline & Swipe to accept/complete)
                  if (isPending || _orderStatus == 'accepted')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      decoration: BoxDecoration(
                        color: isPending ? const Color(0xFF0F172A).withOpacity(0.6) : const Color(0xFF060B26).withOpacity(0.8),
                        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPending) ...[
                            // Swipe To Accept Button
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
                          ] else ...[
                            // Swipe To Complete Button for active trip
                            SwipeButton(
                              text: _paymentType == 'qris' 
                                  ? "Geser untuk Bayar QRIS" 
                                  : "Geser untuk Selesaikan Order",
                              colorStart: Colors.blueAccent.shade400,
                              colorEnd: Colors.indigoAccent.shade400,
                              onSwipeComplete: completeOrder,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Pastikan penumpang telah berada di lokasi tujuan sebelum menyelesaikan orderan.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white30, fontSize: 10),
                            ),
                          ],
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

// Custom Glassmorphic Swipe Button Widget with Shimmer Effect
class SwipeButton extends StatefulWidget {
  final VoidCallback onSwipeComplete;
  final String text;
  final Color? colorStart;
  final Color? colorEnd;
  
  const SwipeButton({
    super.key, 
    required this.onSwipeComplete, 
    required this.text,
    this.colorStart,
    this.colorEnd,
  });

  @override
  State<SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<SwipeButton> with SingleTickerProviderStateMixin {
  double _position = 0.0;
  bool _isFinished = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startC = widget.colorStart ?? Colors.greenAccent;
    final endC = widget.colorEnd ?? Colors.teal;
    final textC = widget.colorStart != null ? Colors.blueAccent.shade100 : Colors.greenAccent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxPosition = constraints.maxWidth - 58; // 58 is the button diameter (60 - padding)
        return Container(
          height: 60,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: startC.withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: startC.withOpacity(0.18)),
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 36.0, right: 12.0),
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            colors: [
                              textC.withOpacity(0.3),
                              Colors.white,
                              textC.withOpacity(0.3),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                            begin: Alignment(-2.0 + _animController.value * 4.0, 0.0),
                            end: Alignment(0.0 + _animController.value * 4.0, 0.0),
                          ).createShader(bounds);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.text,
                              style: const TextStyle(
                                color: Colors.white, // Overridden by ShaderMask
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.double_arrow_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      );
                    },
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
                      gradient: LinearGradient(
                        colors: [startC, endC],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: startC.withOpacity(0.4),
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
