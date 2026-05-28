from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required, user_passes_test
from django.contrib.auth import login, authenticate, logout
from django.contrib.auth.forms import AuthenticationForm
from django.contrib import messages
from django.db.models import Q, Sum, Count, F, DecimalField, OuterRef, Subquery
from django.db.models.functions import Coalesce
from django.utils import timezone
from django.core.paginator import Paginator
from datetime import datetime, timedelta
from decimal import Decimal
from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.db import transaction
import json

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Spacer, Paragraph
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch, mm
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import io
import os

from .models import (
    Book, Author, Genre, Report, Sale, Review, Cart, CartItem,
    Order, Favorite, ReadingWishlist, Profile, Notification
)
from .forms import (
    AuthorForm, BookForm, GenreForm, ReportForm, SaleForm
)

# Регистрируем русские шрифты для PDF
try:
    font_paths = [
        "C:/Windows/Fonts/arial.ttf",
        "C:/Windows/Fonts/times.ttf",
        "C:/Windows/Fonts/arial.ttf",
    ]
    
    font_registered = False
    for font_path in font_paths:
        if os.path.exists(font_path):
            pdfmetrics.registerFont(TTFont('RussianFont', font_path))
            font_registered = True
            break
    
    if not font_registered:
        print("Предупреждение: Русские шрифты не найдены. Текст может отображаться некорректно.")
except Exception as e:
    print(f"Ошибка при регистрации шрифта: {e}")


def is_merchandiser(user):
    """Проверка, является ли пользователь товароведом"""
    if not user.is_authenticated:
        return False
    try:
        return user.profile.role == 'merchandiser'
    except Profile.DoesNotExist:
        return False


def is_admin(user):
    """Проверка, является ли пользователь администратором БД"""
    if not user.is_authenticated:
        return False
    try:
        return user.profile.role == 'admin'
    except Profile.DoesNotExist:
        return False


# ==================== АВТОРИЗАЦИЯ ====================

def user_login(request):
    """Вход в систему (только для товароведа и администратора)"""
    if request.method == 'POST':
        form = AuthenticationForm(data=request.POST)
        if form.is_valid():
            user = form.get_user()
            
            try:
                profile = user.profile
                if profile.role not in ['merchandiser', 'admin']:
                    messages.error(request, 'Доступ запрещен. Только для сотрудников магазина.')
                    return redirect('login')
            except Profile.DoesNotExist:
                messages.error(request, 'Доступ запрещен. Только для сотрудников магазина.')
                return redirect('login')
            
            login(request, user)
            messages.success(request, f'Добро пожаловать, {user.username}!')
            
            profile.last_login_at = timezone.now()
            profile.save()
            
            return redirect('merchandiser_dashboard')
    else:
        form = AuthenticationForm()
    return render(request, 'store/auth/login.html', {'form': form})


def user_logout(request):
    """Выход из системы"""
    logout(request)
    messages.info(request, 'Вы вышли из системы')
    return redirect('login')


# ==================== ТОВАРОВЕД ====================

