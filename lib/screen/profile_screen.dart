import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'dart:io';
import 'package:provider/provider.dart';
import '../providers/login_provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  DocumentSnapshot<Map<String, dynamic>>? _userDoc;

  // 프로필 수정용 변수
  String? _profileText;
  Color? _profileColor;

  Future<void> _loadUserData() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    setState(() {
      _userDoc = doc;
      _profileText = doc.data()?['profileText'] as String?;
      final colorStr = doc.data()?['profileColor'] as String?;
      if (colorStr != null &&
          colorStr.startsWith('#') &&
          colorStr.length == 7) {
        _profileColor =
            Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
      } else if (colorStr != null && colorStr.length > 1) {
        _profileColor = Color(int.parse(colorStr));
      } else {
        _profileColor = null;
      }
    });
  }

  Future<void> _updateProfilePhoto() async {
    // 프로필 수정 모달(텍스트, 컬러)
    String? tempText = _profileText ?? '';
    Color tempColor = _profileColor ?? Colors.teal;
    final controller = TextEditingController(text: tempText);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // 배경 투명
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xEE102040), // 어두운 반투명 남색
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('프로필 수정',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white)),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: '프로필 텍스트(이모지 가능)',
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Text('배경색 선택:',
                        style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) {
                            Color pickerColor = tempColor;
                            return AlertDialog(
                              backgroundColor: const Color(0xFF102040),
                              title: const Text('컬러 선택',
                                  style: TextStyle(color: Colors.white)),
                              content: SingleChildScrollView(
                                child: ColorPicker(
                                  pickerColor: pickerColor,
                                  onColorChanged: (c) {
                                    pickerColor = c;
                                  },
                                  enableAlpha: false,
                                  showLabel: false,
                                  pickerAreaHeightPercent: 0.7,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  child: const Text('확인',
                                      style: TextStyle(color: Colors.white)),
                                  onPressed: () {
                                    Navigator.of(ctx).pop(pickerColor);
                                  },
                                ),
                              ],
                            );
                          },
                        ).then((picked) {
                          if (picked is Color) {
                            setState(() {
                              tempColor = picked;
                            });
                          }
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: tempColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    User? currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser == null) return;
                    final colorStr =
                        '#${tempColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .update({
                      'profileText': controller.text,
                      'profileColor': colorStr,
                    });
                    setState(() {
                      _profileText = controller.text;
                      _profileColor = tempColor;
                    });
                    Navigator.of(context).pop();
                    await _loadUserData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('저장'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    try {
      // 재인증 다이얼로그 출력
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

      // Firestore에서 해당 사용자 관련 모든 데이터 삭제
      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      // 하위 컬렉션 삭제 (예: schedules, groups, friend_requests)
      for (var subPath in ['schedules', 'groups', 'friend_requests']) {
        final subQuery = await userDocRef.collection(subPath).get();
        for (var doc in subQuery.docs) {
          await doc.reference.delete();
        }
      }
      // 다른 사용자 문서에서 내 이메일 제거
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      for (var doc in usersSnapshot.docs) {
        await doc.reference.update({
          'friends': FieldValue.arrayRemove([user.email])
        });
      }
      // 사용자 문서 삭제
      await userDocRef.delete();
      // Firebase Auth 계정 삭제
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
                            const SizedBox(height: 16),
                            // 프로필 사진/텍스트/컬러 영역
                            Builder(
                              builder: (context) {
                                final profileUrl =
                                    _userDoc!.data()?['profileUrl'] as String?;
                                final profileText =
                                    _userDoc!.data()?['profileText'] as String?;
                                final colorStr = _userDoc!
                                    .data()?['profileColor'] as String?;
                                Color bgColor = Colors.teal;
                                if (colorStr != null &&
                                    colorStr.startsWith('#') &&
                                    colorStr.length == 7) {
                                  bgColor = Color(int.parse(
                                          colorStr.substring(1),
                                          radix: 16) +
                                      0xFF000000);
                                } else if (colorStr != null &&
                                    colorStr.length > 1) {
                                  bgColor = Color(int.parse(colorStr));
                                }
                                return CircleAvatar(
                                  radius: 50,
                                  backgroundColor: bgColor,
                                  backgroundImage: profileUrl != null &&
                                          profileUrl.isNotEmpty
                                      ? NetworkImage(profileUrl)
                                      : null,
                                  child:
                                      (profileUrl == null || profileUrl.isEmpty)
                                          ? Text(
                                              (profileText ?? '🙂'),
                                              style: const TextStyle(
                                                fontSize: 38,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                );
                              },
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
                                foregroundColor:
                                    const Color.fromARGB(255, 255, 255, 255),
                                side: const BorderSide(
                                    color: Color.fromARGB(255, 124, 77, 167)),
                              ),
                              child: const Text('프로필 수정'),
                            ),
                          ],
                        ),
                        // 계정 삭제/문의하기 텍스트 버튼을 아래에 배치
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: _deleteAccount,
                                child: const Text(
                                  "계정 삭제",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 16,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('문의 안내'),
                                      content: const Text(
                                        '문의 메일: dean7767@naver.com\n\n'
                                        '앱 관련 문의사항이나 불편사항이 있으시면 위 메일로 연락해 주세요.',
                                        style: TextStyle(fontSize: 15),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text('확인'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text(
                                  '문의 하기',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
      backgroundColor: Colors.black,
    );
  }
}
