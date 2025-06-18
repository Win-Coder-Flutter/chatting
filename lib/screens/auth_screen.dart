import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();
  String? loginError;
  String? signupError;

  void login() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.login(emailCtrl.text.trim(), passwordCtrl.text);
    } catch (e) {
      setState(() => loginError = e.toString());
    }
  }

  void signUp() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (passwordCtrl.text != confirmPasswordCtrl.text) {
      setState(() => signupError = "Passwords do not match");
      return;
    }
    try {
      await auth.signUp(emailCtrl.text.trim(), passwordCtrl.text);
    } catch (e) {
      setState(() => signupError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 400,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    labelColor: Colors.indigo,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.indigo,
                    labelStyle: TextStyle(fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: 'Login'),
                      Tab(text: 'Sign Up'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 500,
                    child: TabBarView(
                      children: [_buildLoginForm(), _buildSignUpForm()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text(
          'Welcome Back 👋',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 24),
        if (loginError != null)
          Text(loginError!, style: TextStyle(color: Colors.red)),
        _buildTextField(
          controller: emailCtrl,
          label: 'Email',
          hint: 'Enter your email',
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: passwordCtrl,
          label: 'Password',
          hint: 'Enter your password',
          obscure: true,
        ),
        SizedBox(height: 70),
        _buildButton('Login', onPressed: login),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text(
          'Create Your Account',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 24),
        if (signupError != null)
          Text(signupError!, style: TextStyle(color: Colors.red)),
        _buildTextField(
          controller: emailCtrl,
          label: 'Email',
          hint: 'Enter your email',
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: passwordCtrl,
          label: 'Password',
          hint: 'Create a password',
          obscure: true,
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: confirmPasswordCtrl,
          label: 'Confirm Password',
          hint: 'Confirm password',
          obscure: true,
        ),
        SizedBox(height: 24),
        _buildButton('Sign Up', onPressed: signUp),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      ),
    );
  }

  Widget _buildButton(String text, {required VoidCallback onPressed}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.indigo,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Text(text, style: TextStyle(fontSize: 16, color: Colors.white)),
    );
  }
}
