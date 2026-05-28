from django.shortcuts import get_object_or_404
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.hashers import make_password
from django.db.models import Avg, Count, Q, F, FloatField
from django.db.models.functions import Coalesce, Cast
from django.core.paginator import Paginator
from django.utils import timezone
from django.db import transaction
import json
import random
import traceback

from store.models import (
    Book, Author, Genre, Profile, Review, Cart, CartItem, 
    Order, OrderItem, User, Notification, Favorite, Sale
)


def book_to_json(book, request=None):
    """Преобразует книгу в JSON с полным URL обложки и ссылкой на файл"""
    try:
        cover_url = None
        if book.cover_image and hasattr(book.cover_image, 'url'):
            if request:
                cover_url = request.build_absolute_uri(book.cover_image.url)
            else:
                cover_url = book.cover_image.url
        
        # Получаем URL файла книги
        book_file_url = None
        if book.book_file and hasattr(book.book_file, 'url'):
            if request:
                book_file_url = request.build_absolute_uri(book.book_file.url)
            else:
                book_file_url = book.book_file.url
        
        # Получаем текущую цену со скидкой
        current_price = float(book.get_current_price())
        original_price = float(book.price)
        discount_percent = None
        sale_price = None
        
        if current_price < original_price:
            discount_percent = int((original_price - current_price) / original_price * 100)
            sale_price = current_price
        
        return {
            'id': book.id,
            'title': book.title,
            'description': book.description,
            'page_count': book.page_count,
            'publication_year': book.publication_year,
            'age_rating': book.age_rating,
            'cover_image_url': cover_url,
            'book_file_url': book_file_url,
            'book_file_type': book.book_file_type,
            'price': original_price,
            'sale_price': sale_price,
            'discount_percent': discount_percent,
            'status': book.status,
            'created_at': book.created_at.isoformat(),
            'published_at': book.published_at.isoformat() if book.published_at else None,
            'authors': [{'id': a.id, 'first_name': a.first_name, 'last_name': a.last_name} for a in book.authors.all()],
            'genres': [{'id': g.id, 'name': g.name} for g in book.genres.all()],
            'views_count': book.views_count,
            'average_rating': book.reviews.aggregate(avg_rating=Avg('rating'))['avg_rating'],
            'reviews_count': book.reviews.count(),
        }
    except Exception as e:
        print(f"Error in book_to_json: {e}")
        traceback.print_exc()
        return {
            'id': book.id,
            'title': book.title,
            'error': str(e)
        }


def cart_to_json(cart):
    """Преобразует корзину в JSON с учетом количества (всегда 1 для электронных книг)"""
    if not cart:
        return {
            'id': None,
            'items': [],
            'total_amount': 0,
            'status': 'active',
            'created_at': None,
            'updated_at': None,
        }
    
    items_data = []
    total = 0
    
    for item in cart.items.all():
        current_price = float(item.book.get_current_price())
        original_price = float(item.book.price)  # Явно преобразуем Decimal в float
        # Для электронных книг всегда quantity = 1
        item_total = current_price
        total += item_total
        
        # Безопасное получение URL обложки
        cover_url = None
        if item.book.cover_image and hasattr(item.book.cover_image, 'url'):
            cover_url = item.book.cover_image.url
        
        # Вычисляем скидку, используя float значения
        discount_percent = None
        if current_price < original_price:
            discount_percent = int((original_price - current_price) / original_price * 100)
        
        items_data.append({
            'id': item.id,
            'book_id': item.book.id,
            'book_title': item.book.title,
            'cover_image_url': cover_url,
            'price': current_price,
            'original_price': original_price,
            'discount_percent': discount_percent,
            'quantity': 1,  # Всегда 1 для электронных книг
            'total_price': item_total,
            'added_at': item.added_at.isoformat(),
        })
    
    has_unpaid_order = hasattr(cart, 'order') and cart.order and cart.order.status == 'pending'
    
    return {
        'id': cart.id,
        'items': items_data,
        'items_count': cart.items.count(),
        'total_amount': total,
        'status': cart.status,
        'created_at': cart.created_at.isoformat(),
        'updated_at': cart.updated_at.isoformat(),
        'has_unpaid_order': has_unpaid_order,
    }


