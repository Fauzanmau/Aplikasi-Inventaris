import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/reservation_model.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart'; // Pastikan path ini sesuai

class ReservationDialog extends StatefulWidget {
  final String labId;
  final String labName;
  final String categoryId;
  final String categoryName;
  final String itemId;
  final String itemName;
  final String satuan;
  final int maxQuantity; // ✅ PERBAIKAN 3: Parameter baru untuk batas quantity

  const ReservationDialog({
    super.key,
    required this.labId,
    required this.labName,
    required this.categoryId,
    required this.categoryName,
    required this.itemId,
    required this.itemName,
    required this.satuan,
    required this.maxQuantity,
  });

  @override
  State<ReservationDialog> createState() => _ReservationDialogState();
}

class _ReservationDialogState extends State<ReservationDialog> {
  int _quantity = 1;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _catatanController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _submitReservation() async {
    // ✅ PERBAIKAN 4: Validasi sebelum kirim
    if (_quantity <= 0 || _quantity > widget.maxQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah barang tidak valid'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final tanggalKembali = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    
    if (tanggalKembali.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal kembali tidak boleh sebelum hari ini'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ PERBAIKAN 2: Penggunaan AuthService sesuai instruksi
      final userData = await AuthService().getUserData();
      
      if (userData == null) {
        throw Exception("User belum login");
      }

      final uid = userData['uid'];
      final nama = userData['namaLengkap'];
      final nim = userData['nim'];
      final kelas = userData['kelas'];
      final prodi = userData['prodi'];

      final reservation = ReservationModel(
        id: '', 
        uid: uid ?? '',
        nama: nama ?? '',
        nim: nim ?? '',
        kelas: kelas ?? '',
        prodi: prodi ?? '',
        labId: widget.labId,
        labName: widget.labName,
        categoryId: widget.categoryId,
        categoryName: widget.categoryName,
        itemId: widget.itemId,
        itemName: widget.itemName,
        satuan: widget.satuan,
        quantity: _quantity,
        status: ReservationModel.dipesan,
        
        catatan: _catatanController.text.trim().isEmpty ? null : _catatanController.text.trim(),
        createdAt: Timestamp.now(),
        tanggalHarusKembali: Timestamp.fromDate(_selectedDate),
      );

      await FirestoreService().createReservation(reservation);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservasi berhasil dikirim'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryPurple = Color(0xFFA020F0);

    return AlertDialog(
      title: const Text(
        'Reservasi Barang',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.itemName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: primaryPurple,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Satuan: ${widget.satuan}',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text('Jumlah Barang:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: primaryPurple,
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: primaryPurple),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_quantity',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  // ✅ PERBAIKAN 3: Tombol + disable jika mencapai maxQuantity
                  icon: const Icon(Icons.add_circle_outline),
                  color: primaryPurple,
                  onPressed: _quantity < widget.maxQuantity
                      ? () => setState(() => _quantity++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text('Tanggal Harus Kembali:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: primaryPurple,
                          onPrimary: Colors.white,
                          onSurface: Colors.black,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20, color: primaryPurple),
                    const SizedBox(width: 12),
                    Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Catatan (Opsional):', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _catatanController,
              maxLength: 200,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tambahkan catatan jika diperlukan...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: primaryPurple),
                ),
                counterStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitReservation,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryPurple,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Kirim Reservasi'),
        ),
      ],
    );
  }
}