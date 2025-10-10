import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // เพิ่ม import
import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  final String serialNumber;

  const NotificationScreen({super.key, required this.serialNumber});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, String>> devices = []; // ⬅ ใช้ Map เพื่อเก็บ serial + name
  String? selectedSerial;
  bool _isLoading = true; // เพิ่ม state สำหรับ loading

  @override
  void initState() {
    super.initState();
    _loadDeviceSerialsForCurrentUser(); // เปลี่ยนชื่อฟังก์ชัน
  }

  // --- แก้ไขฟังก์ชันนี้ทั้งหมด ---
  Future<void> _loadDeviceSerialsForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 1. หา ownerId ที่ถูกต้อง (เหมือนใน homepage.dart)
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    String ownerId;

    if (userData != null && userData.containsKey('owner')) {
      // กรณีเป็นลูกบ้าน
      ownerId = userData['owner'];
    } else {
      // กรณีเป็นเจ้าบ้าน
      ownerId = user.uid;
    }

    // 2. ดึงข้อมูลเฉพาะอุปกรณ์ที่ผู้ใช้มีสิทธิ์
    final snap = await FirebaseFirestore.instance
        .collection('Raspberry_pi')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final all = snap.docs;

    final loaded = all.asMap().entries.map((entry) {
      final index = entry.key;
      final doc = entry.value;
      final data = doc.data();
      final serial = doc.id;
      final name = (data['name'] ?? '').toString().trim();

      return {
        'serial': serial,
        'name': name.isEmpty ? 'อุปกรณ์ที่ ${index + 1}' : name,
      };
    }).toList();

    if (mounted) {
      setState(() {
        devices = loaded;
        // ตรวจสอบว่า serialNumber ที่รับมา ยังมีสิทธิ์เข้าถึงหรือไม่
        if (devices.any((d) => d['serial'] == widget.serialNumber)) {
          selectedSerial = widget.serialNumber;
        } else if (devices.isNotEmpty) {
          // ถ้าไม่มีสิทธิ์แล้ว ให้เลือกอุปกรณ์ตัวแรกแทน
          selectedSerial = devices.first['serial'];
        } else {
          // ไม่มีอุปกรณ์ให้เลือกเลย
          selectedSerial = null;
        }
        _isLoading = false;
      });
    }
  }
  // --- จบส่วนที่แก้ไข ---

  String translateType(dynamic type) {
    final t = (type ?? '').toString().toLowerCase();
    switch (t) {
      case 'mouse':
        return 'หนู';
      case 'snake':
        return 'งู';
      case 'centipede':
        return 'ตะขาบ';
      case 'lizard':
        return 'ตัวเงินตัวทอง';
      default:
        return t;
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- แก้ไขส่วน Build ---
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // กรณีไม่มีอุปกรณ์เลย
    if (selectedSerial == null || devices.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFd4e8ff),
          foregroundColor: Colors.black,
          title: const Text("การแจ้งเตือน"),
          centerTitle: true,
        ),
        body: const Center(
          child: Text('คุณไม่มีอุปกรณ์ที่สามารถดูการแจ้งเตือนได้'),
        ),
      );
    }
    // --- จบส่วนที่แก้ไข ---

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFd4e8ff),
        foregroundColor: Colors.black,
        title: const Text("การแจ้งเตือน"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: DropdownButton<String>(
              value: selectedSerial,
              isExpanded: true,
              underline: Container(height: 2, color: Colors.black54),
              items: devices
                  .map((device) => DropdownMenuItem<String>(
                        value: device['serial'],
                        child: Text(
                          device['name'] ?? '',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => selectedSerial = val);
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Raspberry_pi')
                  .doc(selectedSerial)
                  .collection('detections')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return const Center(child: Text('เกิดข้อผิดพลาด'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snap.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('ยังไม่มีการแจ้งเตือน'));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final ts = (data['timestamp'] as Timestamp).toDate();
                    final imageUrl = data['image_url'] as String?; // ป้องกัน error ถ้าไม่มี image_url

                    // ถ้าไม่มี imageUrl ให้แสดงเป็น Card เปล่าๆ หรือข้อความแทน
                    if (imageUrl == null) {
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('ไม่มีรูปภาพสำหรับการแจ้งเตือนนี้'),
                        ),
                      );
                    }

                    return _NotificationCard(
                      imageUrl: imageUrl,
                      dateTime: ts,
                      typeTh: translateType(data['type']),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.imageUrl,
    required this.dateTime,
    required this.typeTh,
  });

  final String imageUrl;
  final DateTime dateTime;
  final String typeTh;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              // เพิ่ม errorBuilder และ loadingBuilder เพื่อประสบการณ์ใช้งานที่ดีขึ้น
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey[300],
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.grey[600], size: 40),
                      SizedBox(height: 8),
                      Text('ไม่สามารถโหลดรูปภาพได้', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12).copyWith(top: 6, bottom: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    "${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} น.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    typeTh,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}