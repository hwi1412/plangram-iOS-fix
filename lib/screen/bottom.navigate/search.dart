import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../chat_room.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _results = [];
  List<dynamic> friends = [];
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<String> blockedUserUids = [];

  Future<void> _search() async {
    String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return;
    try {
      var snapshot = await FirebaseFirestore.instance.collection("users").get();
      final currentUserEmail =
          FirebaseAuth.instance.currentUser?.email?.toLowerCase();
      final filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final email = data['email'].toString().toLowerCase();
        final name = (data['name']?.toString().toLowerCase() ?? "");
        // 내 계정, 차단된 사용자 제외
        if (email == currentUserEmail) return false;
        if (blockedUserUids.contains(doc.id)) return false;
        return email.contains(query) || name.contains(query);
      }).toList();
      print("검색 쿼리 실행 결과: ${filteredDocs.length}건");
      setState(() {
        _results = filteredDocs;
      });
    } catch (e) {
      print("검색 중 오류 발생: $e");
    }
  }

  Future<void> _sendFriendRequest(String friendEmail) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    var res = await FirebaseFirestore.instance
        .collection("users")
        .where("email", isEqualTo: friendEmail)
        .get();
    if (res.docs.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('사용자를 찾지 못했습니다.')));
      return;
    }
    final friendDoc = res.docs.first;
    final friendUid = friendDoc.id;

    var currentUserDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .get();
    final senderName = currentUserDoc.data()?["name"] ?? '';

    await FirebaseFirestore.instance
        .collection("users")
        .doc(friendUid)
        .collection("friend_requests")
        .doc(currentUser.uid)
        .set({
      'senderEmail': currentUser.email,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('친구 요청이 전송되었습니다.')));
  }

  Future<void> _loadFriends() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    var userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .get();
    setState(() {
      friends = userDoc.data()?["friends"] ?? [];
    });
  }

  Future<void> _loadBlockedUsers() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .collection("blockedUsers")
        .get();
    setState(() {
      blockedUserUids = snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  Future<void> _blockUser(String targetUid) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // 1. targetUid의 이메일 조회
    final targetDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(targetUid)
        .get();
    final targetEmail = targetDoc.data()?["email"];
    final myEmail = currentUser.email;

    // 2. 내 friends에서 targetEmail 제거
    if (targetEmail != null) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(currentUser.uid)
          .update({
        'friends': FieldValue.arrayRemove([targetEmail])
      });
    }

    // 3. 상대방 friends에서 내 이메일 제거
    if (myEmail != null) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(targetUid)
          .update({
        'friends': FieldValue.arrayRemove([myEmail])
      });
    }

    // 4. 차단 처리
    await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .collection("blockedUsers")
        .doc(targetUid)
        .set({"blockedAt": FieldValue.serverTimestamp()});

    // 5. UI 갱신
    await _loadBlockedUsers();
    await _loadFriends();

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('사용자가 차단(및 친구 해제)되었습니다.')));
  }

  Future<void> _unblockUser(String targetUid) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .collection("blockedUsers")
        .doc(targetUid)
        .delete();
    await _loadBlockedUsers();
  }

  Future<void> _showReportDialog(String targetUid, String targetEmail) async {
    String? selectedReason;
    TextEditingController customReasonController = TextEditingController();
    final reasons = ["스팸/광고", "욕설/비방", "부적절한 프로필", "기타"];
    String? errorText;

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

                    // 1. 친구 관계 해제(양방향)
                    final myEmail = currentUser.email;
                    if (targetEmail.isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection("users")
                          .doc(currentUser.uid)
                          .update({
                        'friends': FieldValue.arrayRemove([targetEmail])
                      });
                    }
                    if (myEmail != null) {
                      await FirebaseFirestore.instance
                          .collection("users")
                          .doc(targetUid)
                          .update({
                        'friends': FieldValue.arrayRemove([myEmail])
                      });
                    }

                    // 2. 차단 처리
                    await FirebaseFirestore.instance
                        .collection("users")
                        .doc(currentUser.uid)
                        .collection("blockedUsers")
                        .doc(targetUid)
                        .set({"blockedAt": FieldValue.serverTimestamp()});

                    // 3. 신고 저장
                    await FirebaseFirestore.instance.collection("reports").add({
                      "targetUid": targetUid,
                      "targetEmail": targetEmail,
                      "reporterUid": currentUser.uid,
                      "reporterEmail": myEmail,
                      "reason": reason,
                      "timestamp": FieldValue.serverTimestamp(),
                    });

                    // 4. UI 갱신
                    await _loadBlockedUsers();
                    await _loadFriends();

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

  void _showBlockedUsersScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlockedUsersScreen(
          blockedUserUids: blockedUserUids,
          onUnblock: _unblockUser,
        ),
      ),
    );
    await _loadBlockedUsers();
  }

  Future<Map<String, String>> _getFriendInfo(String friendEmail) async {
    var query = await FirebaseFirestore.instance
        .collection("users")
        .where("email", isEqualTo: friendEmail)
        .get();
    String name = friendEmail;
    if (query.docs.isNotEmpty) {
      name = query.docs.first.data()["name"] ?? friendEmail;
    }
    return {"name": name, "email": friendEmail};
  }

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadBlockedUsers();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final Color color1 = Color.lerp(const Color(0xFF0A2342),
            const Color(0xFF1B2845), _animation.value)!;
        final Color color2 = Color.lerp(const Color(0xFF274472),
            const Color(0xFF102542), 1 - _animation.value)!;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text(
              '친구 찾기',
              style: TextStyle(fontSize: 24),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color1, color2],
                ),
              ),
            ),
            titleTextStyle: const TextStyle(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.block, color: Colors.white),
                tooltip: '차단 관리',
                onPressed: _showBlockedUsersScreen,
              ),
            ],
          ),
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color1, color2],
              ),
            ),
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                const SizedBox(height: 130),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: '이메일 또는 이름 검색',
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  onTap: () {
                    setState(() {
                      _searchController.clear();
                    });
                  },
                ),
                TextButton(
                  onPressed: _search,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.pink,
                  ),
                  child: const Text('검색'),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      var userData =
                          _results[index].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(
                          userData['email'],
                          style: TextStyle(color: Colors.grey[300]),
                        ),
                        subtitle: Text(userData['name'] ?? ''),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () =>
                              _sendFriendRequest(userData['email']),
                          child: const Text('친구 요청'),
                        ),
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 16.0, bottom: 0),
                  child: Divider(
                    color: Color(0xFFBDBDBD),
                    thickness: 0.7,
                    height: 1,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      '친구 관리',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: friends.isEmpty
                      ? const Center(
                          child: Text('친구가 없습니다.',
                              style: TextStyle(color: Colors.black)))
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: friends.length,
                          itemBuilder: (context, index) {
                            String friendEmail = friends[index];
                            return FutureBuilder<Map<String, String>>(
                              future: _getFriendInfo(friendEmail),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return const SizedBox(height: 60);
                                final friendName = snapshot.data!["name"]!;
                                final email = snapshot.data!["email"]!;
                                return ListTile(
                                  title: Text(friendName,
                                      style: const TextStyle(
                                          color: Color.fromARGB(
                                              255, 189, 187, 187),
                                          fontSize: 16)),
                                  subtitle: Text(email,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.more_vert,
                                            color: Colors.white),
                                        tooltip: '더보기',
                                        onPressed: () async {
                                          var q = await FirebaseFirestore
                                              .instance
                                              .collection("users")
                                              .where("email",
                                                  isEqualTo: friendEmail)
                                              .limit(1)
                                              .get();
                                          if (q.docs.isEmpty) return;
                                          final targetUid = q.docs.first.id;
                                          showModalBottomSheet(
                                            context: context,
                                            builder: (context) {
                                              return SafeArea(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    ListTile(
                                                      leading: const Icon(
                                                          Icons.block,
                                                          color: Colors.red),
                                                      title: const Text(
                                                        '차단',
                                                        style: TextStyle(
                                                            color: Colors.red),
                                                      ),
                                                      onTap: () async {
                                                        Navigator.pop(context);
                                                        await _blockUser(
                                                            targetUid);
                                                      },
                                                    ),
                                                    ListTile(
                                                      leading: const Icon(
                                                          Icons.report,
                                                          color: Colors.orange),
                                                      title: const Text(
                                                        '신고',
                                                        style: TextStyle(
                                                            color:
                                                                Colors.orange),
                                                      ),
                                                      onTap: () {
                                                        Navigator.pop(context);
                                                        _showReportDialog(
                                                            targetUid,
                                                            friendEmail);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.person_remove,
                                            color: Colors.red),
                                        tooltip: '친구 끊기',
                                        onPressed: () async {
                                          User? currentUser =
                                              FirebaseAuth.instance.currentUser;
                                          if (currentUser == null) return;
                                          await FirebaseFirestore.instance
                                              .collection("users")
                                              .doc(currentUser.uid)
                                              .update({
                                            'friends': FieldValue.arrayRemove(
                                                [friendEmail])
                                          });
                                          await FirebaseFirestore.instance
                                              .collection("users")
                                              .where("email",
                                                  isEqualTo: friendEmail)
                                              .get()
                                              .then((snapshot) async {
                                            if (snapshot.docs.isNotEmpty) {
                                              await FirebaseFirestore.instance
                                                  .collection("users")
                                                  .doc(snapshot.docs.first.id)
                                                  .update({
                                                'friends':
                                                    FieldValue.arrayRemove(
                                                        [currentUser.email])
                                              });
                                            }
                                          });
                                          setState(() {
                                            friends.removeAt(index);
                                          });
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text('친구 연결이 해제되었습니다.')),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chat,
                                            color: Color.fromARGB(
                                                255, 141, 203, 202)),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => ChatRoomScreen(
                                                    friendEmail: friendEmail)),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

class BlockedUsersScreen extends StatefulWidget {
  final List<String> blockedUserUids;
  final Future<void> Function(String) onUnblock;
  const BlockedUsersScreen(
      {super.key, required this.blockedUserUids, required this.onUnblock});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, String>> blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedUserInfos();
  }

  Future<void> _loadBlockedUserInfos() async {
    List<Map<String, String>> infos = [];
    for (final uid in widget.blockedUserUids) {
      final doc =
          await FirebaseFirestore.instance.collection("users").doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        infos.add({
          "uid": uid,
          "name": data["name"] ?? "",
          "email": data["email"] ?? "",
        });
      }
    }
    setState(() {
      blockedUsers = infos;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('차단된 사용자 관리', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: blockedUsers.isEmpty
          ? const Center(
              child: Text('차단된 사용자가 없습니다.',
                  style: TextStyle(color: Colors.white70)))
          : ListView.builder(
              itemCount: blockedUsers.length,
              itemBuilder: (context, index) {
                final user = blockedUsers[index];
                return ListTile(
                  title: Text(user["name"] ?? "",
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(user["email"] ?? "",
                      style: const TextStyle(color: Colors.grey)),
                  trailing: TextButton(
                    onPressed: () async {
                      await widget.onUnblock(user["uid"]!);
                      setState(() {
                        blockedUsers.removeAt(index);
                      });
                    },
                    child: const Text('차단 해제',
                        style: TextStyle(color: Colors.pink)),
                  ),
                );
              },
            ),
    );
  }
}
