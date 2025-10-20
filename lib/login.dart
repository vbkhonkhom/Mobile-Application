import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// ===================================================================
/// [StatefulWidget] หน้าสำหรับ "เข้าสู่ระบบ" (Login)
/// - ใช้ Google Sign-In เป็นช่องทางหลักในการยืนยันตัวตน
/// - เมื่อล็อกอินสำเร็จ จะมีการสร้างหรืออัปเดตข้อมูลผู้ใช้ใน Firestore
/// ===================================================================
class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<StatefulWidget> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  /// ===================================================================
  /// [สำคัญ] ฟังก์ชันสำหรับจัดการกระบวนการล็อกอินทั้งหมด
  /// - เป็นฟังก์ชันที่ซับซ้อนและเป็นหัวใจของหน้านี้
  /// ===================================================================
  Future<void> login() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final docSnapshot = await docRef.get();

        if (!docSnapshot.exists) {
          // สร้างเอกสารใหม่ (ยังไม่เคยล็อกอินมาก่อน)
          await docRef.set({
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          // เอกสารมีอยู่แล้ว → อัปเดตเฉพาะ email (ไม่แตะ createdAt)
          await docRef.set({
            'email': user.email,
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: ${e.toString()}")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF263F6B),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logoapp.png',
              height: 120,
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    "LOGIN",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: login,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.grey),
                      ),
                    ),
                    icon: Image.asset(
                      'assets/google.png',
                      height: 24,
                    ),
                    label: const Text(
                      "Login with Google",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
