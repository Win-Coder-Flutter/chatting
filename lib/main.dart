import 'package:chatting/providers/auth_provider.dart';
import 'package:chatting/screens/auth_screen.dart';
import 'package:chatting/screens/login_screen.dart';
import 'package:chatting/screens/user_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: "K & A Chat",
            home: auth.user == null
                ? AuthScreen()
                : UserListScreen(currentUserId: auth.user!.uid),
          );
        },
      ),
    );
  }
}
