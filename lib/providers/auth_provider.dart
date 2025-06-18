import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  AuthProvider() {
    _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  User? get user => _user;

  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await saveUserToFirestore(_auth.currentUser!);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveUserToFirestore(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({'uid': user.uid, 'email': user.email});
    }
  }

  Future<void> logout() async => await _auth.signOut();
}