def order_to_json(order):
    """Преобразует заказ в JSON"""
    try:
        items = []
        for item in order.items.all():
            cover_url = None
            if item.book.cover_image and hasattr(item.book.cover_image, 'url'):
                cover_url = item.book.cover_image.url
            
            # Получаем URL файла книги
            book_file_url = None
            if item.book.book_file and hasattr(item.book.book_file, 'url'):
                book_file_url = item.book.book_file.url
            
            items.append({
                'id': item.id,
                'book_id': item.book.id,
                'book_title': item.book.title,
                'cover_image_url': cover_url,
                'book_file_url': book_file_url,
                'book_file_type': item.book.book_file_type,
                'price': float(item.price),
                'quantity': item.quantity,
            })
        
        return {
            'id': order.id,
            'total_amount': float(order.total_amount),
            'status': order.status,
            'payment_method': order.payment_method,
            'order_date': order.order_date.isoformat(),
            'payment_confirmed_at': order.payment_confirmed_at.isoformat() if order.payment_confirmed_at else None,
            'items': items,
        }
    except Exception as e:
        print(f"Error in order_to_json: {e}")
        traceback.print_exc()
        return {
            'id': order.id,
            'total_amount': float(order.total_amount),
            'status': order.status,
            'payment_method': order.payment_method,
            'order_date': order.order_date.isoformat(),
            'payment_confirmed_at': order.payment_confirmed_at.isoformat() if order.payment_confirmed_at else None,
            'items': [],
        }


def get_active_cart(user):
    """Получает активную корзину пользователя или создает новую"""
    # Ищем активную корзину
    cart = Cart.objects.filter(user=user, status='active').order_by('-created_at').first()
    
    # Если нет активной корзины, создаем новую
    if not cart:
        cart = Cart.objects.create(user=user, status='active')
    
    return cart


@csrf_exempt
@require_http_methods(["POST"])
def login_api(request):
    try:
        data = json.loads(request.body)
        email = data.get('email')
        password = data.get('password')
        
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return JsonResponse({'error': 'Пользователь не найден'}, status=400)
        
        if user.check_password(password):
            login(request, user)
            
            try:
                profile = user.profile
                phone = profile.phone
                role = profile.role
            except:
                phone = ''
                role = 'buyer'
            
            return JsonResponse({
                'success': True,
                'user': {
                    'id': user.id,
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name,
                    'phone': phone,
                    'avatar_url': None,
                    'role': role,
                }
            }, status=200)  
        else:
            return JsonResponse({'error': 'Неверный пароль'}, status=400)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Неверный формат JSON'}, status=400)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["POST"])
def register_api(request):
    try:
        data = json.loads(request.body)
        
        if User.objects.filter(email=data['email']).exists():
            return JsonResponse({'error': 'User already exists'}, status=400)
        
        user = User.objects.create_user(
            username=data['email'],
            email=data['email'],
            first_name=data.get('first_name', ''),
            last_name=data.get('last_name', ''),
            password=data['password']
        )
        
        Profile.objects.create(
            user=user,
            phone=data.get('phone', ''),
            role='buyer'
        )
        
        return JsonResponse({'success': True, 'user_id': user.id}, status=201)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["POST"])
def logout_api(request):
    logout(request)
    return JsonResponse({'success': True})


@csrf_exempt
@require_http_methods(["POST"])
def send_reset_code_api(request):
    try:
        data = json.loads(request.body)
        email = data.get('email')
        
        reset_code = str(random.randint(100000, 999999))
        
        request.session['reset_code'] = reset_code
        request.session['reset_email'] = email
        
        print(f"Код для сброса пароля для {email}: {reset_code}")
        
        return JsonResponse({'success': True, 'message': 'Код отправлен на email'})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["POST"])
