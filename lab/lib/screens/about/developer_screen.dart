import 'package:flutter/material.dart';

class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  static const Color primaryPurple = Color(0xFFA020F0);
  static const Color softPurple = Color(0xFFF3E8FF);

  void _viewFullPhoto(BuildContext context) {
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
              tag: 'developer_photo',
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.asset(
                  'assets/images/Pengembang.jpeg',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[900],
                      child: const Icon(
                        Icons.person,
                        size: 100,
                        color: Colors.white,
                      ),
                    );
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: primaryPurple,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Tentang Pengembang",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),

              /// BAGIAN ATAS: FOTO, NAMA, DAN JABATAN
              GestureDetector(
                onTap: () => _viewFullPhoto(context),
                child: Hero(
                  tag: 'developer_photo',
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryPurple, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: primaryPurple.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/Pengembang.jpeg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: softPurple,
                            child: const Icon(
                              Icons.person,
                              size: 65,
                              color: primaryPurple,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Fauzan Maulana, S.Tr.T.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                "Pengembang Aplikasi",
                style: TextStyle(
                  color: primaryPurple,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 32),

              /// CARD DESKRIPSI NARASI
              _buildDescriptionCard(),

              const SizedBox(height: 24),

              /// CARD 1: ALAMAT
              _buildCard(
                title: "Alamat",
                icon: Icons.location_on_rounded,
                child: const Text(
                  "Jalan Medan - Banda Aceh, Desa Meunasah Ranto, Kecamatan Lhoksukon, Kabupaten Aceh Utara",
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.7,
                    color: Colors.black87,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              /// CARD 2: RIWAYAT PENDIDIKAN (TIMELINE VERTIKAL)
              _buildCard(
                title: "Riwayat Pendidikan",
                icon: Icons.school_outlined,
                child: _buildEducationTimeline(),
              ),

              const SizedBox(height: 24),

              /// CARD 3: NAMA ORANG TUA
              _buildCard(
                title: "Orang Tua",
                icon: Icons.family_restroom_rounded,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoItem(title: "Ayah", value: "Sulaiman"),
                    SizedBox(height: 16),
                    _InfoItem(title: "Ibu", value: "Rohamah"),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              /// FOOTER
              const Column(
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

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// WIDGET: CARD DESKRIPSI NARASI
  Widget _buildDescriptionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: softPurple,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: primaryPurple, size: 20),
              const SizedBox(width: 8),
              const Text(
                "Tentang Pengembang",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: primaryPurple.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          const Text(
            "Perkenalkan, saya Fauzan Maulana, S.Tr.T., merupakan mahasiswa angkatan 2022 Program Studi Teknologi Rekayasa Komputer Jaringan, Jurusan Teknologi Informasi dan Komputer, Politeknik Negeri Lhokseumawe, yang telah menyelesaikan pendidikan pada tahun 2026. Aplikasi Inventaris Laboratorium ini dikembangkan sebagai bagian dari penelitian skripsi dengan memanfaatkan teknologi cloud untuk mendukung pengelolaan inventaris laboratorium. Melalui aplikasi ini, diharapkan proses pencatatan dan peminjaman barang dapat dilakukan secara lebih efektif dan efisien.",
            style: TextStyle(
              fontSize: 14.5,
              height: 1.65,
              color: Colors.black87,
            ),
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );
  }

  /// WIDGET: CARD UTAMA (REUSABLE)
  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: softPurple,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: primaryPurple.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  /// WIDGET: TIMELINE VERTIKAL MODERN - JARAK KONSISTEN & PROPORSIONAL
  Widget _buildEducationTimeline() {
    final List<Map<String, String?>> educationHistory = [
      {"text": "SD Negeri 16 Lhoksukon", "subtitle": null},
      {"text": "SMP Negeri 1 Lhoksukon", "subtitle": null},
      {
        "text": "SMK Negeri 1 Lhoksukon", 
        "subtitle": "Program Keahlian Teknik Komputer dan Jaringan"
      },
      {
        "text": "Politeknik Negeri Lhokseumawe", 
        "subtitle": "Jurusan Teknologi Informasi dan Komputer\nProgram Studi Teknologi Rekayasa Komputer Jaringan"
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(educationHistory.length, (index) {
        final isLast = index == educationHistory.length - 1;
        final item = educationHistory[index];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// GARIS DAN TITIK TIMELINE
            Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: primaryPurple,
                    shape: BoxShape.circle,
                    border: Border.all(color: softPurple, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: primaryPurple.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 50, // ✅ Tinggi garis KONSISTEN untuk semua item (tidak terlalu rapat, tidak terlalu jauh)
                    color: primaryPurple.withValues(alpha: 0.3),
                  ),
              ],
            ),
            
            const SizedBox(width: 16),
            
            /// KONTEN TEKS
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16), // ✅ Jarak bawah yang seimbang agar seragam
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item["text"]!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (item["subtitle"] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item["subtitle"]!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// WIDGET HELPER: INFO ITEM (Key-Value)
class _InfoItem extends StatelessWidget {
  final String title;
  final String value;

  const _InfoItem({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: DeveloperScreen.primaryPurple,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}