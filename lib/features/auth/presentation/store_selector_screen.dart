import 'package:flutter/material.dart';

/// Lists stores the user can access (placeholder until full UI).
class StoreSelectorScreen extends StatelessWidget {
  const StoreSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('اختر متجرك'),
        backgroundColor: const Color(0xFF185FA5),
        foregroundColor: Colors.white,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'قائمة المتاجر ستظهر هنا بعد ربط البيانات.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.4),
          ),
        ),
      ),
    );
  }
}
