import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key});

  Future<void> _acceptRequest(String senderUid, String senderEmail) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // 서로의 friends 배열에 추가
    var currentUserRef =
        FirebaseFirestore.instance.collection("users").doc(currentUser.uid);
    var senderRef =
        FirebaseFirestore.instance.collection("users").doc(senderUid);

    await currentUserRef.update({
      "friends": FieldValue.arrayUnion([senderEmail]),
    });
    // sender의 friends 배열에도 추가 (요청 시 수신자 이메일은 senderEmail)
    await senderRef.update({
      "friends": FieldValue.arrayUnion([currentUser.email]),
    });
    // 요청 삭제
    await currentUserRef.collection("friend_requests").doc(senderUid).delete();
  }

  Future<void> _declineRequest(String senderUid) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .collection("friend_requests")
        .doc(senderUid)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null)
      return const Scaffold(
        body: Center(
            child: Text('로그인 필요', style: TextStyle(color: Colors.white))),
        backgroundColor: Colors.black,
      );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(1.0), // 반투명 검정색 적용
        title: const Text('알림', style: TextStyle(color: Colors.white)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color.fromARGB(255, 0, 0, 0),
              Color.fromARGB(255, 0, 0, 0),
            ],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("users")
              .doc(currentUser.uid)
              .collection("friend_requests")
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            var docs = snapshot.data!.docs;
            if (docs.isEmpty)
              return const Center(
                  child:
                      Text('알림이 없습니다.', style: TextStyle(color: Colors.white)));

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                var data = docs[index].data() as Map<String, dynamic>;
                // 요청 보낸 사용자의 uid는 요청 문서의 id
                String senderUid = docs[index].id;
                String senderEmail = data['senderEmail'] ?? '';
                String senderName = data['senderName'] ?? '';
                return ListTile(
                  title: Text('$senderEmail ($senderName)님 께서 친구 요청을 보냈습니다.',
                      style: const TextStyle(color: Colors.white)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _declineRequest(senderUid),
                        child: const Text('거절',
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _acceptRequest(senderUid, senderEmail),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        child: const Text('수락'),
                      ),
                    ],
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
