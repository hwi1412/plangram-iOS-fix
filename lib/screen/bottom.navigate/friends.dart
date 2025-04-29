import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../chat_room.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<dynamic> friends = [];

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
        backgroundColor: Colors.black,
        title: const Text('친구 목록', style: TextStyle(color: Colors.white)),
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
        child: friends.isEmpty
            ? const Center(
                child:
                    Text('친구를 추가하세요.', style: TextStyle(color: Colors.white)))
            : ListView.builder(
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  String friendEmail = friends[index];
                  return FutureBuilder<Map<String, String>>(
                    future: _getFriendInfo(friendEmail),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox(height: 60);
                      final friendName = snapshot.data!["name"]!;
                      return ListTile(
                        title: Text(
                          friendName,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                        subtitle: Text(
                          friendEmail,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.chat, color: Colors.white),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ChatRoomScreen(friendEmail: friendEmail)),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
