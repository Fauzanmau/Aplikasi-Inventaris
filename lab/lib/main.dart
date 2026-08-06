import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'core/routes.dart';
import 'services/role_guard.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/admin_login_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/mahasiswa/mahasiswa_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// 🔥 LOCK ORIENTATION
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  /// 🔥 INIT FIREBASE
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

////////////////////////////////////////////////////////////
/// APP ROOT
////////////////////////////////////////////////////////////
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventaris Laboratorium',
      debugShowCheckedModeBanner: false,

      routes: {
        ...AppRoutes.routes,
        '/admin-login': (context) => const AdminLoginScreen(),
      },

      onGenerateRoute: AppRoutes.onGenerateRoute,
      initialRoute: AppRoutes.root,

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFA020F0),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// ROLE GATE (AUTO REDIRECT BERDASARKAN ROLE)
////////////////////////////////////////////////////////////
class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {

        /// 🔄 LOADING AUTH
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        /// ❌ BELUM LOGIN
        if (!authSnap.hasData) {
          return const LoginScreen();
        }

        /// ✅ SUDAH LOGIN → CEK ROLE
        return FutureBuilder<String?>(
          future: RoleGuard.getUserRole(),
          builder: (context, roleSnap) {

            /// 🔄 LOADING ROLE
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            /// 👑 ADMIN
            if (roleSnap.data == 'admin') {
              return const AdminHomeScreen();
            }

            /// 🎓 DEFAULT → MAHASISWA
            return const MahasiswaHomeScreen();
          },
        );
      },
    );
  }
}