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

  bool hasInvite = false;
  String? roleLabel;
  bool isLoading = true; // ✅ เพิ่ม state โหลดข้อมูล

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _checkInvites();
    await _loadUserRole();
    if (mounted) {
      setState(() {
        isLoading = false; // ✅ ข้อมูลโหลดครบแล้ว
      });
    }
  }

  Future<void> _checkInvites() async {
    final inviteSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('invites')
        .limit(1)
        .get();

    hasInvite = inviteSnap.docs.isNotEmpty;
  }

  Future<void> _loadUserRole() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    final data = doc.data();
    print("🔥 User data: $data");

    if (data == null) return;

    String? label;
    if (data.containsKey('owner')) {
      label = 'ลูกบ้าน';
      print("✅ พบว่าเป็นลูกบ้าน");
    } else {
      final deviceSnap = await FirebaseFirestore.instance
          .collection('Raspberry_pi')
          .where('ownerId', isEqualTo: user!.uid)
          .limit(1)
          .get();
      if (deviceSnap.docs.isNotEmpty) {
        label = 'เจ้าบ้าน';
        print("✅ พบว่าเป็นเจ้าบ้าน");
      }
    }

    roleLabel = label;
    print("🎯 ตั้งค่า roleLabel เป็น: $roleLabel");
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
    if (isLoading) {
      return const Center(child: CircularProgressIndicator()); // ✅ แสดง loading ก่อน
    }

    return Column(
      children: [
        // ✅ แสดงอีเมลผู้ใช้และสถานะ
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