@login_required
@user_passes_test(is_merchandiser)
def merchandiser_dashboard(request):
    """Дашборд товароведа с реальными данными"""
    total_books = Book.objects.count()
    draft_books = Book.objects.filter(status='draft').count()
    published_books = Book.objects.filter(status='published').count()
    archived_books = Book.objects.filter(status='archived').count()
    draft_books_list = Book.objects.filter(status='draft')[:5]
    
    now = timezone.now()
    active_sales = Sale.objects.filter(start_date__lte=now, end_date__gte=now).count()
    recent_reviews = Review.objects.select_related('user', 'book').order_by('-created_at')[:10]
    
    # Статистика по корзинам
    active_carts = Cart.objects.filter(status='active').count()
    ordered_carts = Cart.objects.filter(status='ordered').count()
    paid_carts = Cart.objects.filter(status='paid').count()
    
    thirty_days_ago = now - timedelta(days=30)
    
    recent_orders = Order.objects.filter(
        order_date__gte=thirty_days_ago,
        status__in=['paid', 'completed']
    )
    
    total_revenue = recent_orders.aggregate(total=Coalesce(Sum('total_amount'), Decimal('0')))['total']
    total_orders = recent_orders.count()
    
    sales_by_day = []
    for i in range(30, -1, -1):
        day = now - timedelta(days=i)
        day_start = datetime(day.year, day.month, day.day, 0, 0, 0)
        day_end = datetime(day.year, day.month, day.day, 23, 59, 59)
        day_orders = Order.objects.filter(
            order_date__gte=day_start,
            order_date__lte=day_end,
            status__in=['paid', 'completed']
        )
        day_revenue = day_orders.aggregate(total=Coalesce(Sum('total_amount'), Decimal('0')))['total']
        sales_by_day.append({
            'date': day.strftime('%d.%m'),
            'revenue': float(day_revenue),
            'orders': day_orders.count()
        })
    
    top_books = []
    book_sales = CartItem.objects.filter(
        cart__order__in=recent_orders,
        cart__order__isnull=False
    ).values('book__id', 'book__title', 'book__price').annotate(
        total_sold=Count('id'),
        total_revenue=Sum(F('book__price'))
    ).order_by('-total_sold')[:5]
    
    for item in book_sales:
        top_books.append({
            'title': item['book__title'],
            'sales_count': item['total_sold'],
            'revenue': float(item['total_revenue'] or 0)
        })
    
    context = {
        'total_books': total_books,
        'draft_books': draft_books,
        'published_books': published_books,
        'archived_books': archived_books,
        'draft_books_list': draft_books_list,
        'active_sales': active_sales,
        'recent_reviews': recent_reviews,
        'total_revenue': float(total_revenue),
        'total_orders': total_orders,
        'sales_by_day': sales_by_day,
        'top_books': top_books,
        'active_carts': active_carts,
        'ordered_carts': ordered_carts,
        'paid_carts': paid_carts,
    }
    return render(request, 'store/merchandiser/dashboard.html', context)


@login_required
@user_passes_test(is_merchandiser)
def book_list_merchandiser(request):
    """Список книг для товароведа с реальными данными"""
    books = Book.objects.all().order_by('-created_at')

    status_filter = request.GET.get('status')
    if status_filter:
        books = books.filter(status=status_filter)

    search_query = request.GET.get('search')
    if search_query:
        books = books.filter(
            Q(title__icontains=search_query) |
            Q(authors__first_name__icontains=search_query) |
            Q(authors__last_name__icontains=search_query)
        ).distinct()

    paginator = Paginator(books, 20)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)

    context = {
        'books': page_obj,
        'status_filter': status_filter,
        'search_query': search_query,
        'status_choices': Book.StatusChoices.choices,
    }
    return render(request, 'store/merchandiser/book_list.html', context)


@login_required
@user_passes_test(is_merchandiser)
def book_create(request):
    """Создание новой книги"""
    if request.method == 'POST':
        form = BookForm(request.POST, request.FILES)
        if form.is_valid():
            book = form.save()
            messages.success(request, f'Книга "{book.title}" успешно создана')
            return redirect('merchandiser_book_list')
    else:
        form = BookForm()

    context = {'form': form, 'title': 'Создание книги'}
    return render(request, 'store/merchandiser/book_form.html', context)


@login_required
@user_passes_test(is_merchandiser)
def book_edit(request, book_id):
    """Редактирование книги"""
    book = get_object_or_404(Book, id=book_id)

    if request.method == 'POST':
        form = BookForm(request.POST, request.FILES, instance=book)
        if form.is_valid():
            book = form.save()
            messages.success(request, f'Книга "{book.title}" успешно обновлена')
            return redirect('merchandiser_book_list')
    else:
        form = BookForm(instance=book)

    context = {'form': form, 'book': book, 'title': 'Редактирование книги'}
    return render(request, 'store/merchandiser/book_form.html', context)


