from django.db import models
from django.contrib.auth.models import User
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils import timezone
import os


class Profile(models.Model):
    """Профиль пользователя"""
    
    class RoleChoices(models.TextChoices):
        BUYER = 'buyer', 'Покупатель'
        MERCHANDISER = 'merchandiser', 'Товаровед'
        ADMIN = 'admin', 'Администратор'
    
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    date_of_birth = models.DateField('Дата рождения', null=True, blank=True)
    avatar = models.ImageField('Аватар', upload_to='avatars/', null=True, blank=True)
    phone = models.CharField('Телефон', max_length=20, blank=True)
    role = models.CharField('Роль', max_length=20, choices=RoleChoices.choices, default=RoleChoices.BUYER)
    last_login_at = models.DateTimeField('Последний вход', null=True, blank=True)

    def __str__(self):
        return f'Профиль пользователя {self.user.username}'

    class Meta:
        verbose_name = 'Профиль'
        verbose_name_plural = 'Профили'


class Author(models.Model):
    first_name = models.CharField('Имя', max_length=100)
    last_name = models.CharField('Фамилия', max_length=100)
    bio = models.TextField('Биография', blank=True)

    def __str__(self):
        return f'{self.first_name} {self.last_name}'

    class Meta:
        verbose_name = 'Автор'
        verbose_name_plural = 'Авторы'


class Genre(models.Model):
    name = models.CharField('Название', max_length=100, unique=True)
    description = models.CharField('Описание', max_length=500, blank=True)

    def __str__(self):
        return self.name

    class Meta:
        verbose_name = 'Жанр'
        verbose_name_plural = 'Жанры'


def book_file_upload_path(instance, filename):
    """Генерирует путь для загрузки файла книги"""
    ext = filename.split('.')[-1].lower()
    return f'books/{instance.id}_{instance.title.replace(" ", "_")}.{ext}'


class Book(models.Model):
    class StatusChoices(models.TextChoices):
        DRAFT = 'draft', 'Черновик'
        PUBLISHED = 'published', 'Опубликована'
        ARCHIVED = 'archived', 'В архиве'

    class AgeRatingChoices(models.TextChoices):
        ZERO_PLUS = '0+', '0+'
        SIX_PLUS = '6+', '6+'
        TWELVE_PLUS = '12+', '12+'
        SIXTEEN_PLUS = '16+', '16+'
        EIGHTEEN_PLUS = '18+', '18+'

    class FileTypeChoices(models.TextChoices):
        PDF = 'pdf', 'PDF'
        EPUB = 'epub', 'EPUB'
        TXT = 'txt', 'TXT'
        HTML = 'html', 'HTML'

    title = models.CharField('Название', max_length=255)
    authors = models.ManyToManyField(Author, related_name='books', verbose_name='Авторы')
    genres = models.ManyToManyField(Genre, related_name='books', verbose_name='Жанры')
    description = models.TextField('Аннотация')
    page_count = models.PositiveIntegerField('Количество страниц')
    publication_year = models.PositiveIntegerField('Год публикации')
    age_rating = models.CharField('Возрастной рейтинг', max_length=3, choices=AgeRatingChoices.choices, default=AgeRatingChoices.ZERO_PLUS)
    cover_image = models.ImageField('Обложка', upload_to='covers/', null=True, blank=True)
    
    # Новое поле для загрузки файла книги
    book_file = models.FileField(
        'Файл книги', 
        upload_to=book_file_upload_path,
        null=True, 
        blank=True,
        help_text='Загрузите файл книги (PDF, EPUB, TXT, HTML)'
    )
    book_file_type = models.CharField(
        'Тип файла', 
        max_length=10, 
        choices=FileTypeChoices.choices,
        default=FileTypeChoices.PDF,
        help_text='Тип загружаемого файла'
    )
    
    price = models.DecimalField('Цена', max_digits=10, decimal_places=2, validators=[MinValueValidator(0)])
    status = models.CharField('Статус', max_length=20, choices=StatusChoices.choices, default=StatusChoices.DRAFT)
    views_count = models.PositiveIntegerField('Просмотры', default=0)
    created_at = models.DateTimeField('Дата создания', auto_now_add=True)
    updated_at = models.DateTimeField('Дата обновления', auto_now=True)
    published_at = models.DateTimeField('Дата публикации', null=True, blank=True)

    def __str__(self):
        return self.title
    
    def get_current_price(self):
        now = timezone.now()
        active_sale = self.sales.filter(start_date__lte=now, end_date__gte=now).first()
        if active_sale:
            return self.price * (100 - active_sale.discount_percent) / 100
        return self.price
    
    def get_book_file_url(self):
        """Возвращает URL для доступа к файлу книги"""
        if self.book_file and hasattr(self.book_file, 'url'):
            return self.book_file.url
        return None
    
    def get_book_file_content(self):
        """Читает содержимое файла книги (для текстовых форматов)"""
        if not self.book_file:
            return None
        
        try:
            if self.book_file_type == 'txt':
                with open(self.book_file.path, 'r', encoding='utf-8') as f:
                    return f.read()
            elif self.book_file_type == 'html':
                with open(self.book_file.path, 'r', encoding='utf-8') as f:
                    return f.read()
        except Exception as e:
            print(f"Error reading book file: {e}")
            return None
        return None

    class Meta:
        verbose_name = 'Книга'
        verbose_name_plural = 'Книги'


