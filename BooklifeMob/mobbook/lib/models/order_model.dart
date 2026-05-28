import 'package:flutter/material.dart';

class OrderItem {
  final int id;
  final int bookId;
  final String bookTitle;
  final String? coverImageUrl;
  final String? bookFileUrl;
  final String? bookFileType;
  final double price;
  final int quantity;

  OrderItem({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    this.coverImageUrl,
    this.bookFileUrl,
    this.bookFileType,
    required this.price,
    required this.quantity,
  });

  double get totalPrice => price * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    String? fileUrl = json['book_file_url'];
    if (fileUrl != null && fileUrl.isNotEmpty && !fileUrl.startsWith('http')) {
      fileUrl = 'http://10.0.2.2:8000$fileUrl';
    }
    
    return OrderItem(
      id: json['id'],
      bookId: json['book_id'],
      bookTitle: json['book_title'],
      coverImageUrl: json['cover_image_url'],
      bookFileUrl: fileUrl,
      bookFileType: json['book_file_type'] ?? 'pdf',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
    );
  }
}

class Order {
  final int id;
  final double totalAmount;
  final String status;
  final String paymentMethod;
  final DateTime orderDate;
  final DateTime? paymentConfirmedAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.totalAmount,
    required this.status,
    required this.paymentMethod,
    required this.orderDate,
    this.paymentConfirmedAt,
    required this.items,
  });

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Ожидает подтверждения оплаты';
      case 'paid':
        return 'Оплачен ✓';
      case 'completed':
        return 'Завершен';
      case 'cancelled':
        return 'Отменен';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      paymentMethod: json['payment_method'] ?? '',
      orderDate: DateTime.parse(json['order_date']),
      paymentConfirmedAt: json['payment_confirmed_at'] != null 
          ? DateTime.parse(json['payment_confirmed_at']) 
          : null,
      items: (json['items'] as List?)
          ?.map((i) => OrderItem.fromJson(i))
          .toList() ?? [],
    );
  }
}