@login_required
@user_passes_test(is_merchandiser)
def book_change_status(request, book_id, status):
    """Изменение статуса книги"""
    book = get_object_or_404(Book, id=book_id)

    if status in dict(Book.StatusChoices.choices):
        book.status = status
        if status == 'published' and not book.published_at:
            book.published_at = timezone.now()
        book.save()
        messages.success(request, f'Статус книги "{book.title}" изменен на "{book.get_status_display()}"')

    return redirect('merchandiser_book_list')


@login_required
@user_passes_test(is_merchandiser)
def sale_list(request):
    """Список акций"""
    sales = Sale.objects.all().order_by('-start_date')
    now = timezone.now()

    if request.GET.get('active'):
        sales = sales.filter(start_date__lte=now, end_date__gte=now)

    context = {
        'sales': sales, 
        'show_active_only': request.GET.get('active'), 
        'now': now
    }
    return render(request, 'store/merchandiser/sale_list.html', context)


@login_required
@user_passes_test(is_merchandiser)
def sale_create(request):
    """Создание акции с множественным выбором книг"""
    if request.method == 'POST':
        form = SaleForm(request.POST)
        if form.is_valid():
            sale = form.save()
            books_count = sale.books.count()
            messages.success(request, f'Акция "{sale.name}" успешно создана для {books_count} книг')
            return redirect('merchandiser_sale_list')
    else:
        form = SaleForm()
        # Передаём список книг для отображения в форме
        form.fields['books'].queryset = Book.objects.filter(status='published').order_by('title')

    context = {'form': form, 'title': 'Создание акции'}
    return render(request, 'store/merchandiser/sale_form.html', context)


@login_required
@user_passes_test(is_merchandiser)
def sale_edit(request, sale_id):
    """Редактирование акции с множественным выбором книг"""
    sale = get_object_or_404(Sale, id=sale_id)

    if request.method == 'POST':
        form = SaleForm(request.POST, instance=sale)
        if form.is_valid():
            sale = form.save()
            books_count = sale.books.count()
            messages.success(request, f'Акция "{sale.name}" успешно обновлена для {books_count} книг')
            return redirect('merchandiser_sale_list')
    else:
        form = SaleForm(instance=sale)
        form.fields['books'].queryset = Book.objects.filter(status='published').order_by('title')

    context = {'form': form, 'sale': sale, 'title': 'Редактирование акции'}
    return render(request, 'store/merchandiser/sale_form.html', context)


@login_required
@user_passes_test(is_merchandiser)
def sale_delete(request, sale_id):
    """Удаление акции"""
    sale = get_object_or_404(Sale, id=sale_id)
    sale_name = sale.name
    sale.delete()
    messages.success(request, f'Акция "{sale_name}" успешно удалена')
    return redirect('merchandiser_sale_list')


@login_required
@user_passes_test(is_merchandiser)
def reports(request):
    """Страница отчетов товароведа со списком сформированных отчетов"""
    report_list = Report.objects.filter(created_by=request.user)
    
    status_filter = request.GET.get('status')
    if status_filter:
        report_list = report_list.filter(status=status_filter)
    
    context = {
        'reports': report_list,
        'status_filter': status_filter,
        'status_choices': Report.ReportStatusChoices.choices,
    }
    return render(request, 'store/merchandiser/reports_list.html', context)


