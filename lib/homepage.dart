import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart'; // <<< เพิ่ม import
import 'package:project/adddevicescreen.dart';
import 'package:project/notificationscreen.dart';
import 'package:project/otherscreen.dart';
import 'package:project/wrapper.dart'; // <<< เพิ่ม import

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  // --- เปลี่ยนเป็น List<Map<String, dynamic>> ---
  List<Map<String, dynamic>> devices = [];
  List<String> serials = [];
  Set<int> selectedIndexes = {};
  bool isEditMode = false;
  int _selectedIndex = 0;
  String role = 'loading';
  String currentSerial = '';
  String currentOwnerId = '';
  bool _isFirstTime = true;

  bool hasNotification = false;
  bool hasInvite = false;

  @override
  void initState() {
    super.initState();
    _checkRoleAndLoadDevices();
  }

  /// ===================================================================
  /// [สำคัญ] ตรวจสอบบทบาทผู้ใช้ (เจ้าบ้าน/ลูกบ้าน) และโหลดข้อมูลเริ่มต้น
  /// - เช็คข้อมูล user ใน Firestore เพื่อกำหนด role
  /// - ถ้าเป็น 'member' (ลูกบ้าน) จะใช้ 'ownerId' ที่ผูกไว้
  /// - ถ้าเป็น 'owner' (เจ้าบ้าน) จะใช้ 'uid' ของตัวเอง
  /// - จากนั้นเรียกฟังก์ชันโหลดข้อมูลต่างๆ และแสดง SnackBar ต้อนรับ
  /// ===================================================================
  Future<void> _checkRoleAndLoadDevices() async {
    // ... (โค้ดส่วนนี้เหมือนเดิม) ...
     final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data();

    bool hasDevices = false;

    if (userData != null && userData.containsKey('owner')) {
      final ownerId = userData['owner'];
      role = 'member';
      currentOwnerId = ownerId;
      hasDevices = true;
    } else {
      role = 'owner';
      currentOwnerId = user.uid;
      final deviceSnap = await FirebaseFirestore.instance
          .collection('Raspberry_pi')
          .where('ownerId', isEqualTo: user.uid)
          .limit(1)
          .get();
      hasDevices = deviceSnap.docs.isNotEmpty;
    }

    await _loadDevicesFromRaspberryPi(currentOwnerId);
    await _checkNotifications();
    await _checkInvites();

    if (_isFirstTime && mounted) {
      _isFirstTime = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        String message;
        if (role == 'member') {
          message = 'ล็อกอินสำเร็จในสถานะ: ลูกบ้าน';
        } else if (role == 'owner' && hasDevices) {
          message = 'ล็อกอินสำเร็จในสถานะ: เจ้าบ้าน';
        } else {
          message = 'ล็อกอินสำเร็จ';
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      });
    }
  }

  Future<void> _checkNotifications() async {
     // ... (โค้ดส่วนนี้เหมือนเดิม) ...
    final snapshot = await FirebaseFirestore.instance
        .collection('Raspberry_pi')
        .where('ownerId', isEqualTo: currentOwnerId)
        .get();

    for (var doc in snapshot.docs) {
      final detectionSnap = await FirebaseFirestore.instance
          .collection('Raspberry_pi')
          .doc(doc.id)
          .collection('detections')
          .limit(1)
          .get();
      if (detectionSnap.docs.isNotEmpty) {
        if (mounted) setState(() => hasNotification = true);
        return;
      }
    }

    if (mounted) setState(() => hasNotification = false);
  }

  Future<void> _checkInvites() async {
     // ... (โค้ดส่วนนี้เหมือนเดิม) ...
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final inviteSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('invites')
        .limit(1)
        .get();

    if (mounted) {
      setState(() {
        hasInvite = inviteSnap.docs.isNotEmpty;
      });
    }
  }

  /// ===================================================================
  /// [สำคัญ] โหลดข้อมูลอุปกรณ์จาก Firestore และกำหนดสถานะ Online/Offline
  /// - ดึงข้อมูลอุปกรณ์ทั้งหมดที่เป็นของ ownerId ที่ระบุ
  /// - สร้าง List<Map> ของ 'devices' ขึ้นมาใหม่
  /// - [Logic หลัก] เช็คสถานะ 'isOnline' โดยดูว่า field 'status' เป็น 'online'
  ///   และ 'lastSeen' (เวลาล่าสุดที่พบ) ต้องไม่เกิน 2 นาทีจากเวลาปัจจุบัน
  /// ===================================================================
  Future<void> _loadDevicesFromRaspberryPi(String ownerId) async {
     // ... (โค้ดส่วนนี้เหมือนเดิม) ...
    final snapshot = await FirebaseFirestore.instance
        .collection('Raspberry_pi')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    if (mounted) {
      setState(() {
        serials = snapshot.docs.map((doc) => doc.id).toList();
        devices = List.generate(snapshot.docs.length, (index) {
          final doc = snapshot.docs[index];
          final data = doc.data();
          final name = data['name']?.toString().trim();

          // ตรรกะเช็คสถานะจาก lastSeen
          bool isOnline = false;
          if (data['status'] == 'online' && data['lastSeen'] != null) {
            final lastSeen = (data['lastSeen'] as Timestamp).toDate();
            if (DateTime.now().difference(lastSeen).inMinutes < 2) {
              isOnline = true;
            }
          }

          return {
            'name': (name != null && name.isNotEmpty) ? name : 'อุปกรณ์ที่ ${index + 1}',
            'isOnline': isOnline,
            'serial': doc.id,
          };
        });
        currentSerial = serials.isNotEmpty ? serials.first : '';
        isEditMode = false; // รีเซ็ตโหมดแก้ไขเมื่อโหลดข้อมูลใหม่
        selectedIndexes.clear(); // ล้างรายการที่เลือกไว้
      });
    }
  }

  Future<void> _addDevice() async {
     // ... (โค้ดส่วนนี้เหมือนเดิม) ...
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
    );
    if (result != null && result is String) {
      await _loadDevicesFromRaspberryPi(currentOwnerId);
      await _checkNotifications();
    }
  }

  void _toggleEditMode() {
     // ... (โค้ดส่วนนี้เหมือนเดิม) ...
    setState(() {
      isEditMode = !isEditMode;
      selectedIndexes.clear();
    });
  }

  Future<void> _deleteSelected() async {
     // ... (โค้ดส่วนนี้เหมือนเดิม) ...
    // ใช้ `toList` เพื่อสร้างสำเนาของ `selectedIndexes` ก่อนวนลูป
    for (int i in selectedIndexes.toList()) {
      await FirebaseFirestore.instance
          .collection('Raspberry_pi')
          .doc(serials[i])
          .update({
        'status': 'To be Added',
        'ownerId': FieldValue.delete(),
        'lastSeen': FieldValue.delete(),
      });
    }
    await _loadDevicesFromRaspberryPi(currentOwnerId); // โหลดข้อมูลใหม่หลังลบ
    await _checkNotifications();
    // ไม่ต้อง setState isEditMode = false ที่นี่แล้ว เพราะ _loadDevicesFromRaspberryPi ทำแล้ว
  }


  Future<void> _renameDevice(int index) async {
     // ... (โค้ดส่วนนี้เหมือนเดิม) ...
     final currentName = devices[index]['name'];
    final nameController = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เปลี่ยนชื่อกล้อง'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'ชื่อใหม่'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(context, nameController.text), child: const Text('บันทึก')),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('Raspberry_pi')
          .doc(serials[index])
          .update({'name': newName.trim()});
      await _loadDevicesFromRaspberryPi(currentOwnerId); // โหลดข้อมูลใหม่หลังเปลี่ยนชื่อ
    }
  }

  void _onItemTapped(int index) {
     // ... (โค้ดส่วนนี้เหมือนเดิม) ...
     // ป้องกันการกดแท็บ Notification ถ้ายังไม่มีอุปกรณ์
    if (index == 1 && devices.isEmpty) return;

    setState(() {
      _selectedIndex = index;
      // รีเซ็ตสถานะแจ้งเตือนเมื่อเปลี่ยนแท็บ
      if (index == 1) hasNotification = false;
      if (index == 2) hasInvite = false;
    });
  }

  // --- START: เพิ่มฟังก์ชัน signOut ---
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
        MaterialPageRoute(builder: (_) => const Wrapper()), // กลับไปหน้า Wrapper
        (route) => false,
      );
    }
  }
  // --- END: เพิ่มฟังก์ชัน signOut ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _selectedIndex == 0
            ? (role == 'loading'
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // --- START: แถบ AppBar ด้านบน ---
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        height: 60,
                        color: const Color(0xFFd4e8ff),
                        child: Row(
                          // mainAxisAlignment: MainAxisAlignment.spaceBetween, // เอาออกเพื่อให้ชิดซ้ายขวา
                          children: [
                            Image.asset(
                              'assets/cctv.png',
                              height: 30,
                            ),
                            const SizedBox(width: 8),
                            const Expanded( // ใช้ Expanded ดันข้อความไปทางซ้าย
                              child: Text(
                                'ระบบตรวจจับสิ่งมีชีวิตที่ไม่พึงประสงค์',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // --- START: เพิ่ม IconButton สำหรับ Logout ---
                            IconButton(
                              icon: const Icon(Icons.logout, color: Color.fromARGB(255, 255, 0, 0)), // ไอคอนประตู
                              tooltip: 'ออกจากระบบ', // ข้อความเมื่อกดค้าง
                              onPressed: signOut, // เรียกฟังก์ชัน signOut เมื่อกด
                            ),
                            // --- END: เพิ่ม IconButton ---
                          ],
                        ),
                      ),
                      // --- END: แถบ AppBar ด้านบน ---

                      // --- START: ข้อความ "รายการอุปกรณ์" และปุ่มแก้ไข ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'รายการอุปกรณ์',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            if (devices.isNotEmpty && role == 'owner')
                              IconButton(
                                icon: Icon(isEditMode ? Icons.check : Icons.edit, color: Colors.black),
                                onPressed: _toggleEditMode,
                              ),
                          ],
                        ),
                      ),
                      // --- END: ข้อความและปุ่มแก้ไข ---

                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          childAspectRatio: 1,
                          children: [
                            for (int i = 0; i < devices.length; i++)
                              Stack(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (isEditMode && role == 'owner') {
                                        _renameDevice(i);
                                      } else {
                                        setState(() {
                                          currentSerial = devices[i]['serial'];
                                          _selectedIndex = 1;
                                          hasNotification = false;
                                        });
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF263F6B),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              devices[i]['name'],
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isEditMode && role == 'owner')
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: Checkbox(
                                        value: selectedIndexes.contains(i),
                                        side: MaterialStateBorderSide.resolveWith(
                                          (states) => BorderSide(color: Colors.white, width: 2.0),
                                        ),
                                        activeColor: Colors.green,
                                        checkColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                        onChanged: (value) {
                                          setState(() {
                                            if (value == true) {
                                              selectedIndexes.add(i);
                                            } else {
                                              selectedIndexes.remove(i);
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            if (!isEditMode && role == 'owner')
                              GestureDetector(
                                onTap: _addDevice,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Center(child: Icon(Icons.add, size: 50, color: Colors.black54)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isEditMode && role == 'owner')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                            ),
                            onPressed: selectedIndexes.isEmpty ? null : _deleteSelected,
                            child: const Text("ลบ", style: TextStyle(fontSize: 18, color: Colors.white)),
                          ),
                        ),
                    ],
                  ))
            : (_selectedIndex == 1
                ? NotificationScreen(serialNumber: currentSerial)
                : const OtherScreen()),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.devices), label: 'อุปกรณ์'),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications),
                if (hasNotification)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'การแจ้งเตือน',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.person),
                if (hasInvite)
                  Positioned(
                     top: -4,
                    right: -4,
                     child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'อื่น ๆ',
          ),
        ],
      ),
    );
  }
}

