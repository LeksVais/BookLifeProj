from django import forms
from django.contrib.auth.forms import UserCreationForm
from django.contrib.auth.models import User
from .models import Book, Report, Sale, Review, Profile, Author, Genre


class UserRegistrationForm(UserCreationForm):
    email = forms.EmailField(required=True, label='Email')
    first_name = forms.CharField(max_length=100, required=True, label='Имя')
    last_name = forms.CharField(max_length=100, required=True, label='Фамилия')

    class Meta:
        model = User
        fields = ('username', 'first_name', 'last_name', 'email', 'password1', 'password2')

    def save(self, commit=True):
        user = super().save(commit=False)
        user.email = self.cleaned_data['email']
        user.first_name = self.cleaned_data['first_name']
        user.last_name = self.cleaned_data['last_name']
        if commit:
            user.save()
        return user


class UserProfileForm(forms.ModelForm):
    class Meta:
        model = User
        fields = ('first_name', 'last_name', 'email')
        widgets = {
            'first_name': forms.TextInput(attrs={'class': 'form-control'}),
            'last_name': forms.TextInput(attrs={'class': 'form-control'}),
            'email': forms.EmailInput(attrs={'class': 'form-control'}),
        }


class ProfileForm(forms.ModelForm):
    class Meta:
        model = Profile
        fields = ('phone', 'date_of_birth', 'avatar')
        widgets = {
            'phone': forms.TextInput(attrs={'class': 'form-control'}),
            'date_of_birth': forms.DateInput(attrs={'class': 'form-control', 'type': 'date'}),
            'avatar': forms.FileInput(attrs={'class': 'form-control'}),
        }


class AuthorForm(forms.ModelForm):
    """Форма для создания/редактирования автора"""
    class Meta:
        model = Author
        fields = ('first_name', 'last_name', 'bio')
        widgets = {
            'first_name': forms.TextInput(attrs={'class': 'form-control'}),
            'last_name': forms.TextInput(attrs={'class': 'form-control'}),
            'bio': forms.Textarea(attrs={'class': 'form-control', 'rows': 4}),
        }


class GenreForm(forms.ModelForm):
    """Форма для создания/редактирования жанра"""
    class Meta:
        model = Genre
        fields = ('name', 'description')
        widgets = {
            'name': forms.TextInput(attrs={'class': 'form-control'}),
            'description': forms.TextInput(attrs={'class': 'form-control'}),
        }


class BookForm(forms.ModelForm):
    class Meta:
        model = Book
        fields = (
            'title', 'authors', 'genres', 'description', 'page_count',
            'publication_year', 'age_rating', 'cover_image', 'book_file', 
            'book_file_type', 'price', 'status'
        )
        widgets = {
            'title': forms.TextInput(attrs={'class': 'form-control'}),
            'authors': forms.SelectMultiple(attrs={'class': 'form-control select2'}),
            'genres': forms.SelectMultiple(attrs={'class': 'form-control select2'}),
            'description': forms.Textarea(attrs={'class': 'form-control', 'rows': 5}),
            'page_count': forms.NumberInput(attrs={'class': 'form-control'}),
            'publication_year': forms.NumberInput(attrs={'class': 'form-control'}),
            'age_rating': forms.Select(attrs={'class': 'form-control'}),
            'cover_image': forms.FileInput(attrs={'class': 'form-control'}),
            'book_file': forms.FileInput(attrs={'class': 'form-control'}),
            'book_file_type': forms.Select(attrs={'class': 'form-control'}),
            'price': forms.NumberInput(attrs={'class': 'form-control', 'step': '0.01'}),
            'status': forms.Select(attrs={'class': 'form-control'}),
        }
        help_texts = {
            'book_file': 'Загрузите файл книги в формате PDF, EPUB, TXT или HTML',
            'book_file_type': 'Выберите тип загружаемого файла',
        }


class SaleForm(forms.ModelForm):
    """Форма для создания/редактирования акции с множественным выбором книг"""
    class Meta:
        model = Sale
        fields = ('name', 'books', 'discount_percent', 'start_date', 'end_date', 'description')
        widgets = {
            'name': forms.TextInput(attrs={'class': 'form-control'}),
            'books': forms.SelectMultiple(attrs={'class': 'form-control select2'}),
            'discount_percent': forms.NumberInput(attrs={'class': 'form-control', 'min': 0, 'max': 100}),
            'start_date': forms.DateTimeInput(attrs={'class': 'form-control', 'type': 'datetime-local'}),
            'end_date': forms.DateTimeInput(attrs={'class': 'form-control', 'type': 'datetime-local'}),
            'description': forms.Textarea(attrs={'class': 'form-control', 'rows': 3}),
        }


class ReviewForm(forms.ModelForm):
    class Meta:
        model = Review
        fields = ('rating', 'comment')
        widgets = {
            'rating': forms.Select(attrs={'class': 'form-control'}, choices=[(1, 1), (2, 2), (3, 3), (4, 4), (5, 5)]),
            'comment': forms.Textarea(attrs={'class': 'form-control', 'rows': 5}),
        }


class ReportForm(forms.Form):
    """Форма для создания нового отчета"""
    title = forms.CharField(max_length=255, label='Название отчета', widget=forms.TextInput(attrs={'class': 'form-control'}))
    report_type = forms.ChoiceField(
        choices=Report.ReportTypeChoices.choices, 
        label='Тип отчета',
        widget=forms.Select(attrs={'class': 'form-control'})
    )
    period = forms.ChoiceField(
        choices=[
            ('week', 'Неделя'),
            ('month', 'Месяц'), 
            ('year', 'Год'),
            ('custom', 'Произвольный')
        ],
        label='Период',
        widget=forms.Select(attrs={'class': 'form-control'})
    )
    start_date = forms.DateField(
        label='Дата начала',
        required=False,
        widget=forms.DateInput(attrs={'class': 'form-control', 'type': 'date', 'placeholder': 'ГГГГ-ММ-ДД'})
    )
    end_date = forms.DateField(
        label='Дата окончания',
        required=False,
        widget=forms.DateInput(attrs={'class': 'form-control', 'type': 'date', 'placeholder': 'ГГГГ-ММ-ДД'})
    )
    
    def clean(self):
        cleaned_data = super().clean()
        period = cleaned_data.get('period')
        start_date = cleaned_data.get('start_date')
        end_date = cleaned_data.get('end_date')
        
        if period == 'custom':
            if not start_date:
                self.add_error('start_date', 'Укажите дату начала периода')
            if not end_date:
                self.add_error('end_date', 'Укажите дату окончания периода')
            if start_date and end_date and start_date > end_date:
                self.add_error('end_date', 'Дата окончания не может быть раньше даты начала')
        
        return cleaned_data