@login_required
@user_passes_test(is_merchandiser)
def report_create(request):
    """Создание нового отчета с реальными данными"""
    if request.method == 'POST':
        form = ReportForm(request.POST)
        if form.is_valid():
            period = form.cleaned_data['period']
            if period == 'week':
                end_date = timezone.now().date()
                start_date = end_date - timedelta(days=7)
            elif period == 'month':
                end_date = timezone.now().date()
                start_date = end_date - timedelta(days=30)
            elif period == 'year':
                end_date = timezone.now().date()
                start_date = end_date - timedelta(days=365)
            else:
                start_date = form.cleaned_data['start_date']
                end_date = form.cleaned_data['end_date']
            
            # Получаем заказы за период
            orders = Order.objects.filter(
                order_date__date__gte=start_date,
                order_date__date__lte=end_date,
                status__in=['paid', 'completed']
            )
            
            total_revenue = orders.aggregate(total=Coalesce(Sum('total_amount'), Decimal('0')))['total']
            total_orders_count = orders.count()
            
            books_sales = []
            book_sales_data = CartItem.objects.filter(
                cart__order__in=orders,
                cart__order__isnull=False
            ).values('book__id', 'book__title', 'book__price').annotate(
                sales_count=Count('id')
            ).order_by('-sales_count')
            
            for item in book_sales_data[:10]:
                books_sales.append({
                    'book_id': item['book__id'],
                    'book_title': item['book__title'],
                    'sales_count': item['sales_count'],
                    'revenue': float(item['sales_count'] * item['book__price']),
                })
            
            genre_sales = []
            for genre in Genre.objects.all():
                sales_count = CartItem.objects.filter(
                    book__genres=genre,
                    cart__order__in=orders,
                    cart__order__isnull=False
                ).count()
                if sales_count > 0:
                    genre_sales.append({
                        'genre_id': genre.id,
                        'genre_name': genre.name,
                        'sales_count': sales_count
                    })
            genre_sales.sort(key=lambda x: x['sales_count'], reverse=True)
            
            popular_books = Book.objects.filter(status='published').order_by('-views_count')[:10]
            popular_books_data = []
            for book in popular_books:
                popular_books_data.append({
                    'book_id': book.id,
                    'book_title': book.title,
                    'views_count': book.views_count
                })
            
            daily_sales = []
            current_date = start_date
            while current_date <= end_date:
                day_orders = orders.filter(order_date__date=current_date)
                day_revenue = day_orders.aggregate(total=Coalesce(Sum('total_amount'), Decimal('0')))['total']
                daily_sales.append({
                    'date': current_date.strftime('%d.%m.%Y'),
                    'revenue': float(day_revenue),
                    'orders': day_orders.count()
                })
                current_date += timedelta(days=1)
            
            report_data = {
                'period': {
                    'start_date': start_date.isoformat(),
                    'end_date': end_date.isoformat()
                },
                'summary': {
                    'total_revenue': float(total_revenue),
                    'total_orders_count': total_orders_count
                },
                'books_sales': books_sales,
                'genre_sales': genre_sales[:10],
                'popular_books': popular_books_data,
                'daily_sales': daily_sales
            }
            
            report = Report.objects.create(
                title=form.cleaned_data['title'],
                report_type=form.cleaned_data['report_type'],
                start_date=start_date,
                end_date=end_date,
                data=report_data,
                created_by=request.user
            )
            
            messages.success(request, f'Отчет "{report.title}" успешно создан')
            return redirect('merchandiser_reports')
    else:
        form = ReportForm()
    
    context = {
        'form': form,
        'title': 'Создание отчета'
    }
    return render(request, 'store/merchandiser/report_form.html', context)


@login_required
@user_passes_test(is_merchandiser)
def report_view(request, report_id):
    """Просмотр сформированного отчета с реальными данными"""
    report = get_object_or_404(Report, id=report_id, created_by=request.user)
    
    context = {
        'report': report,
        'data': report.data,
    }
    return render(request, 'store/merchandiser/report_detail.html', context)


