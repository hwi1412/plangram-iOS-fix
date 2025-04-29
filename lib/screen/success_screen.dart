// lib/screen/success_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/login_provider.dart';
import 'style/navigation_bar.dart';
import 'style/app_bar.dart';
import 'style/calendar.dart';
import 'bottom.navigate/search.dart';
import 'bottom.navigate/friends.dart';
import 'bottom.navigate/notice.dart';

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  final GlobalKey<PlangramHomePageContentState> _calendarKey =
      GlobalKey<PlangramHomePageContentState>();
  final bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    // 앱 진입 직후 친구 목록 미리 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LoginProvider>(context, listen: false)
          .fetchFriends()
          .then((_) {
        // 필요 시 캘린더 초기 동작
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      bottomNavigationBar: const CustomNavigationBar(),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color.fromARGB(255, 0, 57, 47),
                const Color.fromARGB(255, 85, 27, 79),
              ],
            ),
          ),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              const SizedBox(height: 5),
              _ProfileCircleList(),
              const SizedBox(height: 5),
              PlangramHomePageContent(key: _calendarKey),
              // ... 이하 동일
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCircleList extends StatefulWidget {
  @override
  State<_ProfileCircleList> createState() => _ProfileCircleListState();
}

class _ProfileCircleListState extends State<_ProfileCircleList> {
  List<Map<String, dynamic>> allProfiles = [];
  bool _loading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // 로그인 프로바이더에서 이메일 리스트 가져온 뒤 프로필 로딩
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    loginProvider.fetchFriends().then((_) => _loadAllProfiles());
  }

  Future<void> _loadAllProfiles() async {
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    final user = loginProvider.user;

    // 내 프로필
    final myProfile = {
      'displayName': user?.displayName ?? '나',
      'photoURL': user?.photoURL ?? '',
      'isMe': true,
      'hasStory': false,
    };

    // 친구 이메일 리스트 순회하며 프로필 조회
    final List<Map<String, dynamic>> others = [];
    for (final email in loginProvider.friends) {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        others.add({
          'displayName': data['name'] ?? '사용자',
          'photoURL': data['profileUrl'] ?? '',
          'isMe': false,
          'hasStory': false,
        });
      }
    }

    setState(() {
      allProfiles = [myProfile, ...others];
      _loading = false;
    });
  }

  Future<void> _onAddStory() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      // TODO: 스토리 업로드 로직
      setState(() => allProfiles[0]['hasStory'] = true);
    }
  }

  Future<void> _viewStory(Map<String, dynamic> profile) async {
    // TODO: 스토리 뷰어 이동
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      height: 80,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(allProfiles.length, (idx) {
            final p = allProfiles[idx];
            return Padding(
              padding: EdgeInsets.only(
                  right: idx == allProfiles.length - 1 ? 0 : 18),
              child: Column(
                children: [
                  p['isMe']
                      ? GestureDetector(
                          onTap: _onAddStory,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: p['hasStory']
                                  ? Border.all(color: Colors.purple, width: 2)
                                  : null,
                            ),
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.teal,
                                  backgroundImage: p['photoURL'] != ''
                                      ? NetworkImage(p['photoURL'])
                                      : null,
                                  child: p['photoURL'] == ''
                                      ? const Icon(Icons.person,
                                          color: Colors.white, size: 28)
                                      : null,
                                ),
                                const Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.blueAccent,
                                    child: Icon(Icons.add,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: () => _viewStory(p),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: p['hasStory']
                                  ? Border.all(color: Colors.purple, width: 2)
                                  : null,
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[700],
                              backgroundImage: p['photoURL'] != ''
                                  ? NetworkImage(p['photoURL'])
                                  : null,
                              child: p['photoURL'] == ''
                                  ? const Icon(Icons.person,
                                      color: Colors.white, size: 28)
                                  : null,
                            ),
                          ),
                        ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 54,
                    child: Text(
                      p['displayName'],
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
