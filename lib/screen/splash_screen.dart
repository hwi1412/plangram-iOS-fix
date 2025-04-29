import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../providers/login_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    await Future.delayed(Duration(seconds: 0));
    //Provider.of<LoginProvider>(context, listen: false).currentUser();
    context.read<LoginProvider>().currentUser();
    User? user = context.read<LoginProvider>().user;
    if (user != null) {
      Navigator.pushReplacementNamed(context, '/success');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: FlutterLogo(
        size: 100,
      ),
    ));
  }
}