class Sale(models.Model):
    """Акция - может содержать несколько книг"""
    name = models.CharField('Название акции', max_length=255)
    books = models.ManyToManyField(Book, related_name='sales', verbose_name='Книги')
    discount_percent = models.PositiveIntegerField('Скидка (%)', validators=[MinValueValidator(0), MaxValueValidator(100)])
    start_date = models.DateTimeField('Дата начала')
    end_date = models.DateTimeField('Дата окончания')
    description = models.TextField('Описание акции', blank=True, help_text='Дополнительная информация об акции')

    def __str__(self):
        books_count = self.books.count()
        if books_count == 1:
            first_book = self.books.first()
            return f'{self.name} ({self.discount_percent}% на "{first_book.title}")'
        return f'{self.name} ({self.discount_percent}% на {books_count} книг)'
    
    def is_active(self):
        now = timezone.now()
        return self.start_date <= now <= self.end_date
    
    def get_affected_books_count(self):
        return self.books.count()

    class Meta:
        verbose_name = 'Акция'
        verbose_name_plural = 'Акции'


class Review(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reviews', verbose_name='Пользователь')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='reviews', verbose_name='Книга')
    rating = models.PositiveIntegerField('Оценка', validators=[MinValueValidator(1), MaxValueValidator(5)])
    comment = models.TextField('Комментарий', max_length=2000)
    created_at = models.DateTimeField('Дата отзыва', auto_now_add=True)

    def __str__(self):
        return f'Отзыв от {self.user.username} на "{self.book.title}"'

    class Meta:
        verbose_name = 'Отзыв'
        verbose_name_plural = 'Отзывы'
        unique_together = ('user', 'book')


class Cart(models.Model):
    """Корзина пользователя - может быть несколько, активная только одна"""
    
    class CartStatusChoices(models.TextChoices):
        ACTIVE = 'active', 'Активна'
        ORDERED = 'ordered', 'Заказана'
        PAID = 'paid', 'Оплачена'
        COMPLETED = 'completed', 'Завершена'
        ABANDONED = 'abandoned', 'Заброшена'

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='carts', verbose_name='Пользователь')
    created_at = models.DateTimeField('Дата создания', auto_now_add=True)
    updated_at = models.DateTimeField('Дата обновления', auto_now=True)
    status = models.CharField('Статус', max_length=20, choices=CartStatusChoices.choices, default=CartStatusChoices.ACTIVE)

    def __str__(self):
        return f'Корзина {self.user.username} (#{self.id})'
    
    def get_total(self):
        return sum(item.get_total_price() for item in self.items.all())

    class Meta:
        verbose_name = 'Корзина'
        verbose_name_plural = 'Корзины'


class CartItem(models.Model):
    cart = models.ForeignKey(Cart, on_delete=models.CASCADE, related_name='items', verbose_name='Корзина')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='cart_items', verbose_name='Книга')
    quantity = models.PositiveIntegerField('Количество', default=1)
    added_at = models.DateTimeField('Дата добавления', auto_now_add=True)

    def __str__(self):
        return f'{self.book.title} x{self.quantity} в корзине {self.cart.user.username}'
    
    def get_total_price(self):
        return self.book.get_current_price() * self.quantity

    class Meta:
        verbose_name = 'Элемент корзины'
        verbose_name_plural = 'Элементы корзины'
        unique_together = ('cart', 'book')


