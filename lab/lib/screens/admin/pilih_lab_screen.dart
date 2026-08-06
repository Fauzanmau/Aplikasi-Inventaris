import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tambah_kategori_screen.dart';
import 'pengembalian_screen.dart';
import 'detail_lab_screen.dart';

const primaryPurple = Color(0xFFA020F0);
const softPurple = Color(0xFFF3E8FF);

class PilihLabScreen extends StatefulWidget {
  final String mode;

  const PilihLabScreen({
    super.key,
    required this.mode,
  });

  @override
  State<PilihLabScreen> createState() => _PilihLabScreenState();
}

class _PilihLabScreenState extends State<PilihLabScreen> {

  @override
  void initState() {
    super.initState();
    // ✅ Hint dialog HANYA muncul di mode 'inventaris' atau 'input' sesuai kebutuhan
    if (widget.mode == 'input') {
      _checkCategoryHint();
    }
  }

  Future<void> _checkCategoryHint() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('seen_category_hint_input') ?? false;
    
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!hasSeen && mounted) {
        _showCategoryHint();
        prefs.setBool('seen_category_hint_input', true);
      }
    });
  }

  void _showCategoryHint() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '💡 Tips',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            const Text(
              'Klik icon di samping nama laboratorium untuk:\n\n'
              '• Tambah kategori baru\n'
              '• Edit atau hapus kategori\n'
              '• Tambah nama barang & satuan',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: softPurple,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_rounded, color: primaryPurple, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cari icon ini di setiap card laboratorium 👉',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const Icon(Icons.tune_rounded, color: primaryPurple, size: 22),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Mengerti, Terima Kasih!',
              style: TextStyle(
                color: primaryPurple,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (widget.mode) {
      case 'input':
      case 'kembali':
      case 'inventaris':
        return "Pilih Laboratorium";
      default:
        return "Pilih Laboratorium";
    }
  }

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
        title: AutoSizeText(
          _getTitle(),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('labs').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: bottomPadding + 80,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final labId = doc.id;
              final data = doc.data() as Map<String, dynamic>;
              final labName = data['name'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: softPurple,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryPurple.withValues(alpha: 0.3),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _navigate(context, labId),
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
                                AutoSizeText(
                                  labId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  minFontSize: 14,
                                ),
                                const SizedBox(height: 4),
                                AutoSizeText(
                                  labName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                  maxLines: 2, 
                                  minFontSize: 11, 
                                ),
                              ],
                            ),
                          ),

                          // ✅ Icon tune HANYA muncul di mode 'input'
                          if (widget.mode == 'input')
                            IconButton(
                              icon: const Icon(
                                Icons.tune_rounded,
                                color: primaryPurple,
                                size: 26,
                              ),
                              tooltip: 'Kelola Kategori & Barang',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TambahKategoriScreen(
                                      labId: labId,
                                    ),
                                  ),
                                );
                              },
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

  void _navigate(BuildContext context, String labId) {
    Widget page;

    switch (widget.mode) {
      case 'input':
        page = DetailLabScreen(labId: labId, mode: 'input');
        break;
      case 'kembali':
        page = PengembalianScreen(labId: labId);
        break;
      case 'inventaris':
        page = DetailLabScreen(labId: labId);
        break;
      default:
        return; // Mengabaikan mode yang tidak dikenali (misal: 'pinjam')
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }
}