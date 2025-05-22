import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  String? _error;

  // 관리자 이메일만 허용
  static const String adminEmail = 'admin@plangram.com';

  Future<void> _login() async {
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _pwController.text.trim(),
      );
      setState(() {
        _error = null;
      });
      // 로그인 성공 시 반드시 네임드 라우트로 이동 (main.dart에서 email 체크)
      Navigator.of(context).pushReplacementNamed('/admin');
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    }
  }

  Future<void> _sendEmailNotification({
    required String toEmail,
    required String action,
    String? until,
  }) async {
    // 실제 운영에서는 Cloud Functions HTTPS Callable 등으로 위임
    // 여기서는 Firestore에 notifications 컬렉션에 기록하는 예시
    await FirebaseFirestore.instance.collection('notifications').add({
      'to': toEmail,
      'action': action,
      'until': until,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> _getUserStatus(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<void> _updateUserStatus({
    required String uid,
    required String email,
    required String status,
    Duration? suspendDuration,
  }) async {
    final prevData = await _getUserStatus(uid);
    DateTime? suspendedUntil;
    Map<String, dynamic> updateData = {'accountStatus': status};
    String actionText = '';
    if (status == 'suspended' && suspendDuration != null) {
      suspendedUntil = DateTime.now().add(suspendDuration);
      updateData['suspendedUntil'] = Timestamp.fromDate(suspendedUntil);
      actionText = '정지 (${suspendDuration.inDays}일)';
    } else if (status == 'banned') {
      updateData['suspendedUntil'] = null;
      actionText = '영구정지';
    } else if (status == 'warned') {
      updateData['suspendedUntil'] = null;
      actionText = '경고';
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update(updateData);

    await _sendEmailNotification(
      toEmail: email,
      action: actionText,
      until: suspendedUntil?.toString(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('[$actionText] 조치가 적용되었습니다.'),
        action: SnackBarAction(
          label: '취소(Undo)',
          onPressed: () async {
            if (prevData != null) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({
                'accountStatus': prevData['accountStatus'] ?? 'active',
                'suspendedUntil': prevData['suspendedUntil'],
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('조치가 취소되었습니다.')),
              );
            }
          },
        ),
        duration: const Duration(seconds: 6),
      ),
    );
    setState(() {}); // 새로고침
  }

  Widget _buildLogin() {
    return Center(
      child: SizedBox(
        width: 320,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('관리자 로그인', style: TextStyle(fontSize: 20)),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: '이메일'),
                ),
                TextField(
                  controller: _pwController,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                  obscureText: true,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _login,
                  child: const Text('로그인'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReports() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('신고 관리 대시보드'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              setState(() {});
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('신고 내역이 없습니다.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, idx) {
              final data = docs[idx].data() as Map<String, dynamic>;
              final targetUid = data['targetUid'] ?? '';
              final targetEmail = data['targetEmail'] ?? '';
              final reporterEmail = data['reporterEmail'] ?? '';
              final reason = data['reason'] ?? '';
              final timestamp = data['timestamp']?.toDate()?.toString() ?? '';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('신고 대상: $targetEmail'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('신고자: $reporterEmail'),
                      Text('사유: $reason'),
                      Text('시각: $timestamp'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange),
                        onPressed: () => _updateUserStatus(
                          uid: targetUid,
                          email: targetEmail,
                          status: 'warned',
                        ),
                        child: const Text('경고',
                            style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () => _updateUserStatus(
                          uid: targetUid,
                          email: targetEmail,
                          status: 'suspended',
                          suspendDuration: const Duration(days: 7), // 7일 정지 예시
                        ),
                        child: const Text('정지',
                            style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black),
                        onPressed: () => _updateUserStatus(
                          uid: targetUid,
                          email: targetEmail,
                          status: 'banned',
                        ),
                        child: const Text('영구정지',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.toLowerCase();

    if (user == null) {
      return _buildLogin();
    }
    if (email != adminEmail) {
      // 관리자 외에는 접근 불가
      return Scaffold(
        body: Center(
          child: Text(
            '관리자 권한이 없습니다.',
            style: const TextStyle(color: Colors.red, fontSize: 18),
          ),
        ),
      );
    }
    return _buildReports();
  }
}
