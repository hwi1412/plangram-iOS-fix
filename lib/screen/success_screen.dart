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
    final bool isDetailBoxVisible =
        _calendarKey.currentState?.selectedDetailDay != null;

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
                  PlangramHomePageContent(
                    key: _calendarKey,
                    isEditing: _isEditing,
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      top: 0,
                      left: 12,
                      bottom: 8 + (isDetailBoxVisible ? 5.0 : 0.0),
                    ),
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

  // 오늘 상태 관련 변수
  int? _todayStatus; // 0: 가능, 1: 바쁨, 2: 휴식
  bool _showTodayStatusSelector = false;

  @override
  void initState() {
    super.initState();
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    loginProvider.fetchFriends().then((_) => _loadAllProfiles());
    _loadTodayStatus();
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

  // 오늘 상태 Firestore에서 불러오기
  Future<void> _loadTodayStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('today_status')
        .doc(user.uid)
        .get();
    if (doc.exists) {
      final data = doc.data();
      setState(() {
        _todayStatus = data?['status'] as int? ?? 0;
      });
    } else {
      setState(() {
        _todayStatus = 0;
      });
    }
  }

  // 오늘 상태 Firestore에 저장
  Future<void> _setTodayStatus(int status) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('today_status')
        .doc(user.uid)
        .set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    setState(() {
      _todayStatus = status;
      _showTodayStatusSelector = false;
    });
  }

  // 오늘 상태 말풍선 토글
  void _toggleTodayStatusSelector() {
    setState(() {
      _showTodayStatusSelector = !_showTodayStatusSelector;
    });
  }

  // 오늘 상태 텍스트 및 색상
  String get _todayStatusText {
    switch (_todayStatus) {
      case 1:
        return "바쁨";
      case 2:
        return "휴식 중";
      default:
        return "만남 가능";
    }
  }

  Color get _todayStatusColor {
    switch (_todayStatus) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.blueGrey;
      default:
        return Colors.green;
    }
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
      child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(allProfiles.length, (idx) {
                final p = allProfiles[idx];
                final isMe = p['isMe'] == true;
                return Padding(
                  padding: EdgeInsets.only(
                      right: idx == allProfiles.length - 1 ? 0 : 18),
                  child: Column(
                    children: [
                      isMe
                          ? Stack(
                              clipBehavior: Clip.none,
                              children: [
                                GestureDetector(
                                  onTap: () {}, // 프로필 사진 탭 시 아무 동작 없음
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: null,
                                    ),
                                    child: CircleAvatar(
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
                                  ),
                                ),
                                // Today 상태 버튼 (플러스 대신)
                                Positioned(
                                  bottom: -6,
                                  right: -6,
                                  child: GestureDetector(
                                    onTap: _toggleTodayStatusSelector,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            _todayStatusColor.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.today,
                                              color: Colors.white, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            _todayStatusText,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : GestureDetector(
                              onTap: () {}, // 친구 프로필 탭 시 아무 동작 없음
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: p['hasStory']
                                      ? Border.all(
                                          color: Colors.purple, width: 2)
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
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
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
          // 오늘 상태 선택 말풍선
          if (_showTodayStatusSelector)
            Positioned(
              left: 36,
              top: 0,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TodayStatusOption(
                        icon: Icons.check_circle,
                        color: Colors.green,
                        text: "오늘 만남 가능",
                        selected: _todayStatus == 0,
                        onTap: () => _setTodayStatus(0),
                      ),
                      const SizedBox(height: 10),
                      _TodayStatusOption(
                        icon: Icons.block,
                        color: Colors.orange,
                        text: "바쁨",
                        selected: _todayStatus == 1,
                        onTap: () => _setTodayStatus(1),
                      ),
                      const SizedBox(height: 10),
                      _TodayStatusOption(
                        icon: Icons.self_improvement,
                        color: Colors.blueGrey,
                        text: "휴식 중",
                        selected: _todayStatus == 2,
                        onTap: () => _setTodayStatus(2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 오늘 상태 선택 옵션 위젯
class _TodayStatusOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _TodayStatusOption({
    required this.icon,
    required this.color,
    required this.text,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
          if (selected)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.check, color: Colors.black54, size: 16),
            ),
        ],
      ),
    );
  }
}
