import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditHelpScreen extends StatefulWidget {
  final String docId;
  final String currentName;
  final String currentPhone;

  const EditHelpScreen({
    super.key,
    required this.docId,
    required this.currentName,
    required this.currentPhone,
  });

  @override
  State<EditHelpScreen> createState() => _EditHelpScreenState();
}

class _EditHelpScreenState extends State<EditHelpScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _phoneController = TextEditingController(text: widget.currentPhone);
  }

  void _updateHelp() async {
    await FirebaseFirestore.instance.collection('helps').doc(widget.docId).update({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
    });

    Navigator.pop(context); // กลับหน้าก่อนหน้า
  }

  void _deleteHelp() async {
    await FirebaseFirestore.instance.collection('helps').doc(widget.docId).delete();
    Navigator.pop(context); // กลับหน้าก่อนหน้า
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไข', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF263F6B)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _deleteHelp,
            child: const Text('ลบ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'ชื่อหน่วยงาน',
                filled: true,
                fillColor: Colors.blue[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'เบอร์โทร',
                filled: true,
                fillColor: Colors.blue[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _updateHelp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF263F6B),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              ),
              child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
