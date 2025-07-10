import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../utils/constants.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final uri = Uri.parse('${AppConstants.baseUrl}${AppConstants.loginEndpoint}');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        _user = User.fromJson(responseData);

        // ✅ Store the student ID in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('studentId', _user!.id.toString());

        _isLoading = false;
        notifyListeners();
        return true;
      } else if (response.statusCode == 401) {
        _error = 'Invalid credentials. Please check your email and password.';
      } else {
        _error = 'Login failed: ${response.body}';
      }
    } catch (e) {
      _error = 'An error occurred during login: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register(Map<String, dynamic> userData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final uri = Uri.parse('${AppConstants.baseUrl}${AppConstants.registerEndpoint}');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        _user = User.fromJson(responseData);

        // ✅ Store the student ID after registration
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('studentId', _user!.id.toString());

        _isLoading = false;
        notifyListeners();
        return true;
      } else if (response.statusCode == 409) {
        _error = 'Registration failed: Email already registered.';
      } else {
        _error = 'Registration failed: ${response.body}';
      }
    } catch (e) {
      _error = 'An error occurred during registration: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  void logout() async {
    _user = null;

    // ✅ Clear student ID from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('studentId');

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// ✅ Helper method to retrieve student ID
  Future<String?> getStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('studentId');
  }
}
