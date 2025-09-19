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

  Future<void> _loadAccessibleSerials() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final firestore = FirebaseFirestore.instance;

    String ownerId = uid;

    // ตรวจสอบว่า user นี้เป็นลูกบ้านหรือเจ้าบ้าน
    final userDoc = await firestore.collection('users').doc(uid).get();
    final userData = userDoc.data();
    if (userData != null && userData['owner'] != null) {
      ownerId = userData['owner'];
    }

    // หาอุปกรณ์ทั้งหมดที่ ownerId นี้เป็นเจ้าของ
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

    setState(() {
      serials = allDevices;
      selectedSerial = allDevices.isNotEmpty ? allDevices.first['serial'] : null;
      isLoading = false;
    });
  }

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
        .orderBy('timestamp', descending: !showStatistic)
        .snapshots();
  }

  Widget _buildStatTable(List<QueryDocumentSnapshot> docs) {
    final freq = {for (var t in allTypes) t: 0};

    for (var d in docs) {
      final t = d['type'].toString().toLowerCase();
      if (freq.containsKey(t)) freq[t] = (freq[t] ?? 0) + 1;
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
        final ts = (data['timestamp'] as Timestamp).toDate();
        final date = DateFormat('dd/MM/yy').format(ts);
        final time = DateFormat('HH:mm').format(ts);

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
                Expanded(flex: 3, child: Text(thType(data['type']), textAlign: TextAlign.center)),
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
                          DateTime.now().year - 2025 + 1,
                          (i) => 2025 + i,
                        ).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
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
