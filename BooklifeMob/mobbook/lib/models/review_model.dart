class Review {
  final int id;
  final int userId;
  final String userName;
  final String? userAvatar;
  final int bookId;
  final int rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.bookId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      userId: json['user_id'],
      userName: json['user_name'] ?? 'Пользователь',
      userAvatar: json['user_avatar'],
      bookId: json['book_id'],
      rating: json['rating'],
      comment: json['comment'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}