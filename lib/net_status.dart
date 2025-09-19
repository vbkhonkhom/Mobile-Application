// lib/net_status.dart
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetStatusService {
  NetStatusService._();
  static final NetStatusService I = NetStatusService._();

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get online$ => _controller.stream;

  Timer? _probeTimer;
  bool? _lastOnline;
  String? _raspberryDocId; // ต้องตั้งค่าก่อนเริ่มเฝ้าดู

  /// ตั้งค่า docId ของเอกสาร Raspberry_pi ที่ต้องการอัปเดต
  void setRaspberryDocId(String docId) {
    _raspberryDocId = docId;
  }

  /// ตรวจว่ามีอินเทอร์เน็ต "จริง" โดยต่อออกนอก
  Future<bool> hasRealInternet({Duration timeout = const Duration(seconds: 2)}) async {
    Future<bool> tryHost(String host, int port) async {
      try {
        final s = await Socket.connect(host, port, timeout: timeout);
        s.destroy();
        return true;
      } catch (_) {
        return false;
      }
    }

    // หลายโฮสต์พร้อมกัน เพิ่มความชัวร์
    final probes = await Future.wait<bool>([
      tryHost('1.1.1.1', 53),
      tryHost('8.8.8.8', 53),
      tryHost('one.one.one.one', 53),
    ]);
    return probes.any((ok) => ok);
  }

  // ✅ เวอร์ชันใหม่ของ connectivity_plus ต้องเป็น List<ConnectivityResult>
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _debounceWrite;

  /// เริ่มเฝ้าดู (ใช้บน Foreground)
  Future<void> startForegroundWatch({Duration probeInterval = const Duration(seconds: 10)}) async {
    // ยกเลิกตัวเดิมหากมี
    _connSub?.cancel();

    // ฟังการเปลี่ยนแปลงจากระบบเครือข่าย (API ใหม่คืน List<ConnectivityResult>)
    _connSub = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      final hasLink = results.any((r) => r != ConnectivityResult.none);
      final online = hasLink ? await hasRealInternet() : false;
      _emitAndMaybeWrite(online);
    });

    // ตั้ง periodic probe กัน edge case ที่ระบบไม่แจ้งเหตุการณ์
    _probeTimer?.cancel();
    _probeTimer = Timer.periodic(probeInterval, (_) async {
      final online = await hasRealInternet();
      _emitAndMaybeWrite(online);
    });

    // ยิงครั้งแรกทันที
    final first = await hasRealInternet();
    _emitAndMaybeWrite(first);
  }

  /// หยุดเฝ้าดู (เช่น dispose)
  void stopForegroundWatch() {
    _connSub?.cancel();
    _connSub = null;
    _probeTimer?.cancel();
    _probeTimer = null;
    _debounceWrite?.cancel();
    _debounceWrite = null;
  }

  void _emitAndMaybeWrite(bool online) {
    if (_lastOnline == online) {
      _controller.add(online);
      return;
    }
    _lastOnline = online;
    _controller.add(online);

    // ดีบาวน์การเขียน 700ms กันสั่น
    _debounceWrite?.cancel();
    _debounceWrite = Timer(const Duration(milliseconds: 700), () {
      _writeStatus(online);
    });
  }

  Future<void> _writeStatus(bool online) async {
    final docId = _raspberryDocId;
    if (docId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('Raspberry_pi')
          .doc(docId)
          .update({
        'status': online ? 'online' : 'offline',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // เงียบไว้หรือ print ก็ได้
    }
  }
}
