import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'addhelpscreen.dart';
import 'edithelpscreen.dart';

/// ===================================================================
/// [StatelessWidget] หน้าสำหรับแสดงข้อมูล "ช่วยเหลือ"
/// - ใช้ StreamBuilder เพื่อแสดงข้อมูลจาก Firestore แบบ Real-time
///   หมายความว่าถ้ามีข้อมูลเปลี่ยนแปลงในฐานข้อมูล หน้าจอนี้จะอัปเดตเองอัตโนมัติ
/// - ผู้ใช้สามารถเพิ่มข้อมูลใหม่ได้
/// - ผู้ใช้จะสามารถแก้ไขได้เฉพาะข้อมูลที่ตัวเองเป็นคนเพิ่มเข้ามาเท่านั้น
/// ===================================================================
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ช่วยเหลือ',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF263F6B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('helps')
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('ยังไม่มีข้อมูลช่วยเหลือ'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final name = data['name'] ?? '';
              final phone = data['phone'] ?? '';
              final ownerId = data.containsKey('ownerId') ? data['ownerId'] : '';
              final docId = docs[index].id;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (ownerId == uid)
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditHelpScreen(
                                    docId: docId,
                                    currentName: name,
                                    currentPhone: phone,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    Text('เบอร์โทร : $phone'),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddHelpScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF263F6B),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text("เพิ่มข้อมูล", style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
