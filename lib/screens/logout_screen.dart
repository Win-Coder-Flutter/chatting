import 'package:chatting/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LogoutScreen extends StatelessWidget {
  const LogoutScreen({super.key});

  void _confirmLogout(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Logout")),
      body: Center(
        child: AlertDialog(
          title: const Text("Confirm Logout"),
          content: const Text("Are you sure you want to log out?"),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Logout"),
              onPressed: () => _confirmLogout(context),
            ),
          ],
        ),
      ),
    );
  }
}
