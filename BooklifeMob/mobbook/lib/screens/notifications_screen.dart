import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    await notificationProvider.loadNotifications();
  }

  Future<void> _markAsRead(int id) async {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    await notificationProvider.markAsRead(id);
  }

  Future<void> _markAllAsRead() async {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    await notificationProvider.markAllAsRead();
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          if (notificationProvider.unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Прочитать все'),
            ),
        ],
      ),
      body: notificationProvider.isLoading && notificationProvider.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : notificationProvider.notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Нет уведомлений',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notificationProvider.notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notificationProvider.notifications[index];
                    return Card(
                      color: notification.isRead ? null : Colors.blue[50],
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: _getNotificationIcon(notification.type),
                        title: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification.message),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(notification.createdAt),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        trailing: notification.isRead
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.check_circle_outline, size: 20),
                                onPressed: () => _markAsRead(notification.id),
                              ),
                        onTap: () {
                          if (!notification.isRead) {
                            _markAsRead(notification.id);
                          }
                          if (notification.data != null && notification.data!.containsKey('book_id')) {
                            Navigator.pushNamed(
                              context,
                              '/book-detail',
                              arguments: notification.data!['book_id'],
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Widget _getNotificationIcon(String type) {
    IconData icon;
    Color color;
    
    switch (type) {
      case 'sale':
        icon = Icons.local_offer;
        color = Colors.red;
        break;
      case 'order':
        icon = Icons.shopping_bag;
        color = Colors.green;
        break;
      case 'info':
      default:
        icon = Icons.info;
        color = Colors.blue;
        break;
    }
    
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Только что';
        }
        return '${difference.inMinutes} мин назад';
      }
      return '${difference.inHours} ч назад';
    } else if (difference.inDays == 1) {
      return 'Вчера';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} дн назад';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
}