// ignore_for_file: camel_case_types

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:plangram/screen/bottom.navigate/map.dart';
import 'package:plangram/screen/bottom.navigate/todo.dart';
import 'screen/login_screen.dart';
import 'screen/signup_screen.dart';
import 'screen/success_screen.dart';

import 'screen/service/chatauth_screen.dart';
import 'screen/bottom.navigate/search.dart'; // search.dart 파일 import 추가
import 'screen/bottom.navigate/friends.dart';
import 'screen/bottom.navigate/notice.dart';
import 'package:provider/provider.dart';
import 'providers/login_provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 추가된 import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    // Firebase 인증 Persistence를 로컬로 설정 (앱 종료 후에도 로그인 상태 유지)
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    print("Firebase 초기화 완료");
  } catch (e, stack) {
    print("Firebase 초기화 실패: $e");
    print("스택 트레이스: $stack");
  }
  // currentUser가 null이면 '/login', 아니면 '/success'를 반환
  final initialRoute =
      FirebaseAuth.instance.currentUser != null ? '/success' : '/login';
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginProvider()),
      ],
      child: plangram(initialRoute: initialRoute), // 수정됨
    ),
  );
}

// Flutter 프레임워크 내부 오류(예: debugAdoptSize 관련)는 사용자가 직접 고칠 수 없습니다.
// flutter upgrade 또는 flutter downgrade로 버전을 변경하거나,
// flutter/packages/flutter/lib/src/rendering/box.dart, animated_size.dart 등에서
// debugAdoptSize 관련 코드를 주석 처리/삭제해야 정상 빌드가 가능합니다.
// (이 코드는 앱 소스가 아니라 Flutter 엔진 소스입니다.)

class plangram extends StatelessWidget {
  final String initialRoute; // 추가된 필드
  const plangram({super.key, required this.initialRoute}); // 수정된 생성자

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // debug 배너 숨김 처리
      initialRoute: initialRoute, // 수정됨
      routes: {
        // '/splash': (context) => SplashScreen(), // SplashScreen 라우트 제거
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignUpScreen(),
        '/success': (context) => SuccessScreen(),
        '/chatauth': (context) => ChatAuthScreen(), // ChatAuthScreen으로의 라우트 정의
        '/search': (context) => SearchScreen(), // SearchScreen으로의 라우트 정의
        '/map': (context) => MapScreen(),
        '/notice': (context) => NoticeScreen(),
        '/todo': (context) => const TodoScreen(), // 추가된 라우트
      },
    );
  }
}
