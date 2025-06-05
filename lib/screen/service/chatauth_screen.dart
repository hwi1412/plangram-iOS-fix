import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../chat_room.dart';
import 'group_chat_room_screen.dart'; // 단체 채팅방 화면
import 'group_chat_creation_screen.dart';
import 'group_chat_search_screen.dart';

class ChatAuthScreen extends StatefulWidget {
  const ChatAuthScreen({super.key});

  @override
  ChatAuthScreenState createState() => ChatAuthScreenState();
}

class ChatAuthScreenState extends State<ChatAuthScreen> {
  List<dynamic> friends = [];
  bool _isSelectionMode = false;
  final Set<String> _selectedGroupChats = {};
  final Set<String> _selectedOneToOneChats = {}; // 추가

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

  // 기존 1:1 채팅 헬퍼 함수 (변경 없음)
  Future<Map<String, String>> _fetchFriendData(String friendEmail) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return {};
    final querySnapshot = await FirebaseFirestore.instance
        .collection("users")
        .where("email", isEqualTo: friendEmail)
        .get();
    String friendName = friendEmail;
    if (querySnapshot.docs.isNotEmpty) {
      friendName = querySnapshot.docs.first.data()["name"] ?? friendEmail;
    }
    List<String> emails = [currentUser.email!, friendEmail];
    emails.sort();
    final chatRoomId = emails.join("_");
    final msgSnapshot = await FirebaseFirestore.instance
        .collection("chat_rooms")
        .doc(chatRoomId)
        .collection("messages")
        .orderBy("timestamp", descending: true)
        .limit(1)
        .get();
    String lastMsg = "";
    if (msgSnapshot.docs.isNotEmpty) {
      lastMsg = msgSnapshot.docs.first.data()["message"] ?? "";
    }
    return {"friendName": friendName, "lastMessage": lastMsg};
  }

  // 헬퍼: 구성원 이메일 리스트를 받아 사용자 이름 리스트로 변환
  Future<List<String>> _getMemberNames(List<dynamic> members) async {
    List<String> names = [];
    for (var email in members) {
      var query = await FirebaseFirestore.instance
          .collection("users")
          .where("email", isEqualTo: email)
          .get();
      if (query.docs.isNotEmpty) {
        names.add(query.docs.first.data()["name"] ?? email);
      } else {
        names.add(email);
      }
    }
    return names;
  }

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  // 삭제 버튼을 눌렀을 때 선택된 단체 채팅방 삭제
  Future<void> _deleteSelectedGroupChats() async {
    for (String roomId in _selectedGroupChats) {
      await FirebaseFirestore.instance
          .collection("group_chat_rooms")
          .doc(roomId)
          .delete();
    }
    setState(() {
      _isSelectionMode = false;
      _selectedGroupChats.clear();
    });
  }

  // 1:1 채팅방 삭제 함수 (chat_rooms 문서 삭제)
  Future<void> _deleteSelectedOneToOneChats() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    for (String friendEmail in _selectedOneToOneChats) {
      List<String> emails = [currentUser.email!, friendEmail];
      emails.sort();
      final chatRoomId = emails.join("_");
      // 먼저 하위 messages 컬렉션의 모든 문서를 삭제
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection("chat_rooms")
          .doc(chatRoomId)
          .collection("messages")
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      // 채팅방 문서 삭제
      batch.delete(
          FirebaseFirestore.instance.collection("chat_rooms").doc(chatRoomId));
      await batch.commit();
    }
    setState(() {
      _selectedOneToOneChats.clear();
      _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.black, // 배경색을 검정색으로 설정
      appBar: AppBar(
        backgroundColor: Colors.black, // AppBar 배경색도 검정색으로 설정
        flexibleSpace: Container(
          color: Colors.black, // flexibleSpace도 검정색으로 통일
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white), // 모두 흰색
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSelectionMode ? Icons.close : Icons.edit,
              color: Colors.white, // 흰색 변경
            ),
            onPressed: () {
              setState(() {
                _isSelectionMode = !_isSelectionMode;
                _selectedGroupChats.clear();
                _selectedOneToOneChats.clear();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const GroupChatSearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.group, color: Colors.white), // 흰색으로 변경
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const GroupChatCreationScreen()),
              );
            },
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black, // 단색 검정색으로 변경
                ),
                // SafeArea로 감싸서 하단 여백 확보
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 16), // 추가 여백
                  children: [
                    // 단체 채팅방 섹션
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Text('단체 채팅방',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("group_chat_rooms")
                          .where("members", arrayContains: currentUser?.email)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        var docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 15),
                            child: Text('등록된 단체 채팅방이 없습니다.',
                                style: TextStyle(color: Colors.white70)),
                          );
                        }
                        return Column(
                          children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                var doc = docs[index];
                                var data = doc.data() as Map<String, dynamic>;
                                String roomName = data['roomName'] ?? '채팅방';
                                List<dynamic> members = data['members'] ?? [];
                                return _isSelectionMode
                                    ? CheckboxListTile(
                                        title: Text(
                                          roomName,
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                        subtitle: FutureBuilder<List<String>>(
                                          future: _getMemberNames(members),
                                          builder: (context, snapshot) {
                                            if (!snapshot.hasData)
                                              return const Text('');
                                            String names =
                                                snapshot.data!.join(', ');
                                            return Text("구성원: $names",
                                                style: const TextStyle(
                                                    color: Colors.white70));
                                          },
                                        ),
                                        value: _selectedGroupChats
                                            .contains(doc.id),
                                        activeColor: Colors.pink,
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedGroupChats.add(doc.id);
                                            } else {
                                              _selectedGroupChats
                                                  .remove(doc.id);
                                            }
                                          });
                                        },
                                      )
                                    : ListTile(
                                        title: Text(roomName,
                                            style: const TextStyle(
                                                color: Colors.white)),
                                        subtitle: FutureBuilder<List<String>>(
                                          future: _getMemberNames(members),
                                          builder: (context, snapshot) {
                                            if (!snapshot.hasData)
                                              return const Text('');
                                            String names =
                                                snapshot.data!.join(', ');
                                            return Text("구성원: $names",
                                                style: const TextStyle(
                                                    color: Colors.white70));
                                          },
                                        ),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  GroupChatRoomScreen(
                                                roomId: doc.id,
                                                roomName: roomName,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                              },
                            ),
                            if (_isSelectionMode)
                              Padding(
                                padding: const EdgeInsets.all(15),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () {
                                        // 취소: 선택 모드 종료하면서 선택 초기화
                                        setState(() {
                                          _isSelectionMode = false;
                                          _selectedGroupChats.clear();
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey),
                                      child: const Text(
                                        '취소',
                                        style: TextStyle(
                                            color: Colors.white), // 변경됨
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        _deleteSelectedGroupChats();
                                      },
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.pink),
                                      child: const Text(
                                        '삭제',
                                        style: TextStyle(
                                            color: Colors.white), // 변경됨
                                      ),
                                    ),
                                  ],
                                ),
                              )
                          ],
                        );
                      },
                    ),
                    // 1:1 채팅방 섹션
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Text('1:1 채팅방',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                    friends.isEmpty
                        ? const Center(
                            child: Text('친구가 없습니다.',
                                style: TextStyle(color: Colors.white)))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: friends.length,
                            itemBuilder: (context, index) {
                              String friendEmail = friends[index];
                              return FutureBuilder<Map<String, String>>(
                                future: _fetchFriendData(friendEmail),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData)
                                    return const SizedBox(height: 60);
                                  final friendName =
                                      snapshot.data!["friendName"]!;
                                  final lastMsg =
                                      snapshot.data!["lastMessage"]!;
                                  return _isSelectionMode
                                      ? CheckboxListTile(
                                          title: Text(friendName,
                                              style: const TextStyle(
                                                  color: Colors.white)),
                                          subtitle: Text(lastMsg,
                                              style: const TextStyle(
                                                  color: Colors.white70)),
                                          value: _selectedOneToOneChats
                                              .contains(friendEmail),
                                          activeColor: Colors.pink,
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedOneToOneChats
                                                    .add(friendEmail);
                                              } else {
                                                _selectedOneToOneChats
                                                    .remove(friendEmail);
                                              }
                                            });
                                          },
                                        )
                                      : GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      ChatRoomScreen(
                                                          friendEmail:
                                                              friendEmail)),
                                            );
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 15, vertical: 8),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[900],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(friendName,
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 18)),
                                                const SizedBox(height: 4),
                                                Text(
                                                  lastMsg,
                                                  style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 14),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                },
                              );
                            },
                          ),
                    if (_isSelectionMode)
                      Padding(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isSelectionMode = false;
                                  _selectedOneToOneChats.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey),
                              child: const Text(
                                '취소',
                                style: TextStyle(color: Colors.white), // 변경됨
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _deleteSelectedOneToOneChats,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.pink),
                              child: const Text(
                                '삭제',
                                style: TextStyle(color: Colors.white), // 변경됨
                              ),
                            ),
                          ],
                        ),
                      )
                  ],
                ),
              ),
            ),
            // 하단의 빈 공간(SizedBox)을 같은 그라디언트 디자인 Container로 감쌈
            Container(
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black, // 단색 검정색으로 변경
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                '부적절하거나 불쾌감을 줄 수 있는 컨텐츠는 제재를 받을 수 있습니다',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