@login_required
@user_passes_test(is_merchandiser)
def report_export_pdf(request, report_id):
    """Экспорт отчета в PDF с поддержкой русского языка"""
    report = get_object_or_404(Report, id=report_id, created_by=request.user)
    data = report.data
    
    buffer = io.BytesIO()
    
    doc = SimpleDocTemplate(
        buffer, 
        pagesize=A4,
        rightMargin=72,
        leftMargin=72,
        topMargin=72,
        bottomMargin=72,
    )
    
    try:
        font_name = 'RussianFont'
        pdfmetrics.registerFont(TTFont(font_name, "C:/Windows/Fonts/arial.ttf"))
    except:
        font_name = 'Helvetica'
    
    styles = getSampleStyleSheet()
    
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontName=font_name,
        fontSize=24,
        textColor=colors.HexColor('#2c3e50'),
        spaceAfter=30,
        alignment=TA_CENTER,
        encoding='utf-8'
    )
    
    heading_style = ParagraphStyle(
        'CustomHeading',
        parent=styles['Heading2'],
        fontName=font_name,
        fontSize=16,
        textColor=colors.HexColor('#34495e'),
        spaceAfter=12,
        spaceBefore=20,
        encoding='utf-8'
    )
    
    normal_style = ParagraphStyle(
        'CustomNormal',
        parent=styles['Normal'],
        fontName=font_name,
        fontSize=10,
        encoding='utf-8'
    )
    
    table_header_style = ParagraphStyle(
        'TableHeader',
        parent=normal_style,
        fontName=font_name,
        fontSize=10,
        textColor=colors.white,
        alignment=TA_CENTER,
        encoding='utf-8'
    )
    
    elements = []
    
    elements.append(Paragraph(report.title, title_style))
    elements.append(Spacer(1, 0.2*inch))
    
    info_data = [
        [Paragraph('<b>Тип отчета:</b>', normal_style), Paragraph(report.get_report_type_display(), normal_style)],
        [Paragraph('<b>Период:</b>', normal_style), Paragraph(f"{report.start_date.strftime('%d.%m.%Y')} - {report.end_date.strftime('%d.%m.%Y')}", normal_style)],
        [Paragraph('<b>Дата создания:</b>', normal_style), Paragraph(report.created_at.strftime('%d.%m.%Y %H:%M'), normal_style)],
        [Paragraph('<b>Создал:</b>', normal_style), Paragraph(report.created_by.get_full_name() or report.created_by.username, normal_style)],
    ]
    
    info_table = Table(info_data, colWidths=[2*inch, 4*inch])
    info_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (0, -1), colors.lightgrey),
        ('TEXTCOLOR', (0, 0), (0, -1), colors.black),
        ('ALIGN', (0, 0), (0, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('FONTNAME', (0, 0), (-1, -1), font_name),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
        ('TOPPADDING', (0, 0), (-1, -1), 8),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
    ]))
    elements.append(info_table)
    elements.append(Spacer(1, 0.3*inch))
    
    if data and data.get('summary'):
        elements.append(Paragraph('Общая статистика', heading_style))
        
        summary_data = [
            [Paragraph('<b>Выручка:</b>', normal_style), Paragraph(f"{data['summary']['total_revenue']:,.2f} ₽", normal_style)],
            [Paragraph('<b>Количество заказов:</b>', normal_style), Paragraph(str(data['summary']['total_orders_count']), normal_style)],
        ]
        
        summary_table = Table(summary_data, colWidths=[2*inch, 2*inch])
        summary_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (0, -1), colors.HexColor('#e8f4f8')),
            ('TEXTCOLOR', (0, 0), (0, -1), colors.black),
            ('ALIGN', (0, 0), (0, -1), 'LEFT'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('FONTNAME', (0, 0), (-1, -1), font_name),
            ('FONTSIZE', (0, 0), (-1, -1), 11),
            ('TOPPADDING', (0, 0), (-1, -1), 10),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 10),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ]))
        elements.append(summary_table)
        elements.append(Spacer(1, 0.3*inch))
    
    if data and data.get('books_sales') and len(data['books_sales']) > 0:
        elements.append(Paragraph('Топ книг по продажам', heading_style))
        
        books_table_data = [
            [Paragraph('<b>№</b>', table_header_style), Paragraph('<b>Название книги</b>', table_header_style), 
             Paragraph('<b>Продано, шт</b>', table_header_style), Paragraph('<b>Выручка, ₽</b>', table_header_style)]
        ]
        
        for i, item in enumerate(data['books_sales'][:10], 1):
            books_table_data.append([
                str(i),
                Paragraph(item['book_title'][:50], normal_style),
                str(item['sales_count']),
                f"{item['revenue']:,.2f}"
            ])
        
        books_table = Table(books_table_data, colWidths=[0.5*inch, 3.5*inch, 1*inch, 1.5*inch])
        books_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#2c3e50')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('ALIGN', (2, 1), (3, -1), 'RIGHT'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('FONTNAME', (0, 0), (-1, -1), font_name),
            ('FONTSIZE', (0, 0), (-1, -1), 9),
            ('TOPPADDING', (0, 0), (-1, -1), 6),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
            ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
        ]))
        elements.append(books_table)
        elements.append(Spacer(1, 0.3*inch))
    
    if data and data.get('genre_sales') and len(data['genre_sales']) > 0:
        elements.append(Paragraph('Продажи по жанрам', heading_style))
        
        genre_table_data = [
            [Paragraph('<b>№</b>', table_header_style), Paragraph('<b>Жанр</b>', table_header_style), Paragraph('<b>Продано, шт</b>', table_header_style)]
        ]
        
        for i, item in enumerate(data['genre_sales'][:10], 1):
            genre_table_data.append([
                str(i),
                Paragraph(item['genre_name'], normal_style),
                str(item['sales_count'])
            ])
        
        genre_table = Table(genre_table_data, colWidths=[0.5*inch, 4*inch, 1.5*inch])
        genre_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#2c3e50')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('ALIGN', (2, 1), (2, -1), 'RIGHT'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('FONTNAME', (0, 0), (-1, -1), font_name),
            ('FONTSIZE', (0, 0), (-1, -1), 9),
            ('TOPPADDING', (0, 0), (-1, -1), 6),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
            ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
        ]))
        elements.append(genre_table)
        elements.append(Spacer(1, 0.3*inch))
    
    if data and data.get('popular_books') and len(data['popular_books']) > 0:
        elements.append(Paragraph('Популярные книги (по просмотрам)', heading_style))
        
        popular_table_data = [
            [Paragraph('<b>№</b>', table_header_style), Paragraph('<b>Название книги</b>', table_header_style), Paragraph('<b>Просмотры</b>', table_header_style)]
        ]
        
        for i, item in enumerate(data['popular_books'][:10], 1):
            popular_table_data.append([
                str(i),
                Paragraph(item['book_title'][:50], normal_style),
                str(item['views_count'])
            ])
        
        popular_table = Table(popular_table_data, colWidths=[0.5*inch, 4*inch, 1.5*inch])
        popular_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#2c3e50')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('ALIGN', (2, 1), (2, -1), 'RIGHT'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('FONTNAME', (0, 0), (-1, -1), font_name),
            ('FONTSIZE', (0, 0), (-1, -1), 9),
            ('TOPPADDING', (0, 0), (-1, -1), 6),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
            ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
        ]))
        elements.append(popular_table)
        elements.append(Spacer(1, 0.3*inch))
    
    if data and data.get('daily_sales') and len(data['daily_sales']) > 0:
        elements.append(Paragraph('Динамика продаж по дням', heading_style))
        
        daily_table_data = [
            [Paragraph('<b>Дата</b>', table_header_style), Paragraph('<b>Выручка, ₽</b>', table_header_style), Paragraph('<b>Заказов</b>', table_header_style)]
        ]
        
        display_sales = data['daily_sales'][-30:] if len(data['daily_sales']) > 30 else data['daily_sales']
        
        for item in display_sales:
            daily_table_data.append([
                item['date'],
                f"{item['revenue']:,.2f}",
                str(item['orders'])
            ])
        
        daily_table = Table(daily_table_data, colWidths=[1.5*inch, 2*inch, 1.5*inch])
        daily_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#2c3e50')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('FONTNAME', (0, 0), (-1, -1), font_name),
            ('FONTSIZE', (0, 0), (-1, -1), 8),
            ('TOPPADDING', (0, 0), (-1, -1), 4),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ('GRID', (0, 0), (-1, -1), 0.25, colors.grey),
            ('BACKGROUND', (0, 1), (-1, -1), colors.white),
        ]))
        elements.append(daily_table)
    
    elements.append(Spacer(1, 0.5*inch))
    footer_text = Paragraph(
        f'<i>Отчет сгенерирован автоматически в системе "БукЛайф" {timezone.now().strftime("%d.%m.%Y %H:%M")}</i>',
        ParagraphStyle('Footer', parent=normal_style, fontSize=8, textColor=colors.grey, alignment=TA_CENTER, fontName=font_name)
    )
    elements.append(footer_text)
    
    doc.build(elements)
    
    pdf = buffer.getvalue()
    buffer.close()
    
    response = HttpResponse(pdf, content_type='application/pdf')
    response['Content-Disposition'] = f'attachment; filename="report_{report.id}_{report.title.replace(" ", "_")}.pdf"'
    
    return response


