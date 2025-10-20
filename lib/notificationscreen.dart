import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  final String serialNumber;

  const NotificationScreen({super.key, required this.serialNumber});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, String>> devices = [];
  String? selectedSerial;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeviceSerialsForCurrentUser();
  }

  Future<void> _loadDeviceSerialsForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    String ownerId;

    if (userData != null && userData.containsKey('owner')) {
      ownerId = userData['owner'];
    } else {
      ownerId = user.uid;
    }

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
        if (devices.any((d) => d['serial'] == widget.serialNumber)) {
          selectedSerial = widget.serialNumber;
        } else if (devices.isNotEmpty) {
          selectedSerial = devices.first['serial'];
        } else {
          selectedSerial = null;
        }
        _isLoading = false;
      });
    }
  }

  String _translateType(String type) {
    switch (type.toLowerCase()) {
      case 'mouse':
        return 'หนู';
      case 'snake':
        return 'งู';
      case 'centipede':
        return 'ตะขาบ';
      case 'lizard':
        return 'ตัวเงินตัวทอง';
      default:
        return type;
    }
  }

  String formatDetectedTypes(dynamic detectedObjects) {
    if (detectedObjects is! List || detectedObjects.isEmpty) {
      return 'ไม่ระบุชนิด';
    }

    final counts = <String, int>{};
    for (var item in detectedObjects) {
      if (item is Map && item.containsKey('type')) {
        final type = item['type'].toString().toLowerCase();
        counts[type] = (counts[type] ?? 0) + 1;
      }
    }

    if (counts.isEmpty) {
      return 'ไม่ระบุชนิด';
    }

    return counts.entries.map((entry) {
      final thaiType = _translateType(entry.key);
      return '${thaiType} ${entry.value} ตัว';
    }).join(', ');
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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

                docs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;

                  final tsValueA = dataA['timestamp'];
                  final tsValueB = dataB['timestamp'];

                  DateTime dtA;
                  DateTime dtB;

                  if (tsValueA is Timestamp) {
                    dtA = tsValueA.toDate();
                  } else if (tsValueA is String) {
                    dtA = DateTime.tryParse(tsValueA) ?? DateTime(1970);
                  } else {
                    dtA = DateTime(1970);
                  }

                  if (tsValueB is Timestamp) {
                    dtB = tsValueB.toDate();
                  } else if (tsValueB is String) {
                    dtB = DateTime.tryParse(tsValueB) ?? DateTime(1970);
                  } else {
                    dtB = DateTime(1970);
                  }

                  return dtB.compareTo(dtA);
                });

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;

                    final dynamic tsValue = data['timestamp'];
                    DateTime ts;
                    if (tsValue is Timestamp) {
                      ts = tsValue.toDate();
                    } else if (tsValue is String) {
                      ts = DateTime.tryParse(tsValue) ?? DateTime.now();
                    } else {
                      ts = DateTime.now();
                    }

                    final imageUrl = data['image_url'] as String?;
                    final detectedObjects = data['detected_objects'];

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
                      detectedSummary: formatDetectedTypes(detectedObjects),
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
    required this.detectedSummary,
  });

  final String imageUrl;
  final DateTime dateTime;
  final String detectedSummary;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        children: [
          // --- 🎯 START: เพิ่ม GestureDetector ครอบรูปภาพ ---
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) {
                return _FullScreenImageViewer(imageUrl: imageUrl);
              }));
            },
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
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
                        const SizedBox(height: 8),
                        Text('ไม่สามารถโหลดรูปภาพได้', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          // --- 🎯 END: เพิ่ม GestureDetector ---
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
                    detectedSummary,
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

// Widget ใหม่สำหรับแสดงภาพเต็มจอ ---
class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          Navigator.pop(context); // กดเพื่อกลับ
        },
        child: Center(
          child: InteractiveViewer( // Widget ที่ช่วยให้ซูมและเลื่อนได้
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4,
            child: Image.network(imageUrl),
          ),
        ),
      ),
    );
  }
}
