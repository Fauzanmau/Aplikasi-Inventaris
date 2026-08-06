import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'panduan_peminjaman_screen.dart';
import '../admin/detail_lab_screen.dart';

// ⚠️ PENTING: Pastikan file 'reservation_screen.dart' ada di folder yang sama 
// (lib/screens/mahasiswa/) dan di dalamnya terdapat 'class ReservationScreen extends StatefulWidget'
import 'reservation_screen.dart'; 

const Color primaryPurple = Color(0xFFA020F0);
const Color softPurple = Color(0xFFF3E8FF);

class MahasiswaBerandaScreen extends StatefulWidget {
  const MahasiswaBerandaScreen({super.key});

  @override
  State<MahasiswaBerandaScreen> createState() => _MahasiswaBerandaScreenState();
}

class _MahasiswaBerandaScreenState extends State<MahasiswaBerandaScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<DocumentSnapshot>? _userStream;

  @override
  void initState() {
    super.initState();
    _initUserStream();
  }

  void _initUserStream() {
    final user = _auth.currentUser;
    if (user != null) {
      _userStream = _firestore.collection('users').doc(user.uid).snapshots();
    }
  }

  // ==================== LIHAT FOTO FULL (klik foto profil) ====================
  void _viewFullPhoto(String photoUrl) {
    if (photoUrl.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: Hero(
              tag: 'profile_photo_mahasiswa',
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                        child: CircularProgressIndicator(color: primaryPurple));
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

    // ✅ UKURAN FOTO PROFIL RESPONSIF
    final profileSize = isDesktop ? 80.0 : 64.0;
    final profileIconSize = isDesktop ? 40.0 : 32.0;
    final nameFontSize = isDesktop ? 24.0 : 18.0;
    final welcomeFontSize = isDesktop ? 16.0 : 14.0;

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
                        Colors.black.withValues(alpha: 0.60),
                      ],
                    ),
                  ),
                ),
                // ✅ TEKS "SELAMAT DATANG" + FOTO PROFIL — otomatis menempel di bawah banner
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: _userStream,
                      builder: (context, snapshot) {
                        String namaUser = 'Pengguna';
                        String? photoUrl;

                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          namaUser = data?['namaLengkap']
                                  ?.toString()
                                  .trim() ??
                              data?['nama']?.toString().trim() ??
                              data?['username']?.toString().trim() ??
                              'Pengguna';
                          photoUrl = data?['photoUrl']?.toString();
                        }

                        return Row(
                          children: [
                            // Foto Profil - KLIK UNTUK LIHAT FULL
                            GestureDetector(
                              onTap: (photoUrl != null && photoUrl.isNotEmpty)
                                  ? () => _viewFullPhoto(photoUrl!)
                                  : null,
                              child: Hero(
                                tag: 'profile_photo_mahasiswa',
                                child: Container(
                                  width: profileSize,
                                  height: profileSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: photoUrl != null &&
                                            photoUrl.isNotEmpty
                                        ? Image.network(
                                            photoUrl,
                                            fit: BoxFit.cover,
                                            loadingBuilder:
                                                (context, child, loadingProgress) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return Container(
                                                color: Colors.white,
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: primaryPurple,
                                                    strokeWidth: 2,
                                                  ),
                                                ),
                                              );
                                            },
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              color: Colors.white,
                                              child: Icon(Icons.person_rounded,
                                                  color: primaryPurple,
                                                  size: profileIconSize),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.white,
                                            child: Icon(Icons.person_rounded,
                                                color: primaryPurple,
                                                size: profileIconSize),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Teks Selamat Datang + Nama
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Selamat Datang",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: welcomeFontSize,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    namaUser,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: nameFontSize,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            /// ================= MENU CARD =================
            Expanded(
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: crossAxisSpacing,
                  mainAxisSpacing: mainAxisSpacing,
                  childAspectRatio: childAspectRatio,
                  children: [
                    // 1. Daftar Inventaris
                    _menuCard(
                      context,
                      title: "Daftar Inventaris",
                      icon: Icons.inventory_2_rounded,
                      colors: const [Color(0xFF16A34A), Color(0xFF15803D)],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const _PilihLabForMahasiswaScreen(),
                          ),
                        );
                      },
                    ),

                    // 2. ✅ BARU: Reservasi (Warna disesuaikan dengan Admin)
                    _menuCard(
                      context,
                      title: "Reservasi",
                      icon: Icons.assignment_rounded,
                      colors: const [Color(0xFFF97316), Color(0xFFEA580C)], // Gradasi Oranye
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReservationScreen(),
                          ),
                        );
                      },
                    ),

                    // 3. Panduan Peminjaman
                    _menuCard(
                      context,
                      title: "Panduan Peminjaman",
                      icon: Icons.menu_book_rounded,
                      colors: const [Color(0xFF6B7280), Color(0xFF374151)],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PanduanPeminjamanScreen(),
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
        splashColor: Colors.white.withValues(alpha: 0.2),
        highlightColor: Colors.white.withValues(alpha: 0.1),
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
                color: colors.last.withValues(alpha: 0.4),
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
                  color: Colors.white.withValues(alpha: 0.18),
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

////////////////////////////////////////////////////
// Pilih Lab untuk Mahasiswa
////////////////////////////////////////////////////
class _PilihLabForMahasiswaScreen extends StatelessWidget {
  const _PilihLabForMahasiswaScreen();

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 20;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryPurple,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const AutoSizeText(
          "Pilih Laboratorium",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          minFontSize: 17,
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('labs')
            .orderBy(FieldPath.documentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.apartment_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada laboratorium',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          final labs = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: bottomPadding + 60,
            ),
            itemCount: labs.length,
            itemBuilder: (context, index) {
              final doc = labs[index];
              final labId = doc.id;
              final data = doc.data() as Map<String, dynamic>;
              final labName = data['name'] as String? ?? 'Tanpa Nama';

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: softPurple,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: primaryPurple.withValues(alpha: 0.3)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailLabScreen(
                            labId: labId,
                            isMahasiswa: true,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: primaryPurple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.desktop_mac_rounded,
                              color: primaryPurple,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  labId.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                AutoSizeText(
                                  labName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                  maxLines: 2,
                                  minFontSize: 12,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: primaryPurple,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}