from django.urls import path
from . import views

urlpatterns = [
    # Аутентификация 
    path('login/', views.user_login, name='login'),
    path('logout/', views.user_logout, name='logout'),
    
    # Главная страница товароведа
    path('', views.merchandiser_dashboard, name='merchandiser_dashboard'),
    
    # Управление книгами
    path('books/', views.book_list_merchandiser, name='merchandiser_book_list'),
    path('book/create/', views.book_create, name='merchandiser_book_create'),
    path('book/<int:book_id>/edit/', views.book_edit, name='merchandiser_book_edit'),
    path('book/<int:book_id>/status/<str:status>/', views.book_change_status, name='merchandiser_book_status'),
    
    # Управление авторами
    path('authors/', views.author_list, name='merchandiser_author_list'),
    path('authors/create/', views.author_create, name='merchandiser_author_create'),
    path('authors/<int:author_id>/edit/', views.author_edit, name='merchandiser_author_edit'),
    path('authors/<int:author_id>/delete/', views.author_delete, name='merchandiser_author_delete'),
    
    # Управление жанрами
    path('genres/', views.genre_list, name='merchandiser_genre_list'),
    path('genres/create/', views.genre_create, name='merchandiser_genre_create'),
    path('genres/<int:genre_id>/edit/', views.genre_edit, name='merchandiser_genre_edit'),
    path('genres/<int:genre_id>/delete/', views.genre_delete, name='merchandiser_genre_delete'),
    
    # Управление акциями
    path('sales/', views.sale_list, name='merchandiser_sale_list'),
    path('sale/create/', views.sale_create, name='merchandiser_sale_create'),
    path('sale/<int:sale_id>/edit/', views.sale_edit, name='merchandiser_sale_edit'),
    path('sale/<int:sale_id>/delete/', views.sale_delete, name='merchandiser_sale_delete'),
    
    # Управление корзинами
    path('carts/', views.cart_list_merchandiser, name='merchandiser_cart_list'),
    path('carts/<int:cart_id>/', views.cart_detail_merchandiser, name='merchandiser_cart_detail'),
    
    # Отчеты 
    path('reports/', views.reports, name='merchandiser_reports'),
    path('reports/create/', views.report_create, name='merchandiser_report_create'),
    path('reports/<int:report_id>/', views.report_view, name='merchandiser_report_view'),
    path('reports/<int:report_id>/export/pdf/', views.report_export_pdf, name='merchandiser_report_export_pdf'),
    path('reports/<int:report_id>/archive/', views.report_archive, name='merchandiser_report_archive'),
    path('reports/<int:report_id>/delete/', views.report_delete, name='merchandiser_report_delete'),
]