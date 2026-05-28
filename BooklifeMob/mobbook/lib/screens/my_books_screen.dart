import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';

class MyBooksScreen extends StatefulWidget {
  const MyBooksScreen({Key? key}) : super(key: key);

  @override
  State<MyBooksScreen> createState() => _MyBooksScreenState();
}

class _MyBooksScreenState extends State<MyBooksScreen> {
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized && mounted) {
        _isInitialized = true;
        _loadOrders();
      }
    });
  }

  Future<void> _loadOrders() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.loadOrders();
    } catch (e) {
      print('Error loading orders: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmPayment(int orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение оплаты'),
        content: const Text(
          'Вы подтверждаете, что оплатили этот заказ?\n\n'
          'После подтверждения книги станут доступны для чтения.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isLoading = true);
    
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final success = await orderProvider.confirmPayment(orderId);
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Оплата подтверждена! Книги доступны для чтения'),
          backgroundColor: Colors.green,
        ),
      );
      _loadOrders();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(orderProvider.error ?? 'Ошибка подтверждения оплаты'),
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
    final orderProvider = Provider.of<OrderProvider>(context);
    
    if ((orderProvider.isLoading || _isLoading) && orderProvider.orders.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final pendingOrders = orderProvider.orders.where((o) => o.status == 'pending').toList();
    final paidOrders = orderProvider.orders.where((o) => o.status == 'paid').toList();
    
    if (pendingOrders.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Мои книги'),
        ),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payment, color: Colors.orange, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ожидают подтверждения оплаты',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Подтвердите оплату заказов, чтобы получить доступ к книгам',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: pendingOrders.length,
                itemBuilder: (context, index) {
                  final order = pendingOrders[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Заказ #${order.id}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  order.statusText,
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(color: Colors.grey[200]),
                          const SizedBox(height: 8),
                          Text(
                            'Дата заказа: ${order.orderDate.toString().substring(0, 10)}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                          Text(
                            'Способ оплаты: ${order.paymentMethod == 'card' ? 'Банковская карта' : order.paymentMethod}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                ...order.items.map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.bookTitle,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text('${item.price.toStringAsFixed(2)} ₽'),
                                    ],
                                  ),
                                )),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Итого:',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${order.totalAmount.toStringAsFixed(2)} ₽',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _confirmPayment(order.id),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Подтвердить оплату'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Для подтверждения оплаты нажмите на кнопку выше.\n'
                            'После подтверждения книги станут доступны для чтения.',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }
    
    if (paidOrders.isNotEmpty) {
      final purchasedBooks = <Map<String, dynamic>>[];
      for (final order in paidOrders) {
        for (final item in order.items) {
          purchasedBooks.add({
            'bookId': item.bookId,
            'title': item.bookTitle,
            'coverImageUrl': item.coverImageUrl,
            'bookFileUrl': item.bookFileUrl,
            'bookFileType': item.bookFileType,
            'orderId': order.id,
            'orderDate': order.orderDate,
          });
        }
      }
      
      return Scaffold(
        appBar: AppBar(
          title: const Text('Мои книги'),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: purchasedBooks.length,
          itemBuilder: (context, index) {
            final book = purchasedBooks[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                        child: book['coverImageUrl'] != null && book['coverImageUrl'].toString().isNotEmpty
                            ? Image.network(
                                book['coverImageUrl'],
                                width: 60,
                                height: 80,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.book, size: 30, color: Colors.grey);
                                },
                              )
                            : const Icon(Icons.book, size: 30, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book['title'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Заказ #${book['orderId']}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                          Text(
                            'Дата покупки: ${book['orderDate'].toString().substring(0, 10)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                          if (book['bookFileType'] != null)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                book['bookFileType'].toString().toUpperCase(),
                                style: const TextStyle(fontSize: 9),
                              ),
                            ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _readBook(
                        book['title'], 
                        book['bookFileUrl'], 
                        book['bookFileType']
                      ),
                      icon: const Icon(Icons.menu_book, size: 18),
                      label: const Text('Читать'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        minimumSize: const Size(100, 40),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои книги'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'У вас пока нет заказов',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Перейдите в каталог и сделайте первый заказ',
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
}