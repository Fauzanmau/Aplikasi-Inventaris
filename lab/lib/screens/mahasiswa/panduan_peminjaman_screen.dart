import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

const Color primaryPurple = Color(0xFFA020F0);
const Color secondaryPurple = Color(0xFF8B00E0);
const Color lightPurple = Color(0xFFCE93D8);

class PanduanPeminjamanScreen extends StatelessWidget {
  const PanduanPeminjamanScreen({super.key});

  //////////////////////////////////////////////////////////
  /// STEP ITEM
  //////////////////////////////////////////////////////////
  Widget stepItem(int index, String text, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryPurple, secondaryPurple],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: primaryPurple.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.5,
                    // ignore: deprecated_member_use
                    color: lightPurple.withOpacity(0.55),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14.8,
                  height: 1.45,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  //////////////////////////////////////////////////////////
  /// NOTE ITEM
  //////////////////////////////////////////////////////////
  Widget noteItem(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: primaryPurple,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //////////////////////////////////////////////////////////
  /// UI
  //////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: primaryPurple,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: AutoSizeText(
          "Panduan Peminjaman",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          minFontSize: 17,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //////////////////////////////////////////////////////////
              /// HEADER CARD
              //////////////////////////////////////////////////////////
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryPurple, secondaryPurple],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: primaryPurple.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Text(
                  "Ikuti langkah-langkah berikut untuk melakukan reservasi barang melalui aplikasi sebelum proses peminjaman dilakukan oleh admin laboratorium.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              //////////////////////////////////////////////////////////
              /// TITLE PROSEDUR
              //////////////////////////////////////////////////////////
              const Text(
                "Prosedur Reservasi",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.2,
                ),
              ),

              const SizedBox(height: 16),

              //////////////////////////////////////////////////////////
              /// STEPS
              //////////////////////////////////////////////////////////
              stepItem(
                0,
                "Pilih laboratorium, lalu buka menu Daftar Inventaris untuk melihat barang yang tersedia.",
              ),
              stepItem(
                1,
                "Pilih barang yang ingin dipinjam, kemudian tekan tombol Reservasi Barang.",
              ),
              stepItem(
                2,
                "Isi jumlah barang, tentukan tanggal rencana pengembalian, dan tambahkan catatan jika diperlukan.",
              ),
              stepItem(
                3,
                "Tekan tombol Reservasi untuk mengirim permintaan. Status reservasi akan menjadi 'Dipesan'.",
              ),
              stepItem(
                4,
                "Datang ke laboratorium. Admin akan memindai (scan) Serial Number barang untuk memproses peminjaman, dan melakukan scan ulang saat pengembalian.",
                isLast: true,
              ),

              const SizedBox(height: 32),

              //////////////////////////////////////////////////////////
              /// TITLE KETENTUAN
              //////////////////////////////////////////////////////////
              const Text(
                "Ketentuan",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.2,
                ),
              ),

              const SizedBox(height: 14),

              //////////////////////////////////////////////////////////
              /// NOTES
              //////////////////////////////////////////////////////////
              noteItem(
                "Reservasi hanya dapat dilakukan apabila stok barang masih tersedia.",
              ),
              noteItem(
                "Mahasiswa datang ke laboratorium untuk mengambil barang yang telah direservasi.",
              ),
              noteItem(
                "Pengguna wajib menjaga kondisi barang yang dipinjam selama masa peminjaman.",
              ),
              noteItem(
                "Barang harus dikembalikan kepada admin sesuai dengan tanggal pengembalian yang telah ditentukan.",
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}