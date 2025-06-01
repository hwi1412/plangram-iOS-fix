import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ProfileScreen extends StatefulWidget {
  final String email;
  const ProfileScreen({super.key, required this.email});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final q = await FirebaseFirestore.instance
        .collection("users")
        .where("email", isEqualTo: widget.email)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) {
      setState(() {
        _userData = q.docs.first.data();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final name = _userData?['name'] ?? widget.email;
    final photoUrl = _userData?['profileUrl'] ?? '';
    final profileText = _userData?['profileText'] ?? '';
    final colorStr = _userData?['profileColor'] as String?;
    Color bgColor = Colors.teal;
    if (colorStr != null && colorStr.startsWith('#') && colorStr.length == 7) {
      bgColor = Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
    } else if (colorStr != null && colorStr.length > 1) {
      bgColor = Color(int.parse(colorStr));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(name, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: bgColor,
              backgroundImage:
                  photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? Text(
                      (profileText.isNotEmpty ? profileText : name[0]),
                      style: const TextStyle(
                          fontSize: 38,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(name,
                style: const TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 8),
            Text(widget.email,
                style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
