import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GroupChatSearchScreen extends StatefulWidget {
  const GroupChatSearchScreen({super.key});

  @override
  State<GroupChatSearchScreen> createState() => _GroupChatSearchScreenState();
}

class _GroupChatSearchScreenState extends State<GroupChatSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> results = [];

  Future<void> _search() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) return;

    var snapshot = await FirebaseFirestore.instance
        .collection("group_chat_rooms")
        .where("roomName", isEqualTo: query)
        .get();
    setState(() {
      results = snapshot.docs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('단체 채팅방 검색'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: '채팅방 이름 또는 구성원 검색',
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _search,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
              child: const Text('검색'),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Text('검색 결과가 없습니다.',
                          style: TextStyle(color: Colors.white)))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final data =
                            results[index].data() as Map<String, dynamic>;
                        return ListTile(
                          title: Text(data['roomName'] ?? '',
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                              "구성원: ${(data['members'] as List<dynamic>).join(', ')}",
                              style: const TextStyle(color: Colors.white70)),
                          onTap: () {
                            // 단체 채팅방으로 이동하는 로직 추가 가능
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
