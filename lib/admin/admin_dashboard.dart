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
    String? suspendReason,
  }) async {
    final prevData = await _getUserStatus(uid);
    DateTime? suspendedUntil;
    Map<String, dynamic> updateData = {'accountStatus': status};
    String actionText = '';
    if (status == 'suspended' && suspendDuration != null) {
      suspendedUntil = DateTime.now().add(suspendDuration);
      updateData['suspendedUntil'] = Timestamp.fromDate(suspendedUntil);
      updateData['suspendReason'] = suspendReason ?? '';
      actionText = '정지 (${suspendDuration.inDays}일)';
    } else if (status == 'banned') {
      updateData['suspendedUntil'] = null;
      updateData['suspendReason'] = null;
      actionText = '영구정지';
    } else if (status == 'warned') {
      updateData['suspendedUntil'] = null;
      updateData['suspendReason'] = null;
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
                'suspendReason': prevData['suspendReason'],
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

  Future<void> _showSuspendDialog(String uid, String email) async {
    final reasonController = TextEditingController();
    bool submitting = false;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('정지 사유 입력'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('정지 사유를 입력하세요. (사용자에게 안내됩니다)'),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '예: 욕설 및 부적절한 언행',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        setModalState(() => submitting = true);
                        await _updateUserStatus(
                          uid: uid,
                          email: email,
                          status: 'suspended',
                          suspendDuration: const Duration(days: 7),
                          suspendReason: reasonController.text.trim(),
                        );
                        Navigator.pop(context);
                      },
                child: const Text('정지'),
              ),
            ],
          );
        });
      },
    );
  }

  // 계정 상태별 유저 목록을 불러오는 함수
  Stream<List<Map<String, dynamic>>> _getUsersByStatus(String status) {
    return FirebaseFirestore.instance
        .collection('users')
        .where('accountStatus', isEqualTo: status)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['uid'] = doc.id;
              return data;
            }).toList());
  }

  // 계정 상태 해제 함수
  Future<void> _releaseAccount(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'accountStatus': 'active',
      'suspendedUntil': null,
      'suspendReason': null,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('계정 상태가 해제되었습니다.')),
    );
    setState(() {});
  }

  Widget _buildAccountStatusSection(String status, String label, Color color) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getUsersByStatus(status),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final users = snapshot.data!;
        if (users.isEmpty) return const SizedBox();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 0, 6),
              child: Text(
                '$label 계정 (${users.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 17,
                ),
              ),
            ),
            ...users.map((user) {
              final until = user['suspendedUntil'];
              String untilStr = '';
              if (until != null && status == 'suspended') {
                if (until is Timestamp) {
                  untilStr = ' ~ ${until.toDate().toLocal()}';
                } else if (until is DateTime) {
                  untilStr = ' ~ ${until.toLocal()}';
                }
              }
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text('${user['email'] ?? ''}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user['suspendReason'] != null &&
                          user['suspendReason'] != '')
                        Text('사유: ${user['suspendReason']}'),
                      if (untilStr.isNotEmpty) Text('정지기간: $untilStr'),
                    ],
                  ),
                  trailing: TextButton(
                    onPressed: () => _releaseAccount(user['uid']),
                    child:
                        const Text('해제', style: TextStyle(color: Colors.pink)),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
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

  Widget _buildAppeals() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appeals')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('해명 요청이 없습니다.', style: TextStyle(color: Colors.grey)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('해명 요청 목록',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text('계정: ${data['email'] ?? ''}'),
                  subtitle: Text(
                      '내용: ${data['message'] ?? ''}\n시각: ${data['timestamp']?.toDate()?.toString() ?? ''}'),
                  trailing: Text(data['status'] ?? '대기',
                      style: const TextStyle(color: Colors.blue)),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildReports() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('신고 관리 대시보드'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          )
        ],
      ),
      body: ListView(
        children: [
          // 해명 요청 목록
          _buildAppeals(),
          // 계정 상태별 분류
          _buildAccountStatusSection('warned', '경고', Colors.orange),
          _buildAccountStatusSection('suspended', '정지', Colors.red),
          _buildAccountStatusSection('banned', '영구정지', Colors.black),
          // 신고 내역
          StreamBuilder<QuerySnapshot>(
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
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, idx) {
                  final data = docs[idx].data() as Map<String, dynamic>;
                  final targetUid = data['targetUid'] ?? '';
                  final targetEmail = data['targetEmail'] ?? '';
                  final reporterEmail = data['reporterEmail'] ?? '';
                  final reason = data['reason'] ?? '';
                  final timestamp =
                      data['timestamp']?.toDate()?.toString() ?? '';
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            onPressed: () =>
                                _showSuspendDialog(targetUid, targetEmail),
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
        ],
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
