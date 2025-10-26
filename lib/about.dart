import 'package:flutter/material.dart';

// สร้างคลาส About ให้เป็น StatelessWidget
class About extends StatelessWidget {
  const About({super.key}); // ใส่ const constructor

  @override
  Widget build(BuildContext context) {
    // UI ของหน้า "เกี่ยวกับ"
    return Scaffold(
      appBar: AppBar(
        title: const Text('เกี่ยวกับ'), // หัวข้อ AppBar
        leading: IconButton( // ปุ่มกลับ
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(), // กดเพื่อกลับไปหน้าก่อนหน้า
        ),
        backgroundColor: const Color(0xFFd4e8ff), // สี AppBar ให้เข้ากับหน้าอื่น
        foregroundColor: Colors.black, // สีตัวหนังสือ AppBar
      ),
      body: Center( // <<< เพิ่ม const ได้
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             crossAxisAlignment: CrossAxisAlignment.center, // จัดข้อความให้อยู่กึ่งกลาง
             // *** แก้ไข: เพิ่ม comma ที่ขาดหายไป ***
             children: [ // <<< ลบ <Widget> ออกก็ได้
                Image.asset(
                  'assets/cctv.png',
                  height: 80,
                ), // <<< ต้องมี comma
                const SizedBox(height: 16), // <<< เพิ่ม SizedBox เพื่อเว้นวรรค และเพิ่ม const
                const Text( // <<< เพิ่ม const ได้
                  'ระบบตรวจจับสิ่งมีชีวิตที่ไม่พึงประสงค์',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ), // <<< ต้องมี comma
                const SizedBox(height: 8), // <<< ต้องมี comma และเพิ่ม const
                const Text( // <<< เพิ่ม const ได้
                  'คณะผู้จัดทำ',
                   style: TextStyle(fontSize: 16),
                   textAlign: TextAlign.center,
                ), // <<< ต้องมี comma
                const Text( // <<< เพิ่ม const ได้
                  'นายวรุฒ อดุลยรัตนพันธุ์',
                   style: TextStyle(fontSize: 16),
                   textAlign: TextAlign.center,
                ), // <<< ต้องมี comma
                const Text( // <<< เพิ่ม const ได้
                  'นางสาวเบญจพร คนคม',
                   style: TextStyle(fontSize: 16),
                   textAlign: TextAlign.center,
                ), // <<< ต้องมี comma
                const Text( // <<< เพิ่ม const ได้
                  'นายสุพัฒชัย นาคย้อย',
                   style: TextStyle(fontSize: 16),
                   textAlign: TextAlign.center,
                ), // <<< ต้องมี comma
                const SizedBox(height: 16), // <<< ต้องมี comma และเพิ่ม const
                const Text( // <<< เพิ่ม const ได้
                  'อาจารย์ที่ปรึกษาหลัก',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ), // <<< ต้องมี comma
                const Text( // <<< เพิ่ม const ได้
                  'ผศ.ดร.ศิริชัย เตรียมล้ำเลิศ',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ), // <<< ต้องมี comma
                const SizedBox(height: 16), // <<< ต้องมี comma และเพิ่ม const
                const Text( // <<< เพิ่ม const ได้
                  'อาจารย์ที่ปรึกษาร่วม',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ), // <<< ต้องมี comma
                const Text( // <<< เพิ่ม const ได้
                  'ดร.ปอลิน กองสุวรรณ',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ), // <<< ต้องมี comma
                const SizedBox(height: 16), // <<< ต้องมี comma และเพิ่ม const
                const Text( // <<< เพิ่ม const ได้
                  'ภาควิชาวิศวกรรมคอมพิวเตอร์',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ), // <<< ต้องมี comma
                const Text( // <<< เพิ่ม const ได้
                  'สาขาวิศวกรรมศาสตร์',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ), // <<< ต้องมี comma
                const Text( // <<< เพิ่ม const ได้
                  'มหาวิทยาลัยเทคโนโลยีราชมงคลธัญบุรี',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ), // <<< Widget ตัวสุดท้ายใน list ไม่ต้องมี comma
                // เพิ่มข้อมูลอื่นๆ ที่ต้องการได้ที่นี่
             ],
          ),
        ),
      ),
    );
  }
}
