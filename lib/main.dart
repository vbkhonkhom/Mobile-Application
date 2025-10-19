import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'wrapper.dart';

// Firebase / FCM
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // เพิ่ม import นี้
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // เปิด UI ก่อน (Firebase ไปทำใน RootGate)
  runApp(const MyApp());
}

// --- 🎯 START: โค้ดที่เพิ่มเข้ามา ---
/// ====== ฟังก์ชันสำหรับอัปเดต Topic Subscription ของผู้ใช้ ======
Future<void> updateUserTopicSubscription() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final messaging = FirebaseMessaging.instance;
  
  // ยกเลิกการสมัคร topic เก่าก่อนเสมอ (เผื่อมีการเปลี่ยนแปลง)
  // หมายเหตุ: หากคุณมี topic อื่นๆ ที่ต้องการให้ user subscribe ค้างไว้ อาจจะต้องจัดการส่วนนี้เพิ่มเติม
  await messaging.unsubscribeFromTopic('animal_alerts');

  // 1. หา userId ที่แท้จริง
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  final userData = userDoc.data();
  String? userId; // <-- เปลี่ยนเป็น nullable

  if (userData != null && userData.containsKey('user')) {
    // กรณีเป็นลูกบ้าน
    userId = userData['user'];
  } else {
    // กรณีเป็นเจ้าบ้าน (ใช้ uid ของตัวเองเป็น topic)
    userId = user.uid;
  }

  // 2. สมัครรับ topic ใหม่ที่เป็น userId
  if (userId != null && userId.isNotEmpty) {
    print("✅ Subscribing to topic: $userId");
    await messaging.subscribeToTopic(userId);
  } else {
    print("⚠️ No userId found, cannot subscribe to a topic.");
  }
}
// --- END: โค้ดที่เพิ่มเข้ามา ---


/// ====== ฟังก์ชันกลางสำหรับอัปเดตสถานะอุปกรณ์ทั้งหมดของผู้ใช้ ======
Future<void> _updateAllDeviceStatuses(bool online) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return; // ถ้ายังไม่ล็อกอิน ก็ไม่ต้องทำอะไร

  try {
    // 1. ค้นหาอุปกรณ์ทั้งหมดที่ user คนนี้เป็นเจ้าของ
    final querySnapshot = await FirebaseFirestore.instance
        .collection('Raspberry_pi')
        .where('userId', isEqualTo: user.uid)
        .get();
    
    if (querySnapshot.docs.isEmpty) return; // ไม่มีอุปกรณ์ให้อัปเดต

    // 2. ใช้ WriteBatch เพื่ออัปเดตทุกอุปกรณ์ในครั้งเดียว (มีประสิทธิภาพกว่า)
    final batch = FirebaseFirestore.instance.batch();
    
    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {
        'status': online ? 'online' : 'offline',
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }

    // 3. ส่งคำสั่งอัปเดตทั้งหมด
    await batch.commit();

  } catch (e) {
    // เงียบไว้ หรือจะ print error เพื่อ debug ก็ได้
    // print("Error updating device statuses: $e");
  }
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
    final online = await hasRealInternet();
    if (_lastOnline != online) {
      _lastOnline = online;
    }
    // --- เรียกใช้ฟังก์ชันกลาง ---
    await _updateAllDeviceStatuses(online);
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
    final online = (r.any((res) => res != ConnectivityResult.none)) ? await hasRealInternet() : false;
    _lastOnline = online;
    if (!online) await OfflineOverlay.open();
    await _writeStatus(online);
  }

  static Future<void> _writeStatus(bool online) async {
    if (Firebase.apps.isEmpty) return; // เผื่อถูกเรียกก่อน init
    // --- เรียกใช้ฟังก์ชันกลาง ---
    await _updateAllDeviceStatuses(online);
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

// START: โค้ดส่วนของ RootGate ที่ถูกแก้ไข
class RootGate extends StatefulWidget {
  const RootGate({super.key});
  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSystem();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NetworkWatcher.stop();
    Heartbeat.I.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // เช็คว่า Firebase พร้อมใช้งานแล้วหรือยังก่อนเริ่ม Heartbeat
    if (Firebase.apps.isNotEmpty &&
        (state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused)) {
      Heartbeat.I.start();
    }
  }

  Future<void> _initializeSystem() async {
    try {
      // ใช้ NetGuard เพื่อให้แน่ใจว่ามีเน็ตก่อนเริ่ม
      await NetGuard.run(
        timeout: const Duration(seconds: 8),
        action: () async {
          // 1. Init Firebase
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );

          // 2. ตั้งค่า Local Notifications
          const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
          const initSettings = InitializationSettings(android: androidInit);
          await flutterLocalNotificationsPlugin.initialize(initSettings);

          // 3. สร้าง Notification Channel (สำหรับ Android)
          await flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'high_importance_channel',
              'High Importance Notifications',
              description:
                  'This channel is used for important notifications.',
              importance: Importance.max,
            ),
          );
          
          // 4. ตั้งค่า Firebase Messaging (FCM)
          await FirebaseMessaging.instance.requestPermission();

          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
            final n = message.notification;
            if (n != null) {
              flutterLocalNotificationsPlugin.show(
                n.hashCode,
                n.title,
                n.body,
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'high_importance_channel',
                    'High Importance Notifications',
                    channelDescription:
                        'This channel is used for important notifications.',
                    importance: Importance.max,
                    priority: Priority.high,
                    playSound: true,
                    fullScreenIntent: true,
                  ),
                ),
              );
            }
          });
        },
      );

      // เมื่อ Firebase และระบบต่างๆ พร้อม
      if (!mounted) return;

      // อัปเดต Topic ของ FCM ตาม User ID
      await updateUserTopicSubscription();

      // เริ่มระบบติดตามสถานะเน็ตและอัปเดต lastSeen
      NetworkWatcher.start();
      Heartbeat.I.start();
      
      // *** เมื่อทุกอย่างเสร็จสิ้น ให้เปลี่ยนหน้าไปยัง Wrapper ***
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Wrapper()),
      );

    } catch (e) {
      // หากเกิดปัญหา (ส่วนใหญ่คือไม่มีเน็ต) ให้ลองใหม่ใน 2 วินาที
      // คุณอาจจะแสดงข้อความข้อผิดพลาดที่นี่ก็ได้
      if (mounted) {
        Future.delayed(const Duration(seconds: 2), _initializeSystem);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // แสดงหน้า Loading นี้เสมอตอนเริ่มต้นแอป
    return Scaffold(
      backgroundColor: const Color(0xFF263F6B), // สีพื้นหลังเหมือนหน้า Login
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logoapp.png',
              height: 120,
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'กำลังเริ่มต้น...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// END: โค้ดส่วนของ RootGate ที่ถูกแก้ไข

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
      await _updateAllDeviceStatuses(true);
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