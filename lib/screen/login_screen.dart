import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/login_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../dialog/signup_complete_modal.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false; // 로그인 진행 중 여부

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Provider.of<LoginProvider>(context, listen: false)
          .signInWithEmailAndPassword(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      final loginProvider = Provider.of<LoginProvider>(context, listen: false);
      if (loginProvider.user != null) {
        // 디버깅: 로그인 후 토큰 claims 출력
        final idToken = await loginProvider.user!.getIdTokenResult(true);
        print(
            'Custom claims for ${loginProvider.user!.email}: ${idToken.claims}');
        Navigator.pushNamed(context, '/success');
      } else {
        _showErrorMessage(loginProvider.errorMessage ?? '로그인 실패');
      }
    } on FirebaseAuthException catch (e, stack) {
      print("LoginScreen catch - 오류: $e");
      print("LoginScreen catch - 스택 트레이스: $stack");
      _showErrorMessage(
          '로그인 중 오류가 발생했습니다. 다시 시도해주세요.\n${e.code}: ${e.message}');
    } catch (e, stack) {
      print("LoginScreen catch - 오류: $e");
      print("LoginScreen catch - 스택 트레이스: $stack");
      _showErrorMessage('로그인 중 오류가 발생했습니다. 다시 시도해주세요.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // 밝은 오로라 색상 그라디언트 적용
            colors: [
              const Color.fromARGB(255, 1, 80, 65), // 원본 시작 색상
              const Color.fromARGB(255, 143, 37, 133), // 원본 종료 색상
            ],
          ),
        ),
        padding: EdgeInsets.all(70),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SizedBox(height: 120), // Plangram 텍스트 위에 공간 추가
              Text(
                'Plangram',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 38,
                  color: const Color.fromARGB(255, 231, 231, 231),
                ),
              ),
              SizedBox(height: 70), // 입력 필드 위에 공간 추가
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(
                      color: const Color.fromARGB(
                          255, 255, 64, 129)), // 라벨 색상을 진한 핑크색으로 설정
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: Colors.pinkAccent), // 필드 선 색상을 진한 핑크색으로 설정
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: Colors.pinkAccent), // 필드 선 색상을 진한 핑크색으로 설정
                  ),
                  floatingLabelBehavior:
                      FloatingLabelBehavior.never, // 라벨이 축소되지 않고 크기를 유지하도록 설정
                ),
                style: TextStyle(color: Colors.white), // 텍스트 색상을 흰색으로 설정
                cursorColor: Colors.pinkAccent, // 타이핑 전 깜빡거리는 선 색상을 진한 핑크색으로 설정
                validator: (value) {
                  if (value!.isEmpty) {
                    return '이메일을 입력해주세요.';
                  }
                  return null;
                },
              ),
              SizedBox(height: 0), // 이메일 필드와 비밀번호 필드 사이의 간격 추가
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle:
                      TextStyle(color: Colors.pinkAccent), // 라벨 색상을 진한 핑크색으로 설정
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: Colors.pinkAccent), // 필드 선 색상을 진한 핑크색으로 설정
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: Colors.pinkAccent), // 필드 선 색상을 진한 핑크색으로 설정
                  ),
                  floatingLabelBehavior:
                      FloatingLabelBehavior.never, // 라벨이 축소되지 않고 크기를 유지하도록 설정
                ),
                obscureText: true,
                style: TextStyle(color: Colors.white), // 텍스트 색상을 흰색으로 설정
                cursorColor: Colors.pinkAccent, // 타이핑 전 깜빡거리는 선 색상을 진한 핑크색으로 설정
                validator: (value) {
                  if (value!.isEmpty) {
                    return '비밀번호를 입력해주세요.';
                  }
                  return null;
                },
              ),
              SizedBox(height: 50), // 입력 필드와 버튼 사이의 간격 추가
              TextButton(
                onPressed: _login,
                child: Text('Login',
                    style: TextStyle(
                        color: Colors.pinkAccent)), // 텍스트 색상을 진한 핑크색으로 설정
              ),
              SizedBox(height: 0), // 버튼 간의 간격 추가
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/signup');
                },
                child: Text('SignUp',
                    style: TextStyle(
                        color: Colors.pinkAccent)), // 텍스트 색상을 진한 핑크색으로 설정
              )
            ],
          ),
        ),
      ),
    );
  }
}
