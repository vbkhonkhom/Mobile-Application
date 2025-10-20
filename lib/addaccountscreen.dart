import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ===================================================================
/// [StatefulWidget] หน้าสำหรับ "เพิ่มบัญชี" (ส่งคำเชิญ)
/// - หน้านี้มีไว้สำหรับ "เจ้าบ้าน" (Owner) เพื่อส่งคำเชิญไปยังผู้ใช้อื่น
///   ให้มาเป็น "ลูกบ้าน" (Member)
/// ===================================================================
class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  /// ===================================================================
  /// [สำคัญ] ฟังก์ชันหลักสำหรับตรวจสอบและส่งคำเชิญ
  /// - มีขั้นตอนการตรวจสอบหลายชั้นก่อนที่จะสร้างคำเชิญใน Firestore
  /// ===================================================================
  Future<void> _submit() async {
  final email = _emailController.text.trim();
  if (email.isEmpty || !email.contains('@')) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("กรุณากรอกอีเมลให้ถูกต้อง")),
    );
    return;
  }

  setState(() => _isLoading = true);
  final currentUser = FirebaseAuth.instance.currentUser;

  if (email == currentUser?.email) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("ไม่สามารถเพิ่มอีเมลของตัวเองได้")),
    );
    setState(() => _isLoading = false);
    return;
  }

  try {
    // ✅ ค้นหา UID ของอีเมลลูกบ้าน
    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ไม่พบบัญชีนี้ในระบบ")),
      );
      return;
    }

    final memberDoc = userQuery.docs.first;
    final memberUid = memberDoc.id;

    // ✅ เช็คว่าเคยเชิญแล้วหรือยัง
    final inviteSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(memberUid)
        .collection('invites')
        .doc(currentUser!.uid)
        .get();

    if (inviteSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("คุณได้ส่งคำเชิญไปแล้ว")),
      );
      return;
    }

    // ✅ ดึง shared ของ currentUser เพื่อตรวจสอบว่าเป็นลูกบ้านอยู่แล้วหรือยัง
    final ownerSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final ownerData = ownerSnapshot.data();
    final sharedList = (ownerData?['shared'] as List<dynamic>? ?? []);

    if (sharedList.contains(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ผู้ใช้นี้เป็นลูกบ้านอยู่แล้ว")),
      );
      return;
    }

    // ✅ สร้างคำเชิญใหม่
    print("Trying to write to: users/$memberUid/invites/${currentUser.uid}");

    await FirebaseFirestore.instance
        .collection('users')
        .doc(memberUid)
        .collection('invites')
        .doc(currentUser.uid)
        .set({
          'owner': currentUser.uid,
          'email': currentUser.email,
          'inviteAt': FieldValue.serverTimestamp(),
        });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("ส่งคำเชิญสำเร็จ")),
    );
    Navigator.pop(context);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("เกิดข้อผิดพลาด: $e")),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
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
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF263F6B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            const Text(
              "เพิ่มบัญชี",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              "บุคคลที่มีสิทธิ์เข้าถึง",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: "example@email.com",
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
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF263F6B),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text("Confirm", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
