import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'OrderRequestPage.dart';

// Global navigator key to handle navigation from background/global notification events
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Key-value memory to persist custom backend URL during runtime (can be customized in UI)
String backendUrl = 'https://ojek.wirodev.com/api';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Awesome Notifications
  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelGroupKey: 'ojol_order_group',
        channelKey: 'ojol_order_channel',
        channelName: 'Ojol Orders',
        channelDescription: 'Notification channel for incoming ride orders',
        defaultColor: const Color(0xFF002B93),
        ledColor: Colors.white,
        importance: NotificationImportance.Max,
        channelShowBadge: true,
        locked: true,
        defaultPrivacy: NotificationPrivacy.Public,
        criticalAlerts: true,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      )
    ],
    channelGroups: [
      NotificationChannelGroup(
        channelGroupKey: 'ojol_order_group',
        channelGroupName: 'Ojol Groups',
      )
    ],
    debug: true,
  );

  // Request notification permissions
  AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
    if (!isAllowed) {
      AwesomeNotifications().requestPermissionToSendNotifications();
    }
  });

  // 2. Initialize OneSignal
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("a0da927e-ab54-4cc3-a83e-4fdca4cc7a98");
  
  // Prompt user for push notification permission (iOS / Android 13+)
  OneSignal.Notifications.requestPermission(true);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static String? currentOpenOrderId;

  @override
  void initState() {
    super.initState();

    // Setup listener for Awesome Notifications click actions
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: NotificationController.onActionReceivedMethod,
    );

    // Setup listener for OneSignal notifications
    setupOneSignalListeners();

    // Check for native background intents (woken up screen)
    checkInitialIntent();
  }

  static const platform = MethodChannel('com.wirodev.ojol/intent');

  void checkInitialIntent() async {
    try {
      final Map? initialOrder = await platform.invokeMethod('getInitialOrder');
      if (initialOrder != null) {
        handleIncomingOrderIntent(initialOrder);
      }
    } catch (e) {
      debugPrint("Error reading initial intent: $e");
    }

    // Handle real-time incoming intents if app is already running
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onNewOrder') {
        final Map? orderData = call.arguments as Map?;
        if (orderData != null) {
          handleIncomingOrderIntent(orderData);
        }
      }
    });
  }

  void handleIncomingOrderIntent(Map orderData) {
    navigateToOrderRequest(
      orderId: orderData['order_id']?.toString() ?? '0',
      origin: orderData['origin']?.toString() ?? 'Unknown',
      destination: orderData['destination']?.toString() ?? 'Unknown',
      price: orderData['price']?.toString() ?? '0',
      passengerName: orderData['passenger_name']?.toString() ?? 'Penumpang',
      paymentType: orderData['payment_type']?.toString() ?? 'cash',
    );
  }

  static void navigateToOrderRequest({
    required String orderId,
    required String origin,
    required String destination,
    required String price,
    bool autoAccept = false,
    String? passengerName,
    String? paymentType,
    String? status,
  }) {
    if (currentOpenOrderId == orderId) {
      debugPrint("Order page for ID $orderId is already open. Skipping duplicate push.");
      return;
    }
    currentOpenOrderId = orderId;

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => OrderRequestPage(
          orderId: orderId,
          origin: origin,
          destination: destination,
          price: price,
          autoAccept: autoAccept,
          passengerName: passengerName,
          paymentType: paymentType,
          status: status,
        ),
      ),
    ).then((_) {
      if (currentOpenOrderId == orderId) {
        currentOpenOrderId = null;
      }
    });
  }

  void setupOneSignalListeners() {
    // Listen to push notifications when they are received (foreground/background)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      debugPrint('Notification will display: ${event.notification.body}');
      
      final additionalData = event.notification.additionalData;
      if (additionalData != null && additionalData['type'] == 'NEW_ORDER') {
        event.preventDefault();
        
        triggerWakeUpCall(
          orderId: additionalData['order_id']?.toString() ?? '0',
          origin: additionalData['origin']?.toString() ?? 'Unknown',
          destination: additionalData['destination']?.toString() ?? 'Unknown',
          price: additionalData['price']?.toString() ?? '0',
        );

        // Immediately navigate to the full screen page since app is in foreground
        navigateToOrderRequest(
          orderId: additionalData['order_id']?.toString() ?? '0',
          origin: additionalData['origin']?.toString() ?? 'Unknown',
          destination: additionalData['destination']?.toString() ?? 'Unknown',
          price: additionalData['price']?.toString() ?? '0',
          passengerName: additionalData['passenger_name']?.toString() ?? 'Penumpang',
          paymentType: additionalData['payment_type']?.toString() ?? 'cash',
        );
      }
    });

    OneSignal.Notifications.addClickListener((event) {
      final additionalData = event.notification.additionalData;
      if (additionalData != null && additionalData['type'] == 'NEW_ORDER') {
        navigateToOrderRequest(
          orderId: additionalData['order_id']?.toString() ?? '0',
          origin: additionalData['origin']?.toString() ?? 'Unknown',
          destination: additionalData['destination']?.toString() ?? 'Unknown',
          price: additionalData['price']?.toString() ?? '0',
          passengerName: additionalData['passenger_name']?.toString() ?? 'Penumpang',
          paymentType: additionalData['payment_type']?.toString() ?? 'cash',
        );
      }
    });
  }

  // Trigger full-screen intent using Awesome Notifications to wake up screen
  static void triggerWakeUpCall({
    required String orderId,
    required String origin,
    required String destination,
    required String price,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: int.tryParse(orderId) ?? 100,
        channelKey: 'ojol_order_channel',
        title: 'Orderan Masuk!',
        body: 'Jemput: $origin → Antar: $destination. Tarif: Rp $price',
        fullScreenIntent: true,
        wakeUpScreen: true,
        category: NotificationCategory.Call,
        autoDismissible: false,
        locked: true,
        payload: {
          'order_id': orderId,
          'origin': origin,
          'destination': destination,
          'price': price,
        },
        notificationLayout: NotificationLayout.Default,
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'ACCEPT',
          label: 'Terima Orderan',
          color: Colors.green,
          actionType: ActionType.Default,
        ),
        NotificationActionButton(
          key: 'DECLINE',
          label: 'Tolak',
          color: Colors.red,
          actionType: ActionType.DismissAction,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ojol Driver',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFFFF8C00),
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const DriverHomePage(),
    );
  }
}