def forgot_password_api(request):
    try:
        data = json.loads(request.body)
        email = data.get('email')
        new_password = data.get('new_password')
        code = data.get('code')
        
        expected_code = request.session.get('reset_code')
        expected_email = request.session.get('reset_email')
        
        if not expected_code or code != expected_code or email != expected_email:
            return JsonResponse({'error': 'Неверный код подтверждения'}, status=400)
        
        user = User.objects.get(email=email)
        user.set_password(new_password)
        user.save()
        
        del request.session['reset_code']
        del request.session['reset_email']
        
        return JsonResponse({'success': True, 'message': 'Пароль успешно изменен'})
    except User.DoesNotExist:
        return JsonResponse({'error': 'Пользователь не найден'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@require_http_methods(["GET"])
def profile_api(request):
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    try:
        profile = request.user.profile
        phone = profile.phone
        role = profile.role
    except:
        phone = ''
        role = 'buyer'
    
    return JsonResponse({
        'id': request.user.id,
        'email': request.user.email,
        'first_name': request.user.first_name,
        'last_name': request.user.last_name,
        'phone': phone,
        'avatar_url': None,
        'role': role,
    })


@csrf_exempt
@require_http_methods(["PUT", "POST"])
def update_profile_api(request):
    """Обновление профиля пользователя - поддерживает PUT и POST"""
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    try:
        if request.content_type and 'application/json' in request.content_type:
            data = json.loads(request.body)
        else:
            data = request.POST.dict()
        
        print(f"Updating profile for user {request.user.id}: {data}")
        
        if 'first_name' in data:
            request.user.first_name = data['first_name'].strip()
        if 'last_name' in data:
            request.user.last_name = data['last_name'].strip()
        request.user.save()
        
        profile, created = Profile.objects.get_or_create(user=request.user, defaults={'role': 'buyer'})
        
        if 'phone' in data:
            profile.phone = data['phone'].strip()
        profile.save()
        
        return JsonResponse({
            'success': True,
            'message': 'Профиль успешно обновлен',
            'user': {
                'id': request.user.id,
                'email': request.user.email,
                'first_name': request.user.first_name,
                'last_name': request.user.last_name,
                'phone': profile.phone,
                'avatar_url': None,
                'role': profile.role,
            }
        })
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Неверный формат данных'}, status=400)
    except Exception as e:
        print(f"Error updating profile: {e}")
        import traceback
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["POST"])
def change_password_api(request):
    """Изменение пароля пользователя"""
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Требуется авторизация'}, status=401)
    
    try:
        data = json.loads(request.body)
        old_password = data.get('old_password')
        new_password = data.get('new_password')
        
        if not old_password or not new_password:
            return JsonResponse({'error': 'Заполните все поля'}, status=400)
        
        if len(new_password) < 6:
            return JsonResponse({'error': 'Новый пароль должен содержать минимум 6 символов'}, status=400)
        
        if not request.user.check_password(old_password):
            return JsonResponse({'error': 'Неверный старый пароль'}, status=400)
        
        if old_password == new_password:
            return JsonResponse({'error': 'Новый пароль должен отличаться от старого'}, status=400)
        
        request.user.set_password(new_password)
        request.user.save()
        
        from django.contrib.auth import update_session_auth_hash
        update_session_auth_hash(request, request.user)
        
        return JsonResponse({
            'success': True,
            'message': 'Пароль успешно изменен'
        })
        
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Неверный формат данных'}, status=400)
    except Exception as e:
        print(f"Error changing password: {e}")
        import traceback
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)


@require_http_methods(["GET"])
def books_api(request):
    try:
        books = Book.objects.filter(status='published')
        
        search = request.GET.get('search')
        if search:
            books = books.filter(
                Q(title__icontains=search) |
                Q(authors__first_name__icontains=search) |
                Q(authors__last_name__icontains=search)
            )
        
        genre = request.GET.get('genre')
        if genre:
            books = books.filter(genres__name__icontains=genre)
        
        author = request.GET.get('author')
        if author:
            books = books.filter(
                Q(authors__first_name__icontains=author) |
                Q(authors__last_name__icontains=author)
            )
        
        min_price = request.GET.get('min_price')
        if min_price:
            books = books.filter(price__gte=float(min_price))
        
        max_price = request.GET.get('max_price')
        if max_price:
            books = books.filter(price__lte=float(max_price))
        
        sort_by = request.GET.get('sort')
        if sort_by == 'price':
            books = books.order_by('price')
        elif sort_by == '-price':
            books = books.order_by('-price')
        elif sort_by == '-views_count':
            books = books.order_by('-views_count')
        else:
            books = books.order_by('-created_at')
        
        page = int(request.GET.get('page', 1))
        paginator = Paginator(books, 30)
        
        try:
            page_obj = paginator.page(page)
        except:
            page_obj = paginator.page(1)
        
        return JsonResponse({
            'results': [book_to_json(b, request) for b in page_obj],
            'count': paginator.count,
            'next': page_obj.has_next(),
            'previous': page_obj.has_previous(),
        })
    except Exception as e:
        print(f"Error in books_api: {e}")
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)


