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

      final prefs = await SharedPreferences.getInstance();
      // Save both studentId and id
      await prefs.setString('studentId', _user!.studentId);
      await prefs.setInt('id', int.parse(_user!.id));
      
      // Corrected line to print the ID
      // Retrieve the ID first, then print it
      final storedId = prefs.getInt('id');
      print("USER ID is: $storedId");

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

  Future<bool> updateStudentProfile(User updatedUser) async {
    final url = Uri.parse('${AppConstants.baseUrl}/api/students/${updatedUser.id}');

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updatedUser.toJson()),
      );

      if (response.statusCode == 200) {
        _user = updatedUser;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to update profile';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
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

        final prefs = await SharedPreferences.getInstance();
        // Save both studentId and id
        await prefs.setString('studentId', _user!.studentId);
        await prefs.setInt('id', _user!.id as int); // Assuming 'id' is an integer

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

  Future<void> logout() async {
    _user = null;

    final prefs = await SharedPreferences.getInstance();
    // Remove both studentId and id on logout
    await prefs.remove('studentId');
    await prefs.remove('id');

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Helper method to retrieve student ID from shared prefs
  Future<String?> getStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('studentId');
  }

  /// Helper method to retrieve user ID from shared prefs
  Future<int?> getId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('id');
  }
}