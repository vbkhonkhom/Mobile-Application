import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? selectedSerial;
  List<Map<String, String>> serials = [];

  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  bool showStatistic = true;
  bool isLoading = true;

  final List<String> allTypes = ['mouse', 'snake', 'centipede', 'lizard'];

  String thType(String en) => switch (en.toLowerCase()) {
        'mouse' => 'หนู',
        'snake' => 'งู',
        'centipede' => 'ตะขาบ',
        'lizard' => 'ตัวเงินตัวทอง',
        _ => en,
      };

  @override
  void initState() {
    super.initState();
    _loadAccessibleSerials();
  }

  /// ===================================================================
  /// [สำคัญ] โหลดรายการอุปกรณ์ (Serials) ที่ผู้ใช้มีสิทธิ์เข้าถึง
  /// - ตรวจสอบก่อนว่าเป็น 'owner' หรือ 'member' เพื่อหา ownerId ที่ถูกต้อง
  /// - ดึงข้อมูลอุปกรณ์ทั้งหมดจาก Firestore ที่ตรงกับ ownerId นั้น
  /// - นำไปสร้าง List สำหรับ Dropdown เลือกอุปกรณ์
  /// ===================================================================
  Future<void> _loadAccessibleSerials() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final firestore = FirebaseFirestore.instance;

    String ownerId = uid;

    final userDoc = await firestore.collection('users').doc(uid).get();
    final userData = userDoc.data();
    if (userData != null && userData['owner'] != null) {
      ownerId = userData['owner'];
    }

    final snapshot = await firestore
        .collection('Raspberry_pi')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final List<Map<String, String>> allDevices = [];
    for (int i = 0; i < snapshot.docs.length; i++) {
      final doc = snapshot.docs[i];
      final name = doc.data()['name'];
      allDevices.add({
        'serial': doc.id,
        'name': name == null || name.toString().trim().isEmpty
            ? 'อุปกรณ์ที่ ${i + 1}'
            : name.toString(),
      });
    }

    if (mounted) {
      setState(() {
        serials = allDevices;
        selectedSerial = allDevices.isNotEmpty ? allDevices.first['serial'] : null;
        isLoading = false;
      });
    }
  }

  /// ===================================================================
  /// [สำคัญ] สร้าง Stream สำหรับดึงข้อมูล Detections แบบ Real-time
  /// - สร้าง query ไปยัง Firestore เพื่อดึงข้อมูลใน subcollection 'detections'
  /// - กรองข้อมูลเฉพาะเดือนและปีที่ผู้ใช้เลือก (`selectedMonth`, `selectedYear`)
  /// - ใช้ .snapshots() เพื่อให้ StreamBuilder อัปเดตข้อมูลอัตโนมัติเมื่อมีข้อมูลใหม่
  /// ===================================================================
  Stream<QuerySnapshot> _monthStream() {
    if (selectedSerial == null) return const Stream.empty();

    final first = DateTime(selectedYear, selectedMonth, 1);
    final next = DateTime(selectedYear, selectedMonth + 1, 1);

    return FirebaseFirestore.instance
        .collection('Raspberry_pi')
        .doc(selectedSerial)
        .collection('detections')
        .where('timestamp', isGreaterThanOrEqualTo: first)
        .where('timestamp', isLessThan: next)
        .orderBy('timestamp', descending: true) 
        .snapshots();
  }

  // สร้างฟังก์ชัน helper สำหรับแปลง detected_objects เป็นข้อความสรุป
  String _formatDetectedTypes(dynamic detectedObjects) {
    if (detectedObjects is! List || detectedObjects.isEmpty) {
      // ลองหาจาก type เก่า (ถ้ามี)
      return 'ไม่ระบุชนิด';
    }
    final counts = <String, int>{};
    for (var item in detectedObjects) {
      if (item is Map && item.containsKey('type')) {
        final type = item['type'].toString().toLowerCase();
        counts[type] = (counts[type] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return 'ไม่ระบุชนิด';
    return counts.entries.map((e) => '${thType(e.key)} ${e.value} ตัว').join(', ');
  }

  /// ===================================================================
  /// [Widget] สร้างตารางสถิติ (DataTable)
  /// - วนลูปข้อมูล (docs) ที่ได้จาก StreamBuilder
  /// - นับความถี่ของสัตว์แต่ละชนิดจาก field `detected_objects`
  /// - นำข้อมูลที่นับได้มาสร้างเป็นตาราง
  /// ===================================================================
  Widget _buildStatTable(List<QueryDocumentSnapshot> docs) {
    final freq = {for (var t in allTypes) t: 0};

    // วนลูปเพื่อนับจำนวนสัตว์แต่ละชนิด
    for (var d in docs) {
      final data = d.data() as Map<String, dynamic>;
      final detectedObjects = data['detected_objects'];
      if (detectedObjects is List) {
        for (var item in detectedObjects) {
          if (item is Map && item.containsKey('type')) {
            final t = item['type'].toString().toLowerCase();
            if (freq.containsKey(t)) {
              freq[t] = (freq[t] ?? 0) + 1;
            }
          }
        }
      }
    }

    return DataTable(
      headingRowColor: MaterialStateProperty.all(const Color(0xFFD2DBFF)),
      columns: const [
        DataColumn(label: Text('ชนิดของสัตว์')),
        DataColumn(label: Text('จำนวนที่พบ')),
      ],
      rows: freq.entries.map((e) {
        return DataRow(
          cells: [
            DataCell(Center(child: Text(thType(e.key)))),
            DataCell(Center(child: Text('${e.value}'))),
          ],
        );
      }).toList(),
    );
  }

  /// ===================================================================
  /// [Widget] สร้างรายการข้อมูลแบบรายวัน (ListView)
  /// - นำข้อมูล (docs) ที่ได้จาก StreamBuilder มาสร้างเป็น ListView
  /// - แต่ละรายการจะแสดง วันที่, เวลา, และชนิดสัตว์ที่พบ
  /// - เมื่อแตะที่รายการ จะแสดงรูปภาพใน Dialog (ถ้ามี image_url)
  /// ===================================================================
  Widget _buildDailyList(List<QueryDocumentSnapshot> docs) {
    final header = Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: const Color(0xFFD2DBFF),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('วัน/เดือน/ปี', textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('เวลา', textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text('ชนิดของสัตว์', textAlign: TextAlign.center)),
        ],
      ),
    );

    final list = ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final data = docs[i].data()! as Map<String, dynamic>;

        // จัดการ Timestamp ให้ปลอดภัย (รองรับทั้ง Timestamp และ String)
        DateTime ts;
        final dynamic tsValue = data['timestamp'];
        if (tsValue is Timestamp) {
          ts = tsValue.toDate();
        } else if (tsValue is String) {
          ts = DateTime.tryParse(tsValue) ?? DateTime.now();
        } else {
          ts = DateTime.now();
        }

        final date = DateFormat('dd/MM/yy').format(ts);
        final time = DateFormat('HH:mm').format(ts);
        final detectedObjects = data['detected_objects'];
        final summaryText = _formatDetectedTypes(detectedObjects);

        return InkWell(
          onTap: data['image_url'] != null
              ? () => showDialog(
                    context: context,
                    builder: (_) => Dialog(child: Image.network(data['image_url'])),
                  )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text(date, textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text(time, textAlign: TextAlign.center)),
                Expanded(flex: 3, child: Text(summaryText, textAlign: TextAlign.center)),
              ],
            ),
          ),
        );
      },
    );

    return Column(
      children: [
        header,
        Expanded(child: list),
      ],
    );
  }



  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (serials.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF263F6B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Spacer(),
              const Center(
                child: Text('ไม่มีอุปกรณ์', style: TextStyle(fontSize: 18)),
              ),
              const Spacer(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF263F6B)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Text('ประวัติ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DropdownButton<String>(
                value: selectedSerial,
                isExpanded: true,
                items: serials.map((device) {
                  return DropdownMenuItem<String>(
                    value: device['serial'],
                    child: Text(device['name'] ?? 'ไม่ทราบชื่อ'),
                  );
                }).toList(),
                onChanged: (v) => setState(() => selectedSerial = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('ตารางสถิติ'),
                        selected: showStatistic,
                        onSelected: (_) => setState(() => showStatistic = true),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('รายการวัน-เวลา'),
                        selected: !showStatistic,
                        onSelected: (_) => setState(() => showStatistic = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('เดือน '),
                      DropdownButton<int>(
                        value: selectedMonth,
                        underline: Container(height: 1),
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'.padLeft(2, '0'))),
                        ),
                        onChanged: (m) => setState(() => selectedMonth = m ?? selectedMonth),
                      ),
                      const SizedBox(width: 12),
                      const Text('ปี '),
                      DropdownButton<int>(
                        value: selectedYear,
                        underline: Container(height: 1),
                        items: List.generate(
                          DateTime.now().year - 2024 + 1, // แก้ไขปีเริ่มต้น
                          (i) => 2024 + i,
                        ).reversed.toList().map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                        onChanged: (y) => setState(() => selectedYear = y ?? selectedYear),
                      ),
                    ],
                  )
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _monthStream(),
                builder: (_, snap) {
                  if (snap.hasError) return const Center(child: Text('เกิดข้อผิดพลาด'));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                  final docs = snap.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text('ไม่มีข้อมูลเดือนนี้'));

                  return showStatistic
                      ? SingleChildScrollView(child: _buildStatTable(docs))
                      : _buildDailyList(docs);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}