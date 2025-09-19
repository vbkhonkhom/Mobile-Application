import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final TextEditingController _serialController = TextEditingController();

  Future<void> saveToFirestore(String serial) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final serialRef = FirebaseFirestore.instance.collection('Raspberry_pi').doc(serial);
    final serialDoc = await serialRef.get();

    if (!serialDoc.exists) {
      _showMessage("ไม่พบอุปกรณ์นี้ในระบบ");
      return;
    }

    final data = serialDoc.data()!;
    final currentStatus = data['status'];
    final currentOwnerId = data['ownerId'];
    // ✅ เพิ่มการตรวจสอบว่า timestamp มีอยู่แล้วหรือไม่
    final hasTimestamp = data.containsKey('timestamp');

    if (currentStatus == 'To be Added') {
      // ✅ ยังไม่มีเจ้าของ และพร้อมใช้งาน
      await serialRef.update({
        'status': 'online',
        'ownerId': user.uid,
        // ✅ เพิ่ม timestamp เฉพาะเมื่อยังไม่มี timestamp
        if (!hasTimestamp) 'timestamp': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context, serial); // ✅ ส่ง serial กลับไปหน้า homepage
    } else if (currentStatus == 'online') {
      if (currentOwnerId == user.uid) {
        Navigator.pop(context, serial); // ✅ เจ้าของเดิมเข้ามาซ้ำ ให้ผ่าน
      } else {
        _showMessage("อุปกรณ์นี้ถูกใช้งานโดยบัญชีอื่นแล้ว");
      }
    } else {
      _showMessage("ไม่สามารถใช้อุปกรณ์นี้ได้");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 🔙 ปุ่มย้อนกลับ
            Padding(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: Color(0xFF263F6B)),
                ),
              ),
            ),
            const Text(
              "Serial ID",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: TextField(
                controller: _serialController,
                decoration: InputDecoration(
                  hintText: "กรอก Serial ID",
                  filled: true,
                  fillColor: Colors.blue[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF263F6B)),
              onPressed: () async {
                final serial = _serialController.text.trim();
                if (serial.isNotEmpty) {
                  await saveToFirestore(serial);
                } else {
                  _showMessage("กรุณากรอก Serial ID");
                }
              },
              child: const Text("ยืนยัน", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}