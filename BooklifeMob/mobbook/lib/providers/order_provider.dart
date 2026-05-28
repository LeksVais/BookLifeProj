import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/order_model.dart';

class OrderProvider extends ChangeNotifier {
  final ApiService _apiService;
  
  List<Order> _orders = [];
  Order? _currentOrder;
  bool _isLoading = false;
  String? _error;

  OrderProvider(this._apiService);

  List<Order> get orders => _orders;
  Order? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  Set<int> getPurchasedBookIds() {
    final purchasedIds = <int>{};
    for (final order in _orders) {
      if (order.status == 'paid') {
        for (final item in order.items) {
          purchasedIds.add(item.bookId);
        }
      }
    }
    return purchasedIds;
  }

  Future<void> loadOrders() async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.getOrders();
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _orders = data.map((o) => Order.fromJson(o)).toList();
      } else if (response.statusCode != 401) {
        _error = 'Ошибка загрузки заказов';
      }
    } catch (e) {
      print('Error loading orders: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Order?> createOrder({
    required String paymentMethod,
    required String email,
    required String phone,
  }) async {
    if (_isLoading) return null;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.createOrder({
        'payment_method': paymentMethod,
        'email': email,
        'phone': phone,
      });
      
      if (response.statusCode == 201) {
        _currentOrder = Order.fromJson(response.data);
        _isLoading = false;
        notifyListeners();
        return _currentOrder;
      } else {
        _error = response.data['error'] ?? 'Ошибка создания заказа';
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> confirmPayment(int orderId) async {
    if (_isLoading) return false;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.confirmPayment(orderId);
      
      if (response.statusCode == 200) {
        // Обновляем статус заказа в локальном списке
        final index = _orders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          _orders[index] = Order(
            id: _orders[index].id,
            totalAmount: _orders[index].totalAmount,
            status: 'paid',
            paymentMethod: _orders[index].paymentMethod,
            orderDate: _orders[index].orderDate,
            paymentConfirmedAt: DateTime.now(),
            items: _orders[index].items,
          );
        }
        if (_currentOrder != null && _currentOrder!.id == orderId) {
          _currentOrder = Order(
            id: _currentOrder!.id,
            totalAmount: _currentOrder!.totalAmount,
            status: 'paid',
            paymentMethod: _currentOrder!.paymentMethod,
            orderDate: _currentOrder!.orderDate,
            paymentConfirmedAt: DateTime.now(),
            items: _currentOrder!.items,
          );
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.data['error'] ?? 'Ошибка подтверждения оплаты';
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

  Future<Order?> getOrderDetails(int orderId) async {
    try {
      final response = await _apiService.getOrder(orderId);
      if (response.statusCode == 200) {
        return Order.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error getting order details: $e');
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}