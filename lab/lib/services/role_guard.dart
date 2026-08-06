import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoleGuard {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =========================
  // GET USER ROLE
  // =========================
  static Future<String?> getUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final snap =
          await _db.collection('users').doc(user.uid).get();

      if (!snap.exists) return null;

      final data = snap.data();
      if (data == null) return null;

      return data['role'];
    } catch (_) {
      return null;
    }
  }

  // =========================
  // CEK ADMIN
  // =========================
  static Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'admin';
  }

  // =========================
  // CEK MAHASISWA
  // =========================
  static Future<bool> isMahasiswa() async {
    final role = await getUserRole();
    return role == 'mahasiswa';
  }
}
