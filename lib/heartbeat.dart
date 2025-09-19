import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class Heartbeat {
  Heartbeat._();
  static final Heartbeat I = Heartbeat._();

  Timer? _t;
  String? _docId;

  void setDoc(String docId) {
    _docId = docId;
  }

  void start({Duration every = const Duration(seconds: 60)}) {
    stop();
    _t = Timer.periodic(every, (_) => _beat());
    _beat(); // ยิงทันทีครั้งแรก
  }

  void stop() {
    _t?.cancel();
    _t = null;
  }

  Future<void> _beat() async {
    final id = _docId;
    if (id == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('Raspberry_pi')
          .doc(id)
          .update({'lastSeen': FieldValue.serverTimestamp()});
    } catch (_) {}
  }
}
