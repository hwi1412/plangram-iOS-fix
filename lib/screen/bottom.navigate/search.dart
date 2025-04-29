import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../chat_room.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _results = [];
  List<dynamic> friends = [];

  Future<void> _search() async {
    String query = _searchController.text.trim().toLowerCase(); // 소문자로 변환
    if (query.isEmpty) return;
    try {
      var res = await FirebaseFirestore.instance
          .collection("users")
          .where("emailKeywords", arrayContains: query) // 수정된 부분
          .get();
      print("검색 쿼리 실행 결과: ${res.docs.length}건");
      setState(() {
        _results = res.docs;
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '이메일로 친구 추가',
          style: TextStyle(fontSize: 24),
        ),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color.fromARGB(255, 0, 57, 47), // 다크 버전 시작 색상
                Color.fromARGB(255, 85, 27, 79), // 다크 버전 종료 색상
              ],
            ),
          ),
        ),
        titleTextStyle: const TextStyle(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color.fromARGB(255, 0, 57, 47),
              Color.fromARGB(255, 85, 27, 79),
            ],
          ),
        ),
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            const SizedBox(height: 50),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: '사용자 이메일 검색',
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
                  var userData = _results[index].data() as Map<String, dynamic>;
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
                      onPressed: () => _sendFriendRequest(userData['email']),
                      child: const Text('친구 요청'),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: friends.isEmpty
                  ? const Center(
                      child: Text('친구가 없습니다.',
                          style: TextStyle(color: Colors.black)))
                  : ListView.builder(
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
                                      color: Colors.black, fontSize: 16)),
                              subtitle: Text(email,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.chat, color: Colors.black),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ChatRoomScreen(
                                            friendEmail: friendEmail)),
                                  );
                                },
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
  }
}
