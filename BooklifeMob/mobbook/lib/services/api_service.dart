import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ApiService {
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    } else if (Platform.isIOS) {
      return 'http://localhost:8000/api';
    } else {
      return 'http://localhost:8000/api';
    }
  }
  
  late Dio _dio;
  
  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
      validateStatus: (status) {
        return status != null && status < 500;
      },
    ));
    
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('sessionid');
        if (token != null) {
          options.headers['Cookie'] = 'sessionid=$token';
        }
        print('Request: ${options.method} ${options.uri}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('Response: ${response.statusCode} ${response.requestOptions.uri}');
        return handler.next(response);
      },
      onError: (error, handler) async {
        print('Error: ${error.response?.statusCode} ${error.requestOptions.uri}');
        print('Error message: ${error.message}');
        
        if (error.response?.statusCode == 401) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('sessionid');
          await prefs.remove('user_data');
        }
        return handler.next(error);
      },
    ));
  }
  
  Dio get dio => _dio;
  
  // Auth endpoints
  Future<Response> login(String email, String password) async {
    return await _dio.post('/auth/login/', data: {
      'email': email,
      'password': password,
    });
  }
  
  Future<Response> register(Map<String, dynamic> userData) async {
    return await _dio.post('/auth/register/', data: userData);
  }
  
  Future<Response> forgotPassword(String email, String newPassword, String code) async {
    return await _dio.post('/auth/forgot-password/', data: {
      'email': email,
      'new_password': newPassword,
      'code': code,
    });
  }
  
  Future<Response> sendResetCode(String email) async {
    return await _dio.post('/auth/send-reset-code/', data: {
      'email': email,
    });
  }
  
  Future<Response> logout() async {
    return await _dio.post('/auth/logout/');
  }
  
  // User endpoints
  Future<Response> getProfile() async {
    return await _dio.get('/user/profile/');
  }
  
  Future<Response> updateProfile(Map<String, dynamic> data) async {
    return await _dio.put('/user/profile/update/', data: data);
  }
  
  Future<Response> changePassword(Map<String, dynamic> data) async {
    return await _dio.post('/user/change-password/', data: data);
  }
  
  // Filter endpoints
  Future<Response> getGenres() async {
    return await _dio.get('/genres/');
  }
  
  Future<Response> getAuthors() async {
    return await _dio.get('/authors/');
  }
  
  // Book endpoints
  Future<Response> getBooks({
    String? search,
    String? genre,
    String? author,
    String? sort,
    double? minPrice,
    double? maxPrice,
    int page = 1,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      if (search != null && search.isNotEmpty) 'search': search,
      if (genre != null && genre.isNotEmpty) 'genre': genre,
      if (author != null && author.isNotEmpty) 'author': author,
      if (sort != null && sort.isNotEmpty) 'sort': sort,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
    };
    return await _dio.get('/books/', queryParameters: query);
  }
  
  Future<Response> getBook(int id) async {
    return await _dio.get('/books/$id/');
  }
  
  Future<Response> getNewBooks({int limit = 10}) async {
    try {
      return await _dio.get('/books/new/', queryParameters: {'limit': limit});
    } catch (e) {
      print('Error in getNewBooks: $e');
      return Response(
        requestOptions: RequestOptions(path: '/books/new/'),
        statusCode: 500,
        data: {'error': 'Server error'},
      );
    }
  }
  
  Future<Response> getPopularBooks({int limit = 10}) async {
    try {
      return await _dio.get('/books/popular/', queryParameters: {'limit': limit});
    } catch (e) {
      print('Error in getPopularBooks: $e');
      return Response(
        requestOptions: RequestOptions(path: '/books/popular/'),
        statusCode: 500,
        data: {'error': 'Server error'},
      );
    }
  }
  
  Future<Response> getRecommendedBooks({int limit = 10}) async {
    try {
      return await _dio.get('/books/recommended/', queryParameters: {'limit': limit});
    } catch (e) {
      print('Error in getRecommendedBooks: $e');
      return Response(
        requestOptions: RequestOptions(path: '/books/recommended/'),
        statusCode: 500,
        data: {'error': 'Server error'},
      );
    }
  }
  
  // Cart endpoints
  Future<Response> getCart() async {
    return await _dio.get('/cart/');
  }
  
  Future<Response> addToCart(int bookId) async {
    return await _dio.post('/cart/add/', data: {'book_id': bookId});
  }
  
  Future<Response> removeFromCart(int cartItemId) async {
    return await _dio.delete('/cart/remove/$cartItemId/');
  }
  
  Future<Response> updateCartItemQuantity(int cartItemId, int quantity) async {
    return await _dio.put('/cart/update/$cartItemId/', data: {'quantity': quantity});
  }
  
  Future<Response> clearCart() async {
    return await _dio.delete('/cart/clear/');
  }
  
  // Order endpoints
  Future<Response> createOrder(Map<String, dynamic> orderData) async {
    return await _dio.post('/orders/create/', data: orderData);
  }
  
  Future<Response> getOrders() async {
    return await _dio.get('/orders/');
  }
  
  Future<Response> getOrder(int id) async {
    return await _dio.get('/orders/$id/');
  }
  
  Future<Response> confirmPayment(int orderId) async {
    return await _dio.post('/orders/$orderId/confirm-payment/');
  }
  
  // Favorite endpoints
  Future<Response> getFavorites() async {
    return await _dio.get('/favorites/');
  }
  
  Future<Response> addToFavorite(int bookId) async {
    return await _dio.post('/favorites/add/', data: {'book_id': bookId});
  }
  
  Future<Response> removeFromFavorite(int bookId) async {
    return await _dio.delete('/favorites/remove/$bookId/');
  }
  
  Future<Response> isFavorite(int bookId) async {
    return await _dio.get('/favorites/check/$bookId/');
  }
  
  // Review endpoints
  Future<Response> getBookReviews(int bookId, {int page = 1}) async {
    try {
      return await _dio.get('/books/$bookId/reviews/', queryParameters: {'page': page});
    } on DioException {
      return Response(
        requestOptions: RequestOptions(path: '/books/$bookId/reviews/'),
        statusCode: 200,
        data: {'results': [], 'count': 0},
      );
    }
  }
  
  Future<Response> createReview(int bookId, Map<String, dynamic> reviewData) async {
    try {
      final response = await _dio.post('/books/$bookId/reviews/create/', data: reviewData);
      return response;
    } on DioException catch (e) {
      print('Error creating review: ${e.response?.data}');
      return Response(
        requestOptions: RequestOptions(path: '/books/$bookId/reviews/create/'),
        statusCode: e.response?.statusCode ?? 500,
        data: {'error': e.response?.data?['error'] ?? e.message},
      );
    }
  }
  
  // Notification endpoints
  Future<Response> getNotifications() async {
    return await _dio.get('/notifications/');
  }
  
  Future<Response> markNotificationAsRead(int id) async {
    return await _dio.post('/notifications/$id/read/');
  }
  
  Future<Response> markAllNotificationsAsRead() async {
    return await _dio.post('/notifications/read-all/');
  }
  
  Future<Response> getUnreadCount() async {
    return await _dio.get('/notifications/unread-count/');
  }
  
  // My books
  Future<Response> getMyBooks() async {
    return await _dio.get('/user/books/');
  }
  
  // Check if user already purchased a book
  Future<Response> checkPurchased(int bookId) async {
    return await _dio.get('/user/books/check/$bookId/');
  }
  
  // Merchandiser endpoints
  Future<Response> getCartsForMerchandiser({String? status, int page = 1}) async {
    final query = <String, dynamic>{
      'page': page,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    return await _dio.get('/merchandiser/carts/', queryParameters: query);
  }
  
  Future<Response> updateCartStatus(int cartId, String status) async {
    return await _dio.post('/merchandiser/carts/$cartId/update-status/', data: {'status': status});
  }
}