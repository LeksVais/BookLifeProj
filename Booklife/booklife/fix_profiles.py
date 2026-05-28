import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'buklife_project.settings')
django.setup()

from django.contrib.auth.models import User
from store.models import Profile

def fix_profiles():
    users = User.objects.all()
    created_count = 0
    
    for user in users:
        profile, created = Profile.objects.get_or_create(
            user=user,
            defaults={
                'role': 'buyer'
            }
        )
        if created:
            created_count += 1
            print(f"Создан профиль для пользователя: {user.username}")
        else:
            print(f"Профиль уже существует для: {user.username}")
    
    print(f"\nВсего создано профилей: {created_count}")
    print(f"Всего пользователей: {users.count()}")

if __name__ == "__main__":
    fix_profiles()