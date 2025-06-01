import 'package:cloud_firestore/cloud_firestore.dart'; // 추가된 import
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 추가된 import

// 새 클래스 Group 추가
class Group {
  String name;
  List<String> members;
  Group({required this.name, required this.members});
}

// TodoItem에 작성자 정보 필드 추가
class TodoItem {
  String text;
  bool completed;
  String? id; // Firestore 문서 id
  String? group; // 할 일에 속한 그룹 (null이면 전체)
  String? creator; // 작성자 이메일
  String? creatorName; // 작성자 이름
  TodoItem(this.text,
      {this.completed = false,
      this.id,
      this.group,
      this.creator,
      this.creatorName});
}

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});
  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  // 초기 _selectedDay를 현재 날짜의 정규화된 값으로 설정
  DateTime _selectedDay =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime? _highlightedDay; // 선택된 날짜 상태 변수
  CalendarFormat _calendarFormat = CalendarFormat.week; // 기본값을 주간으로 변경

  // 날짜별 To-Do 리스트를 저장하는 상태 변수
  final Map<DateTime, List<TodoItem>> _events = {};

  // 그룹 관련 상태 변수 수정
  List<Group> _groups = [];
  String _selectedGroup = "전체 보기"; // 기본 전체보기

  // 선택된 날짜의 To-Do 리스트 getter (그룹 필터 적용)
  List<TodoItem> get _selectedEvents {
    final events = _events[_selectedDay] ?? <TodoItem>[];
    if (_selectedGroup == "My") {
      return events.where((e) => e.group == "MY").toList();
    }
    final filtered = _selectedGroup == "전체 보기"
        ? events
        : events.where((e) => e.group == _selectedGroup).toList();
    filtered
        .sort((a, b) => (a.completed ? 1 : 0).compareTo(b.completed ? 1 : 0));
    return filtered;
  }

  // 새 입력을 위한 텍스트 컨트롤러 추가
  final TextEditingController _todoController = TextEditingController();

  // 날짜를 "YYYY-MM-DD" 문자열로 변환하는 도우미 함수
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // Firestore에서 저장된 todo list들을 불러오는 함수
  Future<void> _loadTodosFromFirestore() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    String currentEmail = currentUser.email!;
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection("todos").get();
    Map<DateTime, List<TodoItem>> loadedEvents = {};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      String dateStr = data["date"] ?? "";
      DateTime date = DateTime.parse(dateStr);
      date = DateTime(date.year, date.month, date.day);
      String? docGroup = data["group"]; // "MY", 특정 그룹, 혹은 null
      String? creator = data["creator"];
      List<String> groupMembers = List<String>.from(data["groupMembers"] ?? []);

      // 접근 권한 체크:
      if (docGroup == "MY") {
        // 개인 todo: 본인이 작성한 경우만 표시
        if (creator != currentEmail) continue;
      } else if (docGroup != null) {
        // 그룹 todo: 해당 그룹의 멤버(이메일)만 표시
        if (!groupMembers.contains(currentEmail)) continue;
      } else {
        // 그룹 필드가 null이면 개인 todo로 간주
        if (creator != currentEmail) continue;
      }

      // 작성자 이름 가져오기
      String? creatorName;
      if (creator != null) {
        final userQuery = await FirebaseFirestore.instance
            .collection("users")
            .where("email", isEqualTo: creator)
            .limit(1)
            .get();
        if (userQuery.docs.isNotEmpty) {
          creatorName = userQuery.docs.first.data()["name"] ?? creator;
        } else {
          creatorName = creator;
        }
      }

      TodoItem todo = TodoItem(
        data["text"],
        completed: data["completed"] ?? false,
        id: doc.id,
        group: data["group"],
        creator: creator,
        creatorName: creatorName,
      );
      if (loadedEvents[date] == null) {
        loadedEvents[date] = [];
      }
      loadedEvents[date]!.add(todo);
    }
    setState(() {
      _events.clear();
      _events.addAll(loadedEvents);
    });
  }

  // Firestore에서 그룹 정보를 불러오는 함수
  Future<void> _loadGroups() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    Set<String> groupNames = {};
    List<Group> loadedGroups = [];
    // Firestore group_chat_rooms에서 불러오기
    QuerySnapshot chatSnapshot = await FirebaseFirestore.instance
        .collection("group_chat_rooms")
        .where("members", arrayContains: currentUser.email)
        .get();
    for (var doc in chatSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      String roomName = data["roomName"] ?? "";
      if (roomName.isNotEmpty && !groupNames.contains(roomName)) {
        groupNames.add(roomName);
        // "members" 필드를 이메일 리스트로 저장
        List<String> members = List<String>.from(data["members"] ?? []);
        loadedGroups.add(Group(name: roomName, members: members));
      }
    }
    // 사용자의 groups 서브컬렉션(맵.dart에서 생성된 그룹)에서 불러오기
    QuerySnapshot mapGroupsSnapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .collection("groups")
        .get();
    for (var doc in mapGroupsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      String groupName = data["groupName"] ?? "";
      if (groupName.isNotEmpty && !groupNames.contains(groupName)) {
        groupNames.add(groupName);
        // 이메일로 변환
        List<dynamic> membersRaw = data["members"] ?? [];
        List<String> members = [];
        for (var member in membersRaw) {
          if (member is String && member.contains('@')) {
            members.add(member); // 이미 이메일
          } else if (member is String) {
            // 이름일 경우 이메일로 변환
            QuerySnapshot userQuery = await FirebaseFirestore.instance
                .collection("users")
                .where("name", isEqualTo: member)
                .limit(1)
                .get();
            if (userQuery.docs.isNotEmpty) {
              members.add((userQuery.docs.first.data()
                  as Map<String, dynamic>)["email"]);
            }
          }
        }
        loadedGroups.add(Group(name: groupName, members: members));
      }
    }
    setState(() {
      _groups = loadedGroups;
    });
  }

  // 현재 사용자의 친구 목록을 불러오는 헬퍼 함수
  Future<List<String>> _getFriendList() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    var userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .get();
    List<String> friendEmails =
        List<String>.from(userDoc.data()?["friends"] ?? []);
    List<String> friendNames = [];
    for (var email in friendEmails) {
      QuerySnapshot query = await FirebaseFirestore.instance
          .collection("users")
          .where("email", isEqualTo: email)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        friendNames.add(
            (query.docs.first.data() as Map<String, dynamic>)["name"] ?? email);
      } else {
        friendNames.add(email);
      }
    }
    return friendNames;
  }

  // 친구 목록을 [{name, email}] 형태로 반환
  Future<List<Map<String, String>>> _getFriendListWithEmail() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    var userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .get();
    List<String> friendEmails =
        List<String>.from(userDoc.data()?["friends"] ?? []);
    List<Map<String, String>> friendList = [];
    for (var email in friendEmails) {
      QuerySnapshot query = await FirebaseFirestore.instance
          .collection("users")
          .where("email", isEqualTo: email)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data() as Map<String, dynamic>;
        friendList.add({"name": data["name"] ?? email, "email": email});
      } else {
        friendList.add({"name": email, "email": email});
      }
    }
    // 본인도 추가
    friendList.add({
      "name": currentUser.displayName ?? currentUser.email!,
      "email": currentUser.email!
    });
    return friendList;
  }

  @override
  void initState() {
    super.initState();
    _loadGroups(); // 그룹 로드 추가
    _loadTodosFromFirestore();
  }

  void _addTodoItem(String todo) async {
    final dateString = _formatDate(_selectedDay);
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    String? groupField;
    List<String>? groupMembers;

    if (_selectedGroup == "전체 보기") {
      groupField = null;
      groupMembers = null;
    } else if (_selectedGroup == "My") {
      groupField = "MY";
      groupMembers = [currentUser.email!];
    } else {
      groupField = _selectedGroup;
      // 그룹 멤버 찾기 (항상 이메일 리스트)
      final groupObj = _groups.firstWhere((g) => g.name == _selectedGroup,
          orElse: () => Group(name: _selectedGroup, members: []));
      groupMembers = groupObj.members;
      // 본인이 포함되어 있지 않으면 추가
      if (!groupMembers.contains(currentUser.email!)) {
        groupMembers.add(currentUser.email!);
      }
    }

    await FirebaseFirestore.instance.collection("todos").add({
      "date": dateString,
      "text": todo,
      "completed": false,
      "group": groupField,
      "groupMembers": groupMembers, // 이메일 리스트로 저장
      "creator": currentUser.email,
    }).then((docRef) {
      setState(() {
        if (_events[_selectedDay] == null) {
          _events[_selectedDay] = [];
        }
        _events[_selectedDay]!
            .add(TodoItem(todo, id: docRef.id, group: groupField));
      });
    });
  }

  // 체크박스 상태 변경 시 Firestore 업데이트
  void _updateTodoCompletion(TodoItem item) {
    if (item.id != null) {
      FirebaseFirestore.instance
          .collection("todos")
          .doc(item.id)
          .update({"completed": item.completed});
    }
  }

  // 그룹 생성/수정 모달
  void _showGroupModal({Group? group}) {
    final TextEditingController groupController =
        TextEditingController(text: group?.name ?? "");
    final Set<String> selectedMembers = Set.from(group?.members ?? []);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromARGB(255, 36, 35, 65),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, modalSetState) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: groupController,
                    decoration: const InputDecoration(
                      labelText: "그룹명",
                      labelStyle: TextStyle(color: Colors.white),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  // 친구(멤버) 선택 체크박스 목록 (이메일로 저장)
                  FutureBuilder<List<Map<String, String>>>(
                    future: _getFriendListWithEmail(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final friendList = snapshot.data!;
                      return Column(
                        children: friendList.map((friend) {
                          final email = friend['email']!;
                          final name = friend['name']!;
                          return CheckboxListTile(
                            title: Text(name,
                                style: const TextStyle(color: Colors.white)),
                            value: selectedMembers.contains(email),
                            activeColor: Colors.green,
                            onChanged: (val) {
                              modalSetState(() {
                                if (val == true) {
                                  selectedMembers.add(email);
                                } else {
                                  selectedMembers.remove(email);
                                }
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (group != null)
                        TextButton(
                          onPressed: () async {
                            User? currentUser =
                                FirebaseAuth.instance.currentUser;
                            if (currentUser != null) {
                              var query = await FirebaseFirestore.instance
                                  .collection("users")
                                  .doc(currentUser.uid)
                                  .collection("groups")
                                  .where("groupName", isEqualTo: group.name)
                                  .get();
                              for (var doc in query.docs) {
                                await doc.reference.delete();
                              }
                            }
                            setState(() {
                              _groups.removeWhere((g) => g.name == group.name);
                              if (_selectedGroup == group.name) {
                                _selectedGroup = "전체 보기";
                              }
                            });
                            Navigator.pop(context);
                          },
                          child: const Text("삭제",
                              style: TextStyle(color: Colors.red)),
                        ),
                      TextButton(
                        onPressed: () async {
                          debugPrint("저장 버튼 클릭됨"); // 디버그 메시지
                          if (groupController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("그룹명을 입력하세요.")));
                            return;
                          }
                          User? currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("사용자가 인증되지 않았습니다.")));
                            return;
                          }
                          if (group != null) {
                            // 기존 그룹 수정: Firestore 업데이트
                            var query = await FirebaseFirestore.instance
                                .collection("users")
                                .doc(currentUser.uid)
                                .collection("groups")
                                .where("groupName", isEqualTo: group.name)
                                .get();
                            for (var doc in query.docs) {
                              await doc.reference.update({
                                "groupName": groupController.text.trim(),
                                "members": selectedMembers.toList()
                              });
                            }
                          } else {
                            // 신규 그룹 생성: Firestore에 저장 (독립적으로)
                            await FirebaseFirestore.instance
                                .collection("users")
                                .doc(currentUser.uid)
                                .collection("groups")
                                .add({
                              "groupName": groupController.text.trim(),
                              "members": selectedMembers.toList(),
                            });
                          }
                          await _loadGroups();
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("그룹이 저장되었습니다.")));
                          Navigator.pop(context);
                        },
                        child: const Text("저장",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // To-Do 신고 다이얼로그
  Future<void> _showTodoReportDialog(TodoItem todo) async {
    String? selectedReason;
    TextEditingController customReasonController = TextEditingController();
    final reasons = ["스팸/광고", "욕설/비방", "부적절한 내용", "기타"];
    String? errorText;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('할 일 신고'),
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
                      "targetUid": null,
                      "targetEmail": todo.creator,
                      "targetName": todo.creatorName,
                      "reporterUid": currentUser.uid,
                      "reporterEmail": currentUser.email,
                      "reason": reason,
                      "todoId": todo.id,
                      "todoText": todo.text,
                      "type": "todo",
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
        title: Text(
          "Let's Do", // 변경된 부분: 제목 수정
          style: TextStyle(color: Colors.grey.shade300),
        ),
        backgroundColor: const Color.fromARGB(255, 25, 25, 37),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 25, 25, 37),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      // 캘린더 클릭 시 월간/주간 토글은 아래 onDaySelected에서 처리
                    },
                    child: TableCalendar(
                      calendarFormat: _calendarFormat,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Month',
                        CalendarFormat.week: 'Week',
                      },
                      pageAnimationEnabled: false,
                      firstDay: DateTime.utc(2020, 10, 16),
                      lastDay: DateTime.utc(2030, 3, 14),
                      focusedDay: _selectedDay,
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
                        rightChevronIcon: const Icon(Icons.chevron_right,
                            color: Colors.white),
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
                          color: Colors.purple.withOpacity(0.3),
                        ),
                        selectedDecoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      selectedDayPredicate: (day) {
                        return day.year == _selectedDay.year &&
                            day.month == _selectedDay.month &&
                            day.day == _selectedDay.day;
                      },
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          final normalizedDay =
                              DateTime(day.year, day.month, day.day);
                          final items = _events[normalizedDay] ?? [];
                          if (items.isNotEmpty) {
                            final displayItems = items.take(9).toList();
                            return Positioned(
                              bottom: 1,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  displayItems.length,
                                  (index) => Container(
                                    width: 4,
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: displayItems[index].completed
                                          ? Colors.green
                                          : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        final normalized = DateTime(selectedDay.year,
                            selectedDay.month, selectedDay.day);
                        setState(() {
                          if (_calendarFormat == CalendarFormat.week) {
                            // 주간에서 날짜 선택 시 월간으로 전환
                            _calendarFormat = CalendarFormat.month;
                          } else if (_calendarFormat == CalendarFormat.month &&
                              isSameDay(_selectedDay, normalized)) {
                            // 월간에서 같은 날짜를 다시 누르면 주간으로 전환
                            _calendarFormat = CalendarFormat.week;
                          }
                          _selectedDay = normalized;
                          _highlightedDay = normalized;
                        });
                      },
                    ),
                  ),
                ],
              ),
              // 그룹 선택 바 (달력 바로 아래)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    // 추가: My 버튼
                    ChoiceChip(
                      label: const Text("My"),
                      selected: _selectedGroup == "My",
                      onSelected: (_) {
                        setState(() {
                          _selectedGroup = "My";
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text("전체 보기"),
                      selected: _selectedGroup == "전체 보기",
                      onSelected: (_) {
                        setState(() => _selectedGroup = "전체 보기");
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _groups.map((grp) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: GestureDetector(
                                onLongPress: () => _showGroupModal(group: grp),
                                child: ChoiceChip(
                                  label: Text(grp.name),
                                  selected: _selectedGroup == grp.name,
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedGroup = grp.name;
                                    });
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () {
                        _showGroupModal();
                      },
                    )
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // === 아래 코드만 남기고 위쪽(중복) 리스트는 제거 ===
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(_selectedEvents.length, (index) {
                      final todo = _selectedEvents[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 0, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal,
                            child: Text(
                              (todo.creatorName != null &&
                                      todo.creatorName!.isNotEmpty)
                                  ? todo.creatorName![0]
                                  : '🙂',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            todo.text,
                            style: TextStyle(
                              decoration: todo.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                              color:
                                  todo.completed ? Colors.grey : Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            todo.creatorName ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: todo.completed,
                                onChanged: (val) {
                                  setState(() {
                                    todo.completed = val ?? false;
                                  });
                                  _updateTodoCompletion(todo);
                                },
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) async {
                                  if (value == 'report') {
                                    _showTodoReportDialog(todo);
                                  } else if (value == 'edit') {
                                    // 수정 다이얼로그
                                    final controller =
                                        TextEditingController(text: todo.text);
                                    final result = await showDialog<String>(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Text('할 일 수정'),
                                          content: TextField(
                                            controller: controller,
                                            decoration: const InputDecoration(
                                              hintText: "수정할 내용을 입력하세요",
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('취소'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                  context,
                                                  controller.text.trim()),
                                              child: const Text('수정'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (result != null &&
                                        result.isNotEmpty &&
                                        result != todo.text) {
                                      setState(() {
                                        todo.text = result;
                                      });
                                      if (todo.id != null) {
                                        await FirebaseFirestore.instance
                                            .collection("todos")
                                            .doc(todo.id)
                                            .update({"text": result});
                                      }
                                    }
                                  } else if (value == 'delete') {
                                    // 삭제 확인 다이얼로그
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Text('할 일 삭제'),
                                          content: const Text(
                                              '정말로 이 할 일을 삭제하시겠습니까?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('취소'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('삭제',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (confirm == true && todo.id != null) {
                                      await FirebaseFirestore.instance
                                          .collection("todos")
                                          .doc(todo.id)
                                          .delete();
                                      setState(() {
                                        _selectedEvents.removeAt(index);
                                        // _events[_selectedDay]도 동기화
                                        _events[_selectedDay]?.remove(todo);
                                      });
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('수정하기'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('삭제하기'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'report',
                                    child: Text('신고하기'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 10.0), // 아래에 10 공간 추가
        child: Container(
          color: const Color.fromARGB(255, 31, 31, 43),
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _todoController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "할 일을 입력하세요",
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(18)), // 모든 모서리 둥글게
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(18)), // 모든 모서리 둥글게
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(18)), // 모든 모서리 둥글게
                      borderSide:
                          const BorderSide(color: Colors.white, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 22),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      _addTodoItem(value);
                      _todoController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                color: Colors.grey,
                onPressed: () {
                  if (_todoController.text.isNotEmpty) {
                    _addTodoItem(_todoController.text);
                    _todoController.clear();
                  }
                },
                tooltip: "추가",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
