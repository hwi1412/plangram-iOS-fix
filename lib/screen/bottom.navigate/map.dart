import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<dynamic> friends = [];
  List<DateTime> friendSchedules = [];
  List<DateTime> _myScheduleDates = []; // 내 캘린더 날짜 저장
  bool _showMyCalendar = false; // 내 캘린더 표시 여부
  String? selectedFriendEmail;
  final List<Map<String, dynamic>> _groups = []; // 그룹 목록

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadMySchedules(); // 내 스케줄 불러오기
    _loadGroups(); // Firestore에서 그룹 불러오기
  }

  // Firestore에서 그룹 불러오기
  Future<void> _loadGroups() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    var snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('groups')
        .get();
    setState(() {
      _groups.clear();
      _groups.addAll(snapshot.docs.map((doc) => {
            "groupId": doc.id,
            "groupName": doc.data()["groupName"],
            "members": doc.data()["members"]
          }));
    });
  }

  // Firestore에 그룹 저장
  Future<void> _saveGroup(Map<String, dynamic> group) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('groups')
        .add(group);
    await _loadGroups(); // 저장 후 그룹 목록 갱신
  }

  // 내 캘린더 불러오기 함수
  Future<void> _loadMySchedules() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    var snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('schedules')
        .get();
    setState(() {
      _myScheduleDates = snapshot.docs
          .map((doc) => (doc.data()['date'] as Timestamp).toDate())
          .toList();
    });
  }

  Future<void> _loadFriends() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    // friends: 이메일 리스트
    List<dynamic> friendEmails = (userDoc.data()?["friends"] ?? [])
        .where((e) => e != currentUser.email)
        .toList();

    // 이메일 → 이름 매핑
    List<Map<String, String>> friendInfos = [];
    for (var email in friendEmails) {
      var query = await FirebaseFirestore.instance
          .collection("users")
          .where("email", isEqualTo: email)
          .limit(1)
          .get();
      String name = email;
      if (query.docs.isNotEmpty) {
        name = query.docs.first.data()["name"] ?? email;
      }
      friendInfos.add({"email": email, "name": name});
    }
    setState(() {
      friends = friendInfos; // [{email: ..., name: ...}, ...]
    });
  }

  Future<void> _loadFriendSchedules(String friendEmail) async {
    var query = await FirebaseFirestore.instance
        .collection('users')
        .where("email", isEqualTo: friendEmail)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return;
    var friendDoc = query.docs.first;
    var schedulesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(friendDoc.id)
        .collection('schedules')
        .get();
    List<DateTime> dates = schedulesSnapshot.docs
        .map((doc) => (doc.data()['date'] as Timestamp).toDate())
        .toList();
    setState(() {
      friendSchedules = dates;
      selectedFriendEmail = friendEmail;
    });
  }

  // 그룹 캘린더 로드: 그룹 멤버 목록을 받아 각 멤버의 스케줄을 불러와 합칩니다.
  Future<void> _loadGroupSchedules(List<String> groupMembers) async {
    List<DateTime> groupDates = [];
    for (String email in groupMembers) {
      var query = await FirebaseFirestore.instance
          .collection('users')
          .where("email", isEqualTo: email)
          .limit(1)
          .get();
      if (query.docs.isEmpty) continue;
      var userDoc = query.docs.first;
      var schedulesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .collection('schedules')
          .get();
      groupDates.addAll(schedulesSnapshot.docs
          .map((doc) => (doc.data()['date'] as Timestamp).toDate())
          .toList());
    }
    setState(() {
      friendSchedules = groupDates;
      selectedFriendEmail = null;
    });
  }

  // 현재 캘린더 날짜가 친구 일정에 포함되면 true
  bool _isFriendScheduleDay(DateTime day) {
    return friendSchedules.any((d) => isSameDay(d, day));
  }

  // 내 캘린더 날짜 확인 함수
  bool _isMyScheduleDay(DateTime day) {
    return _myScheduleDates.any((d) => isSameDay(d, day));
  }

  // 그룹 생성용 하단 모달
  Future<void> _showGroupCreationSheet() async {
    List<String> selectedEmails = [];
    String groupName = "";
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('그룹 생성',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 12),
                  Flexible(
                    fit: FlexFit.loose,
                    child: ListView(
                      shrinkWrap: true,
                      children: friends.map<Widget>((friend) {
                        // friend: {email: ..., name: ...}
                        final email = friend['email'];
                        final name = friend['name'];
                        bool isSelected = selectedEmails.contains(email);
                        return CheckboxListTile(
                          title: Text(name,
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(email,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                          value: isSelected,
                          activeColor: Colors.pink,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                selectedEmails.add(email);
                              } else {
                                selectedEmails.remove(email);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) {
                      groupName = val;
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: '그룹 이름 입력',
                      labelStyle: TextStyle(color: Colors.white),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedEmails.length >= 2 && groupName.isNotEmpty) {
                        await _saveGroup({
                          "groupName": groupName,
                          "members": selectedEmails,
                        });
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('2명 이상의 친구와 그룹 이름을 입력해주세요.',
                                  style: TextStyle(color: Colors.white))),
                        );
                      }
                    },
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.pink),
                    child: const Text('그룹 저장',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 친구 신고 다이얼로그 (search.dart 참고)
  Future<void> _showFriendReportDialog(String targetEmail) async {
    String? selectedReason;
    TextEditingController customReasonController = TextEditingController();
    final reasons = ["스팸/광고", "욕설/비방", "부적절한 프로필", "기타"];
    String? errorText;

    // targetUid 조회
    String? targetUid;
    var query = await FirebaseFirestore.instance
        .collection("users")
        .where("email", isEqualTo: targetEmail)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      targetUid = query.docs.first.id;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('사용자 신고'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...reasons.map((reason) => RadioListTile<String>(
                        title: Text(reason),
                        value: reason,
                        groupValue: selectedReason,
                        onChanged: (val) {
                          setModalState(() {
                            selectedReason = val;
                            errorText = null;
                          });
                        },
                      )),
                  if (selectedReason == "기타")
                    TextField(
                      controller: customReasonController,
                      decoration: const InputDecoration(
                        labelText: "신고 사유 입력",
                      ),
                      maxLength: 100,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    "신고 사유를 선택하거나 직접 입력해 주세요. 허위 신고 시 서비스 이용에 제한이 있을 수 있습니다.",
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        fontStyle: FontStyle.italic),
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () async {
                    String reason = selectedReason == "기타"
                        ? customReasonController.text.trim()
                        : (selectedReason ?? "");
                    if (selectedReason == null) {
                      setModalState(() {
                        errorText = "신고 사유를 선택해 주세요.";
                      });
                      return;
                    }
                    if (selectedReason == "기타" && reason.isEmpty) {
                      setModalState(() {
                        errorText = "기타 사유를 입력해 주세요.";
                      });
                      return;
                    }
                    User? currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser == null) return;

                    await FirebaseFirestore.instance.collection("reports").add({
                      "targetUid": targetUid,
                      "targetEmail": targetEmail,
                      "reporterUid": currentUser.uid,
                      "reporterEmail": currentUser.email,
                      "reason": reason,
                      "timestamp": FieldValue.serverTimestamp(),
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '신고가 정상적으로 접수되었습니다. 운영팀에서 검토 후 필요한 조치를 취할 예정입니다.\nReported content will be reviewed within 24 hours.',
                        ),
                        duration: Duration(seconds: 5),
                      ),
                    );
                  },
                  child: const Text('신고'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, // 변경: 투명 처리
        elevation: 0,
        centerTitle: true,
        title: const Text('친구의 캘린더', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/success');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group, color: Colors.white),
            onPressed: _showGroupCreationSheet,
          )
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF121212), Color(0xFF1E1E1E)], // 변경된 색상: 배경과 동일
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF121212), Color(0xFF1E1E1E)],
          ),
        ),
        child: ListView(
          children: [
            // 캘린더 영역
            TableCalendar(
              firstDay: DateTime.utc(2020, 10, 16),
              lastDay: DateTime.utc(2030, 3, 14),
              focusedDay: DateTime.now(),
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: HeaderStyle(
                titleTextFormatter: (date, locale) =>
                    "${date.year} / ${date.month.toString().padLeft(2, '0')}",
                titleTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                titleCentered: true,
                leftChevronIcon:
                    const Icon(Icons.chevron_left, color: Colors.white),
                rightChevronIcon:
                    const Icon(Icons.chevron_right, color: Colors.white),
                formatButtonVisible: false,
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: const TextStyle(color: Colors.white),
                weekendTextStyle: const TextStyle(color: Colors.red),
                outsideTextStyle:
                    TextStyle(color: Colors.white.withOpacity(0.3)),
                disabledTextStyle:
                    TextStyle(color: Colors.white.withOpacity(0.3)),
                todayDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purple.withOpacity(0.4),
                ),
              ),
              // friend 일정은 defaultBuilder로 커스텀 렌더링 처리
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  bool my = _showMyCalendar ? _isMyScheduleDay(day) : false;
                  bool friend = _isFriendScheduleDay(day);
                  BoxDecoration? decoration;
                  if (my && friend) {
                    decoration = BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.tealAccent.withOpacity(0.5), // 겹치는 일정: 민트색
                    );
                  } else if (my) {
                    decoration = BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withOpacity(0.3), // 내 일정: 빨간색
                    );
                  } else if (friend) {
                    decoration = BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.withOpacity(0.4), // 친구 일정: 회색
                    );
                  }
                  return Container(
                    margin: const EdgeInsets.all(6.0),
                    width: 48,
                    height: 48,
                    decoration: decoration,
                    child: Center(
                      child: Text(
                        day.day.toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ),
            // 토글 스위치 버튼를 이메일 목록 바로 위, 오른쪽에 배치
            Padding(
              padding: const EdgeInsets.only(right: 16, top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Switch(
                    value: _showMyCalendar,
                    activeColor: Colors.pink,
                    onChanged: (val) {
                      setState(() {
                        _showMyCalendar = val;
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '내 캘린더 보기',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white),
            // 친구 목록
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                final friendEmail = friend['email'];
                final friendName = friend['name'];
                return ListTile(
                  title: Text(friendName,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                  subtitle: Text(friendEmail,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  selected: friendEmail == selectedFriendEmail,
                  onTap: () {
                    _loadFriendSchedules(friendEmail);
                  },
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) {
                      if (value == 'report') {
                        _showFriendReportDialog(friendEmail);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'report',
                        child: Text('신고하기'),
                      ),
                    ],
                  ),
                );
              },
            ),
            // 그룹과 개인 리스트 구분선
            if (_groups.isNotEmpty)
              const Divider(
                color: Color.fromARGB(120, 200, 200, 200),
                thickness: 1,
                height: 24,
              ),
            // 그룹 목록 (배경색 제거)
            if (_groups.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _groups.length,
                itemBuilder: (context, index) {
                  final group = _groups[index];
                  return ListTile(
                    title: Text(group["groupName"],
                        style: const TextStyle(color: Colors.white)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () async {
                            User? currentUser =
                                FirebaseAuth.instance.currentUser;
                            if (currentUser == null) return;
                            final roomName = group["groupName"];
                            final members = List<String>.from(group["members"]);
                            if (!members.contains(currentUser.email)) {
                              members.add(currentUser.email!);
                            }
                            await FirebaseFirestore.instance
                                .collection("group_chat_rooms")
                                .add({
                              'roomName': roomName,
                              'members': members,
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('그룹 채팅방이 생성되었습니다.')),
                            );
                          },
                          child: const Text(
                            '채팅방 생성',
                            style: TextStyle(color: Colors.pink),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            User? currentUser =
                                FirebaseAuth.instance.currentUser;
                            if (currentUser == null) return;
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUser.uid)
                                .collection('groups')
                                .doc(group["groupId"])
                                .delete();
                            await _loadGroups();
                          },
                          child: const Text(
                            '그룹 삭제',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      _loadGroupSchedules(List<String>.from(group["members"]));
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