// Controller to intercept notification clicks from Awesome Notifications
class NotificationController {
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    final payload = receivedAction.payload;
    if (payload != null && payload['order_id'] != null) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => OrderRequestPage(
            orderId: payload['order_id']!,
            origin: payload['origin'] ?? 'Unknown',
            destination: payload['destination'] ?? 'Unknown',
            price: payload['price'] ?? '0',
            autoAccept: receivedAction.buttonKeyPressed == 'ACCEPT',
          ),
        ),
      );
    }
  }
}

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  bool isOnline = false;
  String oneSignalId = 'Loading OneSignal...';
  String driverPhone = '081234567890';
  String driverName = 'Wiro Sableng';
  String driverId = 'DRV-0001';
  bool isLoading = false;
  double driverBalance = 0.0;
  
  // Order history & active order state
  List<dynamic> historyOrders = [];
  Map<String, dynamic>? activeOrder;
  bool _loadingHistory = false;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _phoneController.text = driverPhone;
    _nameController.text = driverName;
    _urlController.text = backendUrl;
    
    // Load persisted driver online state and details
    loadSavedState();
    fetchOneSignalId();
    setupOneSignalObserver();
  }

  void loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isOnline = prefs.getBool('is_online') ?? false;
      driverName = prefs.getString('driver_name') ?? 'Wiro Sableng';
      driverPhone = prefs.getString('driver_phone') ?? '081234567890';
      driverId = prefs.getString('driver_id') ?? 'DRV-0001';
      _nameController.text = driverName;
      _phoneController.text = driverPhone;
      
      final storedUrl = prefs.getString('backend_url');
      if (storedUrl != null && storedUrl.isNotEmpty) {
        backendUrl = storedUrl;
        _urlController.text = backendUrl;
      }
    });

    if (isOnline) {
      fetchOrderHistory();
      checkActiveOrder();
      fetchDriverProfile();
    }
  }

  Future<void> fetchDriverProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/driver/profile?phone=$driverPhone'),
      );
      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['success'] == true) {
        setState(() {
          driverBalance = double.tryParse(result['data']['balance'].toString()) ?? 0.0;
          driverName = result['data']['name'];
          driverPhone = result['data']['phone'];
          driverId = 'DRV-' + result['data']['id'].toString().padLeft(4, '0');
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }

  void saveState({required bool online, required String name, required String phone, required String id}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_online', online);
    await prefs.setString('driver_name', name);
    await prefs.setString('driver_phone', phone);
    await prefs.setString('driver_id', id);
    await prefs.setString('backend_url', backendUrl);
  }

  void setupOneSignalObserver() {
    OneSignal.User.pushSubscription.addObserver((state) {
      if (mounted) {
        setState(() {
          oneSignalId = state.current.id ?? 'Belum terdaftar (pastikan internet aktif)';
        });
      }
    });
  }

  void fetchOneSignalId() {
    String? id = OneSignal.User.pushSubscription.id;
    if (id != null && id.isNotEmpty) {
      setState(() {
        oneSignalId = id;
      });
    }
  }

  Future<void> checkActiveOrder() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/driver/order/active?phone=$driverPhone'),
      );
      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['success'] == true) {
        setState(() {
          activeOrder = result['data'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching active order: $e");
    }
  }

  Future<void> fetchOrderHistory() async {
    setState(() {
      _loadingHistory = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$backendUrl/driver/orders?phone=$driverPhone'),
      );
      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['success'] == true) {
        setState(() {
          historyOrders = result['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
    } finally {
      setState(() {
        _loadingHistory = false;
      });
    }
  }

  Future<void> setDriverOnline() async {
    // Check overlay permission first
    const platform = MethodChannel('com.wirodev.ojol/intent');
    try {
      final bool hasOverlayPermission = await platform.invokeMethod('checkOverlayPermission');
      if (!hasOverlayPermission && mounted) {
        final bool? grant = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Izin Tambahan Diperlukan'),
            content: const Text(
              'Agar layar orderan masuk dapat otomatis muncul penuh saat Anda sedang membuka aplikasi lain, mohon aktifkan izin "Tampilkan di atas aplikasi lain" untuk aplikasi ini.'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Nanti Saja'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Aktifkan Sekarang'),
              ),
            ],
          ),
        );
        
        if (grant == true) {
          await platform.invokeMethod('requestOverlayPermission');
          return;
        }
      }
    } catch (e) {
      debugPrint("Error checking overlay permission: $e");
    }

    setState(() {
      isLoading = true;
    });

    final playerId = OneSignal.User.pushSubscription.id;
    if (playerId == null || playerId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mendapatkan OneSignal Player ID. Pastikan internet aktif!'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      backendUrl = _urlController.text.trim();
      final response = await http.post(
        Uri.parse('$backendUrl/driver/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': _phoneController.text.trim(),
          'name': _nameController.text.trim(),
          'onesignal_player_id': playerId,
        }),
      );

      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['success'] == true) {
        final dbId = 'DRV-' + result['data']['id'].toString().padLeft(4, '0');
        setState(() {
          isOnline = true;
          driverName = result['data']['name'];
          driverPhone = result['data']['phone'];
          driverId = dbId;
        });
        saveState(online: true, name: driverName, phone: driverPhone, id: driverId);
        
        // Load active and history data
        fetchOrderHistory();
        checkActiveOrder();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status driver online & terdaftar!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal online')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> setDriverOffline() async {
    setState(() {
      isLoading = true;
    });

    try {
      backendUrl = _urlController.text.trim();
      final response = await http.post(
        Uri.parse('$backendUrl/driver/logout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': _phoneController.text.trim(),
        }),
      );

      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['success'] == true) {
        setState(() {
          isOnline = false;
          activeOrder = null;
        });
        saveState(online: false, name: driverName, phone: driverPhone, id: driverId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status driver sekarang OFFLINE!'),
            backgroundColor: Colors.grey,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal offline')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void openActiveOrderScreen() async {
    if (activeOrder == null) return;
    
    // Open details screen and wait for completion/reject result to refresh
    final bool? completed = await navigatorKey.currentState?.push<bool>(
      MaterialPageRoute(
        builder: (context) => OrderRequestPage(
          orderId: activeOrder!['id'].toString(),
          origin: activeOrder!['origin'],
          destination: activeOrder!['destination'],
          price: activeOrder!['price'].toString().split('.')[0],
          status: activeOrder!['status'],
          passengerName: activeOrder!['passenger_name'],
          paymentType: activeOrder!['payment_type'],
        ),
      ),
    );

    if (completed == true) {
      fetchOrderHistory();
      checkActiveOrder();
      fetchDriverProfile();
    }
  }

  String formatPrice(String price) {
    final intVal = int.tryParse(price.replaceAll('.', ''));
    if (intVal == null) return price;
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return intVal.toString().replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900 for premium dark theme
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          'OJOL DRIVER DASHBOARD',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: showSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              if (isOnline) {
                fetchOrderHistory();
                checkActiveOrder();
                fetchDriverProfile();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Profile and Online/Offline Toggle Header Card
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: isOnline ? Colors.green.withOpacity(0.1) : Colors.white10,
                        child: Icon(
                          Icons.person,
                          color: isOnline ? Colors.greenAccent : Colors.white54,
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
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              driverPhone,
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                            if (isOnline) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet, color: Colors.amber, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Saldo: Rp ${formatPrice(driverBalance.toString().split('.')[0])}',
                                    style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Driver ID Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Text(
                          driverId,
                          style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  
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
                              color: isOnline ? Colors.greenAccent : Colors.white38,
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
                              onChanged: (val) {
                                if (val) {
                                  setDriverOnline();
                                } else {
                                  setDriverOffline();
                                }
                              },
                            ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 2. Active Order Banner / Dropcard (Pulsing card)
            if (isOnline && activeOrder != null && activeOrder!['status'] == 'accepted') ...[
              GestureDetector(
                onTap: openActiveOrderScreen,
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

            // 3. Driver Info / Settings (Only visible when offline)
            if (!isOnline) ...[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.04)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PENGATURAN AKUN',
                              style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Nama Lengkap',
                                labelStyle: const TextStyle(color: Colors.white54),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white24)),
                                prefixIcon: const Icon(Icons.person, color: Colors.white54),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _phoneController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'No. Handphone',
                                labelStyle: const TextStyle(color: Colors.white54),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white24)),
                                prefixIcon: const Icon(Icons.phone, color: Colors.white54),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // 4. Order History List (Visible when online)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'RIWAYAT ORDERAN TERKINI',
                            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                          ),
                          if (_loadingHistory)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _loadingHistory && historyOrders.isEmpty
                          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                          : historyOrders.isEmpty
                            ? const Center(
                                child: Text('Belum ada riwayat orderan.', style: TextStyle(color: Colors.white30)),
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: historyOrders.length,
                                itemBuilder: (context, index) {
                                  final order = historyOrders[index];
                                  final bool isCompleted = order['status'] == 'completed';
                                  final bool isCancelled = order['status'] == 'cancelled' || order['status'] == 'rejected';
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.02)),
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
                                                ? Colors.greenAccent 
                                                : (isCancelled ? Colors.redAccent : Colors.amberAccent),
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
                                                'Order #${order['id']} - ${order['payment_type'] == 'qris' ? 'QRIS' : 'Tunai'}',
                                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Ke: ${order['destination']}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: Colors.white30, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        // Price
                                        Text(
                                          'Rp ${formatPrice(order['price'].toString().split('.')[0])}',
                                          style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Config API Endpoint', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ubah URL target backend agar sesuai dengan IP XAMPP Anda. Pastikan ada folder /public/api atau /api di ujungnya.',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'API Base URL',
                  labelStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  backendUrl = _urlController.text.trim();
                });
                Navigator.pop(context);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }
}
