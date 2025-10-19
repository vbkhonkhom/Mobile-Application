import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:project/accountscreen.dart';
import 'package:project/helpscreen.dart';
import 'package:project/historyscreen.dart';
import 'package:project/wrapper.dart';

class OtherScreen extends StatefulWidget {
  const OtherScreen({super.key});

  @override
  State<OtherScreen> createState() => _OtherScreenState();
}

class _OtherScreenState extends State<OtherScreen> {
  final user = FirebaseAuth.instance.currentUser;

  // 1. เปลี่ยนมาใช้ Future เพื่อให้ FutureBuilder ทำงานได้
  late Future<Map<String, dynamic>> _initializationFuture;

  @override
  void initState() {
    super.initState();
    // 2. เรียกฟังก์ชันเพื่อเริ่มโหลดข้อมูล แต่จะยังไม่รอจนเสร็จ
    _initializationFuture = _initializeScreen();
  }

  // 3. ปรับฟังก์ชันให้คืนค่า (return) ข้อมูลที่จำเป็นออกมาเป็น Map
  Future<Map<String, dynamic>> _initializeScreen() async {
    if (user == null) {
      // กรณีที่อาจจะเกิดขึ้นได้ยาก แต่ป้องกันไว้ก่อน
      throw Exception('User is not logged in.');
    }

    // โหลดข้อมูลทั้งสองส่วนพร้อมกันเพื่อความรวดเร็ว
    final results = await Future.wait([
      _checkInvites(),
      _loadUserRole(),
    ]);

    // คืนค่าข้อมูลที่ได้สำหรับนำไปใช้สร้าง UI
    return {
      'hasInvite': results[0] as bool,
      'roleLabel': results[1] as String?,
    };
  }

  Future<bool> _checkInvites() async {
    final inviteSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('invites')
        .limit(1)
        .get();
    return inviteSnap.docs.isNotEmpty;
  }

  Future<String?> _loadUserRole() async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    final data = doc.data();

    if (data == null) return null;

    if (data.containsKey('owner')) {
      return 'ลูกบ้าน';
    } else {
      final deviceSnap = await FirebaseFirestore.instance
          .collection('Raspberry_pi')
          .where('ownerId', isEqualTo: user!.uid)
          .limit(1)
          .get();
      if (deviceSnap.docs.isNotEmpty) {
        return 'เจ้าบ้าน';
      }
    }
    return null; // กรณีไม่มีอุปกรณ์และไม่ใช่ลูกบ้าน
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Wrapper()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 4. ใช้ FutureBuilder เพื่อจัดการการแสดงผลระหว่างโหลดข้อมูล
    return FutureBuilder<Map<String, dynamic>>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        // **สถานะที่ 1: กำลังโหลดข้อมูล**
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // **สถานะที่ 2: โหลดข้อมูลผิดพลาด**
        if (snapshot.hasError) {
          return Center(
            child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
          );
        }

        // **สถานะที่ 3: โหลดข้อมูลสำเร็จ**
        final data = snapshot.data!;
        final hasInvite = data['hasInvite'] as bool;
        final roleLabel = data['roleLabel'] as String?;

        // 5. นำข้อมูลที่โหลดเสร็จแล้ว (data) มาสร้าง UI ที่สมบูรณ์
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFFd4e8ff),
              child: Row(
                children: [
                  const Icon(Icons.account_circle, color: Color(0xFF263F6B)),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      roleLabel != null
                          ? '${user?.email ?? 'ไม่พบอีเมล'} ($roleLabel)'
                          : user?.email ?? 'ไม่พบอีเมล',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  MenuTile(
                    icon: Icons.settings,
                    titleWidget: Row(
                      children: [
                        const Text('สมาชิกในครัวเรือน'),
                        if (hasInvite)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AccountScreen(),
                        ),
                      );
                    },
                  ),
                  MenuTile(
                    icon: Icons.info_outline,
                    title: 'ช่วยเหลือ',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HelpScreen(),
                      ),
                    ),
                  ),
                  MenuTile(
                    icon: Icons.history,
                    title: 'ประวัติ',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HistoryScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: ElevatedButton(
                      onPressed: signOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        'ออกจากระบบ',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class MenuTile extends StatelessWidget {
  final IconData icon;
  final String? title;
  final Widget? titleWidget;
  final VoidCallback? onTap;

  const MenuTile({
    super.key,
    required this.icon,
    this.title,
    this.titleWidget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: Icon(icon, color: Colors.black),
      title: titleWidget ??
          Text(
            title ?? '',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
      tileColor: const Color(0xFFe8f3ff),
      onTap: onTap,
    );
  }
}