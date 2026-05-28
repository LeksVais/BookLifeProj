import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/book_model.dart';

class FavoriteProvider extends ChangeNotifier {
  final ApiService _apiService;
  
  List<Book> _favorites = [];
  Set<int> _favoriteIds = {};
  bool _isLoading = false;
  String? _error;

  FavoriteProvider(this._apiService);

  List<Book> get favorites => _favorites;
  Set<int> get favoriteIds => _favoriteIds;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get count => _favorites.length;

  Future<void> loadFavorites() async {
    _isLoading = true;
    _error = null;
    
    try {
      final response = await _apiService.getFavorites();
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _favorites = data.map((b) => Book.fromJson(b)).toList();
        _favoriteIds = _favorites.map((b) => b.id).toSet();
        _isLoading = false;
        notifyListeners(); 
      } else {
        _error = 'Ошибка загрузки избранного';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addToFavorite(int bookId) async {
    try {
      final response = await _apiService.addToFavorite(bookId);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _favoriteIds.add(bookId);
        final bookResponse = await _apiService.getBook(bookId);
        if (bookResponse.statusCode == 200) {
          _favorites.add(Book.fromJson(bookResponse.data));
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error adding to favorites: $e');
      return false;
    }
  }

  Future<bool> removeFromFavorite(int bookId) async {
    try {
      final response = await _apiService.removeFromFavorite(bookId);
      if (response.statusCode == 200) {
        _favoriteIds.remove(bookId);
        _favorites.removeWhere((b) => b.id == bookId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error removing from favorites: $e');
      return false;
    }
  }

  Future<bool> isFavorite(int bookId) async {
    // Проверяем локальный кэш
    if (_favoriteIds.contains(bookId)) {
      return true;
    }
    
    try {
      final response = await _apiService.isFavorite(bookId);
      if (response.statusCode == 200) {
        final bool isFav = response.data['is_favorite'] ?? false;
        if (isFav) {
          _favoriteIds.add(bookId);
          notifyListeners();
        }
        return isFav;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void toggleFavorite(int bookId) async {
    if (_favoriteIds.contains(bookId)) {
      await removeFromFavorite(bookId);
    } else {
      await addToFavorite(bookId);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}