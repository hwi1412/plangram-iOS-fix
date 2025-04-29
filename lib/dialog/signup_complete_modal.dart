import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignUpCompleteModal extends StatefulWidget {
  final User user;
  const SignUpCompleteModal({super.key, required this.user});

  @override
  State<SignUpCompleteModal> createState() => _SignUpCompleteModalState();
}

class _SignUpCompleteModalState extends State<SignUpCompleteModal> {
  bool _isResending = false;

  Future<void> _resendVerification() async {
    setState(() {
      _isResending = true;
    });
    await widget.user.sendEmailVerification();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('인증 메일을 재전송하였습니다.')),
    );
    setState(() {
      _isResending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('이메일 인증 필요'),
      content: const Text('이 계정은 아직 이메일 인증이 완료되지 않았습니다.\n인증 메일을 재전송하시겠습니까?'),
      actions: [
        TextButton(
          onPressed: _isResending ? null : _resendVerification,
          child: _isResending
              ? const CircularProgressIndicator()
              : const Text('재전송'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('닫기'),
        ),
      ],
    );
  }
}
