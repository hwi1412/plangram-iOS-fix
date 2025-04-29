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
    final initialRoute =
        FirebaseAuth.instance.currentUser != null ? '/success' : '/login';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignUpScreen(),
        '/success': (context) => SuccessScreen(),
        '/chatauth': (context) => ChatAuthScreen(),
        '/search': (context) => SearchScreen(),
        '/map': (context) => MapScreen(),
        '/notice': (context) => NoticeScreen(),
        '/todo': (context) => const TodoScreen(),
      },
    );
  }
}
