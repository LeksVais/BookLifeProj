class CartItem {
  final int id;
  final int bookId;
  final String bookTitle;
  final String? coverImageUrl;
  final double price;
  final double? salePrice;
  final int? discountPercent;
  final int quantity;
  final DateTime addedAt;

  CartItem({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    this.coverImageUrl,
    required this.price,
    this.salePrice,
    this.discountPercent,
    this.quantity = 1,
    required this.addedAt,
  });

  double get currentPrice => salePrice ?? price;
  double get totalPrice => currentPrice * quantity; 
  bool get hasDiscount => discountPercent != null && discountPercent! > 0;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      bookId: json['book_id'],
      bookTitle: json['book_title'],
      coverImageUrl: json['cover_image_url'],
      price: (json['price'] ?? 0).toDouble(),
      salePrice: json['sale_price'] != null 
          ? (json['sale_price'] as num).toDouble() 
          : null,
      discountPercent: json['discount_percent'],
      quantity: 1, // Всегда 1 для электронных книг
      addedAt: DateTime.parse(json['added_at']),
    );
  }
}

class Cart {
  final int id;
  final List<CartItem> items;
  final double totalAmount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Cart({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  int get itemsCount => items.length;

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      id: json['id'],
      items: (json['items'] as List?)
          ?.map((i) => CartItem.fromJson(i))
          .toList() ?? [],
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'active',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}