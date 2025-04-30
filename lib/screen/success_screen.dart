// lib/screen/success_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
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
  bool _showInfo = false;
  Timer? _infoTimer;

  void _toggleEdit() {
    setState(() {
      if (_isEditing) {
        _calendarKey.currentState?.saveEdits();
      }
      _isEditing = !_isEditing;
      _calendarKey.currentState?.setEditMode(_isEditing);
    });
  }

  void _toggleInfoBubble() {
    setState(() {
      _showInfo = !_showInfo;
    });
    if (_showInfo) {
      _infoTimer?.cancel();
    }
  }

  void _hideInfoBubble() {
    setState(() {
      _showInfo = false;
    });
    _infoTimer?.cancel();
  }

  @override
  void dispose() {
    _infoTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LoginProvider>(context, listen: false)
          .fetchFriends()
          .then((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      bottomNavigationBar: const CustomNavigationBar(),
      body: SafeArea(
        child: Stack(
          children: [
            Container(
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
                  // 캘린더와 아이콘을 Stack으로 감싸지 않고, 캘린더 아래에 Row로 배치
                  PlangramHomePageContent(
                    key: _calendarKey,
                    isEditing: _isEditing,
                  ),
                  // 캘린더를 벗어난 아래에, 왼쪽에 아이콘 두 개 가로 배치
                  Padding(
                    padding: const EdgeInsets.only(top: 0, left: 12, bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _toggleInfoBubble,
                          child: Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.7),
                                width: 2,
                              ),
                              color: Colors.transparent,
                            ),
                            child: Icon(
                              Icons.info_outline,
                              color: Colors.white.withOpacity(0.7),
                              size: 18,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _toggleEdit,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.7),
                                width: 2,
                              ),
                              color: Colors.transparent,
                            ),
                            child: Icon(
                              _isEditing ? Icons.save : Icons.edit,
                              color: Colors.white.withOpacity(0.7),
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_showInfo)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _hideInfoBubble,
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 120),
                          padding: const EdgeInsets.symmetric(
                              vertical: 18, horizontal: 22),
                          decoration: BoxDecoration(
                            color: const Color(0xFF102040).withOpacity(0.95),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LegendRow(color: Colors.red, text: '나만 쉬는 날'),
                              const SizedBox(height: 8),
                              _LegendRow(
                                  color: Color(0xFF1DE9B6), text: '친구도 쉬는 날'),
                              const SizedBox(height: 8),
                              _LegendRow(color: Colors.grey, text: '친구만 쉬는 날'),
                              const SizedBox(height: 8),
                              _LegendRow(color: Colors.purple, text: 'Today'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendRow({required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        Text(
          '= $text',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    loginProvider.fetchFriends().then((_) => _loadAllProfiles());
  }

  Future<void> _loadAllProfiles() async {
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    final user = loginProvider.user;

    final myProfile = {
      'displayName': user?.displayName ?? '나',
      'photoURL': user?.photoURL ?? '',
      'isMe': true,
      'hasStory': false,
    };

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
      setState(() => allProfiles[0]['hasStory'] = true);
    }
  }

  Future<void> _viewStory(Map<String, dynamic> profile) async {}

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
