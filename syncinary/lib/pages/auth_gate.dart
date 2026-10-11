import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/group_service.dart';
import 'groups/my_groups_page.dart';
import 'login_page.dart';
import 'verify_email_page.dart';

/// Routes according to the current session and email verification state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.auth, this.groupService});

  final FirebaseAuth? auth;
  final GroupService? groupService;

  @override
  Widget build(BuildContext context) {
    final session = auth ?? FirebaseAuth.instance;
    return StreamBuilder<User?>(
      stream: session.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return snapshot.data!.emailVerified
              ? MyGroupsPage(service: groupService)
              : VerifyEmailPage(auth: session, groupService: groupService);
        }
        return LoginPage(auth: session, groupService: groupService);
      },
    );
  }
}
