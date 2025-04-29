import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginProvider with ChangeNotifier {
  User? _user;
  String? _errorMessage;
  List<dynamic> _friends = []; // 친구 리스트 추가, 타입 변경

  User? get user => _user;
  String? get errorMessage => _errorMessage;
  List<dynamic> get friends => _friends; // friends getter

  set friends(List<dynamic> value) {
    _friends = value;
    notifyListeners();
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = credential.user;
      _errorMessage = null; // 로그인 성공 시 오류 메시지 초기화
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      // 디버깅용 로그 출력 추가
      print(
          "FirebaseAuthException caught: code=${e.code}, message=${e.message}");
      switch (e.code) {
        case 'user-not-found':
          _errorMessage = '존재하지 않는 계정입니다.';
          break;
        case 'wrong-password':
          _errorMessage = '잘못된 비밀번호입니다.';
          break;
        case 'invalid-email':
          _errorMessage = '올바른 이메일 형식을 입력해주세요.';
          break;
        case 'user-disabled':
          _errorMessage = '이 계정은 비활성화되었습니다.';
          break;
        case 'too-many-requests':
          _errorMessage = '너무 많은 로그인 시도로 인해 잠시 후 다시 시도해주세요.';
          break;
        case 'operation-not-allowed':
          _errorMessage = '이메일/비밀번호 로그인 기능이 비활성화되었습니다.';
          break;
        case 'invalid-credential':
          _errorMessage = '잘못된 인증 정보입니다. 다시 시도해주세요.';
          break;
        default:
          _errorMessage = '로그인에 실패했습니다. 다시 시도해주세요.';
          break;
      }
      notifyListeners();
    } catch (e, stack) {
      // 에러와 스택 트레이스 출력 추가
      print("로그인 처리 중 알 수 없는 오류 발생: $e");
      print("스택 트레이스: $stack");
      _errorMessage = '알 수 없는 오류가 발생했습니다. 다시 시도해주세요.';
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut(); //
    _user = null;
    notifyListeners();
  }

  void currentUser() {
    _user = FirebaseAuth.instance.currentUser;
    notifyListeners();
  }

  Future<void> fetchFriends() async {
    if (_user == null) return;
    final uid = _user!.uid;
    final firestore = FirebaseFirestore.instance;
    final friendsSnapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .get();

    List<dynamic> loadedFriends = [];
    for (var doc in friendsSnapshot.docs) {
      final friendUid = doc.id;
      // Firestore에서 친구의 정보를 가져와 User 객체로 변환 (간단 예시)
      final friendDoc =
          await firestore.collection('users').doc(friendUid).get();
      final data = friendDoc.data();
      if (data != null && data['email'] != null) {
        loadedFriends.add({
          'displayName': data['name'] ?? '친구',
          'photoURL': data['profileUrl'],
        });
      }
    }
    _friends = loadedFriends;
    notifyListeners();
  }

  Future<void> addFriendByEmail(String friendEmail) async {
    if (_user == null) return;
    final firestore = FirebaseFirestore.instance;
    // 이메일로 친구 uid 찾기
    final query = await firestore
        .collection('users')
        .where('email', isEqualTo: friendEmail)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      throw Exception('해당 이메일의 사용자를 찾을 수 없습니다.');
    }
    final friendUid = query.docs.first.id;
    // 내 friends 서브컬렉션에 친구 uid 추가
    await firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('friends')
        .doc(friendUid)
        .set({'addedAt': FieldValue.serverTimestamp()});
    await fetchFriends();
  }
}
