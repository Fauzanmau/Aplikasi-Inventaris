import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🔐 SALT UNTUK HASHING (Ganti dengan value unik & rahasia Anda)
  static const String _passwordSalt = 'inventaris-app-secret-salt-2026-do-not-share';
  
  // 🔑 PASSWORD TETAP UNTUK FIREBASE AUTH (TIDAK DIPAKAI USER)
  static const String _fixedFirebasePassword = 'InventarisApp@Auth2026!';

  //////////////////////////////////////////////////////////
  /// 🔐 HELPER: HASH PASSWORD DENGAN SHA256 + SALT
  //////////////////////////////////////////////////////////
  String _hashPassword(String password) {
    final bytes = utf8.encode(password + _passwordSalt);
    return sha256.convert(bytes).toString();
  }

  //////////////////////////////////////////////////////////
  /// KONVERSI USERNAME → EMAIL INTERNAL
  //////////////////////////////////////////////////////////
  String _usernameToEmail(String username) {
    return '${username.toLowerCase()}@inventaris.app';
  }

  //////////////////////////////////////////////////////////
  /// CEK ROLE BERDASARKAN USERNAME
  //////////////////////////////////////////////////////////
  Future<String?> getRoleByUsername(String username) async {
    try {
      username = username.trim().toLowerCase();
      final snap = await _db
          .collection('users')
          .where('username', isEqualTo: username)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data()['role'];
    } catch (e) {
      if (kDebugMode) print("ERROR getRoleByUsername: $e");
      return null;
    }
  }

  //////////////////////////////////////////////////////////
  /// REGISTER
  //////////////////////////////////////////////////////////
  Future<String?> register({
    required String username,
    required String password,
    required String namaLengkap,
    required String kelas,
    required String nim,
    required String prodi,
  }) async {
    try {
      if (password.length < 6) return 'Password minimal 6 karakter';
      if (username.trim().isEmpty || 
          namaLengkap.trim().isEmpty || 
          kelas.trim().isEmpty || 
          nim.trim().isEmpty || 
          prodi.trim().isEmpty) {
        return 'Semua field wajib diisi';
      }
      final nimTrim = nim.trim();
      if (!RegExp(r'^\d{10,15}$').hasMatch(nimTrim)) {
        return 'NIM harus berupa angka 10–15 digit';
      }

      // Validasi NIM duplikat
      final nimCheck = await _db
          .collection('users')
          .where('nim', isEqualTo: nimTrim)
          .get();
      if (nimCheck.docs.isNotEmpty) {
        return 'NIM sudah digunakan';
      }

      username = username.trim().toLowerCase();
      final email = _usernameToEmail(username);
      
      // Validasi username duplikat
      final usernameCheck = await _db
          .collection('users')
          .where('username', isEqualTo: username)
          .get();
      if (usernameCheck.docs.isNotEmpty) {
        return 'Username sudah digunakan';
      }

      // 🔥 BUAT AKUN FIREBASE DENGAN PASSWORD TETAP
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: _fixedFirebasePassword,
      );
      final uid = cred.user!.uid;

      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'username': username,
        'namaLengkap': namaLengkap.trim(),
        'kelas': kelas.trim().toUpperCase(),
        'nim': nimTrim,
        'prodi': prodi.trim(),
        'jurusan': 'TEKNOLOGI INFORMASI DAN KOMPUTER',
        'role': 'mahasiswa',
        'createdAt': FieldValue.serverTimestamp(),
        'passwordHash': _hashPassword(password), // 🔥 PASSWORD ASLI DISIMPAN DI SINI
      });
      await _auth.signOut();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        return 'Tidak ada koneksi internet.';
      }
      return e.message ?? 'Gagal membuat akun';
    } on SocketException catch (_) {
      return 'Tidak ada koneksi internet.';
    } catch (e) {
      if (kDebugMode) print("ERROR register: $e");
      return 'Terjadi kesalahan saat register';
    }
  }

  //////////////////////////////////////////////////////////
  /// LOGIN - VERIFIKASI HANYA VIA FIRESTORE HASH
  //////////////////////////////////////////////////////////
  Future<String?> login({
    required String username,
    required String password,
  }) async {
    try {
      username = username.trim().toLowerCase();
      
      // 🔍 STEP 1: Cek user di Firestore berdasarkan username
      final snap = await _db
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      
      if (snap.docs.isEmpty) {
        return 'Username tidak ditemukan';
      }
      
      final userData = snap.docs.first.data();
      
      // 🔐 STEP 2: Verifikasi password menggunakan hash di Firestore
      if (userData['passwordHash'] != _hashPassword(password)) {
        return 'Password salah';
      }
      
      // ✅ STEP 3: Jika hash cocok, sign in ke Firebase Auth dengan password tetap
      final email = _usernameToEmail(username);
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: _fixedFirebasePassword,
      );
      
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed' || e.code == 'network_error') {
        return 'Tidak ada koneksi internet.';
      }
      return 'Gagal login. Silakan coba lagi.';
    } on SocketException catch (_) {
      return 'Tidak ada koneksi internet.';
    } catch (e) {
      if (kDebugMode) print("ERROR login: $e");
      return 'Terjadi kesalahan saat login';
    }
  }

  //////////////////////////////////////////////////////////
  /// LOGOUT
  //////////////////////////////////////////////////////////
  Future<void> logout() async => await _auth.signOut();
  
  User? get currentUser => _auth.currentUser;

  Future<String?> getUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      return (await _db.collection('users').doc(user.uid).get()).data()?['role'];
    } catch (e) { 
      return null; 
    }
  }

  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      final doc = await _db.collection('users').doc(user.uid).get();
      return doc.exists ? doc.data() : null;
    } catch (e) { 
      return null; 
    }
  }

  //////////////////////////////////////////////////////////
  /// UPDATE PROFILE
  //////////////////////////////////////////////////////////
  Future<String?> updateProfile({
    required String nama,
    required String nim,
    required String kelas,
    required String prodi,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User belum login';
      
      if (nama.trim().isEmpty || 
          nim.trim().isEmpty || 
          kelas.trim().isEmpty || 
          prodi.trim().isEmpty) {
        return 'Semua field harus diisi';
      }
      
      final nimTrim = nim.trim();
      if (!RegExp(r'^\d{10,15}$').hasMatch(nimTrim)) {
        return 'NIM harus berupa angka 10–15 digit';
      }
      
      // Validasi NIM duplikat (kecuali diri sendiri)
      final nimCheck = await _db
          .collection('users')
          .where('nim', isEqualTo: nimTrim)
          .get();
      if (nimCheck.docs.isNotEmpty && nimCheck.docs.first.id != user.uid) {
        return 'NIM sudah digunakan';
      }
      
      // Validasi format kelas
      final kelasTrim = kelas.trim().toUpperCase();
  
      if (!RegExp(r'^\d+[A-Z]$').hasMatch(kelasTrim)) {
    return 'Format Kelas tidak valid!\nContoh: 1B, 2A, 3C, 4B';
}
      
      await _db.collection('users').doc(user.uid).update({
        'namaLengkap': nama.trim(),
        'nim': nimTrim,
        'kelas': kelasTrim,
        'prodi': prodi.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      if (kDebugMode) print("ERROR updateProfile: $e");
      return 'Gagal memperbarui profil';
    }
  }

  //////////////////////////////////////////////////////////
  /// CHANGE PASSWORD (SETELAH LOGIN)
  //////////////////////////////////////////////////////////
  Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      if (newPassword.length < 6) return 'Password minimal 6 karakter';
      
      final user = _auth.currentUser;
      if (user == null) return 'User belum login';
      
      // Verifikasi password lama via hash Firestore (lebih aman & tidak butuh reauth Firebase)
      final userData = await _db.collection('users').doc(user.uid).get();
      if (userData['passwordHash'] != _hashPassword(oldPassword)) {
        return 'Password lama yang Anda masukkan salah';
      }
      
      // Update hash saja (Firebase Auth tetap pakai _fixedFirebasePassword)
      await _db.collection('users').doc(user.uid).update({
        'passwordHash': _hashPassword(newPassword),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      if (kDebugMode) print("ERROR changePassword: $e");
      return 'Gagal mengganti password';
    }
  }

  //////////////////////////////////////////////////////////
  /// 🔥 FORGOT PASSWORD (RESET MANDIRI) - SUPPORT ADMIN & MAHASISWA
  /// nim parameter optional:
  /// - Jika ada (mahasiswa): verifikasi username + NIM
  /// - Jika null (admin): verifikasi username + role == 'admin'
  //////////////////////////////////////////////////////////
  Future<String?> forgotPassword({
    required String username,
    String? nim,  // 🔥 OPTIONAL - null untuk admin
    required String newPassword,
  }) async {
    try {
      if (newPassword.length < 6) {
        return 'Password baru minimal 6 karakter';
      }
      
      username = username.trim().toLowerCase();
      
      // 🔍 Query berdasarkan role
      QuerySnapshot snap;
      
      if (nim != null && nim.trim().isNotEmpty) {
        // 🎓 Untuk mahasiswa: verifikasi username + NIM
        snap = await _db.collection('users')
            .where('username', isEqualTo: username)
            .where('nim', isEqualTo: nim.trim())
            .limit(1)
            .get();
      } else {
        // 👑 Untuk admin: cukup verifikasi username + role
        snap = await _db.collection('users')
            .where('username', isEqualTo: username)
            .where('role', isEqualTo: 'admin')
            .limit(1)
            .get();
      }
      
      if (snap.docs.isEmpty) {
        return (nim != null && nim.trim().isNotEmpty)
            ? 'Username atau NIM tidak cocok'
            : 'Username admin tidak ditemukan';
      }
      
      final uid = snap.docs.first.id;
      
      // 🔐 Update passwordHash di Firestore
      await _db.collection('users').doc(uid).update({
        'passwordHash': _hashPassword(newPassword),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return null;
      
    } catch (e) {
      if (kDebugMode) print("ERROR forgotPassword: $e");
      return 'Terjadi kesalahan saat reset password';
    }
  }
}