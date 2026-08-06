import 'package:flutter/material.dart';
import '../main.dart';

// 🔥 Auth Screens
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';

// 🔥 Admin Screens
import '../screens/admin/input_barang_screen.dart';

class AppRoutes {
  AppRoutes._(); // mencegah instance

  // 🔥 ROUTE CONSTANTS
  static const String root = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String inputBarang = '/input-barang';

  // 🔥 ROUTES MAP
  static final Map<String, WidgetBuilder> routes = {
    root: (_) => const RoleGate(),
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    forgotPassword: (_) => const ForgotPasswordScreen(),
  };

  // 🔥 ON GENERATE ROUTE
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case inputBarang:
        final args = settings.arguments;
        if (args is Map<String, dynamic>) {
          final labId = args['labId'];
          if (labId is String && labId.isNotEmpty) {
            return MaterialPageRoute(
              builder: (_) => InputBarangScreen(labId: labId),
            );
          }
        }
        return _errorRoute('Lab ID tidak valid');

      default:
        return _errorRoute('Route tidak ditemukan: ${settings.name}');
    }
  }

  // 🔥 ERROR ROUTE HELPER (FIXED ✅)
  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.red.shade700,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, 
                    size: 64, color: Colors.red.shade700),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  // ✅ PERBAIKAN: () => ... (tanpa parameter context)
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kembali ke Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}