import 'package:flutter/material.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Success Screen'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      // 변경: Column 대신 ListView 사용하여 유한 높이 제약 적용
      body: ListView(
        children: const [
          ListTile(
            title: Text(
              'Success Item 1',
              style: TextStyle(color: Colors.white),
            ),
          ),
          ListTile(
            title: Text(
              'Success Item 2',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
