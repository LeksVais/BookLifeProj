class Author {
  final int id;
  final String firstName;
  final String lastName;
  final String? bio;

  Author({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.bio,
  });

  String get fullName => '$firstName $lastName';

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      bio: json['bio'],
    );
  }
}

class Genre {
  final int id;
  final String name;
  final String? description;

  Genre({
    required this.id,
    required this.name,
    this.description,
  });

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'],
      name: json['name'],
      description: json['description'],
    );
  }
}

class Book {
  final int id;
  final String title;
  final String description;
  final int pageCount;
  final int publicationYear;
  final String ageRating;
  final String? coverImageUrl;
  final String? bookFileUrl;
  final String? bookFileType;
  final double price;
  final double? salePrice;
  final int? discountPercent;
  final String status;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final List<Author> authors;
  final List<Genre> genres;
  final int viewsCount;
  final double? averageRating;
  final int? reviewsCount;

  Book({
    required this.id,
    required this.title,
    required this.description,
    required this.pageCount,
    required this.publicationYear,
    required this.ageRating,
    this.coverImageUrl,
    this.bookFileUrl,
    this.bookFileType,
    required this.price,
    this.salePrice,
    this.discountPercent,
    required this.status,
    required this.createdAt,
    this.publishedAt,
    required this.authors,
    required this.genres,
    required this.viewsCount,
    this.averageRating,
    this.reviewsCount,
  });

  double get currentPrice => salePrice ?? price;
  
  bool get hasDiscount => discountPercent != null && discountPercent! > 0;
  
  bool get hasBookFile => bookFileUrl != null && bookFileUrl!.isNotEmpty;

  factory Book.fromJson(Map<String, dynamic> json) {
    String? coverUrl = json['cover_image_url'];
    if (coverUrl != null && coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
      coverUrl = 'http://10.0.2.2:8000$coverUrl';
    }
    
    String? bookFileUrl = json['book_file_url'];
    if (bookFileUrl != null && bookFileUrl.isNotEmpty && !bookFileUrl.startsWith('http')) {
      bookFileUrl = 'http://10.0.2.2:8000$bookFileUrl';
    }
    
    return Book(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      pageCount: json['page_count'] ?? 0,
      publicationYear: json['publication_year'] ?? 0,
      ageRating: json['age_rating'] ?? '0+',
      coverImageUrl: coverUrl,
      bookFileUrl: bookFileUrl,
      bookFileType: json['book_file_type'] ?? 'pdf',
      price: (json['price'] ?? 0).toDouble(),
      salePrice: json['sale_price'] != null 
          ? (json['sale_price'] as num).toDouble() 
          : null,
      discountPercent: json['discount_percent'],
      status: json['status'] ?? 'draft',
      createdAt: DateTime.parse(json['created_at']),
      publishedAt: json['published_at'] != null 
          ? DateTime.parse(json['published_at']) 
          : null,
      authors: (json['authors'] as List?)
          ?.map((a) => Author.fromJson(a))
          .toList() ?? [],
      genres: (json['genres'] as List?)
          ?.map((g) => Genre.fromJson(g))
          .toList() ?? [],
      viewsCount: json['views_count'] ?? 0,
      averageRating: json['average_rating'] != null 
          ? (json['average_rating'] as num).toDouble() 
          : null,
      reviewsCount: json['reviews_count'],
    );
  }
}