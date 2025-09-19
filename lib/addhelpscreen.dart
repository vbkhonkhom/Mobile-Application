import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddHelpScreen extends StatefulWidget {
  const AddHelpScreen({super.key});

  @override
  State<AddHelpScreen> createState() => _AddHelpScreenState();
}

class _AddHelpScreenState extends State<AddHelpScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  void saveToFirestore() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isNotEmpty && phone.isNotEmpty) {
      await FirebaseFirestore.instance.collection('helps').add({
        'name': name,
        'phone': phone,
        'ownerId': FirebaseAuth.instance.currentUser?.uid ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      Navigator.pop(context, true); // ส่งกลับไปบอกว่าเพิ่มสำเร็จ
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context), // กลับหน้าเดิม
                  child: const Icon(Icons.arrow_back, color: Color(0xFF263F6B)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("เพิ่มข้อมูล", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'ชื่อหน่วยงาน',
                  filled: true,
                  fillColor: Colors.blue[100],
                ),
              ),
            ),
            const SizedBox(height: 10),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'เบอร์โทร',
                  filled: true,
                  fillColor: Colors.blue[100],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveToFirestore,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF263F6B)),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
