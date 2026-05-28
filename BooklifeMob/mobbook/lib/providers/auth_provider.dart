import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import 'dart:convert';

class AuthProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final ApiService _apiService;
  
  User? _user;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._prefs, this._apiService) {
    _loadUser();
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isBuyer => _user?.role == 'buyer';

  void _loadUser() {
    final userJson = _prefs.getString('user_data');
    if (userJson != null && userJson.isNotEmpty) {
      try {
        String cleanJson = userJson.trim();
        if (cleanJson.startsWith('{') && cleanJson.endsWith('}')) {
          final Map<String, dynamic> data = json.decode(cleanJson);
          _user = User.fromJson(data);
        } else {
          print('Invalid JSON format: $cleanJson');
          _user = null;
        }
      } catch (e) {
        print('Error loading user: $e');
        print('Raw data: $userJson');
        _user = null;
      }
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.login(email, password);
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        // Save session
        final cookies = response.headers['set-cookie'];
        if (cookies != null && cookies.isNotEmpty) {
          final sessionMatch = RegExp(r'sessionid=([^;]+)').firstMatch(cookies.join(';'));
          if (sessionMatch != null) {
            await _prefs.setString('sessionid', sessionMatch.group(1)!);
          }
        }
        
        // Save user data
        if (data['user'] != null) {
          _user = User.fromJson(data['user']);
          // Сохраняем как JSON строку
          final userJson = json.encode(data['user']);
          await _prefs.setString('user_data', userJson);
          print('User saved successfully: $userJson');
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = response.data['error'] ?? 'Ошибка входа';
      _isLoading = false;
      notifyListeners();
      return false;
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
      final response = await _apiService.register(userData);
      
      if (response.statusCode == 201) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = response.data['error'] ?? 'Ошибка регистрации';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendResetCode(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.sendResetCode(email);
      _isLoading = false;
      notifyListeners();
      return response.statusCode == 200;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email, String newPassword, String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.forgotPassword(email, newPassword, code);
      _isLoading = false;
      notifyListeners();
      return response.statusCode == 200;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.logout();
    } catch (e) {
      print('Logout error: $e');
    }
    
    await _prefs.remove('sessionid');
    await _prefs.remove('user_data');
    _user = null;
    
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.updateProfile(data);
      print('Update profile response: ${response.statusCode}');
      print('Update profile data: ${response.data}');
      
      if (response.statusCode == 200) {
        if (response.data['user'] != null) {
          _user = User.fromJson(response.data['user']);
          await _prefs.setString('user_data', json.encode(response.data['user']));
        } else if (response.data['success'] == true) {
          if (_user != null) {
            final updatedUser = User(
              id: _user!.id,
              email: _user!.email,
              firstName: data['first_name']?.toString() ?? _user!.firstName,
              lastName: data['last_name']?.toString() ?? _user!.lastName,
              phone: data['phone']?.toString() ?? _user!.phone,
              avatarUrl: _user!.avatarUrl,
              role: _user!.role,
              createdAt: _user!.createdAt,
              lastLoginAt: _user!.lastLoginAt,
            );
            _user = updatedUser;
            await _prefs.setString('user_data', json.encode(_user!.toJson()));
          }
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.data['error'] ?? 'Ошибка обновления профиля';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Error updating profile: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.changePassword({
        'old_password': oldPassword,
        'new_password': newPassword,
      });
      
      print('Change password response: ${response.statusCode}');
      print('Change password data: ${response.data}');
      
      if (response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.data['error'] ?? 'Ошибка смены пароля';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Error changing password: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}