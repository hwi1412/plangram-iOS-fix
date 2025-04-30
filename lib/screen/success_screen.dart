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
  int? _todayStatus;
  bool _showTodayStatusSelector = false;

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

  void _handleShowTodayStatusSelector() {
    setState(() {
      _showTodayStatusSelector = !_showTodayStatusSelector;
    });
  }

  void _handleSetTodayStatus(int status) {
    setState(() {
      _todayStatus = status;
      _showTodayStatusSelector = false;
    });
    // Firestore 저장 등 기존 로직 필요시 추가
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
                  const SizedBox(height: 44), // 위쪽 공간 더 넓게 (기존 30 → 44)
                  _ProfileCircleList(
                    onShowTodayStatusSelector: _handleShowTodayStatusSelector,
                    showTodayStatusSelector: _showTodayStatusSelector,
                    todayStatus: _todayStatus,
                    onSetTodayStatus: _handleSetTodayStatus,
                  ),
                  const SizedBox(height: 0), // 아래 공간 더 좁게 (기존 5 → 0)
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
            if (_showTodayStatusSelector)
              Positioned(
                left: 52, // 프로필 위치에 맞게 조정
                top: 50, // 기존 30 → 50 (프로필 원 아래쪽에 위치)
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
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
                          text: "만나자",
                          selected: _todayStatus == 0,
                          onTap: () => _handleSetTodayStatus(0),
                        ),
                        const SizedBox(height: 12),
                        _TodayStatusOption(
                          icon: Icons.block,
                          color: Colors.orange,
                          text: "바쁨",
                          selected: _todayStatus == 1,
                          onTap: () => _handleSetTodayStatus(1),
                        ),
                        const SizedBox(height: 12),
                        _TodayStatusOption(
                          icon: Icons.self_improvement,
                          color: Colors.blueGrey,
                          text: "휴식 중",
                          selected: _todayStatus == 2,
                          onTap: () => _handleSetTodayStatus(2),
                        ),
                      ],
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
  final VoidCallback onShowTodayStatusSelector;
  final bool showTodayStatusSelector;
  final int? todayStatus;
  final ValueChanged<int> onSetTodayStatus;

  const _ProfileCircleList({
    super.key,
    required this.onShowTodayStatusSelector,
    required this.showTodayStatusSelector,
    required this.todayStatus,
    required this.onSetTodayStatus,
  });

  @override
  State<_ProfileCircleList> createState() => _ProfileCircleListState();
}

class _ProfileCircleListState extends State<_ProfileCircleList> {
  List<Map<String, dynamic>> allProfiles = [];
  bool _loading = true;
  final ImagePicker _picker = ImagePicker();
  String? _userDocProfileUrl;
  String? _userDocProfileText;
  Color? _userDocProfileColor;

  @override
  void initState() {
    super.initState();
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    loginProvider.fetchFriends().then((_) => _loadAllProfiles());
    _loadTodayStatus();
    _loadUserProfileFromFirestore();
  }

  Future<void> _loadUserProfileFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    setState(() {
      _userDocProfileUrl = data?['profileUrl'] ?? '';
      _userDocProfileText = data?['profileText'];
      final colorStr = data?['profileColor'];
      if (colorStr is String &&
          colorStr.startsWith('#') &&
          colorStr.length == 7) {
        _userDocProfileColor =
            Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
      } else if (colorStr is String && colorStr.length > 1) {
        _userDocProfileColor = Color(int.parse(colorStr));
      } else {
        _userDocProfileColor = null;
      }
    });
  }

  Future<void> _loadAllProfiles() async {
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    final user = loginProvider.user;

    Map<String, dynamic> myProfile = {
      'displayName': user?.displayName ?? '나',
      'photoURL': user?.photoURL ?? '',
      'isMe': true,
      'hasStory': false,
      'profileText': null,
      'profileColor': null,
    };
    if (user != null) {
      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final myData = myDoc.data();
      if (myData != null) {
        myProfile['profileText'] = myData['profileText'];
        myProfile['profileColor'] = myData['profileColor'];
        myProfile['photoURL'] = myData['profileUrl'] ?? user.photoURL ?? '';
      }
    }

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
          'profileText': data['profileText'],
          'profileColor': data['profileColor'],
        });
      }
    }

    setState(() {
      allProfiles = [myProfile, ...others];
      _loading = false;
    });
  }

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
        widget.onSetTodayStatus(data?['status'] as int? ?? 0);
      });
    } else {
      setState(() {
        widget.onSetTodayStatus(0);
      });
    }
  }

  void _toggleTodayStatusSelector() {
    widget.onShowTodayStatusSelector();
  }

  String get _todayStatusText {
    switch (widget.todayStatus) {
      case 1:
        return "바쁨";
      case 2:
        return "휴식 중";
      default:
        return "만나자";
    }
  }

  Color get _todayStatusColor {
    switch (widget.todayStatus) {
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
        clipBehavior: Clip.none,
        children: [
          SingleChildScrollView(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 40),
            child: Row(
              children: List.generate(allProfiles.length, (idx) {
                final p = allProfiles[idx];
                final isMe = p['isMe'] == true;
                Color? profileColor;
                final colorStr = p['profileColor'];
                if (colorStr is String &&
                    colorStr.startsWith('#') &&
                    colorStr.length == 7) {
                  profileColor = Color(
                      int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
                } else if (colorStr is String && colorStr.length > 1) {
                  profileColor = Color(int.parse(colorStr));
                }
                return Padding(
                  padding: EdgeInsets.only(
                      right: idx == allProfiles.length - 1 ? 0 : 18),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: isMe
                                ? () {
                                    _toggleTodayStatusSelector();
                                  }
                                : null,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: null,
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: (isMe
                                    ? (_userDocProfileColor ?? Colors.teal)
                                    : profileColor ?? Colors.grey[700]),
                                backgroundImage: (isMe
                                    ? (_userDocProfileUrl != null &&
                                            _userDocProfileUrl!.isNotEmpty)
                                        ? NetworkImage(_userDocProfileUrl!)
                                        : null
                                    : (p['photoURL'] != null &&
                                            (p['photoURL'] as String)
                                                .isNotEmpty)
                                        ? NetworkImage(p['photoURL'])
                                        : null),
                                child: (isMe
                                        ? (_userDocProfileUrl == null ||
                                            _userDocProfileUrl!.isEmpty)
                                        : (p['photoURL'] == null ||
                                            (p['photoURL'] as String).isEmpty))
                                    ? Text(
                                        isMe
                                            ? (_userDocProfileText ?? '🙂')
                                            : (p['profileText'] ?? '🙂'),
                                        style: const TextStyle(
                                          fontSize: 22,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          if (isMe)
                            Positioned(
                              top: -32,
                              left: -12,
                              right: -12,
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    // 말풍선은 터치해도 아무 동작 없음
                                    onTap: null,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 240,
                                        minWidth: 120,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 28, vertical: 14),
                                      decoration: BoxDecoration(
                                        color:
                                            _todayStatusColor.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(22),
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
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.today,
                                              color: Colors.white, size: 40),
                                          const SizedBox(width: 10),
                                          Flexible(
                                            child: Text(
                                              _todayStatusText,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 33,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
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
        ],
      ),
    );
  }
}

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
