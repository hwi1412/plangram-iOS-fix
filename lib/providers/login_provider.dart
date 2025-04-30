// lib/providers/login_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginProvider with ChangeNotifier {
  User? _user;
  String? _errorMessage;

  /// users/{uid} 문서의 friends 필드:
  ///   ["friend1@email.com", "friend2@email.com", ...]
  List<String> _friends = [];

  // ── getters ──
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  List<String> get friends => _friends;

  // ── authentication ──
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      _user = cred.user;
      _errorMessage = null;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _errorMessage = '로그인 실패: ${e.code}';
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

  // ── friends ──
  /// users/{uid}.friends(이메일 배열)을 로컬에 저장
  Future<void> fetchFriends() async {
    if (_user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .get();
    _friends = List<String>.from(doc.data()?['friends'] ?? []);
    notifyListeners();
  }

  /// 이메일을 friends 필드에 추가
  Future<void> addFriendByEmail(String friendEmail) async {
    if (_user == null) return;
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('users').doc(_user!.uid).update({
      'friends': FieldValue.arrayUnion([friendEmail])
    });
    await fetchFriends();
  }

  /// 이메일을 friends 필드에서 삭제
  Future<void> removeFriendByEmail(String friendEmail) async {
    if (_user == null) return;
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('users').doc(_user!.uid).update({
      'friends': FieldValue.arrayRemove([friendEmail])
    });
    await fetchFriends();
  }

  /// 친구 이메일 리스트를 가져옴
  Future<List<String>> getFriends() async {
    if (_user == null) return [];
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .get();
    return List<String>.from(doc.data()?['friends'] ?? []);
  }
}