class Order(models.Model):
    class OrderStatusChoices(models.TextChoices):
        PENDING = 'pending', 'Ожидает оплаты'
        PAID = 'paid', 'Оплачен'
        COMPLETED = 'completed', 'Завершен'
        CANCELLED = 'cancelled', 'Отменен'

    cart = models.OneToOneField(Cart, on_delete=models.SET_NULL, null=True, blank=True, related_name='order', verbose_name='Корзина')
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name='orders', verbose_name='Пользователь')
    order_date = models.DateTimeField('Дата заказа', auto_now_add=True)
    total_amount = models.DecimalField('Общая сумма', max_digits=10, decimal_places=2)
    status = models.CharField('Статус', max_length=20, choices=OrderStatusChoices.choices, default=OrderStatusChoices.PENDING)
    payment_method = models.CharField('Способ оплаты', max_length=50)
    payment_confirmed_at = models.DateTimeField('Дата подтверждения оплаты', null=True, blank=True)

    def __str__(self):
        return f'Заказ №{self.id} от {self.user.username}'

    class Meta:
        verbose_name = 'Заказ'
        verbose_name_plural = 'Заказы'


class Favorite(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='favorites', verbose_name='Пользователь')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='favorited_by', verbose_name='Книга')
    created_at = models.DateTimeField('Дата добавления', auto_now_add=True)

    def __str__(self):
        return f'{self.book.title} в избранном у {self.user.username}'

    class Meta:
        verbose_name = 'Избранное'
        verbose_name_plural = 'Избранное'
        unique_together = ('user', 'book')


class ReadingWishlist(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='wishlist', verbose_name='Пользователь')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='wished_by', verbose_name='Книга')
    created_at = models.DateTimeField('Дата добавления', auto_now_add=True)

    def __str__(self):
        return f'{self.book.title} в списке желаний у {self.user.username}'

    class Meta:
        verbose_name = 'Список желаний'
        verbose_name_plural = 'Списки желаний'
        unique_together = ('user', 'book')


class Report(models.Model):
    class ReportTypeChoices(models.TextChoices):
        SALES = 'sales', 'Отчет по продажам'
        POPULARITY = 'popularity', 'Отчет по популярности'
    
    class ReportStatusChoices(models.TextChoices):
        ACTIVE = 'active', 'Активен'
        ARCHIVED = 'archived', 'В архиве'
    
    title = models.CharField('Название отчета', max_length=255)
    report_type = models.CharField('Тип отчета', max_length=20, choices=ReportTypeChoices.choices)
    status = models.CharField('Статус', max_length=20, choices=ReportStatusChoices.choices, default=ReportStatusChoices.ACTIVE)
    start_date = models.DateField('Дата начала периода')
    end_date = models.DateField('Дата окончания периода')
    data = models.JSONField('Данные отчета', help_text='Содержит выручку, количество заказов, продажи по книгам/жанрам')
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='created_reports', verbose_name='Создал')
    created_at = models.DateTimeField('Дата создания', auto_now_add=True)
    updated_at = models.DateTimeField('Дата обновления', auto_now=True)
    
    def __str__(self):
        return f'{self.title} ({self.get_report_type_display()})'
    
    def archive(self):
        self.status = self.ReportStatusChoices.ARCHIVED
        self.save()
    
    def delete_report(self):
        self.delete()
    
    class Meta:
        verbose_name = 'Отчет'
        verbose_name_plural = 'Отчеты'
        ordering = ['-created_at']


class OrderItem(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    book = models.ForeignKey(Book, on_delete=models.CASCADE)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    quantity = models.IntegerField(default=1)
    
    class Meta:
        db_table = 'order_items'
    
    @property
    def total_price(self):
        return self.price * self.quantity
    
    def __str__(self):
        return f'{self.book.title} x{self.quantity}'


class Notification(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    title = models.CharField(max_length=200)
    message = models.TextField()
    type = models.CharField(max_length=50, choices=[
        ('order', 'Заказ'),
        ('payment', 'Оплата'),
        ('sale', 'Акция'),
        ('info', 'Информация'),
    ], default='info')
    data = models.JSONField(blank=True, null=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'notifications'
    
    def __str__(self):
        return self.title