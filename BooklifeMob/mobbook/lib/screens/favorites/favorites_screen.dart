import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/favorite_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Set<int> _purchasedBookIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    await favoriteProvider.loadFavorites();
    
    if (authProvider.isAuthenticated) {
      await _loadPurchasedBooks();
    }
  }
  
  Future<void> _loadPurchasedBooks() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    await orderProvider.loadOrders();
    
    final purchasedIds = <int>{};
    for (final order in orderProvider.orders) {
      if (order.status == 'paid') {
        for (final item in order.items) {
          purchasedIds.add(item.bookId);
        }
      }
    }
    setState(() {
      _purchasedBookIds = purchasedIds;
    });
  }

  Future<void> _addToCart(int bookId) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final success = await cartProvider.addToCart(bookId);
    
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
        const SnackBar(
          content: Text('Ошибка добавления в корзину'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _readBook(String bookTitle, String? bookFileUrl, String? fileType) {
    if (bookFileUrl == null || bookFileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Файл книги временно недоступен'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    Navigator.pushNamed(
      context,
      '/reader',
      arguments: {
        'title': bookTitle,
        'url': bookFileUrl,
        'fileType': fileType ?? 'pdf',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final favoriteProvider = Provider.of<FavoriteProvider>(context);
    
    if (favoriteProvider.isLoading && favoriteProvider.favorites.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (favoriteProvider.favorites.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Избранное пусто',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Добавляйте книги в избранное, чтобы не потерять',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context, 
                    '/main', 
                    (route) => false,
                  );
                },
                child: const Text('Перейти в каталог'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Избранное (${favoriteProvider.count})'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: favoriteProvider.favorites.length,
          itemBuilder: (context, index) {
            final book = favoriteProvider.favorites[index];
            final isPurchased = _purchasedBookIds.contains(book.id);
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 60,
                        height: 80,
                        color: Colors.grey[200],
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty
                                  ? Image.network(
                                      book.coverImageUrl!,
                                      width: 60,
                                      height: 80,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(Icons.book, color: Colors.grey);
                                      },
                                    )
                                  : const Icon(Icons.book, color: Colors.grey),
                            ),
                            if (isPurchased)
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: isPurchased ? Colors.green[700] : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            book.authors.map((a) => a.fullName).join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (book.bookFileType != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                book.bookFileType!.toUpperCase(),
                                style: const TextStyle(fontSize: 9),
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (isPurchased)
                            Text(
                              'В вашей библиотеке',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[600],
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else if (book.hasDiscount) ...[
                            Row(
                              children: [
                                Text(
                                  '${book.price.toStringAsFixed(2)} ₽',
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${book.currentPrice.toStringAsFixed(2)} ₽',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              '${book.price.toStringAsFixed(2)} ₽',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    if (isPurchased)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu_book, color: Colors.green),
                            onPressed: () => _readBook(book.title, book.bookFileUrl, book.bookFileType),
                            iconSize: 24,
                          ),
                          IconButton(
                            icon: const Icon(Icons.favorite, color: Colors.red),
                            onPressed: () async {
                              await favoriteProvider.removeFromFavorite(book.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Книга удалена из избранного'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                            iconSize: 24,
                          ),
                        ],
                      )
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.shopping_cart_outlined),
                            onPressed: () => _addToCart(book.id),
                            color: Colors.blue,
                            iconSize: 24,
                          ),
                          IconButton(
                            icon: const Icon(Icons.favorite, color: Colors.red),
                            onPressed: () async {
                              await favoriteProvider.removeFromFavorite(book.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Книга удалена из избранного'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                            iconSize: 24,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}