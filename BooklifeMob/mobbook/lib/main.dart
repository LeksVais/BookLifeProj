import 'package:booklife/screens/auth/forgot_password_screen.dart';
import 'package:booklife/screens/auth/login_screen.dart';
import 'package:booklife/screens/auth/register_screen.dart';
import 'package:booklife/screens/book_detail_screen.dart';
import 'package:booklife/screens/cart/cart_screen.dart';
import 'package:booklife/screens/cart/checkout_screen.dart';
import 'package:booklife/screens/catalog/catalog_screen.dart';
import 'package:booklife/screens/catalog/reader_screen.dart';
import 'package:booklife/screens/favorites/favorites_screen.dart';
import 'package:booklife/screens/main_screen.dart';
import 'package:booklife/screens/my_books_screen.dart';
import 'package:booklife/screens/notifications_screen.dart';
import 'package:booklife/screens/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'providers/book_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/favorite_provider.dart';
import 'providers/order_provider.dart';
import 'providers/notification_provider.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final apiService = ApiService();
  
  runApp(MyApp(
    prefs: prefs,
    apiService: apiService,
  ));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  final ApiService apiService;

  const MyApp({
    Key? key,
    required this.prefs,
    required this.apiService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(prefs, apiService)),
        ChangeNotifierProvider(create: (_) => BookProvider(apiService)),
        ChangeNotifierProvider(create: (_) => CartProvider(apiService)),
        ChangeNotifierProvider(create: (_) => FavoriteProvider(apiService)),
        ChangeNotifierProvider(create: (_) => OrderProvider(apiService)),
        ChangeNotifierProvider(create: (_) => NotificationProvider(apiService)),
      ],
      child: MaterialApp(
        title: 'БукЛайф',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
          ),
        ),
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/book-detail': (context) => const BookDetailScreen(),
          '/cart': (context) => const CartScreen(),
          '/checkout': (context) => const CheckoutScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/my-books': (context) => const MyBooksScreen(),
          '/favorites': (context) => const FavoritesScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/catalog': (context) => const CatalogScreen(),
          '/reader': (context) => const ReaderScreen(),  
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/main') {
            final args = settings.arguments as int?;
            return MaterialPageRoute(
              builder: (_) => MainScreen(initialIndex: args ?? 0),
            );
          }
          return null;
        },
      ),
    );
  }
}