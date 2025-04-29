import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CustomNavigationBar extends StatelessWidget {
  const CustomNavigationBar({super.key});

  Widget _buildChatIcon() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('messages')
          .where('read', isEqualTo: false)
          .where('sender', isNotEqualTo: currentUser?.email)
          .snapshots(),
      builder: (context, snapshot) {
        bool showIndicator = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.send, color: Colors.white, size: 28),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color.fromARGB(255, 0, 57, 47),
            const Color.fromARGB(255, 85, 27, 79),
          ],
        ),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 추가: 고정 타입 설정
        backgroundColor: Colors.transparent,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.search, color: Colors.white, size: 28),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people, color: Colors.white, size: 28),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box, color: Colors.white, size: 28),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildChatIcon(),
            label: '',
          ),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushNamed(context, '/search');
          } else if (index == 1) {
            Navigator.pushNamed(context, '/map');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/todo');
          } else if (index == 3) {
            Navigator.pushNamed(context, '/chatauth');
          }
        },
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
    );
  }
}