@login_required
@user_passes_test(is_merchandiser)
def report_archive(request, report_id):
    """Отправить отчет в архив"""
    report = get_object_or_404(Report, id=report_id, created_by=request.user)
    report.archive()
    messages.success(request, f'Отчет "{report.title}" отправлен в архив')
    return redirect('merchandiser_reports')


@login_required
@user_passes_test(is_merchandiser)
def report_delete(request, report_id):
    """Удаление отчета"""
    report = get_object_or_404(Report, id=report_id, created_by=request.user)
    report_title = report.title
    report.delete()
    messages.success(request, f'Отчет "{report_title}" удален')
    return redirect('merchandiser_reports')


# ==================== УПРАВЛЕНИЕ КОРЗИНАМИ ДЛЯ ТОВАРОВЕДА ====================

@login_required
@user_passes_test(is_merchandiser)
def cart_list_merchandiser(request):
    """Список всех корзин для товароведа"""
    carts = Cart.objects.all().order_by('-created_at')
    
    status_filter = request.GET.get('status')
    if status_filter:
        carts = carts.filter(status=status_filter)
    
    user_search = request.GET.get('user_search')
    if user_search:
        carts = carts.filter(
            Q(user__username__icontains=user_search) |
            Q(user__email__icontains=user_search) |
            Q(user__first_name__icontains=user_search) |
            Q(user__last_name__icontains=user_search)
        )
    
    paginator = Paginator(carts, 20)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    context = {
        'carts': page_obj,
        'status_filter': status_filter,
        'user_search': user_search,
        'status_choices': Cart.CartStatusChoices.choices,
    }
    return render(request, 'store/merchandiser/cart_list.html', context)


