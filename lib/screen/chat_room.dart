import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatRoomScreen extends StatefulWidget {
  final String friendEmail;
  const ChatRoomScreen({super.key, required this.friendEmail});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _msgController = TextEditingController();
  late String chatRoomId;
  late String currentUserEmail;

  @override
  void initState() {
    super.initState();
    currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    List<String> users = [currentUserEmail, widget.friendEmail];
    users.sort();
    chatRoomId = users.join('_');
  }

  Future<String> _fetchFriendName() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection("users")
        .where("email", isEqualTo: widget.friendEmail)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.data()["name"] ?? widget.friendEmail;
    }
    return widget.friendEmail;
  }

  Future<void> _sendMessage() async {
    String msg = _msgController.text.trim();
    if (msg.isEmpty) return;
    await FirebaseFirestore.instance
        .collection("chat_rooms")
        .doc(chatRoomId)
        .collection("messages")
        .add({
      "sender": currentUserEmail,
      "message": msg,
      "timestamp": FieldValue.serverTimestamp(),
      "read": false,
    });
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 배경색 검정
      appBar: AppBar(
        backgroundColor: Colors.black, // 앱바 검정
        title: FutureBuilder<String>(
          future: _fetchFriendName(), // 친구의 이름 불러오기
          builder: (context, snapshot) {
            String title = snapshot.hasData
                ? "${snapshot.data}와 채팅"
                : "${widget.friendEmail}와 채팅";
            return Text(title, style: const TextStyle(color: Colors.white));
          },
        ),
      ),
      body: Container(
        color: Colors.black, // 본문 배경 검정
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("chat_rooms")
                    .doc(chatRoomId)
                    .collection("messages")
                    .orderBy("timestamp", descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  var docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      bool isMe = data['sender'] == currentUserEmail;
                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(11),
                          margin: const EdgeInsets.symmetric(
                              vertical: 2, horizontal: 8),
                          color: isMe ? Colors.blueAccent : Colors.grey,
                          child: Text(
                            data['message'],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(
                        hintText: '메시지 입력',
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        border: InputBorder.none,
                        filled: true,
                        fillColor: Colors.black, // 입력 필드 배경 검정
                        hintStyle: TextStyle(color: Colors.white60),
                      ),
                      style: const TextStyle(color: Colors.white), // 텍스트 흰색
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.send, color: Colors.white), // 전송버튼 흰색
                    onPressed: _sendMessage,
                  )
                ],
              ),
            ),
            const SizedBox(height: 10), // 추가된 10px 여백
          ],
        ),
      ),
    );
  }
}
