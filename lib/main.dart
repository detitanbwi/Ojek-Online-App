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
    // Null defaults to the default app icon
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
  // Replace with your OneSignal App ID
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("a0da927e-ab54-4cc3-a83e-4fdca4cc7a98"); // To be configured by user, or fallback
  
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
      autoAccept: orderData['action'] == 'ACCEPT',
    );
  }

  void setupOneSignalListeners() {
    // Listen to push notifications when they are received (foreground/background)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      debugPrint('Notification will display: ${event.notification.body}');
      
      // Check data payload
      final additionalData = event.notification.additionalData;
      if (additionalData != null && additionalData['type'] == 'NEW_ORDER') {
        // Prevent default display so we can show it via AwesomeNotifications full-screen intent
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
        );
      }
    });

    // In OneSignal v5, background notification processing is handled via OSNotificationLifeCycleListener
    // or by checking custom payloads. Since OneSignal payload will trigger OSNotificationWillDisplayEvent, 
    // we can also catch it in background. If OneSignal.Notifications click handles it, we route too.
    OneSignal.Notifications.addClickListener((event) {
      final additionalData = event.notification.additionalData;
      if (additionalData != null && additionalData['type'] == 'NEW_ORDER') {
        navigateToOrderRequest(
          orderId: additionalData['order_id']?.toString() ?? '0',
          origin: additionalData['origin']?.toString() ?? 'Unknown',
          destination: additionalData['destination']?.toString() ?? 'Unknown',
          price: additionalData['price']?.toString() ?? '0',
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
        fullScreenIntent: true, // Wakes up screen & displays activity on lockscreen
        wakeUpScreen: true,     // Force screen to turn on
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

  static void navigateToOrderRequest({
    required String orderId,
    required String origin,
    required String destination,
    required String price,
    bool autoAccept = false,
  }) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => OrderRequestPage(
          orderId: orderId,
          origin: origin,
          destination: destination,
          price: price,
          autoAccept: autoAccept,
        ),
      ),
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
          seedColor: const Color(0xFF002B93),
          primary: const Color(0xFF002B93),
          secondary: const Color(0xFFCC5900),
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
      if (receivedAction.buttonKeyPressed == 'ACCEPT') {
        // Accept action handled directly from notification button
        debugPrint('Accepted order from notification action: ${payload['order_id']}');
      }
      
      // Open OrderRequestPage
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => OrderRequestPage(
            orderId: payload['order_id']!,
            origin: payload['origin'] ?? 'Unknown',
            destination: payload['destination'] ?? 'Unknown',
            price: payload['price'] ?? '0',
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
  bool isLoading = false;
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
      _nameController.text = driverName;
      _phoneController.text = driverPhone;
      
      // Update global backendUrl if stored
      final storedUrl = prefs.getString('backend_url');
      if (storedUrl != null && storedUrl.isNotEmpty) {
        backendUrl = storedUrl;
        _urlController.text = backendUrl;
      }
    });
  }

  void saveState({required bool online, required String name, required String phone}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_online', online);
    await prefs.setString('driver_name', name);
    await prefs.setString('driver_phone', phone);
    await prefs.setString('backend_url', backendUrl);
  }

  void setupOneSignalObserver() {
    // Add observer to watch for player ID registration changes reactively
    OneSignal.User.pushSubscription.addObserver((state) {
      if (mounted) {
        setState(() {
          oneSignalId = state.current.id ?? 'Belum terdaftar (pastikan internet aktif)';
        });
      }
    });
  }

  void fetchOneSignalId() {
    // Try to get immediate ID if already available
    String? id = OneSignal.User.pushSubscription.id;
    if (id != null && id.isNotEmpty) {
      setState(() {
        oneSignalId = id;
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
          return; // Stop here, let them authorize and set online again
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
          content: Text('Gagal mendapatkan OneSignal Player ID. Menunggu SDK OneSignal siap, pastikan koneksi internet aktif!'),
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
        setState(() {
          isOnline = true;
          driverName = result['data']['name'];
          driverPhone = result['data']['phone'];
        });
        saveState(online: true, name: driverName, phone: driverPhone);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status driver online & terdaftar!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        String errorMsg = result['message'] ?? 'Gagal menghubungi server';
        if (result['errors'] != null) {
          errorMsg += ': ' + result['errors'].toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
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
        });
        saveState(online: false, name: driverName, phone: driverPhone);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status driver sekarang OFFLINE!'),
            backgroundColor: Colors.grey,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal menghubungi server'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF002B93),
        title: const Text('Ojol Driver MVP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: showSettingsDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Connection Status Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 4,
                shadowColor: Colors.black12,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFFE6F4EA) : const Color(0xFFF1F3F4),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 6,
                              backgroundColor: isOnline ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isOnline ? 'ONLINE' : 'OFFLINE',
                              style: TextStyle(
                                color: isOnline ? Colors.green[800] : Colors.grey[700],
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        driverName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF002B93)),
                      ),
                      Text(
                        driverPhone,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Driver Registration / Setup Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 4,
                shadowColor: Colors.black12,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Driver',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        enabled: !isOnline,
                        decoration: InputDecoration(
                          labelText: 'Nama Driver',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          prefixIcon: const Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phoneController,
                        enabled: !isOnline,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'No. Handphone',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          prefixIcon: const Icon(Icons.phone),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. OneSignal and Connection Info Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 4,
                shadowColor: Colors.black12,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Device & API Config',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      const Text('OneSignal Player ID:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      SelectableText(
                        oneSignalId,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const Text('Target Endpoint URL:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        _urlController.text,
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 4. Action Button
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : (isOnline ? setDriverOffline : setDriverOnline),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOnline ? Colors.redAccent : const Color(0xFFCC5900),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 6,
                  shadowColor: (isOnline ? Colors.redAccent : const Color(0xFFCC5900)).withOpacity(0.4),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : Text(
                        isOnline ? 'Matikan & Set Offline' : 'Aktifkan & Set Online',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
              ),
              const SizedBox(height: 12),
              
              // Dev demo trigger button for lockscreen testing
              TextButton(
                onPressed: () {
                  _MyAppState.triggerWakeUpCall(
                    orderId: '99',
                    origin: 'Terminal Karangente',
                    destination: 'Pantai Boom Banyuwangi',
                    price: '22.000',
                  );
                },
                child: const Text('Test Wake-Up Screen (Simulasi Orderan)'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Config API Endpoint'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ubah URL target backend agar sesuai dengan IP XAMPP Anda. Pastikan ada folder /public/api atau /api di ujungnya.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'API Base URL',
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