@login_required
@user_passes_test(is_merchandiser)
def cart_detail_merchandiser(request, cart_id):
    """Детальный просмотр корзины"""
    cart = get_object_or_404(Cart, id=cart_id)
    
    if request.method == 'POST':
        new_status = request.POST.get('status')
        if new_status in dict(Cart.CartStatusChoices.choices):
            old_status = cart.status
            cart.status = new_status
            cart.save()
            
            # Если корзина связана с заказом и статус становится paid
            if hasattr(cart, 'order') and cart.order and new_status == 'paid':
                order = cart.order
                if order.status == 'pending':
                    order.status = 'paid'
                    order.payment_confirmed_at = timezone.now()
                    order.save()
                    
                    # Создаем уведомление для пользователя
                    Notification.objects.create(
                        user=order.user,
                        title='Оплата подтверждена',
                        message=f'Товаровед подтвердил оплату заказа №{order.id}. Книги доступны для чтения.',
                        type='payment',
                        data={'order_id': order.id}
                    )
            
            messages.success(request, f'Статус корзины изменен с "{old_status}" на "{new_status}"')
        else:
            messages.error(request, 'Неверный статус')
        
        return redirect('merchandiser_cart_detail', cart_id=cart_id)
    
    context = {
        'cart': cart,
        'status_choices': Cart.CartStatusChoices.choices,
    }
    return render(request, 'store/merchandiser/cart_detail.html', context)

# ==================== УПРАВЛЕНИЕ АВТОРАМИ ====================

@login_required
@user_passes_test(is_merchandiser)
def author_list(request):
    """Список всех авторов"""
    authors = Author.objects.all().order_by('last_name', 'first_name')
    
    search_query = request.GET.get('search')
    if search_query:
        authors = authors.filter(
            Q(first_name__icontains=search_query) |
            Q(last_name__icontains=search_query)
        )
    
    paginator = Paginator(authors, 20)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    context = {
        'authors': page_obj,
        'search_query': search_query,
    }
    return render(request, 'store/merchandiser/author_list.html', context)


