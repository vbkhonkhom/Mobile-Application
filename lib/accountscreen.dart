import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/addaccountscreen.dart';
import 'package:project/wrapper.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> accountList = [];
  List<Map<String, dynamic>> invites = [];
  bool isEditMode = false;
  int? selectedIndex;
  bool isMember = false;
  bool isDeviceEmpty = true;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([
        _checkIfMember(),
        _checkDeviceExist(),
        _loadSharedAccounts(),
        _loadInvites(),
      ]);
    } catch (e) {
      debugPrint('Error initializing account screen: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _checkIfMember() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    final data = userDoc.data();
    isMember = data != null && data.containsKey('owner');
  }

  Future<void> _checkDeviceExist() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      isDeviceEmpty = true;
      return;
    }

    String targetUid = currentUser.uid;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(targetUid).get();
    final data = userDoc.data();

    if (data != null && data.containsKey('owner')) {
      targetUid = data['owner'];
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('Raspberry_pi')
        .where('ownerId', isEqualTo: targetUid)
        .limit(1)
        .get();

    isDeviceEmpty = snapshot.docs.isEmpty;
  }

  /// โหลดรายชื่อทั้งหมดที่เข้าถึงอุปกรณ์ชุดเดียวกัน:
  /// - ใส่เจ้าบ้าน 1 รายการ (ติดธง isOwner: true)
  /// - ใส่ลูกบ้านทั้งหมด (isOwner: false)
  /// - กันซ้ำด้วย normalize(ตัดช่องว่าง/แปลงเป็นตัวพิมพ์เล็ก)
  Future<void> _loadSharedAccounts() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    final userData = userDoc.data();
    if (userData == null) return;

    // 1) หา owner ที่แท้จริงของกลุ่มนี้
    final String ownerId = userData.containsKey('owner') ? userData['owner'] : currentUser.uid;

    // 2) ดึงอีเมลเจ้าบ้าน
    final ownerDoc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
    final String? ownerEmailRaw = ownerDoc.data()?['email'];
    if (ownerEmailRaw == null) {
      accountList = [];
      return;
    }

    String norm(String s) => s.trim().toLowerCase();
    final String ownerEmail = ownerEmailRaw.trim();
    final String ownerKey = norm(ownerEmail);

    // 3) ใช้ชุด seen แบบ normalize เพื่อกันซ้ำ
    final seen = <String>{};
    final List<Map<String, dynamic>> temp = [];

    // 4) ใส่เจ้าบ้านก่อนและติดธง isOwner
    if (seen.add(ownerKey)) {
      temp.add({'email': ownerEmail, 'isOwner': true});
    }

    // 5) ใส่ลูกบ้านทั้งหมดจาก users/{ownerId}/shared
    final sharedSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(ownerId)
        .collection('shared')
        .get();

    for (final d in sharedSnap.docs) {
      final String? emailRaw = d.data()['email'];
      if (emailRaw == null) continue;

      final email = emailRaw.trim();
      final key = norm(email);

      // กันซ้ำทั้งกรณีซ้ำกับเจ้าบ้าน และซ้ำกันเอง
      if (key.isEmpty || !seen.add(key)) continue;

      temp.add({'email': email, 'isOwner': false});
    }

    accountList = temp;
  }

  Future<void> _loadInvites() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('invites')
        .get();

    invites = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (!data.containsKey('email')) continue;
      final email = data['email'];

      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final fromUid = query.docs.first.id;
        invites.add({
          'docId': doc.id,
          'from': fromUid,
          'fromEmail': email,
        });
      }
    }
  }

  Future<void> _acceptInvite(Map<String, dynamic> invite) async {
    final batch = FirebaseFirestore.instance.batch();
    final userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    final inviteRef = userRef.collection('invites').doc(invite['docId']);
    final ownerRef = FirebaseFirestore.instance.collection('users').doc(invite['from']);

    final sharedDoc = ownerRef.collection('shared').doc(user!.uid);
    batch.set(sharedDoc, {
      'email': user!.email,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    batch.set(userRef, {'owner': invite['from']}, SetOptions(merge: true));
    batch.delete(inviteRef);

    await batch.commit();
    await Future.delayed(const Duration(milliseconds: 300));
    await _initialize();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Wrapper()),
        (route) => false,
      );
    }
  }

  Future<void> _rejectInvite(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('invites')
        .doc(docId)
        .delete();

    await _loadInvites();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ปฏิเสธคำเชิญแล้ว")));
  }

  Future<void> _addSharedAccount(String email) async {
    if (email == user!.email) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ไม่สามารถเพิ่มบัญชีของตัวเองได้")),
      );
      return;
    }

    final users = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (users.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ไม่มีบัญชีนี้ในระบบ")),
      );
      return;
    }

    final targetUid = users.docs.first.id;
    final existingInvite = await FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .collection('invites')
        .doc(user!.uid)
        .get();

    if (existingInvite.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ได้ส่งคำเชิญไปแล้ว")),
      );
      return;
    }

    final sharedSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('shared')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (sharedSnapshot.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("บัญชีนี้เป็นลูกบ้านอยู่แล้ว")),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .collection('invites')
        .doc(user!.uid)
        .set({
      'from': user!.uid,
      'email': user!.email,
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("ส่งคำเชิญสำเร็จ")),
    );
  }

  Future<void> _deleteSelectedAccount() async {
    final selected = accountList[selectedIndex!];

    final result = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: selected['email'])
        .limit(1)
        .get();

    if (result.docs.isNotEmpty) {
      final memberUid = result.docs.first.id;

      final sharedRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('shared')
          .doc(memberUid);

      final memberRef = FirebaseFirestore.instance.collection('users').doc(memberUid);

      final deviceQuery = FirebaseFirestore.instance
          .collection('Raspberry_pi')
          .where('ownerId', isEqualTo: user!.uid)
          .get();

      // ✅ ทำ Firestore query พร้อมกัน
      final results = await Future.wait([
        sharedRef.delete(),
        memberRef.update({'owner': FieldValue.delete()}),
        deviceQuery,
      ]);

      final deviceSnapshot = results[2] as QuerySnapshot;
      final batch = FirebaseFirestore.instance.batch();

      for (var doc in deviceSnapshot.docs) {
        batch.set(doc.reference, {'status': 'ready'}, SetOptions(merge: true));
      }

      await batch.commit();
    }

    await _initialize();

    if (mounted) {
      setState(() {
        selectedIndex = null;
        isEditMode = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? "เลือกบัญชี" : "บัญชี", style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF263F6B)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        actions: [
          if (accountList.isNotEmpty && !isMember)
            TextButton(
              onPressed: () => setState(() {
                isEditMode = !isEditMode;
                selectedIndex = null;
              }),
              child: Text(isEditMode ? 'เสร็จสิ้น' : 'แก้ไข', style: const TextStyle(color: Color(0xFF263F6B))),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final showNoDevice = isDeviceEmpty;
    final showNoInvites = invites.isEmpty;

    return Column(
      children: [
        const SizedBox(height: 10),

        // ❌ เอาส่วนแสดงอีเมลตัวเองด้านบนออก (ไม่ต้องการแล้ว)
        // เดิม: ถ้าไม่ต้องการให้คงไว้ ให้ลบออกอย่างถาวร

        const SizedBox(height: 10),

        if (showNoDevice && showNoInvites)
          const Expanded(
            child: Center(child: Text("กรุณาเพิ่มอุปกรณ์ก่อน", style: TextStyle(fontSize: 16))),
          ),

        if (invites.isNotEmpty) ...invites.map((invite) => _buildInviteCard(invite)),

        if (!showNoDevice)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: accountList.length,
              itemBuilder: (_, index) {
                final account = accountList[index];
                final String email = (account['email'] ?? '').toString();
                final bool isOwner = account['isOwner'] == true;

                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(color: const Color(0xFFE8F3FF), borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    title: Text(isOwner ? '$email (เจ้าบ้าน)' : email),
                    trailing: isEditMode
                        ? Radio<int>(
                            value: index,
                            groupValue: selectedIndex,
                            onChanged: (val) => setState(() => selectedIndex = val),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),

        if (isEditMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ElevatedButton(
              onPressed: selectedIndex != null ? _deleteSelectedAccount : null,
              style: ElevatedButton.styleFrom(backgroundColor: const Color.fromRGBO(211, 47, 47, 1)),
              child: const Text("ลบบัญชี", style: TextStyle(color: Colors.white)),
            ),
          ),

        if (!isEditMode && !isMember && !isDeviceEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF263F6B)),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddAccountScreen()),
                );
                if (result != null && result is String) {
                  await _addSharedAccount(result);
                }
              },
              child: const Text("เพิ่มบัญชี", style: TextStyle(color: Colors.white)),
            ),
          ),
      ],
    );
  }

  Widget _buildInviteCard(Map<String, dynamic> invite) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFFE8F3FF), borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(invite['fromEmail'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("ได้เพิ่มคุณให้เป็นลูกบ้าน"),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () => _rejectInvite(invite['docId']),
                child: const Text("ปฏิเสธ", style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF263F6B),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () => _acceptInvite(invite),
                child: const Text("ยอมรับ", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