@require_http_methods(["GET"])
def book_detail_api(request, book_id):
    try:
        book = get_object_or_404(Book, id=book_id, status='published')
        
        book.views_count += 1
        book.save()
        
        return JsonResponse(book_to_json(book, request))
    except Exception as e:
        print(f"Error in book_detail_api: {e}")
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)


@require_http_methods(["GET"])
def new_books_api(request):
    try:
        limit = int(request.GET.get('limit', 10))
        books = Book.objects.filter(status='published').order_by('-created_at')[:limit]
        return JsonResponse([book_to_json(b, request) for b in books], safe=False)
    except Exception as e:
        print(f"Error in new_books_api: {e}")
        traceback.print_exc()
        return JsonResponse([], safe=False)


@require_http_methods(["GET"])
def popular_books_api(request):
    try:
        limit = int(request.GET.get('limit', 10))
        books = Book.objects.filter(status='published').order_by('-views_count')[:limit]
        return JsonResponse([book_to_json(b, request) for b in books], safe=False)
    except Exception as e:
        print(f"Error in popular_books_api: {e}")
        traceback.print_exc()
        return JsonResponse([], safe=False)


@require_http_methods(["GET"])
def recommended_books_api(request):
    try:
        limit = int(request.GET.get('limit', 10))
        books = Book.objects.filter(status='published').annotate(
            avg_rating=Coalesce(Avg('reviews__rating', output_field=FloatField()), 0.0)
        ).order_by('-avg_rating')[:limit]
        return JsonResponse([book_to_json(b, request) for b in books], safe=False)
    except Exception as e:
        print(f"Error in recommended_books_api: {e}")
        traceback.print_exc()
        return JsonResponse([], safe=False)


@require_http_methods(["GET"])
def cart_api(request):
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    cart = get_active_cart(request.user)
    return JsonResponse(cart_to_json(cart))


@csrf_exempt
@require_http_methods(["POST"])
def add_to_cart_api(request):
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    try:
        data = json.loads(request.body)
        book_id = data.get('book_id')
        
        book = get_object_or_404(Book, id=book_id)
        
        # Проверяем, есть ли уже оплаченный заказ на эту книгу
        has_paid_order = Order.objects.filter(
            user=request.user,
            status='paid',
            items__book=book
        ).exists()
        
        if has_paid_order:
            return JsonResponse({
                'error': 'Вы уже купили эту книгу. Она доступна в разделе "Мои книги"'
            }, status=400)
        
        cart = get_active_cart(request.user)
        
        existing_item = CartItem.objects.filter(cart=cart, book=book).first()
        
        if existing_item:
            return JsonResponse({
                'error': 'Эта книга уже добавлена в корзину. Электронные копии продаются единожды.'
            }, status=400)
        
        CartItem.objects.create(
            cart=cart,
            book=book,
            quantity=1
        )
        
        return JsonResponse(cart_to_json(cart))
        
    except Exception as e:
        print(f"Error adding to cart: {e}")
        import traceback
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["DELETE"])
def remove_from_cart_api(request, item_id):
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    cart_item = get_object_or_404(CartItem, id=item_id, cart__user=request.user)
    cart_item.delete()
    
    return JsonResponse({'success': True})


@csrf_exempt
@require_http_methods(["PUT"])
def update_cart_item_api(request, item_id):
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    try:
        data = json.loads(request.body)
        quantity = data.get('quantity', 1)
        
        if quantity != 1:
            return JsonResponse({'error': 'Количество копий электронной книги не может быть изменено'}, status=400)
        
        cart_item = get_object_or_404(CartItem, id=item_id, cart__user=request.user)
        cart_item.quantity = 1
        cart_item.save()
        
        cart = cart_item.cart
        return JsonResponse(cart_to_json(cart))
        
    except Exception as e:
        print(f"Error updating cart item: {e}")
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["DELETE"])
def clear_cart_api(request):
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    cart = get_active_cart(request.user)
    cart.items.all().delete()
    
    return JsonResponse({'success': True})


