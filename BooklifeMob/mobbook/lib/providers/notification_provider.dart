import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiService _apiService;
  
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  NotificationProvider(this._apiService);

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getNotifications();
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _notifications = data.map((n) => NotificationModel.fromJson(n)).toList();
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        _isLoading = false;
        notifyListeners();
      } else {
        _error = 'Ошибка загрузки уведомлений';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUnreadCount() async {
    try {
      final response = await _apiService.getUnreadCount();
      if (response.statusCode == 200) {
        _unreadCount = response.data['count'] ?? 0;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading unread count: $e');
    }
  }

  Future<bool> markAsRead(int notificationId) async {
    try {
      final response = await _apiService.markNotificationAsRead(notificationId);
      if (response.statusCode == 200) {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = NotificationModel.fromJson(
            response.data
          );
          _unreadCount = _notifications.where((n) => !n.isRead).length;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Error marking as read: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await _apiService.markAllNotificationsAsRead();
      if (response.statusCode == 200) {
        for (var i = 0; i < _notifications.length; i++) {
          _notifications[i] = NotificationModel.fromJson(
            {..._notifications[i].toJson(), 'is_read': true}
          );
        }
        _unreadCount = 0;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error marking all as read: $e');
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

extension NotificationModelToJson on NotificationModel {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'data': data,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}