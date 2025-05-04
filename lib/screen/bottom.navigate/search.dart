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

  Future<void> _search() async {
    String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return;
    try {
      var res = await FirebaseFirestore.instance
          .collection("users")
          .where("emailKeywords", arrayContains: query)
          .get();
      final currentUserEmail =
          FirebaseAuth.instance.currentUser?.email?.toLowerCase();
      final filteredDocs = res.docs.where((doc) {
        final data = doc.data();
        // 필터: 내 이메일과 일치하는 문서를 제외
        return data['email'].toString().toLowerCase() != currentUserEmail;
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

    // target user 문서 조회 (email이 일치하는 문서)
    var res = await FirebaseFirestore.instance
        .collection("users")
        .where("email", isEqualTo: friendEmail)
        .get();
    if (res.docs.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('사용자를 찾지 못했습니다.')));
      return;
    }
    // target user uid 추출
    final friendDoc = res.docs.first;
    final friendUid = friendDoc.id;

    // 현재 사용자 정보 조회 (이름 필요)
    var currentUserDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .get();
    final senderName = currentUserDoc.data()?["name"] ?? '';

    // friend_requests 하위 컬렉션에 요청 저장 (요청자는 currentUser.uid)
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
        // 남색 계열의 두 가지 색상 그라디언트
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
                          style: TextStyle(
                              color: Colors.grey[300]), // 이메일 텍스트를 밝은 회색으로
                        ),
                        subtitle: Text(userData['name'] ?? ''),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.black, // 버튼 텍스트를 검정색으로
                          ),
                          onPressed: () =>
                              _sendFriendRequest(userData['email']),
                          child: const Text('친구 요청'),
                        ),
                      );
                    },
                  ),
                ),
                // 얇은 회색 선 추가
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
                                        icon: const Icon(Icons.person_remove,
                                            color: Colors.red),
                                        tooltip: '친구 끊기',
                                        onPressed: () async {
                                          User? currentUser =
                                              FirebaseAuth.instance.currentUser;
                                          if (currentUser == null) return;
                                          // 내 friends에서 삭제
                                          await FirebaseFirestore.instance
                                              .collection("users")
                                              .doc(currentUser.uid)
                                              .update({
                                            'friends': FieldValue.arrayRemove(
                                                [friendEmail])
                                          });
                                          // 상대방 friends에서도 나를 삭제 (옵션)
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