@csrf_exempt
@require_http_methods(["POST"])
def create_order_api(request):
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Требуется авторизация'}, status=401)
    
    try:
        with transaction.atomic():
            data = json.loads(request.body)
            payment_method = data.get('payment_method', 'card')
            
            cart = get_active_cart(request.user)
            
            if cart.items.count() == 0:
                return JsonResponse({'error': 'Корзина пуста'}, status=400)
            
            total_amount = 0
            order_items_data = []
            
            for cart_item in cart.items.all():
                current_price = cart_item.book.get_current_price()
                total_amount += current_price
                order_items_data.append({
                    'book': cart_item.book,
                    'price': current_price,
                    'quantity': 1
                })
            
            order = Order.objects.create(
                user=request.user,
                total_amount=total_amount,
                payment_method=payment_method,
                status='pending',
                cart=cart
            )
            
            for item_data in order_items_data:
                OrderItem.objects.create(
                    order=order,
                    book=item_data['book'],
                    price=item_data['price'],
                    quantity=1
                )
            
            # Меняем статус корзины на ORDERED
            cart.status = 'ordered'
            cart.save()
            
            # Создаем уведомление о создании заказа
            Notification.objects.create(
                user=request.user,
                title='Заказ создан',
                message=f'Заказ №{order.id} создан. Ожидает подтверждения оплаты.',
                type='order',
                data={'order_id': order.id}
            )
            
            return JsonResponse(order_to_json(order), status=201)
            
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Неверный формат данных'}, status=400)
    except Exception as e:
        print(f"Error creating order: {e}")
        import traceback
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["POST"])
def confirm_payment_api(request, order_id):
    """Подтверждение оплаты заказа пользователем"""
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Требуется авторизация'}, status=401)
    
    try:
        order = get_object_or_404(Order, id=order_id, user=request.user)
        
        if order.status != 'pending':
            return JsonResponse({'error': 'Заказ уже обработан'}, status=400)
        
        with transaction.atomic():
            order.status = 'paid'
            order.payment_confirmed_at = timezone.now()
            order.save()
            
            # Обновляем статус корзины
            if order.cart:
                order.cart.status = 'paid'
                order.cart.save()
            
            # Создаем уведомление о подтверждении оплаты
            Notification.objects.create(
                user=request.user,
                title='Оплата подтверждена',
                message=f'Оплата заказа №{order.id} подтверждена. Книги доступны для чтения.',
                type='payment',
                data={'order_id': order.id}
            )
            
            return JsonResponse({
                'success': True,
                'message': 'Оплата подтверждена'
            })
            
    except Exception as e:
        print(f"Error confirming payment: {e}")
        import traceback
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)


@require_http_methods(["GET"])
def orders_api(request):
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    orders = Order.objects.filter(user=request.user).order_by('-order_date')
    return JsonResponse([order_to_json(o) for o in orders], safe=False)


@require_http_methods(["GET"])
def order_detail_api(request, order_id):
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    order = get_object_or_404(Order, id=order_id, user=request.user)
    return JsonResponse(order_to_json(order))


@require_http_methods(["GET"])
def favorites_api(request):
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    favorites = Favorite.objects.filter(user=request.user).select_related('book')
    books = [f.book for f in favorites]
    return JsonResponse([book_to_json(b, request) for b in books], safe=False)


@csrf_exempt
@require_http_methods(["POST"])
def add_to_favorite_api(request):
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    try:
        data = json.loads(request.body)
        book_id = data.get('book_id')
        book = get_object_or_404(Book, id=book_id)
        
        favorite, created = Favorite.objects.get_or_create(user=request.user, book=book)
        
        return JsonResponse({'success': True, 'created': created})
    except Exception as e:
        print(f"Error adding to favorites: {e}")
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["DELETE"])
def remove_from_favorite_api(request, book_id):
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    book = get_object_or_404(Book, id=book_id)
    deleted_count, _ = Favorite.objects.filter(user=request.user, book=book).delete()
    
    return JsonResponse({'success': True, 'deleted': deleted_count})


