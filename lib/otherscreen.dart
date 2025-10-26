import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:project/accountscreen.dart';
import 'package:project/helpscreen.dart';
import 'package:project/historyscreen.dart';
import 'package:project/wrapper.dart';
import 'package:project/about.dart'; // <<< ตรวจสอบว่า import ไฟล์ about.dart ถูกต้อง

class OtherScreen extends StatefulWidget {
  const OtherScreen({super.key});

  @override
  State<OtherScreen> createState() => _OtherScreenState();
}

class _OtherScreenState extends State<OtherScreen> {
  final user = FirebaseAuth.instance.currentUser;

  late Future<Map<String, dynamic>> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeScreen();
  }

  Future<Map<String, dynamic>> _initializeScreen() async {
    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final results = await Future.wait([
      _checkInvites(),
      _loadUserRole(),
    ]);

    return {
      'hasInvite': results[0] as bool,
      'roleLabel': results[1] as String?,
    };
  }

  Future<bool> _checkInvites() async {
    // ... (โค้ดเหมือนเดิม) ...
    final inviteSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('invites')
        .limit(1)
        .get();
    return inviteSnap.docs.isNotEmpty;
  }

  Future<String?> _loadUserRole() async {
    // ... (โค้ดเหมือนเดิม) ...
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
    return null;
  }

  // --- START: แก้ไขฟังก์ชัน signOut ---
  Future<void> signOut() async {
    // แสดงกล่องยืนยันก่อนออกจากระบบ
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // คืนค่า false
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // คืนค่า true
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    // ถ้าผู้ใช้กดยืนยัน (confirm == true)
    if (confirm == true) {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Wrapper()),
        (route) => false,
      );
    }
  }
  // --- END: แก้ไขฟังก์ชัน signOut ---

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
          );
        }

        final data = snapshot.data!;
        final hasInvite = data['hasInvite'] as bool;
        final roleLabel = data['roleLabel'] as String?;

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
                    icon: Icons.group,
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
                    icon: Icons.contact_support_outlined,
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
                  MenuTile(
                    icon: Icons.info_outline,
                    title: 'เกี่ยวกับ',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const About(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: ElevatedButton(
                      onPressed: signOut, // <<< ปุ่มนี้เรียกใช้ฟังก์ชัน signOut ที่แก้ไขแล้ว
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

// คลาส MenuTile เหมือนเดิม
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
    return Container(
      color: const Color(0xFFe8f3ff),
      margin: const EdgeInsets.symmetric(vertical: 1.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(icon, color: Colors.black),
        title: titleWidget ??
            Text(
              title ?? '',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
        onTap: onTap,
      ),
    );
  }
}
