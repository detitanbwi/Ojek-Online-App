import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'OrderRequestPage.dart';
import 'WelcomeScreen.dart';
import 'LoginScreen.dart';

import 'services/api_service.dart';
import 'widgets/dashboard_tab.dart';
import 'widgets/history_tab.dart';
import 'widgets/profile_tab.dart';

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
  late ApiService apiService;
  
  // Theme Mode
  bool isDarkMode = true;

  // Bottom Navigation Index
  int _selectedIndex = 0;

  // Order history & active order state
  List<dynamic> historyOrders = [];
  Map<String, dynamic>? activeOrder;
  bool _loadingHistory = false;
  bool _refreshingDashboard = false;
  bool _refreshingHistory = false;
  bool _refreshingProfile = false;
  
  Timer? _syncTimer;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    apiService = ApiService(baseUrl: backendUrl);
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
      final result = await apiService.fetchProfile(driverEmail);
      if (result['success'] == true) {
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
      final result = await apiService.checkActiveOrder(driverEmail);
      if (result['success'] == true) {
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
      final result = await apiService.fetchOrders(driverEmail);
      if (result['success'] == true) {
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
      final result = await apiService.fetchProfile(driverEmail);
      if (result['success'] == true) {
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
      final result = await apiService.setOnline(driverEmail, playerId);
      if (result['success'] == true) {
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
      final result = await apiService.logout(driverEmail);
      final bool isDriverNotFound = result['message'] == 'Driver not found.';

      if (result['success'] == true || isDriverNotFound) {
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



  void performLogout() async {
    setState(() {
      isLoading = true;
    });
    try {
      await apiService.logout(driverEmail);
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
        backgroundColor: const Color(0xFF0F172A),
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.4),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/logo-white.png',
              height: 36,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Text(
              _selectedIndex == 0
                  ? 'DASHBOARD'
                  : (_selectedIndex == 1 ? 'RIWAYAT ORDER' : 'PROFIL AKUN'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.2,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
        actions: [
          // Theme Toggle Button
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              color: Colors.amberAccent,
            ),
            onPressed: toggleTheme,
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            DashboardTab(
              driverName: driverName,
              driverBalance: driverBalance,
              isOnline: isOnline,
              isLoading: isLoading,
              isRefreshing: _refreshingDashboard,
              isDarkMode: isDarkMode,
              historyOrders: historyOrders,
              activeOrder: activeOrder,
              titleColor: titleColor,
              subTitleColor: subTitleColor,
              cardBg: cardBg,
              dividerColor: dividerColor,
              onRefresh: () async {
                if (!isOnline) return;
                setState(() => _refreshingDashboard = true);
                
                final timeoutTimer = Timer(const Duration(seconds: 8), () {
                  if (mounted && _refreshingDashboard) {
                    setState(() => _refreshingDashboard = false);
                  }
                });

                try {
                  await Future.wait([
                    fetchDriverProfile(),
                    checkActiveOrder(),
                    fetchOrderHistory(),
                  ]);
                } catch (e) {
                  debugPrint("Dashboard refresh error: $e");
                } finally {
                  timeoutTimer.cancel();
                  if (mounted) {
                    setState(() => _refreshingDashboard = false);
                  }
                }
              },
              onOnlineChanged: (val) {
                if (val) {
                  setDriverOnline();
                } else {
                  setDriverOffline();
                }
              },
              onActiveOrderTap: openActiveOrderScreen,
            ),
            HistoryTab(
              isOnline: isOnline,
              isDarkMode: isDarkMode,
              loadingHistory: _loadingHistory,
              isRefreshing: _refreshingHistory,
              historyOrders: historyOrders,
              titleColor: titleColor,
              subTitleColor: subTitleColor,
              cardBg: cardBg,
              dividerColor: dividerColor,
              onRefresh: () async {
                if (!isOnline) return;
                setState(() => _refreshingHistory = true);

                final timeoutTimer = Timer(const Duration(seconds: 8), () {
                  if (mounted && _refreshingHistory) {
                    setState(() => _refreshingHistory = false);
                  }
                });

                try {
                  await fetchOrderHistory();
                } catch (e) {
                  debugPrint("History refresh error: $e");
                } finally {
                  timeoutTimer.cancel();
                  if (mounted) {
                    setState(() => _refreshingHistory = false);
                  }
                }
              },
              onOrderTap: openHistoryDetailScreen,
            ),
            ProfileTab(
              driverName: driverName,
              driverEmail: driverEmail,
              driverPhone: driverPhone,
              driverBalance: driverBalance,
              driverId: driverId,
              isDarkMode: isDarkMode,
              isRefreshing: _refreshingProfile,
              titleColor: titleColor,
              subTitleColor: subTitleColor,
              cardBg: cardBg,
              dividerColor: dividerColor,
              onWithdraw: (bank, acc, amount) async {
                final int rawId = int.tryParse(driverId.replaceAll('DRV-', '')) ?? 0;
                final result = await apiService.withdraw(
                  driverId: rawId,
                  bankName: bank,
                  accountNumber: acc,
                  amount: amount,
                );
                if (result['success'] == true) {
                  setState(() {
                    driverBalance = double.tryParse(result['data']['wallet_balance'].toString()) ?? (driverBalance - amount);
                  });
                }
                return result;
              },
              onRefresh: () async {
                setState(() => _refreshingProfile = true);

                final timeoutTimer = Timer(const Duration(seconds: 8), () {
                  if (mounted && _refreshingProfile) {
                    setState(() => _refreshingProfile = false);
                  }
                });

                try {
                  await fetchDriverProfile();
                } catch (e) {
                  debugPrint("Profile refresh error: $e");
                } finally {
                  timeoutTimer.cancel();
                  if (mounted) {
                    setState(() => _refreshingProfile = false);
                  }
                }
              },
              onLogoutTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    title: const Text('Konfirmasi Keluar'),
                    content: const Text('Apakah Anda yakin ingin keluar dari akun driver WiroJek ini?'),
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
        height: 70,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Builder(
          builder: (context) {
            final Color selectedNavColor = isDarkMode ? Colors.blue.shade300 : const Color(0xFF1E3A8A);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selectedIndex = 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.dashboard_rounded,
                          color: _selectedIndex == 0 ? selectedNavColor : (isDarkMode ? Colors.white30 : Colors.black38),
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _selectedIndex == 0 ? FontWeight.bold : FontWeight.normal,
                            color: _selectedIndex == 0 ? selectedNavColor : (isDarkMode ? Colors.white30 : Colors.black38),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selectedIndex = 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          color: _selectedIndex == 1 ? selectedNavColor : (isDarkMode ? Colors.white30 : Colors.black38),
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Riwayat',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _selectedIndex == 1 ? FontWeight.bold : FontWeight.normal,
                            color: _selectedIndex == 1 ? selectedNavColor : (isDarkMode ? Colors.white30 : Colors.black38),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selectedIndex = 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_rounded,
                          color: _selectedIndex == 2 ? selectedNavColor : (isDarkMode ? Colors.white30 : Colors.black38),
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Profil',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _selectedIndex == 2 ? FontWeight.bold : FontWeight.normal,
                            color: _selectedIndex == 2 ? selectedNavColor : (isDarkMode ? Colors.white30 : Colors.black38),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
        ),
      ),
    );
  }
}
