// lib/providers/login_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginProvider with ChangeNotifier {
  User? _user;
  String? _errorMessage;

  /// friends 필드에는 친구들의 이메일 주소 리스트가 저장되어 있습니다.
  List<String> _friends = [];

  // getters
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  List<String> get friends => _friends;

  // setters
  void setUser(User? newUser) {
    _user = newUser;
    notifyListeners();
  }

  //===== Authentication =====//
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      _user = cred.user;
      _errorMessage = null;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      // (기존 에러 처리 코드 유지)
      _errorMessage = '로그인에 실패했습니다. (${e.code})';
      notifyListeners();
    } catch (e) {
      _errorMessage = '알 수 없는 오류가 발생했습니다.';
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    _user = null;
    notifyListeners();
  }

  void currentUser() {
    _user = FirebaseAuth.instance.currentUser;
    notifyListeners();
  }

  //===== friends =====//
  /// users/{uid} 문서의 'friends' 필드(이메일 리스트) 불러오기
  Future<void> fetchFriends() async {
    if (_user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .get();
    final data = doc.data();
    final List<dynamic> raw = data?['friends'] ?? [];
    _friends = raw.cast<String>();
    notifyListeners();
  }

  /// 이메일로 친구 추가 (원래 구현 유지)
  Future<void> addFriendByEmail(String friendEmail) async {
    if (_user == null) return;
    final firestore = FirebaseFirestore.instance;
    final query = await firestore
        .collection('users')
        .where('email', isEqualTo: friendEmail)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      throw Exception('해당 이메일의 사용자를 찾을 수 없습니다.');
    }
    final friendUid = query.docs.first.id;
    await firestore.collection('users').doc(_user!.uid).update({
      'friends': FieldValue.arrayUnion([friendEmail])
    });
    await fetchFriends();
  }

  /// 친구 삭제 (원래 구현 유지)
  Future<void> removeFriend(String friendEmail) async {
    if (_user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .update({
      'friends': FieldValue.arrayRemove([friendEmail])
    });
    await fetchFriends();
  }

  /// 친구 목록을 가져오는 메소드 (원래 구현 유지)
  Future<List<String>> getFriends() async {
    if (_user == null) return [];
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .get();
    final data = doc.data();
    final List<dynamic> raw = data?['friends'] ?? [];
    return raw.cast<String>();
  }
}
