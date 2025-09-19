import 'package:flutter/material.dart';
import 'package:project/adddevicescreen.dart';


class ConnectedDeviceScreen extends StatefulWidget {
  const ConnectedDeviceScreen({super.key});

  @override
  State<ConnectedDeviceScreen> createState() => _ConnectedDeviceScreenState();
}

class _ConnectedDeviceScreenState extends State<ConnectedDeviceScreen> {
  List<String> deviceNames = ["IP Cam 1"];

Future<void> _navigateAndAddDevice() async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
  );

  if (result == true) {
    setState(() {
      final newDeviceNumber = deviceNames.length + 1;
      deviceNames.add("IP Cam $newDeviceNumber");
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 50),

          // หัวข้อ + ปุ่มแก้ไข
          Stack(
            children: [
              const Center(
                child: Text(
                  "All Devices",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              Positioned(
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.black),
                  onPressed: () {
                    // ปุ่มแก้ไขอุปกรณ์ (ยังไม่ทำ)
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // แสดงกล่องอุปกรณ์ทั้งหมด
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: deviceNames.length + 1,
              itemBuilder: (context, index) {
                if (index == deviceNames.length) {
                  return GestureDetector(
                    onTap: _navigateAndAddDevice,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(Icons.add, size: 40, color: Colors.black54),
                      ),
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF263F6B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      deviceNames[index],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.devices), label: "Device"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: "Notifications"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Other"),
        ],
        onTap: (index) {
          // Handle bottom nav
        },
      ),
    );
  }
}
