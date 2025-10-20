import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/homepage.dart';
import 'package:project/login.dart';

/// ===================================================================
/// [StatelessWidget] Wrapper - ทำหน้าที่เป็น "ประตู" หรือ "ผู้คัดกรอง"
/// - หน้าที่เดียวของมันคือ ตรวจสอบสถานะการล็อกอินของผู้ใช้ แล้วเลือกว่าจะ
///   แสดงหน้า Login หรือหน้า Homepage
/// - ทำให้การจัดการ Flow การล็อกอินและออกจากระบบเป็นไปอย่างอัตโนมัติ
/// ===================================================================
class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user != null) {
          return const Homepage();
        } else {
          return const Login();
        }
      },
    );
  }
}
