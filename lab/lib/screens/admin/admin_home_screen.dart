import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:lab/screens/about/developer_screen.dart';
import 'package:lab/screens/admin/KelolaLaboratoriumScreen.dart';
import '../../services/auth_service.dart';
import 'beranda_screen.dart';
import 'riwayat_screen.dart';
import '../profile/profile_screen.dart';

const Color primaryPurple = Color(0xFFA020F0);

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _index = 0;
  final AuthService _auth = AuthService();

  final List<_NavItem> _navItems = const [
    _NavItem('Beranda', BerandaScreen(), Icons.home_rounded),
    _NavItem('Peminjaman', RiwayatScreen(), Icons.fact_check_rounded),
    _NavItem('Profil', ProfileScreen(), Icons.account_circle_rounded),
  ];

  Future<void> _loadUser() async {
    final data = await _auth.getUserData();
    if (!mounted || data == null) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _onBottomNavTap(int index) {
    setState(() => _index = index);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Konfirmasi Logout',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 19,
          ),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) Navigator.pop(context);
      await _auth.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryPurple,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AutoSizeText(
              _navItems[_index].title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              minFontSize: 17,
            ),
          ],
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
              decoration: const BoxDecoration(color: primaryPurple),
              child: Column(
                children: [
                  Image.asset('assets/images/logo.png', height: 95),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            ListTile(
              // Ikon disesuaikan agar lebih relevan dengan konteks Laboratorium
              leading: const Icon(Icons.desktop_mac_rounded, color: primaryPurple),
              title: const Text('Kelola Laboratorium'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const KelolaLaboratoriumScreen(),
                  ),
                );
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.person_outline_rounded, color: primaryPurple),
              title: const Text('Tentang Pengembang'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DeveloperScreen(),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.redAccent),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _logout,
            ),
            
            const Spacer(),
            
            /// FOOTER: COPYRIGHT & NAMA PENGEMBANG
            const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    "© 2026",
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Fauzan Maulana, S.Tr.T.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primaryPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _navItems[_index].page,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: primaryPurple.withOpacity(0.25),
              blurRadius: 25,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: _onBottomNavTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: primaryPurple,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white60,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          elevation: 0,
          iconSize: 30,
          items: _navItems.map((e) {
            return BottomNavigationBarItem(
              icon: Icon(e.icon),
              activeIcon: Icon(e.icon, color: Colors.white),
              label: e.title,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  final String title;
  final Widget page;
  final IconData icon;
  const _NavItem(this.title, this.page, this.icon);
}