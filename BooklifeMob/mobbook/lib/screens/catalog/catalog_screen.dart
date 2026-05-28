import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/book_model.dart';
import 'filters_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({Key? key}) : super(key: key);

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false;
  Set<int> _purchasedBookIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized && mounted) {
        _isInitialized = true;
        _loadData();
      }
    });
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        final bookProvider = Provider.of<BookProvider>(context, listen: false);
        if (!bookProvider.isLoading && bookProvider.hasMore) {
          bookProvider.loadBooks();
        }
      }
    });
  }

  Future<void> _loadData() async {
    final bookProvider = Provider.of<BookProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    await bookProvider.loadFilters();
    await bookProvider.loadBooks(refresh: true);
    await bookProvider.loadNewBooks();
    await bookProvider.loadPopularBooks();
    await bookProvider.loadRecommendedBooks();
    
    // Загружаем купленные книги, если пользователь авторизован
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

  Future<void> _refresh() async {
    final bookProvider = Provider.of<BookProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    await bookProvider.loadBooks(refresh: true);
    await bookProvider.loadNewBooks();
    await bookProvider.loadPopularBooks();
    await bookProvider.loadRecommendedBooks();
    
    if (authProvider.isAuthenticated) {
      await _loadPurchasedBooks();
    }
  }
  
  bool _isBookPurchased(int bookId) {
    return _purchasedBookIds.contains(bookId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 48) / 2;
    
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () {
                  showSearch(
                    context: context,
                    delegate: BookSearchDelegate(purchasedBookIds: _purchasedBookIds),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      Text(
                        'Поиск книг...',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // New books section
          Consumer<BookProvider>(
            builder: (context, provider, child) {
              if (provider.newBooks.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Новинки',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 280,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: provider.newBooks.length,
                        itemBuilder: (context, index) {
                          final book = provider.newBooks[index];
                          return Container(
                            width: cardWidth,
                            margin: EdgeInsets.only(
                              right: index == provider.newBooks.length - 1 ? 0 : 12,
                            ),
                            child: BookCard(
                              book: book,
                              isPurchased: _isBookPurchased(book.id),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
          
          // Popular books section
          Consumer<BookProvider>(
            builder: (context, provider, child) {
              if (provider.popularBooks.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Популярное',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 280,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: provider.popularBooks.length,
                        itemBuilder: (context, index) {
                          final book = provider.popularBooks[index];
                          return Container(
                            width: cardWidth,
                            margin: EdgeInsets.only(
                              right: index == provider.popularBooks.length - 1 ? 0 : 12,
                            ),
                            child: BookCard(
                              book: book,
                              isPurchased: _isBookPurchased(book.id),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
          
          // Recommended books section
          Consumer<BookProvider>(
            builder: (context, provider, child) {
              if (provider.recommendedBooks.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Рекомендуем',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 280,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: provider.recommendedBooks.length,
                        itemBuilder: (context, index) {
                          final book = provider.recommendedBooks[index];
                          return Container(
                            width: cardWidth,
                            margin: EdgeInsets.only(
                              right: index == provider.recommendedBooks.length - 1 ? 0 : 12,
                            ),
                            child: BookCard(
                              book: book,
                              isPurchased: _isBookPurchased(book.id),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
          
          // All books section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Все книги',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) => const FiltersScreen(),
                      );
                    },
                    child: const Text('Фильтры'),
                  ),
                ],
              ),
            ),
          ),
          
          // Books grid - показываем все книги с плашкой "Куплено"
          Consumer<BookProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.books.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              if (provider.books.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text('Книги не найдены'),
                  ),
                );
              }
              
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: provider.books.length,
                    itemBuilder: (context, index) {
                      final book = provider.books[index];
                      return BookCard(
                        book: book,
                        isPurchased: _isBookPurchased(book.id),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          
          // Loading more indicator
          Consumer<BookProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.books.isNotEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
              }
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            },
          ),
        ],
      ),
    );
  }
}

class BookCard extends StatelessWidget {
  final Book book;
  final bool isPurchased;
  
  const BookCard({Key? key, required this.book, this.isPurchased = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final coverHeight = screenWidth * 0.35;
    final fontSizeTitle = screenWidth * 0.032;
    final fontSizeAuthor = screenWidth * 0.028;
    final fontSizePrice = screenWidth * 0.035;
    
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/book-detail',
          arguments: book.id,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book cover with purchased badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    height: coverHeight,
                    width: double.infinity,
                    color: Colors.grey[100],
                    child: Center(
                      child: book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty
                          ? Image.network(
                              book.coverImageUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.book,
                                  size: coverHeight * 0.3,
                                  color: Colors.grey[400],
                                );
                              },
                            )
                          : Icon(
                              Icons.book,
                              size: coverHeight * 0.3,
                              color: Colors.grey[400],
                            ),
                    ),
                  ),
                ),
                // Плашка "Куплено"
                if (isPurchased)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Куплено',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            
            // Book info
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.025),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: fontSizeTitle,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.008),
                  Text(
                    book.authors.map((a) => a.fullName).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSizeAuthor,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.015),
                  if (!isPurchased)
                    Row(
                      children: [
                        if (book.hasDiscount) ...[
                          Text(
                            '${book.price.toStringAsFixed(0)} ₽',
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              fontSize: fontSizeAuthor,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.015),
                          Text(
                            '${book.currentPrice.toStringAsFixed(0)} ₽',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: fontSizePrice,
                            ),
                          ),
                        ] else ...[
                          Text(
                            '${book.price.toStringAsFixed(0)} ₽',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: fontSizePrice,
                            ),
                          ),
                        ],
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'В вашей библиотеке',
                        style: TextStyle(
                          fontSize: fontSizeAuthor,
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Обновленный SearchDelegate с плашкой "Куплено"
class BookSearchDelegate extends SearchDelegate {
  final Set<int> purchasedBookIds;
  
  BookSearchDelegate({this.purchasedBookIds = const {}});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text('Введите название книги или автора'),
      );
    }
    
    return BookSearchResults(query: query, purchasedBookIds: purchasedBookIds);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text('Поиск книг по названию или автору'),
      );
    }
    
    return BookSearchResults(query: query, purchasedBookIds: purchasedBookIds);
  }
}

class BookSearchResults extends StatelessWidget {
  final String query;
  final Set<int> purchasedBookIds;
  
  const BookSearchResults({Key? key, required this.query, this.purchasedBookIds = const {}})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Provider.of<BookProvider>(context, listen: false).loadBooks(refresh: true),
      builder: (context, snapshot) {
        final bookProvider = Provider.of<BookProvider>(context);
        final books = bookProvider.books.where((book) =>
          book.title.toLowerCase().contains(query.toLowerCase()) ||
          book.authors.any((author) =>
            author.fullName.toLowerCase().contains(query.toLowerCase())
          )
        ).toList();
        
        if (books.isEmpty) {
          return const Center(
            child: Text('Ничего не найдено'),
          );
        }
        
        return ListView.builder(
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            final isPurchased = purchasedBookIds.contains(book.id);
            return ListTile(
              leading: book.coverImageUrl != null
                  ? Stack(
                      children: [
                        Image.network(
                          book.coverImageUrl!,
                          width: 50,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 50,
                              height: 70,
                              color: Colors.grey[300],
                              child: const Icon(Icons.book),
                            );
                          },
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
                    )
                  : Container(
                      width: 50,
                      height: 70,
                      color: Colors.grey[300],
                      child: const Icon(Icons.book),
                    ),
              title: Text(
                book.title,
                style: isPurchased
                    ? TextStyle(color: Colors.green[700])
                    : null,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.authors.map((a) => a.fullName).join(', ')),
                  if (isPurchased)
                    Text(
                      'Уже в библиотеке',
                      style: TextStyle(fontSize: 10, color: Colors.green[600]),
                    ),
                ],
              ),
              trailing: isPurchased
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : Text('${book.currentPrice.toStringAsFixed(2)} ₽'),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/book-detail',
                  arguments: book.id,
                );
              },
            );
          },
        );
      },
    );
  }
}