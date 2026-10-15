import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/groups/my_groups_page.dart';
import '../pages/login_page.dart';
import '../pages/verify_email_page.dart';
import '../services/group_service.dart';

/// Routes to login, email verification, or groups based on auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.auth, this.groupService});

  final FirebaseAuth? auth;
  final GroupService? groupService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: (auth ?? FirebaseAuth.instance).authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return snapshot.data!.emailVerified
              ? MyGroupsPage(service: groupService)
              : VerifyEmailPage(auth: auth, groupService: groupService);
        }

        return LoginPage(auth: auth, groupService: groupService);
      },
    );
  }
}
