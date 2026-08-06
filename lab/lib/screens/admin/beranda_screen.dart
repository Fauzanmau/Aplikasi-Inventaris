import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pilih_lab_screen.dart';
import '../../services/auth_service.dart';
// ✅ Tambahkan import untuk AdminReservationScreen
import 'admin_reservation_screen.dart';

const Color primaryPurple = Color(0xFFA020F0);

class BerandaScreen extends StatefulWidget {
  const BerandaScreen({super.key});

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  final AuthService _auth = AuthService();
  Stream<DocumentSnapshot>? _userStream;

  @override
  void initState() {
    super.initState();
    _initUserStream();
  }

  void _initUserStream() {
    final user = _auth.currentUser;
    if (user != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ DETEKSI UKURAN LAYAR UNTUK RESPONSIVITAS
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    
    // ✅ KONFIGURASI GRID RESPONSIF
    final crossAxisCount = isDesktop ? 4 : 2;
    final childAspectRatio = isDesktop ? 1.2 : 0.95;
    final horizontalPadding = isDesktop ? 40.0 : 20.0;
    final crossAxisSpacing = isDesktop ? 20.0 : 16.0;
    final mainAxisSpacing = isDesktop ? 20.0 : 16.0;

    // ✅ KONFIGURASI TINGGI BANNER RESPONSIF
    final bannerHeight = isDesktop ? 320.0 : 220.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            /// ================= HEADER =================
            Stack(
              children: [
                // ✅ GAMBAR BANNER — tinggi responsif
                Container(
                  width: double.infinity,
                  height: bannerHeight,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/tik.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // ✅ GRADIENT OVERLAY — tinggi mengikuti banner
                Container(
                  width: double.infinity,
                  height: bannerHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        // ignore: deprecated_member_use
                        Colors.black.withOpacity(0.60),
                      ],
                    ),
                  ),
                ),
                // ✅ TEKS "SELAMAT DATANG" — otomatis menempel di bawah banner
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Selamat Datang",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StreamBuilder<DocumentSnapshot>(
                          stream: _userStream,
                          builder: (context, snapshot) {
                            String nama = 'Pengguna';
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data = snapshot.data!.data() as Map<String, dynamic>?;
                              nama = data?['namaLengkap'] ?? 'Pengguna';
                            }
                            return Text(
                              nama,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                height: 1.1,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            /// ================= MENU CARD =================
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: crossAxisSpacing,
                  mainAxisSpacing: mainAxisSpacing,
                  childAspectRatio: childAspectRatio,
                  children: [
                    // 1. Inventaris
                    _menuCard(
                      context,
                      title: "Daftar Inventaris",
                      icon: Icons.inventory_2_rounded,
                      colors: [const Color(0xFF16A34A), const Color(0xFF15803D)],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PilihLabScreen(mode: 'inventaris'),
                        ),
                      ),
                    ),
                    // 2. Input Barang (BARU)
                    _menuCard(
                      context,
                      title: "Input Barang",
                      icon: Icons.playlist_add_circle_rounded,
                      colors: [const Color(0xFF4F46E5), const Color(0xFF4338CA)], // Indigo
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PilihLabScreen(mode: 'input'),
                        ),
                      ),
                    ),
                    // 3. Reservasi (MENGANTIKAN Peminjaman)
                    _menuCard(
                      context,
                      title: "Reservasi",
                      icon: Icons.assignment_rounded,
                      colors: [const Color(0xFFF97316), const Color(0xFFEA580C)],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminReservationScreen(),
                        ),
                      ),
                    ),
                    // 4. Pengembalian
                    _menuCard(
                      context,
                      title: "Pengembalian",
                      icon: Icons.move_to_inbox_rounded,
                      colors: [const Color(0xFFDC2626), const Color(0xFFB91C1C)],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PilihLabScreen(mode: 'kembali'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ================= MENU CARD WIDGET =================
  Widget _menuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        // ignore: deprecated_member_use
        splashColor: Colors.white.withOpacity(0.2),
        // ignore: deprecated_member_use
        highlightColor: Colors.white.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: colors.last.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: Colors.white),
              ),
              const SizedBox(height: 14),
              AutoSizeText(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
                maxLines: 2,
                minFontSize: 12,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}