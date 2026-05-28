import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/book_model.dart';
import '../models/review_model.dart';

class BookProvider extends ChangeNotifier {
  final ApiService _apiService;
  
  List<Book> _books = [];
  List<Book> _newBooks = [];
  List<Book> _popularBooks = [];
  List<Book> _recommendedBooks = [];
  Book? _currentBook;
  List<Review> _reviews = [];
  
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;
  
  // Filters
  String? _searchQuery;
  String? _selectedGenre;
  String? _selectedAuthor;
  String? _sortBy;
  double? _minPrice;
  double? _maxPrice;
  
  List<Genre> _availableGenres = [];
  List<Author> _availableAuthors = [];
  bool _isLoadingFilters = false;

  BookProvider(this._apiService);

  List<Book> get books => _books;
  List<Book> get newBooks => _newBooks;
  List<Book> get popularBooks => _popularBooks;
  List<Book> get recommendedBooks => _recommendedBooks;
  Book? get currentBook => _currentBook;
  List<Review> get reviews => _reviews;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  
  String? get searchQuery => _searchQuery;
  String? get selectedGenre => _selectedGenre;
  String? get selectedAuthor => _selectedAuthor;
  String? get sortBy => _sortBy;
  
  List<Genre> get availableGenres => _availableGenres;
  List<Author> get availableAuthors => _availableAuthors;
  bool get isLoadingFilters => _isLoadingFilters;

  Future<void> loadFilters() async {
    _isLoadingFilters = true;
    notifyListeners();
    
    try {
      final genresResponse = await _apiService.getGenres();
      if (genresResponse.statusCode == 200) {
        final List<dynamic> data = genresResponse.data;
        _availableGenres = data.map((g) => Genre.fromJson(g)).toList();
        print('Loaded ${_availableGenres.length} genres');
      } else {
        print('Failed to load genres: ${genresResponse.statusCode}');
      }
      
      final authorsResponse = await _apiService.getAuthors();
      if (authorsResponse.statusCode == 200) {
        final List<dynamic> data = authorsResponse.data;
        _availableAuthors = data.map((a) => Author.fromJson(a)).toList();
        print('Loaded ${_availableAuthors.length} authors');
      } else {
        print('Failed to load authors: ${authorsResponse.statusCode}');
      }
    } catch (e) {
      print('Error loading filters: $e');
    }
    
    _isLoadingFilters = false;
    notifyListeners();
  }

  Future<void> loadBooks({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _books = [];
      _hasMore = true;
    }
    
    if (!_hasMore) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getBooks(
        search: _searchQuery,
        genre: _selectedGenre,
        author: _selectedAuthor,
        sort: _sortBy,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        page: _currentPage,
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> results = data['results'] ?? [];
        final newBooks = results.map((b) => Book.fromJson(b)).toList();
        
        if (refresh) {
          _books = newBooks;
        } else {
          _books.addAll(newBooks);
        }
        
        _hasMore = data['next'] != null && data['next'] is bool 
            ? data['next'] 
            : data['next'] != null;
        if (_hasMore) _currentPage++;
        
        _isLoading = false;
        notifyListeners();
      } else {
        _error = 'Ошибка загрузки книг';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading books: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNewBooks() async {
    try {
      final response = await _apiService.getNewBooks(limit: 10);
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data is List ? response.data : [];
        _newBooks = data.map((b) => Book.fromJson(b)).toList();
        notifyListeners();
      } else {
        print('Failed to load new books: ${response.statusCode}');
        _newBooks = [];
        notifyListeners();
      }
    } catch (e) {
      print('Error loading new books: $e');
      _newBooks = [];
      notifyListeners();
    }
  }

  Future<void> loadPopularBooks() async {
    try {
      final response = await _apiService.getPopularBooks(limit: 10);
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data is List ? response.data : [];
        _popularBooks = data.map((b) => Book.fromJson(b)).toList();
        notifyListeners();
      } else {
        print('Failed to load popular books: ${response.statusCode}');
        _popularBooks = [];
        notifyListeners();
      }
    } catch (e) {
      print('Error loading popular books: $e');
      _popularBooks = [];
      notifyListeners();
    }
  }

  Future<void> loadRecommendedBooks() async {
    try {
      final response = await _apiService.getRecommendedBooks(limit: 10);
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data is List ? response.data : [];
        _recommendedBooks = data.map((b) => Book.fromJson(b)).toList();
        notifyListeners();
      } else {
        print('Failed to load recommended books: ${response.statusCode}');
        _recommendedBooks = [];
        notifyListeners();
      }
    } catch (e) {
      print('Error loading recommended books: $e');
      _recommendedBooks = [];
      notifyListeners();
    }
  }

  Future<void> loadBookDetails(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getBook(id);
      if (response.statusCode == 200) {
        _currentBook = Book.fromJson(response.data);
        _isLoading = false;
        notifyListeners();
      } else {
        _error = 'Ошибка загрузки книги';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadReviews(int bookId, {bool refresh = false}) async {
    if (refresh) {
      _reviews = [];
    }
    
    try {
      final response = await _apiService.getBookReviews(bookId);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['results'] ?? [];
        _reviews = data.map((r) => Review.fromJson(r)).toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading reviews: $e');
    }
  }

  Future<bool> addReview(int bookId, int rating, String comment) async {
    try {
      final response = await _apiService.createReview(bookId, {
        'rating': rating,
        'comment': comment,
      });
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        await loadReviews(bookId, refresh: true);
        return true;
      }
      return false;
    } catch (e) {
      print('Error adding review: $e');
      return false;
    }
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    loadBooks(refresh: true);
  }

  void setGenre(String? genre) {
    _selectedGenre = genre;
    loadBooks(refresh: true);
  }

  void setAuthor(String? author) {
    _selectedAuthor = author;
    loadBooks(refresh: true);
  }

  void setSortBy(String? sort) {
    _sortBy = sort;
    loadBooks(refresh: true);
  }

  void setPriceRange(double? min, double? max) {
    _minPrice = min;
    _maxPrice = max;
    loadBooks(refresh: true);
  }

  void clearFilters() {
    _searchQuery = null;
    _selectedGenre = null;
    _selectedAuthor = null;
    _sortBy = null;
    _minPrice = null;
    _maxPrice = null;
    loadBooks(refresh: true);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}