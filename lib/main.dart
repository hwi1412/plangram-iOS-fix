// ignore_for_file: camel_case_types

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // FlutterFire CLI로 생성된 옵션 파일 import
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
import 'package:flutter/foundation.dart';
import 'admin/admin_dashboard.dart'; // 추가

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginProvider()),
      ],
      child: const PlangramApp(),
    ),
  );
}

class PlangramApp extends StatelessWidget {
  const PlangramApp({super.key});

  @override
  Widget build(BuildContext context) {
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    // 앱 시작 시 currentUser() 호출로 friends 정보 항상 유지
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loginProvider.currentUser();
    });

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snapshot.data;
          if (user == null) {
            return LoginScreen();
          }
          final email = user.email?.toLowerCase();
          if (email == 'admin@plangram.com') {
            return const AdminDashboard();
          }
          return const SuccessScreen();
        },
      ),
      routes: {
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignUpScreen(),
        '/success': (context) => SuccessScreen(),
        '/chatauth': (context) => ChatAuthScreen(),
        '/search': (context) => SearchScreen(),
        '/map': (context) => MapScreen(),
        '/notice': (context) => NoticeScreen(),
        '/todo': (context) => const TodoScreen(),
        '/admin': (context) {
          final user = FirebaseAuth.instance.currentUser;
          final email = user?.email?.toLowerCase();
          if (email == 'admin@plangram.com') {
            return const AdminDashboard();
          }
          // 관리자가 아니면 캘린더(성공)로 강제 이동
          return const SuccessScreen();
        },
      },
    );
  }
}
