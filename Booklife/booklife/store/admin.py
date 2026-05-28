from django.contrib import admin
from django.utils.html import format_html
from .models import Profile, Author, Genre, Book, Report, Sale, Review, Cart, CartItem, Order, Favorite, ReadingWishlist


@admin.register(Profile)
class ProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'phone', 'role', 'date_of_birth')
    search_fields = ('user__username', 'user__email', 'phone')
    list_filter = ('role', 'date_of_birth')


@admin.register(Author)
class AuthorAdmin(admin.ModelAdmin):
    list_display = ('first_name', 'last_name')
    search_fields = ('first_name', 'last_name')


@admin.register(Genre)
class GenreAdmin(admin.ModelAdmin):
    list_display = ('name',)
    search_fields = ('name',)


@admin.register(Book)
class BookAdmin(admin.ModelAdmin):
    list_display = ('title', 'display_authors', 'price', 'status', 'age_rating', 'views_count')
    list_filter = ('status', 'age_rating', 'genres')
    search_fields = ('title', 'authors__first_name', 'authors__last_name')
    filter_horizontal = ('authors', 'genres')

    def display_authors(self, obj):
        return ", ".join([str(author) for author in obj.authors.all()])
    display_authors.short_description = 'Авторы'


@admin.register(Sale)
class SaleAdmin(admin.ModelAdmin):
    list_display = ('name', 'display_books', 'discount_percent', 'start_date', 'end_date', 'is_active')
    list_filter = ('start_date', 'end_date')
    search_fields = ('name', 'books__title')
    filter_horizontal = ('books',)
    
    def display_books(self, obj):
        books = obj.books.all()
        if books.count() > 3:
            return f"{', '.join([b.title[:30] for b in books[:3]])} и ещё {books.count() - 3}"
        return ", ".join([b.title for b in books])
    display_books.short_description = 'Книги'
    
    def is_active(self, obj):
        return obj.is_active()
    is_active.boolean = True
    is_active.short_description = 'Активна'


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ('user', 'book', 'rating', 'created_at')
    list_filter = ('rating', 'created_at')
    search_fields = ('user__username', 'book__title', 'comment')


@admin.register(Cart)
class CartAdmin(admin.ModelAdmin):
    list_display = ('user', 'status', 'created_at', 'updated_at')
    list_filter = ('status', 'created_at')


@admin.register(CartItem)
class CartItemAdmin(admin.ModelAdmin):
    list_display = ('cart', 'book', 'added_at')
    list_filter = ('added_at',)


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'total_amount', 'status', 'order_date')
    list_filter = ('status', 'order_date', 'payment_method')
    search_fields = ('user__username', 'cart__id')


@admin.register(Favorite)
class FavoriteAdmin(admin.ModelAdmin):
    list_display = ('user', 'book', 'created_at')
    list_filter = ('created_at',)
    search_fields = ('user__username', 'book__title')


@admin.register(ReadingWishlist)
class ReadingWishlistAdmin(admin.ModelAdmin):
    list_display = ('user', 'book', 'created_at')
    list_filter = ('created_at',)
    search_fields = ('user__username', 'book__title')

@admin.register(Report)
class ReportAdmin(admin.ModelAdmin):
    list_display = ('title', 'report_type', 'status', 'created_by', 'created_at')
    list_filter = ('report_type', 'status', 'created_at')
    search_fields = ('title', 'created_by__username')
    readonly_fields = ('created_at', 'updated_at')