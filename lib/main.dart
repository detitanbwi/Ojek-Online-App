import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'OrderRequestPage.dart';

import 'WelcomeScreen.dart';
import 'LoginScreen.dart';

// Global navigator key to handle navigation from background/global notification events
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Key-value memory to persist custom backend URL during runtime
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

  @override
  void dispose() {
    super.dispose();
  }

  static const platform = MethodChannel('com.wirodev.wirojek/intent');

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
      adminFee: orderData['admin_fee']?.toString(),
      driverFare: orderData['driver_fare']?.toString(),
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
    String? adminFee,
    String? driverFare,
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
          adminFee: adminFee,
          driverFare: driverFare,
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
          paymentType: additionalData['passenger_name']?.toString() ?? 'cash',
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
      title: 'WiroJek Driver',
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
      home: const WelcomeScreen(),
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
  String driverEmail = 'driver@wirojek.com';
  String driverName = 'Wiro Sableng';
  String driverId = 'DRV-0001';
  bool isLoading = false;
  double driverBalance = 0.0;
  
  // Theme Mode
  bool isDarkMode = true;

  // Bottom Navigation Index
  int _selectedIndex = 0;

  // Order history & active order state
  List<dynamic> historyOrders = [];
  Map<String, dynamic>? activeOrder;
  bool _loadingHistory = false;
  
  Timer? _syncTimer;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _phoneController.text = driverPhone;
    _nameController.text = driverName;
    
    // Load persisted driver online state and details
    loadSavedState();
    fetchOneSignalId();
    setupOneSignalObserver();
  }

  @override
  void dispose() {
    stopSyncTimer();
    super.dispose();
  }

  void loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isOnline = prefs.getBool('is_online') ?? false;
      driverName = prefs.getString('driver_name') ?? 'Wiro Sableng';
      driverPhone = prefs.getString('driver_phone') ?? '081234567890';
      driverEmail = prefs.getString('driver_email') ?? 'driver@wirojek.com';
      driverId = prefs.getString('driver_id') ?? 'DRV-0001';
      isDarkMode = prefs.getBool('is_dark_mode') ?? true;
      _nameController.text = driverName;
      _phoneController.text = driverPhone;
    });

    if (isOnline) {
      fetchOrderHistory();
      checkActiveOrder();
      fetchDriverProfile();
      startSyncTimer();
    }
  }

  void saveState({required bool online, required String name, required String phone, required String email, required String id}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_online', online);
    await prefs.setString('driver_name', name);
    await prefs.setString('driver_phone', phone);
    await prefs.setString('driver_email', email);
    await prefs.setString('driver_id', id);
  }

  void toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = !isDarkMode;
    });
    await prefs.setBool('is_dark_mode', isDarkMode);
  }

  void setupOneSignalObserver() {
    OneSignal.User.pushSubscription.addObserver((state) {
      if (mounted) {
        setState(() {
          oneSignalId = state.current.id ?? 'Belum terdaftar';
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

  void startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (isOnline) {
        checkDriverStatusOnline();
      } else {
        timer.cancel();
      }
    });
  }

  void stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> checkDriverStatusOnline() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/driver/profile?email=$driverEmail'),
      );
      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['success'] == true) {
        final bool serverOnline = result['data']['status_online'] == true;
        
        if (isOnline && !serverOnline) {
          stopSyncTimer();
          setState(() {
            isOnline = false;
            activeOrder = null;
            driverBalance = 0.0;
          });
          saveState(online: false, name: driverName, phone: driverPhone, email: driverEmail, id: driverId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Koneksi Anda telah diputus (detached) oleh Admin.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        } else if (isOnline && serverOnline) {
          setState(() {
            driverBalance = double.tryParse(result['data']['balance'].toString()) ?? 0.0;
          });
        }
      }
    } catch (e) {
      debugPrint("Error in status sync: $e");
    }
  }

  Future<void> checkActiveOrder() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/driver/order/active?email=$driverEmail'),
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
        Uri.parse('$backendUrl/driver/orders?email=$driverEmail'),
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

  Future<void> fetchDriverProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/driver/profile?email=$driverEmail'),
      );
      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['success'] == true) {
        setState(() {
          driverBalance = double.tryParse(result['data']['balance'].toString()) ?? 0.0;
          driverName = result['data']['name'];
          driverPhone = result['data']['phone'];
          driverEmail = result['data']['email'];
          driverId = 'DRV-' + result['data']['id'].toString().padLeft(4, '0');
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }

  Future<void> setDriverOnline() async {
    const platform = MethodChannel('com.wirodev.wirojek/intent');
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
      final response = await http.post(
        Uri.parse('$backendUrl/driver/set-online'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': driverEmail,
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
          driverEmail = result['data']['email'];
          driverId = dbId;
        });
        saveState(online: true, name: driverName, phone: driverPhone, email: driverEmail, id: driverId);
        
        // Load active and history data
        fetchOrderHistory();
        checkActiveOrder();
        fetchDriverProfile();
        startSyncTimer();

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
      final response = await http.post(
        Uri.parse('$backendUrl/driver/logout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': driverEmail,
        }),
      );

      final result = jsonDecode(response.body);
      final bool isDriverNotFound = response.statusCode == 404 || (result != null && result['message'] == 'Driver not found.');

      if ((response.statusCode == 200 && result['success'] == true) || isDriverNotFound) {
        stopSyncTimer();
        setState(() {
          isOnline = false;
          activeOrder = null;
          driverBalance = 0.0;
        });
        saveState(online: false, name: driverName, phone: driverPhone, email: driverEmail, id: driverId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDriverNotFound 
                ? 'Driver tidak ditemukan di database. Mengatur status ke offline.' 
                : 'Status driver sekarang OFFLINE!'),
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
          adminFee: activeOrder!['admin_fee']?.toString().split('.')[0],
          driverFare: activeOrder!['driver_fare']?.toString().split('.')[0],
        ),
      ),
    );

    if (completed == true) {
      fetchOrderHistory();
      checkActiveOrder();
      fetchDriverProfile();
    }
  }

  void openHistoryDetailScreen(Map<String, dynamic> order) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => OrderRequestPage(
          orderId: order['id'].toString(),
          origin: order['origin'],
          destination: order['destination'],
          price: order['price'].toString().split('.')[0],
          status: order['status'],
          passengerName: order['passenger_name'],
          paymentType: order['payment_type'],
          adminFee: order['admin_fee']?.toString().split('.')[0],
          driverFare: order['driver_fare']?.toString().split('.')[0],
        ),
      ),
    );
  }

  String formatPrice(String price) {
    final intVal = int.tryParse(price.replaceAll('.', ''));
    if (intVal == null) return price;
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return intVal.toString().replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  // Dashboard Tab Content Widget
  Widget buildDashboardTab(Color titleColor, Color subTitleColor, Color cardBg, Color dividerColor) {
    return Column(
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
              ],
            ),
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

        // 3. Main Dashboard body listing history if online, or elegant placeholder if offline
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: !isOnline
                ? Center(
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
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RIWAYAT ORDERAN TERKINI',
                            style: TextStyle(color: subTitleColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                          ),
                          if (_loadingHistory)
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: titleColor),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _loadingHistory && historyOrders.isEmpty
                          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                          : historyOrders.isEmpty
                            ? Center(
                                child: Text('Belum ada riwayat orderan.', style: TextStyle(color: subTitleColor.withOpacity(0.5))),
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: historyOrders.length,
                                itemBuilder: (context, index) {
                                  final order = historyOrders[index];
                                  final bool isCompleted = order['status'] == 'completed';
                                  final bool isCancelled = order['status'] == 'cancelled' || order['status'] == 'rejected';
                                  
                                  return GestureDetector(
                                    onTap: () => openHistoryDetailScreen(order),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: cardBg,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: dividerColor),
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
                                            style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
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
    );
  }

  // Profile Tab Content Widget
  Widget buildProfileTab(Color titleColor, Color subTitleColor, Color cardBg, Color dividerColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
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
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: const Text('Keluar dari Akun?'),
                  content: const Text('Anda tidak akan dapat menerima pesanan ojek online baru saat berada di luar akun.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        performLogout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Keluar Akun'),
                    ),
                  ],
                ),
              );
            },
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
    );
  }

  void performLogout() async {
    setState(() {
      isLoading = true;
    });
    try {
      await http.post(
        Uri.parse('$backendUrl/driver/logout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': driverEmail}),
      );
    } catch (e) {
      debugPrint("API Logout error: $e");
    }

    // Reset local state
    stopSyncTimer();
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

  Widget buildDetailRow(IconData icon, String label, String value, Color titleColor, Color subTitleColor) {
    return Row(
      children: [
        Icon(icon, color: subTitleColor, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: subTitleColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: titleColor, fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Theme colors
    final Color scaffoldBg = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6);
    final Color cardBg = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final Color subTitleColor = isDarkMode ? Colors.white54 : Colors.black54;
    final Color dividerColor = isDarkMode ? Colors.white10 : Colors.black12;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Text(
          _selectedIndex == 0 ? 'DASHBOARD DRIVER' : 'PROFIL AKUN',
          style: TextStyle(color: titleColor, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2),
        ),
        actions: [
          // Theme Toggle Button
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              color: isDarkMode ? Colors.amberAccent : Colors.indigoAccent,
            ),
            onPressed: toggleTheme,
          ),
          if (_selectedIndex == 0)
            IconButton(
              icon: Icon(Icons.refresh, color: isDarkMode ? Colors.white70 : Colors.black87),
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
        child: _selectedIndex == 0 
            ? buildDashboardTab(titleColor, subTitleColor, cardBg, dividerColor)
            : buildProfileTab(titleColor, subTitleColor, cardBg, dividerColor),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: cardBg,
        selectedItemColor: Colors.amber.shade700,
        unselectedItemColor: isDarkMode ? Colors.white30 : Colors.black38,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