@login_required
@user_passes_test(is_merchandiser)
def author_create(request):
    """Создание нового автора"""
    if request.method == 'POST':
        form = AuthorForm(request.POST)
        if form.is_valid():
            author = form.save()
            messages.success(request, f'Автор "{author.first_name} {author.last_name}" успешно создан')
            return redirect('merchandiser_author_list')
    else:
        form = AuthorForm()
    
    context = {'form': form, 'title': 'Создание автора'}
    return render(request, 'store/merchandiser/author_form.html', context)


@login_required
@user_passes_test(is_merchandiser)
def author_edit(request, author_id):
    """Редактирование автора"""
    author = get_object_or_404(Author, id=author_id)
    
    if request.method == 'POST':
        form = AuthorForm(request.POST, instance=author)
        if form.is_valid():
            author = form.save()
            messages.success(request, f'Автор "{author.first_name} {author.last_name}" успешно обновлен')
            return redirect('merchandiser_author_list')
    else:
        form = AuthorForm(instance=author)
    
    context = {'form': form, 'author': author, 'title': 'Редактирование автора'}
    return render(request, 'store/merchandiser/author_form.html', context)


@login_required
@user_passes_test(is_merchandiser)
def author_delete(request, author_id):
    """Удаление автора"""
    author = get_object_or_404(Author, id=author_id)
    author_name = f"{author.first_name} {author.last_name}"
    
    # Проверяем, есть ли книги у этого автора
    if author.books.exists():
        messages.error(request, f'Невозможно удалить автора "{author_name}", так как он связан с книгами')
    else:
        author.delete()
        messages.success(request, f'Автор "{author_name}" успешно удален')
    
    return redirect('merchandiser_author_list')


# ==================== УПРАВЛЕНИЕ ЖАНРАМИ ====================

@login_required
@user_passes_test(is_merchandiser)
def genre_list(request):
    """Список всех жанров"""
    genres = Genre.objects.all().order_by('name')
    
    search_query = request.GET.get('search')
    if search_query:
        genres = genres.filter(name__icontains=search_query)
    
    paginator = Paginator(genres, 20)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    context = {
        'genres': page_obj,
        'search_query': search_query,
    }
    return render(request, 'store/merchandiser/genre_list.html', context)


@login_required
@user_passes_test(is_merchandiser)
def genre_create(request):
    """Создание нового жанра"""
    if request.method == 'POST':
        form = GenreForm(request.POST)
        if form.is_valid():
            genre = form.save()
            messages.success(request, f'Жанр "{genre.name}" успешно создан')
            return redirect('merchandiser_genre_list')
    else:
        form = GenreForm()
    
    context = {'form': form, 'title': 'Создание жанра'}
    return render(request, 'store/merchandiser/genre_form.html', context)


@login_required
@user_passes_test(is_merchandiser)
def genre_edit(request, genre_id):
    """Редактирование жанра"""
    genre = get_object_or_404(Genre, id=genre_id)
    
    if request.method == 'POST':
        form = GenreForm(request.POST, instance=genre)
        if form.is_valid():
            genre = form.save()
            messages.success(request, f'Жанр "{genre.name}" успешно обновлен')
            return redirect('merchandiser_genre_list')
    else:
        form = GenreForm(instance=genre)
    
    context = {'form': form, 'genre': genre, 'title': 'Редактирование жанра'}
    return render(request, 'store/merchandiser/genre_form.html', context)


@login_required
@user_passes_test(is_merchandiser)
def genre_delete(request, genre_id):
    """Удаление жанра"""
    genre = get_object_or_404(Genre, id=genre_id)
    genre_name = genre.name
    
    if genre.books.exists():
        messages.error(request, f'Невозможно удалить жанр "{genre_name}", так как он связан с книгами')
    else:
        genre.delete()
        messages.success(request, f'Жанр "{genre_name}" успешно удален')
    
    return redirect('merchandiser_genre_list')