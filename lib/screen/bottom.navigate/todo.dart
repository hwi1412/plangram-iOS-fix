import 'package:cloud_firestore/cloud_firestore.dart'; // 추가된 import
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 추가된 import
import 'dart:async';

// 새 클래스 Group 추가
class Group {
  String name;
  List<String> members;
  Group({required this.name, required this.members});
}

// TodoItem에 completedMembers 필드 추가
class TodoItem {
  String text;
  String? id;
  String? group;
  String? creator;
  String? creatorName;
  List<String> groupMembers;
  List<String> completedMembers; // ✅ 체크한 멤버 이메일
  DateTime? createdAt;
  DateTime? updatedAt;
  TodoItem(
    this.text, {
    this.id,
    this.group,
    this.creator,
    this.creatorName,
    this.groupMembers = const [],
    this.completedMembers = const [],
    this.createdAt,
    this.updatedAt,
  });
  int get completedCount => completedMembers.length;
  int get memberCount => groupMembers.length;
  double get completionRate =>
      memberCount == 0 ? 0 : completedCount / memberCount;
  String get compoundKey => "${group ?? "MY"}|$text"; // 날짜는 상위 Map에서 관리
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
  // _events 구조 변경: Map<DateTime, Map<compoundKey, TodoItem>>
  final Map<DateTime, Map<String, TodoItem>> _events = {};
  final Map<String, Map<String, dynamic>> _userCache =
      {}; // email -> {name, photoUrl}

  // 그룹 관련 상태 변수 수정
  List<Group> _groups = [];
  String _selectedGroup = "전체 보기"; // 기본 전체보기

  // 선택된 날짜의 To-Do 리스트 getter (정렬: 완료율 낮은 순, 텍스트 사전순)
  List<TodoItem> get _selectedEvents {
    final dayEvents = _events[_selectedDay] ?? {};
    User? currentUser = FirebaseAuth.instance.currentUser;
    final myEmail = currentUser?.email ?? "";
    List<TodoItem> filtered;

    if (_selectedGroup == "My") {
      // 내 개인 todo만
      filtered = dayEvents.values
          .where((e) => e.group == "MY" && e.creator == myEmail)
          .toList();
    } else if (_selectedGroup == "전체 보기") {
      // 내가 속한 모든 그룹 + 내 개인 todo
      filtered = dayEvents.values
          .where((e) =>
              (e.group == "MY" && e.creator == myEmail) ||
              (e.group != null &&
                  e.group != "MY" &&
                  e.groupMembers.contains(myEmail)))
          .toList();
    } else {
      // 특정 그룹: 그룹명만 일치하면 모두 보여줌 (내가 멤버가 아니어도)
      filtered =
          dayEvents.values.where((e) => e.group == _selectedGroup).toList();
    }

    // 정렬: 완료율 높은 것 아래로, 완료율 같으면 텍스트 사전순
    filtered.sort((a, b) {
      final rateA = a.completionRate;
      final rateB = b.completionRate;
      if (rateA != rateB) return rateA.compareTo(rateB);
      return a.text.compareTo(b.text);
    });
    return filtered;
  }

  // 새 입력을 위한 텍스트 컨트롤러 추가
  final TextEditingController _todoController = TextEditingController();

  // 날짜를 "YYYY-MM-DD" 문자열로 변환하는 도우미 함수
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // Firestore에서 저장된 todo list들을 불러오는 함수 (구조 변경)
  Future<void> _loadTodosFromFirestore() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    String currentEmail = currentUser.email!;
    final myGroups = _groups.map((g) => g.name).toSet();
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection("todos").get();
    Map<DateTime, Map<String, TodoItem>> loadedEvents = {};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      String dateStr = data["date"] ?? "";
      DateTime date = DateTime.parse(dateStr);
      date = DateTime(date.year, date.month, date.day);
      String? docGroup = data["group"];
      String? creator = data["creator"];
      List<String> groupMembers = List<String>.from(data["groupMembers"] ?? []);
      List<String> completedMembers =
          List<String>.from(data["completedMembers"] ?? []);
      // 필터링 조건:
      if (docGroup == "MY") {
        if (creator != currentEmail) continue;
      }
      // 그룹 투두는 필터링 없이 모두 불러옴

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

