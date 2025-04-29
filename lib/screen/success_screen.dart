import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    // 친구 목록 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LoginProvider>(context, listen: false).fetchFriends();
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
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5),
                    _ProfileCircleList(),
                    const SizedBox(height: 5),
                    PlangramHomePageContent(key: _calendarKey),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF22223B),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.circle,
                                              size: 14, color: Colors.red),
                                          SizedBox(width: 6),
                                          Text("= 나만 쉬는 날",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13)),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        children: const [
                                          Icon(Icons.circle,
                                              size: 14, color: Colors.teal),
                                          SizedBox(width: 6),
                                          Text("= 친구도 쉬는 날",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13)),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        children: const [
                                          Icon(Icons.circle,
                                              size: 14, color: Colors.grey),
                                          SizedBox(width: 6),
                                          Text("= 친구만 쉬는 날",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13)),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        children: const [
                                          Icon(Icons.circle,
                                              size: 14, color: Colors.purple),
                                          SizedBox(width: 6),
                                          Text("= Today",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.15),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(
                                Icons.info_outline,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 6.0),
                          child: GestureDetector(
                            onTap: () {
                              _calendarKey.currentState?.toggleEditing();
                              setState(() {
                                _isEditing = !_isEditing;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.15),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                _isEditing ? Icons.save : Icons.edit,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              "휴무 일을 선택하고 친구와 교류하세요!",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            const SizedBox(height: 3),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 프로필 리스트 위젯: 내 프로필이 항상 첫 번째, 친구 리스트는 Firestore에서 가져옴
class _ProfileCircleList extends StatefulWidget {
  @override
  State<_ProfileCircleList> createState() => _ProfileCircleListState();
}

class _ProfileCircleListState extends State<_ProfileCircleList> {
  List<Map<String, dynamic>> allProfiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAllProfiles();
  }

  Future<void> _loadAllProfiles() async {
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    final user = loginProvider.user;

    final myProfile = {
      'displayName': user?.displayName ?? '나',
      'photoURL': user?.photoURL,
      'isMe': true,
    };

    final usersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

    final List<Map<String, dynamic>> others = [];
    for (var doc in usersSnapshot.docs) {
      if (doc.id == user?.uid) continue;
      final data = doc.data();
      others.add({
        'displayName': data['name'] ?? '사용자',
        'photoURL': data['profileUrl'],
        'isMe': false,
      });
    }

    setState(() {
      allProfiles = [myProfile, ...others];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // 가로 스크롤이 가능하도록 SingleChildScrollView + Row 사용
    return SizedBox(
      height: 80,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(allProfiles.length, (idx) {
            final profile = allProfiles[idx];
            return Padding(
              padding: EdgeInsets.only(
                  right: idx == allProfiles.length - 1 ? 0 : 18),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        profile['isMe'] ? Colors.teal : Colors.grey[700],
                    backgroundImage:
                        profile['photoURL'] != null && profile['photoURL'] != ''
                            ? NetworkImage(profile['photoURL'])
                            : null,
                    child: (profile['photoURL'] == null ||
                            profile['photoURL'] == '')
                        ? Icon(Icons.person, color: Colors.white, size: 28)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 54,
                    child: Text(
                      profile['displayName'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
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
