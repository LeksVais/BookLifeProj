import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/cart_model.dart';

class CartProvider extends ChangeNotifier {
  final ApiService _apiService;
  
  Cart? _cart;
  bool _isLoading = false;
  String? _error;

  CartProvider(this._apiService);

  Cart? get cart => _cart;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get itemsCount => _cart?.itemsCount ?? 0;
  double get totalAmount => _cart?.totalAmount ?? 0;

  Future<void> loadCart() async {
    if (_isLoading) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getCart();
      if (response.statusCode == 200) {
        _cart = Cart.fromJson(response.data);
        _isLoading = false;
        notifyListeners();
      } else if (response.statusCode == 401) {
        _cart = null;
        _isLoading = false;
        notifyListeners();
      } else {
        _error = 'Ошибка загрузки корзины';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading cart: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addToCart(int bookId) async {
    try {
      final response = await _apiService.addToCart(bookId);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await loadCart();
        return true;
      } else {
        final errorMsg = response.data['error'] ?? 'Ошибка добавления в корзину';
        _error = errorMsg;
        return false;
      }
    } catch (e) {
      print('Error adding to cart: $e');
      _error = e.toString();
      return false;
    }
  }

  Future<bool> removeFromCart(int cartItemId) async {
    try {
      final response = await _apiService.removeFromCart(cartItemId);
      if (response.statusCode == 200) {
        await loadCart();
        return true;
      }
      return false;
    } catch (e) {
      print('Error removing from cart: $e');
      return false;
    }
  }

  Future<bool> clearCart() async {
    try {
      final response = await _apiService.clearCart();
      if (response.statusCode == 200) {
        _cart = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error clearing cart: $e');
      return false;
    }
  }

  Future<void> clearCartAndRefresh() async {
    await clearCart();
    await loadCart();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}