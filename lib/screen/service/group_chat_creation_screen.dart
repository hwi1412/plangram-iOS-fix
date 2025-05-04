import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GroupChatCreationScreen extends StatefulWidget {
  const GroupChatCreationScreen({super.key});

  @override
  State<GroupChatCreationScreen> createState() =>
      _GroupChatCreationScreenState();
}

class _GroupChatCreationScreenState extends State<GroupChatCreationScreen> {
  List<String> friends = [];
  List<String> selectedFriends = [];
  final TextEditingController _roomNameController = TextEditingController();

  Future<void> _loadFriends() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    var userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .get();
    setState(() {
      friends = List<String>.from(userDoc.data()?["friends"] ?? []);
    });
  }

  Future<void> _createGroupChat() async {
    if (_roomNameController.text.trim().isEmpty || selectedFriends.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('채팅방 이름과 최소 2명의 친구를 선택하세요.')));
      return;
    }
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      // 그룹 채팅방에 현재 사용자도 포함
      List<String> members = [currentUser.email!, ...selectedFriends];
      // 그룹 채팅방 ID는 자동 생성되도록 add 사용
      await FirebaseFirestore.instance.collection("group_chat_rooms").add({
        'roomName': _roomNameController.text.trim(),
        'members': members,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('단체 채팅방이 생성되었습니다.')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('오류 발생: $e')));
    }
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
        title: const Text('단체 채팅방 생성'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            TextField(
              controller: _roomNameController,
              decoration: const InputDecoration(
                labelText: '채팅방 이름',
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 15),
            const Text('친구 선택 (최소 2명)', style: TextStyle(color: Colors.white)),
            Expanded(
              child: ListView.builder(
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  String friendEmail = friends[index];
                  bool isSelected = selectedFriends.contains(friendEmail);
                  return FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection("users")
                        .where("email", isEqualTo: friendEmail)
                        .limit(1)
                        .get(),
                    builder: (context, snapshot) {
                      return ListTile(
                        title: Builder(
                          builder: (context) {
                            String friendName = friendEmail;
                            if (snapshot.hasData &&
                                snapshot.data!.docs.isNotEmpty) {
                              friendName = (snapshot.data!.docs.first.data()
                                      as Map<String, dynamic>)["name"] ??
                                  friendEmail;
                            }
                            return Text(friendName,
                                style: const TextStyle(color: Colors.white));
                          },
                        ),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                selectedFriends.add(friendEmail);
                              } else {
                                selectedFriends.remove(friendEmail);
                              }
                            });
                          },
                          activeColor: Colors.pink,
                          checkColor: Colors.white,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: _createGroupChat,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
                  child: const Text('확인'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
