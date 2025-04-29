import 'package:flutter/material.dart';
import 'package:plangram/providers/login_provider.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:plangram/screen/profile_screen.dart'; // ProfileScreen 추가 import

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return AppBar(
      title: const Text('Plangram', style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            // 어둡게 변환된 오로라 색상 그라디언트 적용
            colors: [
              const Color.fromARGB(255, 0, 57, 47), // 다크 버전 시작 색상
              const Color.fromARGB(255, 85, 27, 79), // 다크 버전 종료 색상
            ],
          ),
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.person,
          color: const Color.fromRGBO(244, 244, 244, 1)
              .withOpacity(0.7), // 변경된 아이콘 색상
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
      ),
      actions: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("users")
              .doc(currentUser!.uid)
              .collection("friend_requests")
              .snapshots(),
          builder: (context, snapshot) {
            bool showIndicator =
                snapshot.hasData && snapshot.data!.docs.isNotEmpty;
            return IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications,
                    color: const Color.fromRGBO(255, 255, 255, 1)
                        .withOpacity(0.7), // 변경된 아이콘 색상
                  ),
                  if (showIndicator)
                    const Positioned(
                      right: -1,
                      top: -1,
                      child: CircleAvatar(
                        radius: 6,
                        backgroundColor: Colors.red,
                      ),
                    ),
                ],
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/notice');
              },
            );
          },
        ),
      ],
    );
  }
}
