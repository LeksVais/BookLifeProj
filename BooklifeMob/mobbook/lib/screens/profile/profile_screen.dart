import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/favorite_provider.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _isDataLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
    // Используем addPostFrameCallback для загрузки данных после построения
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadNotificationSettings() {
    // Загружаем настройки уведомлений из shared_preferences
    // Пока просто устанавливаем значение по умолчанию
    _notificationsEnabled = true;
  }

  void _saveNotificationSettings(bool value) {
    setState(() {
      _notificationsEnabled = value;
    });
    // TODO: Сохранить в shared_preferences
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value 
            ? 'Уведомления включены' 
            : 'Уведомления выключены'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _loadData() async {
    if (_isDataLoading) return;
    _isDataLoading = true;
    
    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
      await Future.wait([
        orderProvider.loadOrders(),
        favoriteProvider.loadFavorites(),
      ]);
    } catch (e) {
      print('Error loading profile data: $e');
    } finally {
      if (mounted) {
        _isDataLoading = false;
      }
    }
  }

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final favoriteProvider = Provider.of<FavoriteProvider>(context);
    
    final user = authProvider.user;
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue.shade700, Colors.purple.shade700],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  user.avatarUrl!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.blue.shade700,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.blue.shade700,
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.fullName ?? 'Пользователь',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),
                
                // Stats cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Заказов',
                          '${orderProvider.orders.length}',
                          Icons.shopping_bag_outlined,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Избранное',
                          '${favoriteProvider.count}',
                          Icons.favorite_border,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Уведомления',
                          '${notificationProvider.unreadCount}',
                          Icons.notifications_outlined,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Menu items
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Мои данные',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  icon: Icons.book,
                  title: 'Мои книги',
                  subtitle: 'Купленные книги',
                  onTap: () {
                    Navigator.pushNamed(context, '/my-books');
                  },
                ),
                _buildMenuItem(
                  icon: Icons.favorite,
                  title: 'Избранное',
                  subtitle: 'Сохраненные книги (${favoriteProvider.count})',
                  onTap: () {
                    Navigator.pushNamed(context, '/favorites');
                  },
                ),
                _buildMenuItem(
                  icon: Icons.notifications,
                  title: 'Уведомления',
                  subtitle: notificationProvider.unreadCount > 0
                      ? '${notificationProvider.unreadCount} непрочитанных'
                      : 'Нет новых уведомлений',
                  onTap: () {
                    Navigator.pushNamed(context, '/notifications');
                  },
                ),
                
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Настройки',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  icon: Icons.person_outline,
                  title: 'Редактировать профиль',
                  subtitle: 'Изменить личные данные',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                    ).then((_) => _loadData());
                  },
                ),
                _buildMenuItem(
                  icon: Icons.lock_outline,
                  title: 'Сменить пароль',
                  subtitle: 'Обновить пароль',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                    );
                  },
                ),
                
                // Настройка уведомлений - Switch
                SwitchListTile(
                  secondary: Icon(
                    Icons.notifications_active,
                    color: _notificationsEnabled ? Colors.blue : Colors.grey,
                  ),
                  title: const Text('Уведомления'),
                  subtitle: Text(
                    _notificationsEnabled 
                        ? 'Получать уведомления о заказах и акциях'
                        : 'Уведомления отключены',
                  ),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    _saveNotificationSettings(value);
                  },
                ),
                
                _buildMenuItem(
                  icon: Icons.logout,
                  title: 'Выйти',
                  subtitle: 'Завершить сеанс',
                  onTap: _logout,
                  isDestructive: true,
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.blue),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}