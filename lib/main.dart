import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'wrapper.dart';

// Firebase / FCM
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Firestore (อัปเดต status/lastSeen)
import 'package:cloud_firestore/cloud_firestore.dart';

// real‑time network changes
import 'package:connectivity_plus/connectivity_plus.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// ===== ใส่ docId ของ Raspberry_pi ที่ต้องการอัปเดต =====
/// TODO: เปลี่ยนให้เป็น docId จริงที่แอปคุณใช้งานอยู่
const String kRaspberryDocId = 'qcoSjhZXfYNkCUMxKfOn';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // เปิด UI ก่อน (Firebase ไปทำใน RootGate)
  runApp(const MyApp());
}

/// ====== เช็คอินเทอร์เน็ต (HTTP 204 + TCP) ======
Future<bool> hasRealInternet({Duration timeout = const Duration(seconds: 3)}) async {
  Future<bool> tryHttp204(String url) async {
    try {
      final client = HttpClient()..connectionTimeout = timeout;
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close().timeout(timeout);
      return res.statusCode == 204 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> tryTcp(String host, int port) async {
    try {
      final s = await Socket.connect(host, port, timeout: timeout);
      s.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  final checks = await Future.wait<bool>([
    tryHttp204('https://www.google.com/generate_204'),
    tryHttp204('https://clients3.google.com/generate_204'),
    tryHttp204('http://connectivitycheck.gstatic.com/generate_204'),
    tryTcp('1.1.1.1', 53),
    tryTcp('8.8.8.8', 53),
  ], eagerError: false);

  return checks.any((ok) => ok);
}

/// ====== Exception กรณีไม่มีเน็ต ======
class NoInternetException implements Exception {
  final String message;
  NoInternetException([this.message = 'No internet connection']);
  @override
  String toString() => message;
}

/// ====== จัดการหน้าออฟไลน์ “ศูนย์กลาง” ด้วยการเก็บ Route ที่เปิดจริง ๆ ======
class OfflineOverlay {
  static bool _isOpening = false;
  static Route<dynamic>? _route; // เก็บ route ที่ถูก push อยู่

  static bool get isOpen => _route != null;

  static Future<void> open() async {
    if (_isOpening || _route != null) return;
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    _isOpening = true;
    final route = PageRouteBuilder(
      opaque: true,
      settings: const RouteSettings(name: '/nointernet'),
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => const _NoInternetPage(),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );

    _route = route;
    nav.push(route).whenComplete(() {
      _route = null;
      _isOpening = false;
    });

    _isOpening = false;
  }

  static Future<void> close() async {
    final nav = navigatorKey.currentState;
    final r = _route;
    if (nav == null || r == null) return;

    if (r.isActive) {
      nav.removeRoute(r);
    }
    _route = null;
  }
}

/// ====== NetGuard: ห่อ async ที่เสี่ยงค้างด้วย timeout ======
class NetGuard {
  static Future<T> run<T>({
    required Future<T> Function() action,
    Duration timeout = const Duration(seconds: 6),
    bool showDialogIfOffline = true,
  }) async {
    try {
      return await action().timeout(timeout);
    } on TimeoutException {
      final online = await hasRealInternet();
      if (!online) {
        if (showDialogIfOffline) await OfflineOverlay.open();
        throw NoInternetException();
      }
      rethrow;
    } on SocketException {
      final online = await hasRealInternet();
      if (!online) {
        if (showDialogIfOffline) await OfflineOverlay.open();
        throw NoInternetException();
      }
      rethrow;
    } on HandshakeException {
      final online = await hasRealInternet();
      if (!online) {
        if (showDialogIfOffline) await OfflineOverlay.open();
        throw NoInternetException();
      }
      rethrow;
    } on HttpException {
      final online = await hasRealInternet();
      if (!online) {
        if (showDialogIfOffline) await OfflineOverlay.open();
        throw NoInternetException();
      }
      rethrow;
    }
  }
}

/// ====== Heartbeat: อัปเดต lastSeen เป็นระยะ และคำนวณ status ฝั่ง client ======
class Heartbeat {
  Heartbeat._();
  static final Heartbeat I = Heartbeat._();

  Timer? _timer;
  Duration interval = const Duration(seconds: 60);
  bool? _lastOnline;

  void start() {
    stop();
    _timer = Timer.periodic(interval, (_) => _beat());
    _beat(); // ยิงทันทีครั้งแรก
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _beat() async {
    // คำนวณออนไลน์จริง ๆ แล้วอัปเดต lastSeen + status
    final online = await hasRealInternet();
    if (_lastOnline != online) {
      _lastOnline = online;
    }

    try {
      await FirebaseFirestore.instance
          .collection('Raspberry_pi')
          .doc(kRaspberryDocId)
          .update({
        'lastSeen': FieldValue.serverTimestamp(),
        'status': online ? 'online' : 'offline',
      });
    } catch (_) {
      // เงียบไว้
    }
  }
}

/// ====== เฝ้าเน็ต real‑time (connectivity_plus + ตรวจซ้ำ) และอัปเดต Firestore ======
class NetworkWatcher {
  static StreamSubscription<List<ConnectivityResult>>? _sub;
  static bool? _lastOnline;

  static void start() {
    stop();

    _sub = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      final hasLink = results.any((r) => r != ConnectivityResult.none);
      final online = hasLink ? await hasRealInternet() : false;
      if (_lastOnline == online) return;
      _lastOnline = online;

      // อัปเดต UI
      if (!online) {
        await OfflineOverlay.open();
      } else {
        await OfflineOverlay.close();
      }

      // อัปเดต Firestore (status + lastSeen)
      await _writeStatus(online);
    });

    _primeOnce();
  }

  static Future<void> _primeOnce() async {
    final r = await Connectivity().checkConnectivity();
    final online = (r != ConnectivityResult.none) ? await hasRealInternet() : false;
    _lastOnline = online;
    if (!online) await OfflineOverlay.open();
    await _writeStatus(online);
  }

  static Future<void> _writeStatus(bool online) async {
    if (Firebase.apps.isEmpty) return; // เผื่อถูกเรียกก่อน init
    try {
      await FirebaseFirestore.instance
          .collection('Raspberry_pi')
          .doc(kRaspberryDocId)
          .update({
        'status': online ? 'online' : 'offline',
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // เงียบไว้
    }
  }

  static void stop() {
    _sub?.cancel();
    _sub = null;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'Flutter App',
      home: const RootGate(),
    );
  }
}

/// RootGate: รอ Firebase → เริ่ม NetworkWatcher+Heartbeat → เข้า Wrapper
class RootGate extends StatefulWidget {
  const RootGate({super.key});
  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> with WidgetsBindingObserver {
  bool _firebaseReady = false;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFirebase();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NetworkWatcher.stop();
    Heartbeat.I.stop();
    super.dispose();
  }

  /// lifecycle: เวลาสลับโฟกัส ยิง heartbeat ทันที
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      Heartbeat.I.start();
    }
  }

  Future<void> _initFirebase() async {
    if (_initializing) return;
    _initializing = true;
    setState(() {});

    try {
      await NetGuard.run(
        timeout: const Duration(seconds: 8),
        action: () async {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );

          // Local notifications
          const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
          const initSettings = InitializationSettings(android: androidInit);
          await flutterLocalNotificationsPlugin.initialize(initSettings);

          // Notification Channel (Android)
          await flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'high_importance_channel',
              'High Importance Notifications',
              description: 'This channel is used for important notifications.',
              importance: Importance.max,
            ),
          );

          // FCM
          await FirebaseMessaging.instance.requestPermission();
          await FirebaseMessaging.instance.subscribeToTopic('animal_alerts');

          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
            final n = message.notification;
            final a = n?.android;
            if (n != null && a != null) {
              flutterLocalNotificationsPlugin.show(
                n.hashCode,
                n.title,
                n.body,
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'high_importance_channel',
                    'High Importance Notifications',
                    channelDescription: 'This channel is used for important notifications.',
                    importance: Importance.max,
                    priority: Priority.high,
                    playSound: true,
                    fullScreenIntent: true,
                  ),
                ),
              );
            }
          });

          FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
            debugPrint("📲 Notification tapped (from background)");
          });

          final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
          if (initialMessage != null) {
            debugPrint("📲 Opened from terminated via notification");
          }
        },
      );

      if (!mounted) return;
      _firebaseReady = true;

      // เริ่มเฝ้าเน็ต + heartbeat เมื่อระบบพร้อม
      NetworkWatcher.start();
      Heartbeat.I.start();
    } on NoInternetException {
      if (!mounted) return;
      _firebaseReady = false;
      Future.delayed(const Duration(seconds: 1), _initFirebase);
    } catch (_) {
      if (!mounted) return;
      _firebaseReady = false;
      Future.delayed(const Duration(seconds: 2), _initFirebase);
    } finally {
      _initializing = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_firebaseReady) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F8FB),
        body: SizedBox.shrink(),
      );
    }
    return const Wrapper();
  }
}

