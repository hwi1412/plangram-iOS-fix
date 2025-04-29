import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlangramHomePageContent extends StatefulWidget {
  const PlangramHomePageContent({super.key});

  @override
  PlangramHomePageContentState createState() => PlangramHomePageContentState();
}

class PlangramHomePageContentState extends State<PlangramHomePageContent> {
  final ValueNotifier<List<DateTime>> _selectedDates = ValueNotifier([]);
  final ValueNotifier<List<DateTime>> _friendSelectedDates = ValueNotifier([]);
  bool isEditing = false; // 초기값 false로 변경
  DateTime? _selectedDetailDay;
  List<String> _usersForSelectedDay = [];
  StreamSubscription<QuerySnapshot>? _userScheduleSubscription;
  StreamSubscription<QuerySnapshot>? _friendScheduleSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeUserSchedules();
    _subscribeFriendSchedules();
  }

  // 본인 일정 실시간 업데이트 (내 schedules 컬렉션 구독)
  void _subscribeUserSchedules() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    _userScheduleSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('schedules')
        .snapshots()
        .listen((snapshot) {
      final dates = snapshot.docs
          .map((doc) => (doc.data()['date'] as Timestamp).toDate())
          .toList();
      setState(() {
        _selectedDates.value = dates;
      });
    });
  }

  // 친구 일정 실시간 업데이트 (collectionGroup 구독 후 친구 목록으로 필터링)
  void _subscribeFriendSchedules() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final currentUserEmail = currentUser.email;
    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final List<dynamic> friendEmailsDynamic =
        currentUserDoc.data()?["friends"] ?? [];
    final List<String> friendEmails =
        friendEmailsDynamic.map((e) => e.toString()).toList();

    // 상호 친구 목록 가져오기: 내 이메일이 친구의 "friends" 리스트에 포함되어 있는 친구만 mutual 처리
    List<String> mutualFriendEmails = [];
    for (String email in friendEmails) {
      var queryResult = await FirebaseFirestore.instance
          .collection("users")
          .where("email", isEqualTo: email)
          .get();
      if (queryResult.docs.isNotEmpty) {
        var friendData = queryResult.docs.first.data();
        List<dynamic> friendFriends = friendData["friends"] ?? [];
        if (friendFriends.contains(currentUserEmail)) {
          mutualFriendEmails.add(email);
        }
      }
    }

    _friendScheduleSubscription = FirebaseFirestore.instance
        .collectionGroup('schedules')
        .snapshots()
        .listen((snapshot) {
      final friendDates = <DateTime>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final scheduleEmail = data['userEmail'] as String?;
        if (scheduleEmail != null &&
            mutualFriendEmails.contains(scheduleEmail)) {
          friendDates.add((data['date'] as Timestamp).toDate());
        }
      }
      setState(() {
        _friendSelectedDates.value = friendDates;
      });
    });
  }

  @override
  void dispose() {
    _userScheduleSubscription?.cancel();
    _friendScheduleSubscription?.cancel();
    _selectedDates.dispose();
    _friendSelectedDates.dispose();
    super.dispose();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (isEditing) {
      final exists =
          _selectedDates.value.any((day) => isSameDay(day, selectedDay));
      if (!exists) {
        _selectedDates.value = [..._selectedDates.value, selectedDay];
      } else {
        _selectedDates.value = _selectedDates.value
            .where((day) => !isSameDay(day, selectedDay))
            .toList();
      }
    } else {
      if (_selectedDetailDay != null &&
          isSameDay(_selectedDetailDay, selectedDay)) {
        // 같은 날을 다시 누르면 상세 정보 숨김
        setState(() {
          _selectedDetailDay = null;
        });
      } else {
        setState(() {
          _selectedDetailDay = selectedDay;
        });
        _fetchUsersForDay(selectedDay);
      }
    }
  }

  Future<void> _fetchUsersForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    final querySnapshot = await FirebaseFirestore.instance
        .collectionGroup('schedules')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    final users = <String>{};
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final name =
          (data['userName'] as String?) ?? (data['userEmail'] as String?);
      if (name != null && name.isNotEmpty) {
        users.add(name);
      }
    }
    setState(() {
      _usersForSelectedDay = users.toList();
    });
  }

  void toggleEditing() {
    if (!isEditing) {
      setState(() {
        isEditing = true;
      });
    } else {
      _onSavePressed(); // 저장 후 editing 모드 종료
      setState(() {
        isEditing = false;
      });
    }
  }

  Future<void> _onSavePressed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await saveSchedules(user.uid, _selectedDates.value);
      setState(() {
        isEditing = false;
      });
    }
  }

  Future<void> saveSchedules(String userId, List<DateTime> dates) async {
    final batch = FirebaseFirestore.instance.batch();
    final userSchedulesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('schedules');
    final existingSchedules = await userSchedulesRef.get();
    for (var doc in existingSchedules.docs) {
      batch.delete(doc.reference);
    }
    var userDoc =
        await FirebaseFirestore.instance.collection("users").doc(userId).get();
    final userName = userDoc.data()?["name"] ?? '';
    final currentUser = FirebaseAuth.instance.currentUser;
    for (var date in dates) {
      batch.set(userSchedulesRef.doc(), {
        'date': Timestamp.fromDate(date),
        'userEmail': currentUser?.email ?? '',
        'userName': userName,
      });
    }
    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getSchedules(String userId) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('schedules')
        .get();
    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }

  // 단체 채팅방 생성 함수 (자동 채팅방 이름: "MM/DD Plan")
  Future<void> _onCreatePlanGroupChat(DateTime day) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final roomName = "${day.month}/${day.day} Plan";
    // 그룹 채팅방에 현재 사용자를 포함하고, 선택된 사용자도 추가
    // _usersForSelectedDay는 user id 대신 user name이 표시된다면
    // Firestore "group_chat_rooms"에 저장 시 members는 이메일 등 고유 정보여야 함.
    // 예시로, 여기서는 _usersForSelectedDay 값을 그대로 사용합니다.
    List<String> members = [
      if (currentUser.email != null) currentUser.email!,
      ..._usersForSelectedDay
    ];
    await FirebaseFirestore.instance.collection("group_chat_rooms").add({
      'roomName': roomName,
      'members': members,
      'timestamp': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('계획 채팅방이 생성되었습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 상단 수정/저장 버튼 Row를 제거함
        // ...existing code (제거된 버튼 관련 부분)...
        ValueListenableBuilder<List<DateTime>>(
          valueListenable: _selectedDates,
          builder: (context, selectedDates, _) {
            return ValueListenableBuilder<List<DateTime>>(
              valueListenable: _friendSelectedDates,
              builder: (context, friendDates, __) {
                return TableCalendar(
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
                  selectedDayPredicate: (day) =>
                      selectedDates.any((d) => isSameDay(d, day)),
                  onDaySelected: _onDaySelected,
                  calendarBuilders: CalendarBuilders(
                    selectedBuilder: (context, day, focusedDay) {
                      final myCount = 1;
                      final friendCount =
                          friendDates.where((d) => isSameDay(d, day)).length;
                      final totalCount = myCount + friendCount;
                      final dotCount = totalCount >= 3 ? 3 : totalCount;
                      final decoration = BoxDecoration(
                        shape: BoxShape.circle,
                        color: friendDates.any((d) => isSameDay(d, day))
                            ? Colors.greenAccent.withOpacity(0.7)
                            : Colors.red.withOpacity(0.4),
                      );
                      return Container(
                        margin: const EdgeInsets.all(6.0),
                        width: 48,
                        height: 48,
                        decoration: decoration,
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: Text(day.day.toString(),
                                  style: const TextStyle(color: Colors.white)),
                            ),
                            if (dotCount > 0)
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(dotCount, (_) {
                                    return Container(
                                      width: 4,
                                      height: 4,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 1),
                                      decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle),
                                    );
                                  }),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                    defaultBuilder: (context, day, focusedDay) {
                      final myCount = 0;
                      final friendCount =
                          friendDates.where((d) => isSameDay(d, day)).length;
                      final totalCount = myCount + friendCount;
                      final dotCount = totalCount >= 3 ? 3 : totalCount;
                      if (friendCount > 0) {
                        return Container(
                          margin: const EdgeInsets.all(6.0),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.withOpacity(0.4),
                          ),
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment.center,
                                child: Text(day.day.toString()),
                              ),
                              if (dotCount > 0)
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(dotCount, (_) {
                                      return Container(
                                        width: 4,
                                        height: 4,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 1),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }
                      return null; // ...기본 셀 렌더링...
                    },
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
                      color:
                          Colors.purple.withOpacity(0.4), // 오늘 날짜 원 보라색 반투명 0.8
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
        if (_selectedDetailDay != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            color: Colors.white10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedDetailDay!.year}-${_selectedDetailDay!.month}-${_selectedDetailDay!.day} 선택 사용자:',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _usersForSelectedDay.isEmpty
                    ? const Text('선택한 사용자가 없습니다.',
                        style: TextStyle(color: Colors.white70))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _usersForSelectedDay
                            .map((email) => Text(email,
                                style: const TextStyle(color: Colors.white)))
                            .toList(),
                      ),
              ],
            ),
          ),
        if (_selectedDetailDay != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_usersForSelectedDay.length >= 3)
                TextButton(
                  onPressed: () => _onCreatePlanGroupChat(_selectedDetailDay!),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.pink,
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                  ),
                  child: const Text(
                    '채팅방 만들기',
                    style: TextStyle(fontSize: 17),
                  ),
                )
            ],
          ),
      ],
    );
  }
}
