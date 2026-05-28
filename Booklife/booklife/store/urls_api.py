from django.urls import path
from . import views_api

urlpatterns = [
    # Auth
    path('auth/register/', views_api.register_api, name='api_register'),
    path('auth/login/', views_api.login_api, name='api_login'),
    path('auth/logout/', views_api.logout_api, name='api_logout'),
    path('auth/send-reset-code/', views_api.send_reset_code_api, name='api_send_reset_code'),
    path('auth/forgot-password/', views_api.forgot_password_api, name='api_forgot_password'),
    
    # User profile
    path('user/profile/', views_api.profile_api, name='api_profile'),
    path('user/profile/update/', views_api.update_profile_api, name='api_update_profile'),
    path('user/change-password/', views_api.change_password_api, name='api_change_password'),
    path('user/books/', views_api.my_books_api, name='api_user_books'),
    
    # Books
    path('books/', views_api.books_api, name='api_books'),
    path('books/<int:book_id>/', views_api.book_detail_api, name='api_book_detail'),
    path('books/new/', views_api.new_books_api, name='api_new_books'),
    path('books/popular/', views_api.popular_books_api, name='api_popular_books'),
    path('books/recommended/', views_api.recommended_books_api, name='api_recommended_books'),
    
    # Reviews
    path('books/<int:book_id>/reviews/', views_api.book_reviews_api, name='api_book_reviews'),
    path('books/<int:book_id>/reviews/create/', views_api.create_review_api, name='api_create_review'),
    
    # Cart
    path('cart/', views_api.cart_api, name='api_cart'),
    path('cart/add/', views_api.add_to_cart_api, name='api_add_to_cart'),
    path('cart/remove/<int:item_id>/', views_api.remove_from_cart_api, name='api_remove_from_cart'),
    path('cart/update/<int:item_id>/', views_api.update_cart_item_api, name='api_update_cart_item'),
    path('cart/clear/', views_api.clear_cart_api, name='api_clear_cart'),
    
    # Orders
    path('orders/', views_api.orders_api, name='api_orders'),
    path('orders/create/', views_api.create_order_api, name='api_create_order'),
    path('orders/<int:order_id>/', views_api.order_detail_api, name='api_order_detail'),
    path('orders/<int:order_id>/confirm-payment/', views_api.confirm_payment_api, name='api_confirm_payment'),
    
    # Favorites
    path('favorites/', views_api.favorites_api, name='api_favorites'),
    path('favorites/add/', views_api.add_to_favorite_api, name='api_add_to_favorites'),
    path('favorites/remove/<int:book_id>/', views_api.remove_from_favorite_api, name='api_remove_from_favorites'),
    path('favorites/check/<int:book_id>/', views_api.check_favorite_api, name='api_check_favorite'),
    
    # Filters
    path('genres/', views_api.get_genres_api, name='api_genres'),
    path('authors/', views_api.get_authors_api, name='api_authors'),

    # Notifications
    path('notifications/', views_api.notifications_api, name='api_notifications'),
    path('notifications/<int:notification_id>/read/', views_api.mark_notification_read_api, name='api_mark_notification_read'),
    path('notifications/read-all/', views_api.mark_all_notifications_read_api, name='api_mark_all_notifications_read'),
    path('notifications/unread-count/', views_api.unread_count_api, name='api_unread_count'),
    
    # Merchandiser endpoints
    path('merchandiser/carts/', views_api.merchandiser_carts_api, name='api_merchandiser_carts'),
    path('merchandiser/carts/<int:cart_id>/update-status/', views_api.merchandiser_update_cart_status_api, name='api_merchandiser_update_cart_status'),

    path('user/books/check/<int:book_id>/', views_api.check_purchased_api, name='api_check_purchased'),

]