/// ===== หน้าเต็มจอเมื่อออฟไลน์ =====
class _NoInternetPage extends StatefulWidget {
  const _NoInternetPage();

  @override
  State<_NoInternetPage> createState() => _NoInternetPageState();
}

class _NoInternetPageState extends State<_NoInternetPage> {
  bool _checking = false;

  Future<void> _retry() async {
    if (_checking) return;
    if (!mounted) return;
    setState(() => _checking = true);

    final ok = await hasRealInternet();

    if (!mounted) return;
    setState(() => _checking = false);

    if (ok) {
      // อัปเดตสถานะด้วยว่าออนไลน์แล้ว + lastSeen
      try {
        await FirebaseFirestore.instance
            .collection('Raspberry_pi')
            .doc(kRaspberryDocId)
            .update({
          'status': 'online',
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
      // ปิดผ่านตัวกลาง → กัน pop ซ้อน
      await OfflineOverlay.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 72, color: Color(0xFF263F6B)),
                const SizedBox(height: 16),
                const Text(
                  'กรุณาตรวจสอบระบบเครือข่ายของคุณ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'การเชื่อมต่ออาจถูกปิดหรือสัญญาณขาดหายชั่วคราว',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _retry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF263F6B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _checking
                        ? const SizedBox(
                            height: 22, width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('ลองอีกครั้ง',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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

/// ===== ครอบ UI ตอนกำลังโหลดนาน ๆ (ถ้าต้องใช้เฉพาะจุด) =====
class GuardWhileWaiting extends StatefulWidget {
  final Duration after;
  final Widget child;
  const GuardWhileWaiting({
    super.key,
    this.after = const Duration(seconds: 6),
    required this.child,
  });

  @override
  State<GuardWhileWaiting> createState() => _GuardWhileWaitingState();
}

class _GuardWhileWaitingState extends State<GuardWhileWaiting> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(widget.after, () async {
      if (!mounted) return;
      final ok = await hasRealInternet();
      if (!ok && mounted) {
        await OfflineOverlay.open();
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
