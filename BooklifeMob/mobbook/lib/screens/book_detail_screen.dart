import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/favorite_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../models/review_model.dart';

class BookDetailScreen extends StatefulWidget {
  const BookDetailScreen({Key? key}) : super(key: key);

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  int _bookId = 0;
  bool _isInFavorites = false;
  bool _isPurchased = false;
  bool _isLoading = true;
  bool _isInitialized = false;
  
  // Review form
  final _reviewController = TextEditingController();
  int _selectedRating = 5;
  bool _isSubmittingReview = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is int) {
        _bookId = args;
        _isInitialized = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadData();
        });
      }
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      
      await bookProvider.loadBookDetails(_bookId);
      await bookProvider.loadReviews(_bookId);
      
      _isInFavorites = await favoriteProvider.isFavorite(_bookId);
      
      if (authProvider.isAuthenticated) {
        await orderProvider.loadOrders();
        final purchasedIds = orderProvider.getPurchasedBookIds();
        _isPurchased = purchasedIds.contains(_bookId);
      }
    } catch (e) {
      print('Error loading book data: $e');
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addToCart() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final success = await cartProvider.addToCart(_bookId);
    
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Книга добавлена в корзину'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cartProvider.error ?? 'Ошибка добавления в корзину'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
    
    if (_isInFavorites) {
      await favoriteProvider.removeFromFavorite(_bookId);
    } else {
      await favoriteProvider.addToFavorite(_bookId);
    }
    
    if (mounted) {
      setState(() {
        _isInFavorites = !_isInFavorites;
      });
    }
  }

  Future<void> _submitReview() async {
    if (_reviewController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите текст отзыва'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() => _isSubmittingReview = true);
    
    final bookProvider = Provider.of<BookProvider>(context, listen: false);
    final success = await bookProvider.addReview(
      _bookId,
      _selectedRating,
      _reviewController.text,
    );
    
    setState(() => _isSubmittingReview = false);
    
    if (!mounted) return;
    
    if (success) {
      _reviewController.clear();
      setState(() => _selectedRating = 5);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Отзыв добавлен'),
          backgroundColor: Colors.green,
        ),
      );
      await bookProvider.loadReviews(_bookId, refresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка добавления отзыва'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _readBook() {
    final book = Provider.of<BookProvider>(context, listen: false).currentBook;
    
    if (book == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Информация о книге недоступна'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (book.bookFileUrl == null || book.bookFileUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Файл книги отсутствует'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    Navigator.pushNamed(
      context,
      '/reader',
      arguments: {
        'title': book.title,
        'url': book.bookFileUrl,
        'fileType': book.bookFileType ?? 'pdf',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = Provider.of<BookProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    if (_isLoading || (bookProvider.isLoading && bookProvider.currentBook == null)) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final book = bookProvider.currentBook;
    if (book == null) {
      return const Scaffold(
        body: Center(child: Text('Книга не найдена')),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(book.title),
        actions: [
          IconButton(
            icon: Icon(
              _isInFavorites ? Icons.favorite : Icons.favorite_border,
              color: _isInFavorites ? Colors.red : null,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Colors.grey[100],
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 130,
                        height: 180,
                        color: Colors.grey[200],
                        child: book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty
                            ? Image.network(
                                book.coverImageUrl!,
                                width: 130,
                                height: 180,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.book, size: 50, color: Colors.grey);
                                },
                              )
                            : const Icon(Icons.book, size: 50, color: Colors.grey),
                      ),
                    ),
                  ),
                  
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            book.authors.map((a) => a.fullName).join(', '),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (book.averageRating != null) ...[
                            Row(
                              children: [
                                ...List.generate(5, (index) {
                                  return Icon(
                                    index < book.averageRating!.floor()
                                        ? Icons.star
                                        : (index < book.averageRating!
                                                ? Icons.star_half
                                                : Icons.star_border),
                                    size: 16,
                                    color: Colors.amber,
                                  );
                                }),
                                const SizedBox(width: 4),
                                Text(
                                  '${book.averageRating!.toStringAsFixed(1)} (${book.reviewsCount ?? 0})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (_isPurchased) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Книга уже в вашей библиотеке',
                                      style: TextStyle(color: Colors.green[700], fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _readBook,
                                icon: const Icon(Icons.menu_book),
                                label: const Text('Читать'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  side: const BorderSide(color: Colors.green),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ] else if (book.hasDiscount) ...[
                            Text(
                              '${book.price.toStringAsFixed(2)} ₽',
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '${book.currentPrice.toStringAsFixed(2)} ₽',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: Colors.red,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '-${book.discountPercent}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _addToCart,
                                child: const Text('В корзину'),
                              ),
                            ),
                          ] else ...[
                            Text(
                              '${book.price.toStringAsFixed(2)} ₽',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _addToCart,
                                child: const Text('В корзину'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Описание',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    book.description,
                    style: const TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Характеристики',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow('Страниц', '${book.pageCount}'),
                  _buildDetailRow('Год издания', '${book.publicationYear}'),
                  _buildDetailRow('Возрастной рейтинг', book.ageRating),
                  _buildDetailRow('Жанры', book.genres.map((g) => g.name).join(', ')),
                  if (book.bookFileType != null)
                    _buildDetailRow('Формат файла', book.bookFileType!.toUpperCase()),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Отзывы',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  if (authProvider.isAuthenticated && _isPurchased) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Text('Оценка: '),
                                ...List.generate(5, (index) {
                                  return IconButton(
                                    icon: Icon(
                                      index < _selectedRating
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedRating = index + 1;
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  );
                                }),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _reviewController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Поделитесь мнением о книге...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                onPressed: _isSubmittingReview ? null : _submitReview,
                                child: _isSubmittingReview
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Оставить отзыв'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  if (bookProvider.reviews.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Нет отзывов. Будьте первым!'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: bookProvider.reviews.length,
                      itemBuilder: (context, index) {
                        final review = bookProvider.reviews[index];
                        return _buildReviewCard(review);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReviewCard(Review review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    review.userName.isNotEmpty ? review.userName[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < review.rating
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 14,
                              color: Colors.amber,
                            );
                          }),
                          const SizedBox(width: 8),
                          Text(
                            review.createdAt.toString().substring(0, 10),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(review.comment),
          ],
        ),
      ),
    );
  }
}