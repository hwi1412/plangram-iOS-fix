import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'dart:io';
import 'package:provider/provider.dart';
import '../providers/login_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  DocumentSnapshot<Map<String, dynamic>>? _userDoc;

  Future<void> _loadUserData() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    setState(() {
      _userDoc = doc;
    });
  }

  Future<void> _updateProfilePhoto() async {
    // 이미지 선택
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    File imageFile = File(pickedFile.path);
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Firebase Storage에 업로드하고 URL 획득
      final ref = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${currentUser.uid}.jpg');
      final metadata =
          firebase_storage.SettableMetadata(contentType: 'image/jpeg');
      await ref.putFile(imageFile, metadata);
      String downloadUrl = await ref.getDownloadURL();

      // Firestore의 user 문서 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({'profileUrl': downloadUrl});

      // 화면 갱신
      await _loadUserData();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('프로필 사진이 업데이트되었습니다.')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('업로드 실패: $e')));
    }
  }

  // 계정 삭제 함수 수정 (재인증 추가)
  Future<void> _deleteAccount() async {
    try {
      // 재인증을 위한 다이얼로그 출력
      final TextEditingController passwordController = TextEditingController();
      final password = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('재인증 필요'),
            content: TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '비밀번호 입력',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(passwordController.text),
                child: const Text('확인'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('취소'),
              ),
            ],
          );
        },
      );
      if (password == null || password.isEmpty) return;

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 이메일/비밀번호 자격증명을 통한 재인증
      final credential =
          EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);

      // 재인증 후 계정 삭제
      await user.delete();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("계정 삭제 실패: $e")));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color.fromARGB(255, 0, 57, 47),
                Color.fromARGB(255, 85, 27, 79),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () async {
              await Provider.of<LoginProvider>(context, listen: false)
                  .signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color.fromARGB(255, 0, 57, 47),
              Color.fromARGB(255, 85, 27, 79),
            ],
          ),
        ),
        child: currentUser == null
            ? const Center(
                child: Text('로그인 정보가 없습니다.',
                    style: TextStyle(color: Colors.white)))
            : _userDoc == null
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 기존 프로필 정보 영역
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 상단에 배치 (위쪽 여백은 필요한 경우 추가)
                            const SizedBox(height: 16),
                            // 프로필 사진 영역
                            CircleAvatar(
                              radius: 50,
                              backgroundImage:
                                  _userDoc!.data()?['profileUrl'] != null
                                      ? NetworkImage(
                                          _userDoc!.data()!['profileUrl'])
                                      : null,
                              backgroundColor: Colors.grey,
                              child: _userDoc!.data()?['profileUrl'] == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '이메일: ${currentUser.email}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '사용자 이름: ${_userDoc!.data()?['name'] ?? '미등록'}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '친구 수: ${(_userDoc!.data()?['friends'] as List<dynamic>?)?.length ?? 0}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _updateProfilePhoto,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.pink,
                                side: const BorderSide(color: Colors.pink),
                              ),
                              child: const Text('프로필 사진 변경'),
                            ),
                            const SizedBox(height: 16),
                            // 계정 삭제 버튼 추가
                            ElevatedButton(
                              onPressed: _deleteAccount,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              child: const Text("계정 삭제",
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
      backgroundColor: Colors.black,
    );
  }
}
