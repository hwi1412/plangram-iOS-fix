import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmailVerificationDialog extends StatefulWidget {
  final User user;
  const EmailVerificationDialog({super.key, required this.user});

  @override
  State<EmailVerificationDialog> createState() =>
      _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<EmailVerificationDialog> {
  bool _isChecking = false;

  Future<void> _checkVerification() async {
    setState(() {
      _isChecking = true;
    });
    await widget.user.reload();
    if (widget.user.emailVerified) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아직 이메일 인증이 완료되지 않았습니다.')),
      );
    }
    setState(() {
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black,
      title: const Text(
        '이메일 인증',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
          '가입하신 이메일로 발송된 인증 메일의 링크를 클릭해주세요.\n스팸 메일함도 확인하세요.\n완료 후 "인증 확인" 버튼을 누르세요.',
          style: TextStyle(color: Colors.white)),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _isChecking ? null : _checkVerification,
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: _isChecking
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('인증 확인'),
        ),
      ],
    );
  }
}
