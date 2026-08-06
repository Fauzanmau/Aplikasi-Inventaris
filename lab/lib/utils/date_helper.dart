import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DateHelper {

  //////////////////////////////////////////////////////////
  /// FORMAT TANGGAL (dd/MM/yyyy)
  //////////////////////////////////////////////////////////
  static String formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    return DateFormat('dd/MM/yyyy').format(ts.toDate());
  }

  //////////////////////////////////////////////////////////
  /// FORMAT TANGGAL + JAM (dd/MM/yyyy HH:mm)
  //////////////////////////////////////////////////////////
  static String formatDateTime(Timestamp? ts) {
    if (ts == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate());
  }

  //////////////////////////////////////////////////////////
  /// CEK TERLAMBAT
  /// 🔥 Telat hanya jika SUDAH LEWAT tanggal
  /// Deadline: 19 Juni
  /// Hari ini: 19 Juni → BELUM TELAT
  //////////////////////////////////////////////////////////
  static bool isOverdue(Timestamp? ts) {
    if (ts == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final target = ts.toDate();
    final targetDate = DateTime(
      target.year,
      target.month,
      target.day,
    );

    // ✅ HANYA TELAT JIKA SUDAH LEWAT TANGGAL
    return today.isAfter(targetDate);
  }
}
