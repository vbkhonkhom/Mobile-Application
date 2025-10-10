import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/adddevicescreen.dart';
import 'package:project/notificationscreen.dart';
import 'package:project/otherscreen.dart';

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

  Future<void> _checkRoleAndLoadDevices() async {
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

  // --- แก้ไขฟังก์ชันนี้ ---
  // ในคลาส _HomepageState, ฟังก์ชัน _loadDevicesFromRaspberryPi()
  Future<void> _loadDevicesFromRaspberryPi(String ownerId) async {
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
          if (data['status'] == 'online' && data['lastSeen'] != null) { // <--- อ่านจาก lastSeen
            final lastSeen = (data['lastSeen'] as Timestamp).toDate(); // <--- อ่านจาก lastSeen
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
        isEditMode = false;
      });
    }
  }

  Future<void> _addDevice() async {
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
    setState(() {
      isEditMode = !isEditMode;
      selectedIndexes.clear();
    });
  }

  Future<void> _deleteSelected() async {
    // ใช้ `toList` เพื่อสร้างสำเนาของ `selectedIndexes` ก่อนวนลูป
    for (int i in selectedIndexes.toList()) {
      await FirebaseFirestore.instance
          .collection('Raspberry_pi')
          .doc(serials[i])
          .update({
        'status': 'To be Added',
        'ownerId': FieldValue.delete(),
        'lastSeen': FieldValue.delete(), // <-- เพิ่มบรรทัดนี้เพื่อลบฟิลด์ lastSeen
      });
    }
    await _loadDevicesFromRaspberryPi(currentOwnerId);
    await _checkNotifications();
    if (mounted) {
      setState(() {
        selectedIndexes.clear();
        isEditMode = false;
      });
    }
  }

  Future<void> _renameDevice(int index) async {
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
      await _loadDevicesFromRaspberryPi(currentOwnerId);
    }
  }

  void _onItemTapped(int index) {
    if (index == 1 && devices.isEmpty) return;
    setState(() {
      _selectedIndex = index;
      if (index == 1) hasNotification = false;
      if (index == 2) hasInvite = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _selectedIndex == 0
            ? (role == 'loading'
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        height: 60,
                        color: const Color(0xFFd4e8ff),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('อุปกรณ์ทั้งหมด', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            if (devices.isNotEmpty && role == 'owner')
                              IconButton(
                                icon: Icon(isEditMode ? Icons.check : Icons.edit, color: Colors.black),
                                onPressed: _toggleEditMode,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          padding: const EdgeInsets.all(20),
                          childAspectRatio: 1,
                          children: [
                            for (int i = 0; i < devices.length; i++)
                              Stack(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (isEditMode && role == 'owner') {
                                        _renameDevice(i);
                                      } else { // <-- เอาเงื่อนไข isOnline ออก
                                        setState(() {
                                          currentSerial = devices[i]['serial'];
                                          _selectedIndex = 1;
                                        });
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF263F6B), // <-- สีฟ้าเสมอ
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(height: 8),
                                            Text(
                                              devices[i]['name'],
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isEditMode && role == 'owner')
                                    Positioned(
                                      top: 6,
                                      left: 6,
                                      child: Checkbox(
                                        value: selectedIndexes.contains(i),
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
                                  child: const Center(child: Icon(Icons.add, size: 50)),
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
            icon: Stack(children: [
              const Icon(Icons.notifications),
              if (hasNotification)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  ),
                ),
            ]),
            label: 'การแจ้งเตือน',
          ),
          BottomNavigationBarItem(
            icon: Stack(children: [
              const Icon(Icons.person),
              if (hasInvite)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  ),
                ),
            ]),
            label: 'อื่น ๆ',
          ),
        ],
      ),
    );
  }
}