@require_http_methods(["GET"])
def check_favorite_api(request, book_id):
    if not request.user.is_authenticated:
        return JsonResponse({'is_favorite': False})
    
    is_favorite = Favorite.objects.filter(user=request.user, book_id=book_id).exists()
    return JsonResponse({'is_favorite': is_favorite})


@require_http_methods(["GET"])
def book_reviews_api(request, book_id):
    try:
        book = get_object_or_404(Book, id=book_id)
        page = int(request.GET.get('page', 1))
        paginator = Paginator(book.reviews.all().order_by('-created_at'), 20)
        
        try:
            page_obj = paginator.page(page)
        except:
            page_obj = paginator.page(1)
        
        return JsonResponse({
            'results': [
                {
                    'id': r.id,
                    'user_id': r.user.id,
                    'user_name': r.user.get_full_name() or r.user.username,
                    'user_avatar': None,
                    'book_id': r.book.id,
                    'rating': r.rating,
                    'comment': r.comment,
                    'created_at': r.created_at.isoformat(),
                }
                for r in page_obj
            ],
            'count': paginator.count,
        })
    except Exception as e:
        print(f"Error in book_reviews_api: {e}")
        return JsonResponse({'results': [], 'count': 0})


@csrf_exempt
@require_http_methods(["POST"])
def create_review_api(request, book_id):
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Требуется авторизация'}, status=401)
    
    try:
        data = json.loads(request.body)
        book = get_object_or_404(Book, id=book_id)
        
        existing_review = Review.objects.filter(user=request.user, book=book).first()
        if existing_review:
            existing_review.rating = data.get('rating', 5)
            existing_review.comment = data.get('comment', '')
            existing_review.save()
            return JsonResponse({
                'success': True, 
                'message': 'Отзыв обновлен',
                'review_id': existing_review.id
            }, status=200)
        
        review = Review.objects.create(
            user=request.user,
            book=book,
            rating=data.get('rating', 5),
            comment=data.get('comment', '')
        )
        
        return JsonResponse({
            'success': True, 
            'message': 'Отзыв добавлен',
            'review_id': review.id
        }, status=201)
        
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Неверный формат данных'}, status=400)
    except Exception as e:
        print(f"Error creating review: {e}")
        return JsonResponse({'error': str(e)}, status=500)


@require_http_methods(["GET"])
def notifications_api(request):
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    notifications = Notification.objects.filter(user=request.user).order_by('-created_at')
    return JsonResponse([
        {
            'id': n.id,
            'title': n.title,
            'message': n.message,
            'type': n.type,
            'data': n.data,
            'is_read': n.is_read,
            'created_at': n.created_at.isoformat(),
        }
        for n in notifications
    ], safe=False)


@csrf_exempt
@require_http_methods(["POST"])
def mark_notification_read_api(request, notification_id):
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    notification = get_object_or_404(Notification, id=notification_id, user=request.user)
    notification.is_read = True
    notification.save()
    
    return JsonResponse({'success': True})


@csrf_exempt
@require_http_methods(["POST"])
def mark_all_notifications_read_api(request):
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
    return JsonResponse({'success': True})


@require_http_methods(["GET"])
def unread_count_api(request):
    if not request.user.is_authenticated:
        return JsonResponse({'count': 0})
    
    count = Notification.objects.filter(user=request.user, is_read=False).count()
    return JsonResponse({'count': count})


@require_http_methods(["GET"])
def my_books_api(request):
    """Получение книг, которые пользователь купил (оплаченные заказы)"""
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    # Получаем книги из оплаченных заказов
    purchased_books = Book.objects.filter(
        order_items__order__user=request.user,
        order_items__order__status='paid'
    ).distinct()
    
    return JsonResponse([book_to_json(b, request) for b in purchased_books], safe=False)


user_books_api = my_books_api


# ==================== ТОВАРОВЕД API ====================

