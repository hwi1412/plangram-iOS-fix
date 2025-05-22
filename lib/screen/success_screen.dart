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

  void _handleSetTodayStatus(int status) async {
    setState(() {
      _todayStatus = status;
      _showTodayStatusSelector = false;
    });
    // Firestore에 저장
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('today_status')
          .doc(user.uid)
          .set({'status': status});
    }
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
    _loadTodayStatusFromFirestore(); // Firestore에서 상태 불러오기
  }

  // Firestore에서 내 todayStatus 불러오기
  Future<void> _loadTodayStatusFromFirestore() async {
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.toLowerCase();

    // 관리자 계정이면 강제 AdminDashboard로 이동
    if (email == 'admin@plangram.com') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/admin');
      });
      return const SizedBox();
    }

    // 계정 상태 확인 및 제한
    return FutureBuilder<DocumentSnapshot>(
      future: user != null
          ? FirebaseFirestore.instance.collection('users').doc(user.uid).get()
          : null,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final status = data['accountStatus'] ?? 'active';
        final suspendedUntil = data['suspendedUntil'];
        final suspendReason = data['suspendReason'] ?? '';
        final now = DateTime.now();

        if (status == 'banned') {
          // 영구정지
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await FirebaseAuth.instance.signOut();
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => AlertDialog(
                title: const Text('접근 제한'),
                content: const Text('이 계정은 영구정지되었습니다.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                    child: const Text('확인'),
                  ),
                ],
              ),
            );
          });
          return const SizedBox();
        } else if (status == 'suspended' && suspendedUntil != null) {
          DateTime until;
          if (suspendedUntil is Timestamp) {
            until = suspendedUntil.toDate();
          } else if (suspendedUntil is DateTime) {
            until = suspendedUntil;
          } else {
            until = now;
          }
          if (until.isAfter(now)) {
            final TextEditingController appealController =
                TextEditingController();
            bool sending = false;
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.block, color: Colors.red, size: 60),
                      const SizedBox(height: 16),
                      Text(
                        '이 계정은 ${until.toLocal()}까지 정지 상태입니다.',
                        style: const TextStyle(fontSize: 18, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      if (suspendReason.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            '정지 사유: $suspendReason',
                            style: const TextStyle(
                                fontSize: 16, color: Colors.black87),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: appealController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '해명/이의제기 메시지',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: sending
                            ? null
                            : () async {
                                if (appealController.text.trim().isEmpty)
                                  return;
                                sending = true;
                                // uid/email은 user가 null이 아님이 이미 보장됨
                                await FirebaseFirestore.instance
                                    .collection('appeals')
                                    .add({
                                  'uid': user?.uid ?? '',
                                  'email': user?.email ?? '',
                                  'message': appealController.text.trim(),
                                  'timestamp': FieldValue.serverTimestamp(),
                                  'status': '대기',
                                });
                                sending = false;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('해명 요청이 전송되었습니다.')),
                                );
                              },
                        child: const Text('해명/이의제기 전송'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          Navigator.of(context).pushReplacementNamed('/login');
                        },
                        child: const Text('로그아웃'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        } else if (status == 'warned') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('경고: 운영정책 위반 이력이 있습니다.'),
                duration: Duration(seconds: 3),
              ),
            );
          });
        }

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
                        onShowTodayStatusSelector:
                            _handleShowTodayStatusSelector,
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
                                  color: Colors.white
                                      .withOpacity(0.3), // 흰색 반투명 배경
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
                                  color: Colors.white
                                      .withOpacity(0.3), // 흰색 반투명 배경
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
                                color:
                                    const Color(0xFF102040).withOpacity(0.95),
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
                                  _LegendRow(color: Colors.red, text: '내 휴무일'),
                                  const SizedBox(height: 8),
                                  _LegendRow(
                                      color: Color(0xFF1DE9B6), text: '공동 휴무일'),
                                  const SizedBox(height: 8),
                                  _LegendRow(
                                      color: Colors.grey, text: '친구 휴무일'),
                                  const SizedBox(height: 8),
                                  _LegendRow(color: Colors.purple, text: '오늘'),
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
                              text: "만나요",
                              selected: _todayStatus == 0,
                              onTap: () => _handleSetTodayStatus(0),
                            ),
                            const SizedBox(height: 12),
                            _TodayStatusOption(
                              icon: Icons.block,
                              color: Colors.orange,
                              text: "바빠요",
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
      },
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

  List<Map<String, dynamic>> _friendProfiles = [];

  @override
  void initState() {
    super.initState();
    _fetchAndLoadProfiles();
    _loadTodayStatus();
    _loadUserProfileFromFirestore();
  }

  Future<void> _fetchAndLoadProfiles() async {
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    // fetchFriends가 완료된 후에만 친구 프로필을 불러오도록 순서 보장
    await loginProvider.fetchFriends();
    await _loadAllProfiles();
    await _loadFriendProfiles();
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

  Future<void> _loadFriendProfiles() async {
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    final List<Map<String, dynamic>> friendProfiles = [];
    for (final email in loginProvider.friends) {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        int todayStatus = 0;
        try {
          final todayStatusDoc = await FirebaseFirestore.instance
              .collection('today_status')
              .doc(query.docs.first.id)
              .get();
          if (todayStatusDoc.exists) {
            todayStatus = todayStatusDoc.data()?['status'] ?? 0;
          }
        } catch (_) {}
        friendProfiles.add({
          'displayName': data['name'] ?? '사용자',
          'photoURL': data['profileUrl'] ?? '',
          'profileText': data['profileText'],
          'profileColor': data['profileColor'],
          'todayStatus': todayStatus,
        });
      }
    }
    setState(() {
      _friendProfiles = friendProfiles;
    });
  }

  String _friendTodayStatusText(int? status) {
    switch (status) {
      case 1:
        return "바빠요";
      case 2:
        return "휴식 중";
      default:
        return "만나요";
    }
  }

  Color _friendTodayStatusColor(int? status) {
    switch (status) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.blueGrey;
      default:
        return Colors.green;
    }
  }

  void _toggleTodayStatusSelector() {
    widget.onShowTodayStatusSelector();
  }

  String get _todayStatusText {
    switch (widget.todayStatus) {
      case 1:
        return "바빠요";
      case 2:
        return "휴식 중";
      default:
        return "만나요";
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
              children: [
                Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () {
                            _toggleTodayStatusSelector();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: null,
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  _userDocProfileColor ?? Colors.teal,
                              backgroundImage: (_userDocProfileUrl != null &&
                                      _userDocProfileUrl!.isNotEmpty)
                                  ? NetworkImage(_userDocProfileUrl!)
                                  : null,
                              child: (_userDocProfileUrl == null ||
                                      _userDocProfileUrl!.isEmpty)
                                  ? Text(
                                      _userDocProfileText ?? '🙂',
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
                        Positioned(
                          top: -32,
                          left: -12,
                          right: -12,
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: null,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 240,
                                    minWidth: 120,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 28, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: _todayStatusColor.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
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
                        '나',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                ..._friendProfiles.asMap().entries.map((entry) {
                  final f = entry.value;
                  final idx = entry.key;
                  Color? profileColor;
                  final colorStr = f['profileColor'];
                  if (colorStr is String &&
                      colorStr.startsWith('#') &&
                      colorStr.length == 7) {
                    profileColor = Color(
                        int.parse(colorStr.substring(1), radix: 16) +
                            0xFF000000);
                  } else if (colorStr is String && colorStr.length > 1) {
                    profileColor = Color(int.parse(colorStr));
                  }
                  return Padding(
                    padding: EdgeInsets.only(left: idx == -1 ? 18 : 21),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                border: null,
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    profileColor ?? Colors.grey[700],
                                backgroundImage: (f['photoURL'] != null &&
                                        (f['photoURL'] as String).isNotEmpty)
                                    ? NetworkImage(f['photoURL'])
                                    : null,
                                child: (f['photoURL'] == null ||
                                        (f['photoURL'] as String).isEmpty)
                                    ? Text(
                                        f['profileText'] ?? '🙂',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            Positioned(
                              top: -32,
                              left: -12,
                              right: -12,
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 240,
                                      minWidth: 120,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 28, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: _friendTodayStatusColor(
                                              f['todayStatus'])
                                          .withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
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
                                            _friendTodayStatusText(
                                                f['todayStatus']),
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
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 54,
                          child: Text(
                            f['displayName'] ?? '',
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
              ],
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