      final text = data["text"] ?? "";
      final compoundKey = "${docGroup ?? "MY"}|$text";
      final todo = TodoItem(
        text,
        id: doc.id,
        group: docGroup,
        creator: creator,
        creatorName: creatorName,
        groupMembers: groupMembers,
        completedMembers: completedMembers,
        createdAt: (data["createdAt"] as Timestamp?)?.toDate(),
        updatedAt: (data["updatedAt"] as Timestamp?)?.toDate(),
      );
      loadedEvents[date] ??= {};
      // 중복 방지: 같은 날짜+텍스트+그룹 조합 하나만 유지
      loadedEvents[date]![compoundKey] = todo;
    }
    setState(() {
      _events.clear();
      _events.addAll(loadedEvents);
    });
  }

  // 친구 목록을 [{name, email}] 형태로 반환

  // 실시간 Firestore 스트림 구독 및 마이그레이션
  Stream<QuerySnapshot> get _todoStream =>
      FirebaseFirestore.instance.collection("todos").snapshots();

  StreamSubscription<QuerySnapshot>? _todoSubscription; // 스트림 구독 변수 추가

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _listenTodos();
  }

  @override
  void dispose() {
    _todoSubscription?.cancel(); // 스트림 구독 해제
    _todoController.dispose();
    super.dispose();
  }

  // 이메일 변환 헬퍼
  Future<String> _ensureEmail(String value) async {
    if (value.contains('@')) return value;
    final q = await FirebaseFirestore.instance
        .collection("users")
        .where("name", isEqualTo: value)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) {
      return q.docs.first.data()["email"] ?? value;
    }
    return value;
  }

  // groupMembers 전체를 이메일로 변환
  Future<List<String>> _ensureEmails(List<dynamic> members) async {
    List<String> emails = [];
    for (var m in members) {
      if (m is String) {
        emails.add(await _ensureEmail(m));
      }
    }
    return emails;
  }

  void _listenTodos() {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final myEmail = currentUser.email!;
    _todoSubscription = _todoStream.listen((snapshot) async {
      Map<DateTime, Map<String, TodoItem>> loadedEvents = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final group = data["group"];
        final creator = data["creator"];
        List<dynamic> groupMembersRaw = data["groupMembers"] ?? [];
        List<String> groupMembers = List<String>.from(groupMembersRaw);
        List<String> completedMembers =
            List<String>.from(data["completedMembers"] ?? []);
        // 필터
        if (group == "MY") {
          if (creator != myEmail) continue;
        } else if (group != null) {
          if (!groupMembers.contains(myEmail)) continue;
        } else {
          if (creator != myEmail) continue;
        }
        // 날짜/키
        String dateStr = data["date"] ?? "";
        DateTime date = DateTime.parse(dateStr);
        date = DateTime(date.year, date.month, date.day);
        final text = data["text"] ?? "";
        final compoundKey = "${group ?? "MY"}|$text";

        // Fetch creatorName
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

        loadedEvents[date] ??= {};
        loadedEvents[date]![compoundKey] = TodoItem(
          text,
          id: doc.id,
          group: group,
          creator: creator,
          creatorName: creatorName,
          groupMembers: groupMembers,
          completedMembers: completedMembers,
          createdAt: (data["createdAt"] as Timestamp?)?.toDate(),
          updatedAt: (data["updatedAt"] as Timestamp?)?.toDate(),
        );
      }
      if (!mounted) return;
      setState(() {
        _events.clear();
        _events.addAll(loadedEvents);
      });
    });
  }

  // 유저 정보 캐시
  Future<String> _getUserName(String email) async {
    if (_userCache.containsKey(email)) {
      return _userCache[email]?['name'] ?? email;
    }
    final q = await FirebaseFirestore.instance
        .collection("users")
        .where("email", isEqualTo: email)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) {
      final data = q.docs.first.data();
      _userCache[email] = {
        "name": data["name"] ?? email,
        "photoUrl": data["profileUrl"] ?? "",
      };
      return data["name"] ?? email;
    }
    return email;
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

  // To-Do 추가/갱신
  Future<void> _addTodoItem(String todo) async {
    final dateString = _formatDate(_selectedDay);
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    String? groupField;
    List<String> groupMembers;
    if (_selectedGroup == "전체 보기" || _selectedGroup == "My") {
      groupField = "MY";
      groupMembers = [currentUser.email!];
    } else {
      groupField = _selectedGroup;
      final groupObj = _groups.firstWhere((g) => g.name == _selectedGroup,
          orElse: () => Group(name: _selectedGroup, members: []));
      // 반드시 이메일로 변환
      groupMembers = await _ensureEmails(groupObj.members);
      if (!groupMembers.contains(currentUser.email!)) {
        groupMembers.add(currentUser.email!);
      }
    }
    final compoundKey = "$groupField|$todo";
    // 중복 방지: 동일한 날짜+텍스트+그룹 존재 시 merge
    final query = await FirebaseFirestore.instance
        .collection("todos")
        .where("date", isEqualTo: dateString)
        .where("text", isEqualTo: todo)
        .where("group", isEqualTo: groupField)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      // merge: groupMembers/creator 유지, completed 확장
      final doc = query.docs.first;
      final data = doc.data();
      // completedMap logic removed as it's not used
      await doc.reference.update({
        "groupMembers": groupMembers,
        "updatedAt": FieldValue.serverTimestamp(),
      });
      return;
    }
    await FirebaseFirestore.instance.collection("todos").add({
      "date": dateString,
      "text": todo,
      "group": groupField,
      "groupMembers": groupMembers,
      "completedMembers": [],
      "creator": currentUser.email,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  // 체크박스 상태 변경 (본인만 가능, Firestore update, 로컬 반영)
  Future<void> _toggleMemberCompletion(
      TodoItem item, String memberEmail, bool checked) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || memberEmail != currentUser.email) return;
    if (item.id == null) return;
    await FirebaseFirestore.instance.collection("todos").doc(item.id).update({
      "completed.$memberEmail": checked,
      "updatedAt": FieldValue.serverTimestamp()
    });
    if (!mounted) return; // 추가: 위젯이 dispose된 경우 setState 금지
    setState(() {
      if (checked) {
        if (!item.completedMembers.contains(memberEmail)) {
          item.completedMembers.add(memberEmail);
        }
      } else {
        item.completedMembers.remove(memberEmail);
      }
    });
  }

  // 그룹 생성/수정 모달: 친구(멤버) 선택 체크박스에서 본인 이메일 제외
  void _showGroupModal({Group? group}) {
    final TextEditingController groupController =
        TextEditingController(text: group?.name ?? "");
    User? currentUser = FirebaseAuth.instance.currentUser;
    final String? myEmail = currentUser?.email;
    final Set<String> selectedMembers = Set.from(group?.members ?? []);
    if (myEmail != null) selectedMembers.remove(myEmail); // 본인은 자동 포함
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
                  // 친구(멤버) 선택 체크박스 목록 (본인 이메일 제외)
                  FutureBuilder<List<Map<String, String>>>(
                    future: _getFriendListWithEmail(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final friendList = snapshot.data!;
                      return Column(
                        children: friendList
                            .where((friend) => friend['email'] != myEmail)
                            .map((friend) {
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
                          final groupName = groupController.text.trim();
                          final allMembers = {
                            ...selectedMembers,
                            if (myEmail != null) myEmail
                          }.toList();

                          // 1. users/{uid}/groups에 저장 (기존 코드)
                          if (group != null) {
                            var query = await FirebaseFirestore.instance
                                .collection("users")
                                .doc(currentUser.uid)
                                .collection("groups")
                                .where("groupName", isEqualTo: group.name)
                                .get();
                            for (var doc in query.docs) {
                              await doc.reference.update({
                                "groupName": groupName,
                                "members": allMembers,
                              });
                            }
                          } else {
                            await FirebaseFirestore.instance
                                .collection("users")
                                .doc(currentUser.uid)
                                .collection("groups")
                                .add({
                              "groupName": groupName,
                              "members": allMembers,
                            });
                          }

                          // 2. group_chat_rooms에 저장 (모든 멤버에게 그룹이 보이게)
                          final groupChatQuery = await FirebaseFirestore
                              .instance
                              .collection("group_chat_rooms")
                              .where("roomName", isEqualTo: groupName)
                              .limit(1)
                              .get();
                          if (groupChatQuery.docs.isNotEmpty) {
                            // 이미 존재하면 멤버만 업데이트
                            await groupChatQuery.docs.first.reference.update({
                              "members": allMembers,
                            });
                          } else {
                            // 새로 생성
                            await FirebaseFirestore.instance
                                .collection("group_chat_rooms")
                                .add({
                              "roomName": groupName,
                              "members": allMembers,
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
                          final items = _events[normalizedDay] ?? {};
                          if (items.isNotEmpty) {
                            final displayItems =
                                (items.values).take(9).toList();
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
                                      color:
                                          displayItems[index].completedCount ==
                                                      displayItems[index]
                                                          .groupMembers
                                                          .length &&
                                                  displayItems[index]
                                                      .groupMembers
                                                      .isNotEmpty
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
                      final isAllCompleted =
                          todo.completedCount == todo.memberCount &&
                              todo.memberCount > 0;
                      final currentUser = FirebaseAuth.instance.currentUser;
                      final myEmail = currentUser?.email ?? "";
                      // 모든 멤버(본인 포함) 체크박스+아바타
                      final memberCheckboxes =
                          todo.groupMembers.map((memberEmail) {
                        final isChecked =
                            todo.completedMembers.contains(memberEmail);
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: isChecked,
                              onChanged: memberEmail == myEmail
                                  ? (val) async {
                                      if (val == true) {
                                        if (!todo.completedMembers
                                            .contains(memberEmail)) {
                                          todo.completedMembers
                                              .add(memberEmail);
                                        }
                                      } else {
                                        todo.completedMembers
                                            .remove(memberEmail);
                                      }
                                      if (todo.id != null) {
                                        await FirebaseFirestore.instance
                                            .collection("todos")
                                            .doc(todo.id)
                                            .update({
                                          "completedMembers":
                                              todo.completedMembers
                                        });
                                      }
                                      if (!mounted) return;
                                      setState(() {});
                                    }
                                  : null,
                              activeColor: memberEmail == myEmail
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            FutureBuilder<QuerySnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection("users")
                                  .where("email", isEqualTo: memberEmail)
                                  .limit(1)
                                  .get(),
                              builder: (context, snapshot) {
                                String display = memberEmail;
                                if (snapshot.hasData &&
                                    snapshot.data!.docs.isNotEmpty) {
                                  display = (snapshot.data!.docs.first.data()
                                          as Map<String, dynamic>)["name"] ??
                                      memberEmail;
                                }
                                return Text(display,
                                    style: const TextStyle(fontSize: 12));
                              },
                            ),
                          ],
                        );
                      }).toList();

                      return Dismissible(
                        key: ValueKey(todo.id ?? todo.compoundKey),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          color: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) async {
                          if (todo.id != null) {
                            await FirebaseFirestore.instance
                                .collection("todos")
                                .doc(todo.id)
                                .delete();
                          }
                          setState(() {
                            _events[_selectedDay]?.remove(todo.compoundKey);
                          });
                        },
                        child: GestureDetector(
                          // onLongPress에서 수정 다이얼로그 호출 제거
                          child: Opacity(
                            opacity: isAllCompleted ? 0.3 : 1.0,
                            child: Card(
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
                                    decoration: isAllCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isAllCompleted
                                        ? Colors.grey
                                        : Colors.black,
                                  ),
                                ),
                                subtitle: Wrap(
                                  spacing: 8,
                                  children: memberCheckboxes,
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) async {
                                    if (value == 'report') {
                                      _showTodoReportDialog(todo);
                                    } else if (value == 'edit') {
                                      // 수정 다이얼로그는 여기서만 띄움
                                      final controller = TextEditingController(
                                          text: todo.text);
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
                                        final newCompoundKey =
                                            "${todo.group}|$result";
                                        if (_events[_selectedDay]
                                                ?.containsKey(newCompoundKey) ==
                                            true) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      "이미 같은 할 일이 존재합니다.")));
                                          return;
                                        }
                                        if (todo.id != null) {
                                          await FirebaseFirestore.instance
                                              .collection("todos")
                                              .doc(todo.id)
                                              .update({"text": result});
                                        }
                                        setState(() {
                                          _events[_selectedDay]
                                              ?.remove(todo.compoundKey);
                                          todo.text = result;
                                          _events[_selectedDay]
                                              ?[newCompoundKey] = todo;
                                        });
                                      }
                                    } else if (value == 'delete') {
                                      if (todo.id != null) {
                                        await FirebaseFirestore.instance
                                            .collection("todos")
                                            .doc(todo.id)
                                            .delete();
                                        setState(() {
                                          _events[_selectedDay]
                                              ?.remove(todo.compoundKey);
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
                              ),
                            ),
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

  // 유저 프로필 캐시 + 로딩
  Future<Map<String, dynamic>> _getUserProfile(String email) async {
    if (_userCache.containsKey(email)) return _userCache[email]!;
    final q = await FirebaseFirestore.instance
        .collection("users")
        .where("email", isEqualTo: email)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) {
      final data = q.docs.first.data();
      _userCache[email] = {
        "name": data["name"] ?? email,
        "photoUrl": data["profileUrl"] ?? "",
      };
      return _userCache[email]!;
    }
    return {"name": email, "photoUrl": ""};
  }
}
