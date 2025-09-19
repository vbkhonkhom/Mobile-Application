import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDeviceSerials();
  }

  Future<void> _loadDeviceSerials() async {
    final snap = await FirebaseFirestore.instance.collection('Raspberry_pi').get();
    final all = snap.docs;

    // สร้างรายการชื่อ + serial
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
        selectedSerial = widget.serialNumber;
      });
    }
  }

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
    if (selectedSerial == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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

                    return _NotificationCard(
                      imageUrl: data['image_url'],
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
