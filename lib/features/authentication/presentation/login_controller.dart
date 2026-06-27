import 'package:flutter/material.dart';

import '../data/auth_repository.dart';

class LoginController extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  Future<bool> login() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final success = await _repository.login(
      username: usernameController.text.trim(),
      password: passwordController.text,
    );

    if (!success) {
      errorMessage = "Invalid username or password.";
    }

    isLoading = false;
    notifyListeners();

    return success;
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}