@require_http_methods(["GET"])
def merchandiser_carts_api(request):
    """API для товароведа - просмотр всех корзин"""
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    try:
        profile = request.user.profile
        if profile.role not in ['merchandiser', 'admin']:
            return JsonResponse({'error': 'Доступ запрещен'}, status=403)
    except Profile.DoesNotExist:
        return JsonResponse({'error': 'Доступ запрещен'}, status=403)
    
    status_filter = request.GET.get('status')
    carts = Cart.objects.all().order_by('-created_at')
    
    if status_filter:
        carts = carts.filter(status=status_filter)
    
    # Пагинация
    page = int(request.GET.get('page', 1))
    paginator = Paginator(carts, 20)
    
    try:
        page_obj = paginator.page(page)
    except:
        page_obj = paginator.page(1)
    
    result = []
    for cart in page_obj:
        result.append({
            'id': cart.id,
            'user': {
                'id': cart.user.id,
                'username': cart.user.username,
                'email': cart.user.email,
                'full_name': cart.user.get_full_name() or cart.user.username,
            },
            'status': cart.status,
            'created_at': cart.created_at.isoformat(),
            'updated_at': cart.updated_at.isoformat(),
            'items_count': cart.items.count(),
            'total_amount': float(cart.get_total()),
            'has_order': hasattr(cart, 'order'),
            'order_status': cart.order.status if hasattr(cart, 'order') and cart.order else None,
            'items': [
                {
                    'book_id': item.book.id,
                    'book_title': item.book.title,
                    'price': float(item.book.price),
                    'quantity': item.quantity,
                }
                for item in cart.items.all()
            ]
        })
    
    return JsonResponse({
        'results': result,
        'count': paginator.count,
        'next': page_obj.has_next(),
        'previous': page_obj.has_previous(),
    })


@require_http_methods(["GET"])
def get_genres_api(request):
    """Получение списка всех жанров"""
    try:
        genres = Genre.objects.all()
        return JsonResponse([
            {'id': g.id, 'name': g.name, 'description': g.description}
            for g in genres
        ], safe=False)
    except Exception as e:
        print(f"Error in get_genres_api: {e}")
        return JsonResponse([], safe=False)


@require_http_methods(["GET"])
def get_authors_api(request):
    """Получение списка всех авторов"""
    try:
        authors = Author.objects.all()
        return JsonResponse([
            {'id': a.id, 'first_name': a.first_name, 'last_name': a.last_name, 'bio': a.bio}
            for a in authors
        ], safe=False)
    except Exception as e:
        print(f"Error in get_authors_api: {e}")
        return JsonResponse([], safe=False)


@require_http_methods(["GET"])
def check_purchased_api(request, book_id):
    """Проверка, купил ли пользователь книгу"""
    if not request.user.is_authenticated:
        return JsonResponse({'is_purchased': False})
    
    is_purchased = Order.objects.filter(
        user=request.user,
        status='paid',
        items__book_id=book_id
    ).exists()
    
    return JsonResponse({'is_purchased': is_purchased})


@csrf_exempt
@require_http_methods(["POST"])
def merchandiser_update_cart_status_api(request, cart_id):
    """API для товароведа - обновление статуса корзины"""
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    try:
        profile = request.user.profile
        if profile.role not in ['merchandiser', 'admin']:
            return JsonResponse({'error': 'Доступ запрещен'}, status=403)
    except Profile.DoesNotExist:
        return JsonResponse({'error': 'Доступ запрещен'}, status=403)
    
    try:
        data = json.loads(request.body)
        new_status = data.get('status')
        
        if new_status not in [s[0] for s in Cart.CartStatusChoices.choices]:
            return JsonResponse({'error': 'Неверный статус'}, status=400)
        
        cart = get_object_or_404(Cart, id=cart_id)
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
                
                Notification.objects.create(
                    user=order.user,
                    title='Оплата подтверждена',
                    message=f'Товаровед подтвердил оплату заказа №{order.id}. Книги доступны для чтения.',
                    type='payment',
                    data={'order_id': order.id}
                )
        
        return JsonResponse({
            'success': True,
            'message': f'Статус корзины изменен с {old_status} на {new_status}'
        })
        
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Неверный формат данных'}, status=400)
    except Exception as e:
        print(f"Error updating cart status: {e}")
        return JsonResponse({'error': str(e)}, status=500)