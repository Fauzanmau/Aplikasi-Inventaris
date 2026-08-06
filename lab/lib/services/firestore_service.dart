import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/barang_model.dart';
import '../models/riwayat_model.dart';
import '../models/reservation_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Iterable<DocumentSnapshot<T>> _filterConfigDocs<T extends Object?>(
    Iterable<DocumentSnapshot<T>> docs,
  ) => docs.where((doc) => doc.id != 'placeholder');

  List<BarangModel> _filterAndMapBarang(
    QuerySnapshot<BarangModel> snapshot,
  ) => _filterConfigDocs(snapshot.docs)
      .map((doc) => doc.data())
      .whereType<BarangModel>()
      .toList();

  bool _isConfigDoc(String docId) => docId == 'placeholder';

  String _sanitizeSerialForDocId(String serial) {
    return serial.replaceAll('/', '_');
  }

  Future<int> getReservedQuantity(
    String labId,
    String categoryId,
    String itemId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('reservations')
          .where('labId', isEqualTo: labId)
          .where('categoryId', isEqualTo: categoryId)
          .where('itemId', isEqualTo: itemId)
          .where('status', isEqualTo: ReservationModel.dipesan)
          .get();

      int totalReserved = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalReserved += (data['quantity'] as int? ?? 0);
      }
      return totalReserved;
    } catch (e) {
      debugPrint('Error getting reserved quantity: $e');
      return 0;
    }
  }

  // ✅ BARU: Stream untuk mendapatkan jumlah reservasi secara REALTIME
  Stream<int> getReservedQuantityStream(
    String labId,
    String categoryId,
    String itemId,
  ) {
    return _firestore
        .collection('reservations')
        .where('labId', isEqualTo: labId)
        .where('categoryId', isEqualTo: categoryId)
        .where('itemId', isEqualTo: itemId)
        .where('status', isEqualTo: ReservationModel.dipesan)
        .snapshots()
        .map((snapshot) {
      int totalReserved = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalReserved += (data['quantity'] as int? ?? 0);
      }
      return totalReserved;
    });
  }

  Future<void> addLab({
    required String labId,
    required String labName,
  }) async {
    debugPrint('[FirestoreService] Menambahkan laboratorium: $labId');
    
    final trimmedId = labId.trim();
    final trimmedName = labName.trim();

    if (trimmedId.isEmpty || trimmedName.isEmpty) {
      throw Exception('Kode dan nama laboratorium tidak boleh kosong');
    }

    if (trimmedId.contains('/') || trimmedId.contains(' ')) {
      throw Exception('Kode laboratorium tidak boleh mengandung spasi atau garis miring (/)');
    }

    final labRef = _firestore.collection('labs').doc(trimmedId);
    final inventoryPlaceholderRef = labRef.collection('inventory').doc('placeholder');
    final categoriesPlaceholderRef = labRef.collection('categories').doc('placeholder');

    await _firestore.runTransaction((transaction) async {
      final labDoc = await transaction.get(labRef);
      if (labDoc.exists) {
        throw Exception('Kode laboratorium sudah digunakan');
      }

      transaction.set(labRef, {
        'name': trimmedName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(inventoryPlaceholderRef, {
        'type': 'inventory_placeholder',
        'createdAt': FieldValue.serverTimestamp(),
        'description': 'Placeholder agar koleksi inventory muncul di console',
      });

      transaction.set(categoriesPlaceholderRef, {
        'type': 'categories_placeholder',
        'createdAt': FieldValue.serverTimestamp(),
        'description': 'Placeholder agar koleksi categories muncul di console',
      });
    });
    
    debugPrint('[FirestoreService] Laboratorium $trimmedId berhasil ditambahkan');
  }

  Future<void> updateLabDetails({
    required String oldLabId,
    required String newLabId,
    required String newName,
  }) async {
    debugPrint('[FirestoreService] Memperbarui detail laboratorium: $oldLabId -> $newLabId');
    
    final trimmedNewId = newLabId.trim();
    final normalizedName = newName.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    if (trimmedNewId.isEmpty) throw Exception('Kode laboratorium tidak boleh kosong');
    if (trimmedNewId.contains('/') || trimmedNewId.contains(' ')) {
      throw Exception('Kode laboratorium tidak boleh mengandung spasi atau garis miring (/)');
    }
    if (normalizedName.length < 3) throw Exception('Nama laboratorium minimal 3 karakter');
    if (normalizedName.length > 100) throw Exception('Nama laboratorium maksimal 100 karakter');

    if (oldLabId == trimmedNewId) {
      final labRef = _firestore.collection('labs').doc(oldLabId);
      final labDoc = await labRef.get();
      if (!labDoc.exists) throw Exception('Laboratorium tidak ditemukan');

      await labRef.update({
        'name': normalizedName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _propagateLabNameChange(oldLabId, normalizedName);
      debugPrint('[FirestoreService] Nama laboratorium $oldLabId berhasil diperbarui');
      return;
    }

    final newLabRef = _firestore.collection('labs').doc(trimmedNewId);
    final newLabDoc = await newLabRef.get();
    if (newLabDoc.exists) {
      throw Exception('Kode laboratorium baru sudah digunakan');
    }

    final oldLabRef = _firestore.collection('labs').doc(oldLabId);
    final oldLabDoc = await oldLabRef.get();
    if (!oldLabDoc.exists) {
      throw Exception('Laboratorium tidak ditemukan');
    }

    final oldData = oldLabDoc.data() ?? <String, dynamic>{};
    final newData = Map<String, dynamic>.from(oldData);
    newData['name'] = normalizedName;
    newData['updatedAt'] = FieldValue.serverTimestamp();

    await newLabRef.set(newData);

    try {
      await _copyAndUpdateSubcollection(
        oldCollection: oldLabRef.collection('inventory'),
        newCollection: newLabRef.collection('inventory'),
        newLabId: trimmedNewId,
        newLabName: normalizedName,
      );

      final categoriesSnap = await oldLabRef.collection('categories').get();
      for (var catDoc in categoriesSnap.docs) {
        final newCatRef = newLabRef.collection('categories').doc(catDoc.id);
        final catData = Map<String, dynamic>.from(catDoc.data() as Map);
        
        if (catData.containsKey('labId')) catData['labId'] = trimmedNewId;
        if (catData.containsKey('labName')) catData['labName'] = normalizedName;
        
        await newCatRef.set(catData);

        await _copyAndUpdateSubcollection(
          oldCollection: catDoc.reference.collection('item_types'),
          newCollection: newCatRef.collection('item_types'),
          newLabId: trimmedNewId,
          newLabName: normalizedName,
        );
      }

      await deleteLab(oldLabId);
      
      debugPrint('[FirestoreService] Laboratorium berhasil dipindahkan dari $oldLabId ke $trimmedNewId');
    } catch (e) {
      debugPrint('[FirestoreService] Gagal menyalin data, melakukan rollback...');
      await _cleanupNewLab(trimmedNewId);
      throw Exception('Gagal mengubah kode laboratorium: $e');
    }
  }

  Future<void> _propagateLabNameChange(String labId, String newLabName) async {
    var batch = _firestore.batch();
    int count = 0;

    final invSnap = await _firestore.collection('labs').doc(labId).collection('inventory').get();
    for (var doc in invSnap.docs) {
      final data = doc.data();
      final updates = <String, dynamic>{};
      if (data.containsKey('labName')) updates['labName'] = newLabName;
      updates['updatedAt'] = FieldValue.serverTimestamp();
      
      if (updates.isNotEmpty) {
        batch.update(doc.reference, updates);
        count++;
      }
      if (count == 400) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();

    count = 0;
    batch = _firestore.batch();
    final catSnap = await _firestore.collection('labs').doc(labId).collection('categories').get();
    for (var doc in catSnap.docs) {
      final data = doc.data();
      final updates = <String, dynamic>{};
      if (data.containsKey('labName')) updates['labName'] = newLabName;
      
      if (updates.isNotEmpty) {
        batch.update(doc.reference, updates);
        count++;
      }
      if (count == 400) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();

    count = 0;
    batch = _firestore.batch();
    for (var catDoc in catSnap.docs) {
      final itemSnap = await catDoc.reference.collection('item_types').get();
      for (var itemDoc in itemSnap.docs) {
        final data = itemDoc.data();
        final updates = <String, dynamic>{};
        if (data.containsKey('labName')) updates['labName'] = newLabName;
        
        if (updates.isNotEmpty) {
          batch.update(itemDoc.reference, updates);
          count++;
        }
        if (count == 400) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      }
    }
    if (count > 0) await batch.commit();
  }

  Future<void> _copyAndUpdateSubcollection({
    required CollectionReference oldCollection,
    required CollectionReference newCollection,
    required String newLabId,
    required String newLabName,
  }) async {
    final snap = await oldCollection.get();
    if (snap.docs.isEmpty) return;

    var batch = _firestore.batch();
    int count = 0;

    for (var doc in snap.docs) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      if (data.containsKey('labId')) data['labId'] = newLabId;
      if (data.containsKey('labName')) data['labName'] = newLabName;

      batch.set(newCollection.doc(doc.id), data);
      count++;

      if (count == 400) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit();
    }
  }

  Future<void> _cleanupNewLab(String labId) async {
    final labRef = _firestore.collection('labs').doc(labId);
    
    final invSnap = await labRef.collection('inventory').get();
    await _deleteDocsInBatches(invSnap.docs);
    
    final catSnap = await labRef.collection('categories').get();
    for (var catDoc in catSnap.docs) {
      final itemSnap = await catDoc.reference.collection('item_types').get();
      await _deleteDocsInBatches(itemSnap.docs);
    }
    await _deleteDocsInBatches(catSnap.docs);
    await labRef.delete();
  }

  Future<void> deleteLab(String labId) async {
    debugPrint('[FirestoreService] Menghapus laboratorium: $labId');
    
    try {
      final labRef = _firestore.collection('labs').doc(labId);
      final labDoc = await labRef.get();
      
      if (!labDoc.exists) {
        throw Exception('Laboratorium tidak ditemukan');
      }

      final inventorySnap = await getInventoryRef(labId).get();
      await _deleteDocsInBatches(inventorySnap.docs);

      final categoriesSnap = await getCategoriesRef(labId).get();
      for (var catDoc in categoriesSnap.docs) {
        final itemTypesSnap = await getItemTypesRef(labId, catDoc.id).get();
        await _deleteDocsInBatches(itemTypesSnap.docs);
      }

      await _deleteDocsInBatches(categoriesSnap.docs);
      await labRef.delete();
      
      debugPrint('[FirestoreService] Laboratorium $labId berhasil dihapus sepenuhnya');
    } catch (e) {
      debugPrint('[FirestoreService] Gagal menghapus laboratorium $labId: $e');
      rethrow;
    }
  }

  Future<void> _deleteDocsInBatches(List<DocumentSnapshot> docs) async {
    if (docs.isEmpty) return;
    
    var batch = _firestore.batch();
    int count = 0;
    
    for (var doc in docs) {
      batch.delete(doc.reference);
      count++;
      
      if (count == 400) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }
    
    if (count > 0) {
      await batch.commit();
    }
  }

  Future<void> initializeCollections(String labId) async {
    final batch = _firestore.batch();
    bool hasOperations = false;

    final inventoryConfigRef = _firestore
        .collection('labs').doc(labId).collection('inventory').doc('placeholder');
    
    final inventoryDoc = await inventoryConfigRef.get();
    if (!inventoryDoc.exists) {
      batch.set(inventoryConfigRef, {
        'type': 'inventory_placeholder',
        'createdAt': FieldValue.serverTimestamp(),
        'description': 'Placeholder agar koleksi inventory muncul di console',
      }, SetOptions(merge: true));
      hasOperations = true;
    }

    final categoriesConfigRef = _firestore
        .collection('labs').doc(labId).collection('categories').doc('placeholder');
    
    final categoriesDoc = await categoriesConfigRef.get();
    if (!categoriesDoc.exists) {
      batch.set(categoriesConfigRef, {
        'type': 'categories_placeholder',
        'createdAt': FieldValue.serverTimestamp(),
        'description': 'Placeholder agar koleksi categories muncul di console',
      }, SetOptions(merge: true));
      hasOperations = true;
    }

    if (hasOperations) {
      await batch.commit();
    }
  }

  Future<void> initializeCategoryItemTypes(String labId, String categoryId) async {
    if (_isConfigDoc(categoryId)) return;
    
    final configRef = _firestore
        .collection('labs').doc(labId)
        .collection('categories').doc(categoryId)
        .collection('item_types').doc('placeholder');
    
    final configDoc = await configRef.get();
    if (!configDoc.exists) {
      await configRef.set({
        'type': 'item_types_placeholder',
        'createdAt': FieldValue.serverTimestamp(),
        'description': 'Placeholder agar subkoleksi item_types tetap muncul',
      }, SetOptions(merge: true));
    }
  }

  Future<void> ensureAllCategoriesHaveItemTypesConfig(String labId) async {
    try {
      final categoriesSnap = await getCategoriesRef(labId).get();
      
      for (var catDoc in _filterConfigDocs(categoriesSnap.docs)) {
        final itemTypesRef = getItemTypesRef(labId, catDoc.id);
        final placeholderRef = itemTypesRef.doc('placeholder');
        
        final configDoc = await placeholderRef.get();
        if (!configDoc.exists) {
          await placeholderRef.set({
            'type': 'item_types_placeholder',
            'createdAt': FieldValue.serverTimestamp(),
            'description': 'Placeholder agar koleksi item_types tetap muncul',
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('Warning: ensureAllCategoriesHaveItemTypesConfig error: $e');
    }
  }

  Future<void> updateUserInfoInAllRiwayat(
    String uid,
    String newNamaLengkap,
    String newNim,
    String newKelas,
    String newProdi,
  ) async {
    try {
      final allInventorySnap = await _firestore.collectionGroup('inventory').get();
      var batch = _firestore.batch();
      int operationCount = 0;

      for (var doc in _filterConfigDocs(allInventorySnap.docs)) {
        final data = doc.data() ?? <String, dynamic>{};
        final List<dynamic> riwayatList = List.from(data['riwayat'] ?? []);
        bool hasChanges = false;

        for (int i = 0; i < riwayatList.length; i++) {
          final riwayat = Map<String, dynamic>.from(riwayatList[i]);

          if (riwayat['uidPeminjam'] == uid) {
            if (riwayat['peminjam'] != newNamaLengkap) {
              riwayat['peminjam'] = newNamaLengkap;
              hasChanges = true;
            }
            if (riwayat['nim'] != newNim) {
              riwayat['nim'] = newNim;
              hasChanges = true;
            }
            if (riwayat['kelas'] != newKelas) {
              riwayat['kelas'] = newKelas;
              hasChanges = true;
            }
            if (riwayat['prodi'] != newProdi) {
              riwayat['prodi'] = newProdi;
              hasChanges = true;
            }
          }
          riwayatList[i] = riwayat;
        }

        if (hasChanges) {
          if (operationCount >= 400) {
            await batch.commit();
            batch = _firestore.batch();
            operationCount = 0;
          }

          batch.update(doc.reference, {
            'riwayat': riwayatList,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          operationCount++;
        }
      }

      if (operationCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      rethrow;
    }
  }

  CollectionReference getCategoriesRef(String labId) {
    return _firestore.collection('labs').doc(labId).collection('categories');
  }

  CollectionReference getItemTypesRef(String labId, String categoryId) {
    return getCategoriesRef(labId).doc(categoryId).collection('item_types');
  }

  CollectionReference<BarangModel> getInventoryRef(String labId) {
    return _firestore
        .collection('labs').doc(labId).collection('inventory')
        .withConverter<BarangModel>(
          fromFirestore: (snap, _) => BarangModel.fromDocument(snap),
          toFirestore: (barang, _) => barang.toMap(),
        );
  }

  Stream<List<BarangModel>> getBarangByLab(String labId) {
    return getInventoryRef(labId)
        .orderBy('tanggalInput', descending: true)
        .snapshots()
        .map(_filterAndMapBarang);
  }

  Stream<List<BarangModel>> getBarangAvailable(String labId) {
    return getInventoryRef(labId)
        .where('availableQuantity', isGreaterThan: 0)
        .snapshots()
        .map(_filterAndMapBarang);
  }

  Future<void> updateCategoryName(
    String labId, String categoryId, String oldName, String newName,
  ) async {
    if (_isConfigDoc(categoryId)) return;

    final batch = _firestore.batch();
    batch.update(getCategoriesRef(labId).doc(categoryId), {
      'name': newName,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final inventorySnap = await getInventoryRef(labId)
        .where('categoryId', isEqualTo: categoryId).get();

    for (var doc in _filterConfigDocs(inventorySnap.docs)) {
      batch.update(doc.reference, {
        'categoryName': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> updateItemTypeName(
    String labId, String categoryId, String itemId,
    String oldName, String newName,
  ) async {
    if (_isConfigDoc(itemId)) return;

    final batch = _firestore.batch();
    final itemTypeRef = getItemTypesRef(labId, categoryId).doc(itemId);
    batch.update(itemTypeRef, {
      'name': newName,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final inventorySnap = await getInventoryRef(labId)
        .where('itemId', isEqualTo: itemId).get();

    for (var doc in _filterConfigDocs(inventorySnap.docs)) {
      batch.update(doc.reference, {
        'itemName': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> updateItemUnit(
    String labId, String categoryId, String itemId,
    String oldUnit, String newUnit,
  ) async {
    if (oldUnit == newUnit || _isConfigDoc(itemId)) return;

    var batch = _firestore.batch();
    final itemTypeRef = getItemTypesRef(labId, categoryId).doc(itemId);
    batch.update(itemTypeRef, {
      'satuan': newUnit,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final inventorySnap = await getInventoryRef(labId)
        .where('itemId', isEqualTo: itemId).get();

    int operationCount = 1;
    
    for (var doc in _filterConfigDocs(inventorySnap.docs)) {
      if (operationCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        operationCount = 0;
      }
      batch.update(doc.reference, {
        'satuan': newUnit,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      operationCount++;
    }

    if (operationCount > 0) await batch.commit();
  }

  Future<void> updateItemNameAndUnit(
    String labId, String categoryId, String itemId,
    String oldName, String newName,
    String oldUnit, String newUnit,
  ) async {
    if (_isConfigDoc(itemId)) return;

    var batch = _firestore.batch();
    final itemTypeRef = getItemTypesRef(labId, categoryId).doc(itemId);
    final updates = <String, dynamic>{};
    
    if (oldName != newName) updates['name'] = newName;
    if (oldUnit != newUnit) updates['satuan'] = newUnit;
    
    if (updates.isNotEmpty) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      batch.update(itemTypeRef, updates);
    }

    final inventorySnap = await getInventoryRef(labId)
        .where('itemId', isEqualTo: itemId).get();

    int operationCount = updates.isNotEmpty ? 1 : 0;
    
    for (var doc in _filterConfigDocs(inventorySnap.docs)) {
      if (operationCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        operationCount = 0;
      }
      
      final inventoryUpdates = <String, dynamic>{};
      if (oldName != newName) inventoryUpdates['itemName'] = newName;
      if (oldUnit != newUnit) inventoryUpdates['satuan'] = newUnit;
      inventoryUpdates['updatedAt'] = FieldValue.serverTimestamp();
      
      if (inventoryUpdates.isNotEmpty) {
        batch.update(doc.reference, inventoryUpdates);
        operationCount++;
      }
    }

    if (operationCount > 0) await batch.commit();
  }

  Future<void> updateItemImage(
    String labId, String categoryId, String itemId,
    String? newImageUrl, String? newImagePublicId,
  ) async {
    if (_isConfigDoc(itemId)) return;

    var batch = _firestore.batch();
    final itemTypeRef = getItemTypesRef(labId, categoryId).doc(itemId);
    final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    
    if (newImageUrl != null) updates['imageUrl'] = newImageUrl;
    if (newImagePublicId != null) updates['imagePublicId'] = newImagePublicId;
    
    if (updates.length > 1) batch.update(itemTypeRef, updates);

    final inventorySnap = await getInventoryRef(labId)
        .where('itemId', isEqualTo: itemId).get();

    int operationCount = updates.length > 1 ? 1 : 0;
    
    for (var doc in _filterConfigDocs(inventorySnap.docs)) {
      if (operationCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        operationCount = 0;
      }
      
      final inventoryUpdates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
      if (newImageUrl != null) inventoryUpdates['imageUrl'] = newImageUrl;
      if (newImagePublicId != null) inventoryUpdates['imagePublicId'] = newImagePublicId;
      
      if (inventoryUpdates.length > 1) {
        batch.update(doc.reference, inventoryUpdates);
        operationCount++;
      }
    }

    if (operationCount > 0) await batch.commit();
  }

  Future<void> deleteItemImage(
    String labId, String categoryId, String itemId,
  ) async {
    if (_isConfigDoc(itemId)) return;

    var batch = _firestore.batch();
    final itemTypeRef = getItemTypesRef(labId, categoryId).doc(itemId);
    
    batch.update(itemTypeRef, {
      'imageUrl': FieldValue.delete(),
      'imagePublicId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final inventorySnap = await getInventoryRef(labId)
        .where('itemId', isEqualTo: itemId).get();

    int operationCount = 1;
    
    for (var doc in _filterConfigDocs(inventorySnap.docs)) {
      if (operationCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        operationCount = 0;
      }
      
      batch.update(doc.reference, {
        'imageUrl': FieldValue.delete(),
        'imagePublicId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      operationCount++;
    }

    if (operationCount > 0) await batch.commit();
  }

  Future<void> addBarang(String labId, BarangModel barang) async {
    if (_isConfigDoc(barang.serialNumber)) {
      throw Exception('Serial Number "placeholder" tidak diperbolehkan');
    }

    final ref = getInventoryRef(labId).doc(_sanitizeSerialForDocId(barang.serialNumber));
    final labDoc = await _firestore.collection('labs').doc(labId).get();

    if (!labDoc.exists) throw Exception('Lab tidak ditemukan');
    final labName = labDoc.data()?['name'] ?? labId;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (snapshot.exists) throw Exception('Serial Number sudah terdaftar');

      final newBarang = barang.copyWith(labId: labId, labName: labName);
      transaction.set(ref, newBarang);
    });
  }

  Future<void> addQuantity(String labId, String serialNumber, int addQty) async {
    if (addQty <= 0 || _isConfigDoc(serialNumber)) return;

    final ref = getInventoryRef(labId).doc(_sanitizeSerialForDocId(serialNumber));

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw Exception('Barang tidak ditemukan');

      transaction.update(ref, {
        'totalQuantity': FieldValue.increment(addQty),
        'availableQuantity': FieldValue.increment(addQty),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<BarangModel?> getBarang(String labId, String serialNumber) async {
    if (_isConfigDoc(serialNumber)) return null;
    final doc = await getInventoryRef(labId).doc(_sanitizeSerialForDocId(serialNumber)).get();
    return doc.data();
  }

  Future<void> pinjamBarang(
    String labId, String serialNumber,
    RiwayatPeminjaman riwayat, int qty, {
    bool isFromReservation = false,
  }) async {
    if (qty <= 0 || _isConfigDoc(serialNumber)) return;

    final ref = getInventoryRef(labId).doc(_sanitizeSerialForDocId(serialNumber));

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw Exception('Barang tidak ditemukan');

      final barang = snapshot.data();
      if (barang == null) throw Exception('Data barang tidak valid');
      if (barang.condition == 'RUSAK') throw Exception('Barang dalam kondisi rusak');
      
      if (barang.availableQuantity < qty) {
        throw Exception('Stok tidak cukup');
      }

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'riwayat': FieldValue.arrayUnion([
          riwayat.copyWith(quantity: qty).toMap(),
        ]),
      };

      updates['availableQuantity'] = FieldValue.increment(-qty);

      transaction.update(ref, updates);
    });
  }

  Future<void> kembalikanBarangSpecific(
    String labId,
    String serialNumber,
    String uidPeminjam,
    Timestamp tanggalPinjam,
  ) async {
    if (_isConfigDoc(serialNumber)) return;

    final ref = getInventoryRef(labId).doc(_sanitizeSerialForDocId(serialNumber));

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw Exception('Barang tidak ditemukan');

      final barang = snapshot.data();
      if (barang == null) throw Exception('Data barang tidak valid');
      
      final updatedRiwayat = List<RiwayatPeminjaman>.from(barang.riwayat);
      
      final index = updatedRiwayat.lastIndexWhere((r) => 
          r.uidPeminjam == uidPeminjam && 
          r.tanggalPinjam == tanggalPinjam
      );

      if (index == -1) throw Exception('Tidak ada riwayat peminjaman yang cocok');

      final selected = updatedRiwayat[index];
      updatedRiwayat.removeAt(index);

      transaction.update(ref, {
        'availableQuantity': FieldValue.increment(selected.quantity),
        'updatedAt': FieldValue.serverTimestamp(),
        'riwayat': updatedRiwayat.map((e) => e.toMap()).toList(),
      });
    });
  }

  Future<void> updateCondition(
    String labId, String serialNumber, String condition,
  ) async {
    if (_isConfigDoc(serialNumber)) return;

    final ref = getInventoryRef(labId).doc(_sanitizeSerialForDocId(serialNumber));

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;

      final barang = snapshot.data();
      if (barang == null) return;

      if (barang.sedangDipinjam && condition == 'RUSAK') {
        throw Exception('Tidak bisa ubah ke rusak saat sedang dipinjam');
      }

      transaction.update(ref, {
        'condition': condition,
        'availableQuantity': condition == 'BAIK' ? barang.totalQuantity : 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteBarang(String labId, String serialNumber) async {
    if (_isConfigDoc(serialNumber)) return;
    
    final ref = getInventoryRef(labId).doc(_sanitizeSerialForDocId(serialNumber));
    final doc = await ref.get();
    
    if (!doc.exists) return;
    
    final barang = doc.data();
    if (barang == null || barang.sedangDipinjam) {
      throw Exception('Tidak dapat menghapus barang yang sedang dipinjam atau data tidak valid');
    }
    
    await ref.delete();
  }

  Future<int> countBarang(String labId) async {
    final snapshot = await getInventoryRef(labId).get();
    return _filterConfigDocs(snapshot.docs).length;
  }

  Future<void> deleteCategoryAndRelated(
    String labId, String categoryId, String categoryName,
  ) async {
    if (_isConfigDoc(categoryId)) return;

    try {
      final inventorySnap = await getInventoryRef(labId)
          .where('categoryId', isEqualTo: categoryId).get();

      for (var doc in inventorySnap.docs) {
        final barang = doc.data();
        if (barang.sedangDipinjam) {
          throw Exception('Tidak dapat menghapus kategori karena masih ada barang yang sedang dipinjam');
        }
      }
      
      if (inventorySnap.docs.isNotEmpty) {
        await _deleteDocsInBatches(inventorySnap.docs);
      }

      final itemSnap = await getItemTypesRef(labId, categoryId).get();
      final validItemDocs = _filterConfigDocs(itemSnap.docs).toList();
      
      if (validItemDocs.isNotEmpty) {
        await _deleteDocsInBatches(validItemDocs);
      }

      await getCategoriesRef(labId).doc(categoryId).delete();
      
      debugPrint('[FirestoreService] Kategori $categoryId berhasil dihapus');
    } catch (e) {
      debugPrint('[FirestoreService] Gagal menghapus kategori $categoryId: $e');
      rethrow;
    }
  }

  Future<void> deleteItemTypeAndRelatedInventory(
    String labId, String categoryId, String itemId, String itemName,
  ) async {
    if (_isConfigDoc(itemId)) return;

    try {
      final inventorySnap = await getInventoryRef(labId)
          .where('itemId', isEqualTo: itemId).get();

      for (var doc in inventorySnap.docs) {
        final barang = doc.data();
        if (barang.sedangDipinjam) {
          throw Exception('Tidak dapat menghapus item type karena masih ada barang yang sedang dipinjam');
        }
      }

      if (inventorySnap.docs.isNotEmpty) {
        await _deleteDocsInBatches(inventorySnap.docs);
      }

      await getItemTypesRef(labId, categoryId).doc(itemId).delete();
      
      debugPrint('[FirestoreService] Item type $itemId berhasil dihapus');
    } catch (e) {
      debugPrint('[FirestoreService] Gagal menghapus item type $itemId: $e');
      rethrow;
    }
  }

  CollectionReference<ReservationModel> getReservationsRef() {
    return _firestore.collection('reservations').withConverter<ReservationModel>(
      fromFirestore: (snap, _) => ReservationModel.fromDocument(snap),
      toFirestore: (reservation, _) => reservation.toMap(),
    );
  }

  Future<String> createReservation(ReservationModel reservation) async {
    debugPrint('[FirestoreService] Membuat atau memperbarui reservasi untuk itemId: ${reservation.itemId}');

    if (reservation.quantity <= 0) {
      throw Exception('Jumlah barang harus lebih dari 0');
    }
    if (reservation.uid.isEmpty) {
      throw Exception('UID tidak boleh kosong');
    }
    if (reservation.labId.isEmpty) {
      throw Exception('Lab ID tidak boleh kosong');
    }
    if (reservation.itemId.isEmpty) {
      throw Exception('Item ID tidak boleh kosong');
    }

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final tanggalKembali = reservation.tanggalHarusKembali.toDate();
    final tanggalKembaliDate = DateTime(tanggalKembali.year, tanggalKembali.month, tanggalKembali.day);
    
    if (tanggalKembaliDate.isBefore(today)) {
      throw Exception('Tanggal harus kembali tidak valid (tidak boleh di masa lalu)');
    }

    final reservationRef = getReservationsRef().doc();

    await _firestore.runTransaction((transaction) async {
      final userReservationsSnap = await _firestore.collection('reservations')
          .where('uid', isEqualTo: reservation.uid)
          .where('labId', isEqualTo: reservation.labId)
          .where('categoryId', isEqualTo: reservation.categoryId)
          .where('itemId', isEqualTo: reservation.itemId)
          .where('status', isEqualTo: ReservationModel.dipesan)
          .limit(1)
          .get();

      final inventorySnap = await _firestore.collection('labs')
          .doc(reservation.labId)
          .collection('inventory')
          .where('itemId', isEqualTo: reservation.itemId)
          .where('condition', isEqualTo: 'BAIK')
          .get();

      if (inventorySnap.docs.isEmpty) {
        throw Exception('Barang tidak ditemukan');
      }

      int totalAvailable = 0;
      for (var doc in inventorySnap.docs) {
        totalAvailable += (doc.data()['availableQuantity'] as int? ?? 0);
      }

      // ✅ PERBAIKAN: Hitung total yang sudah direservasi
      int totalReserved = 0;
      final reservedSnap = await _firestore.collection('reservations')
          .where('labId', isEqualTo: reservation.labId)
          .where('categoryId', isEqualTo: reservation.categoryId)
          .where('itemId', isEqualTo: reservation.itemId)
          .where('status', isEqualTo: ReservationModel.dipesan)
          .get();
      
      for (var doc in reservedSnap.docs) {
        totalReserved += (doc.data()['quantity'] as int? ?? 0);
      }

      int stokReservasi = totalAvailable - totalReserved;

      if (stokReservasi < reservation.quantity) {
        throw Exception('Stok tidak mencukupi');
      }

      if (userReservationsSnap.docs.isNotEmpty) {
        final existingDoc = userReservationsSnap.docs.first;
        final updates = <String, dynamic>{
          'quantity': FieldValue.increment(reservation.quantity),
          'tanggalHarusKembali': reservation.tanggalHarusKembali,
          'createdAt': Timestamp.now(),
        };

        if (reservation.catatan != null && reservation.catatan!.isNotEmpty) {
          updates['catatan'] = reservation.catatan;
        }

        transaction.update(existingDoc.reference, updates);
      } else {
        final newReservation = reservation.copyWith(
          id: reservationRef.id,
          status: ReservationModel.dipesan,
          createdAt: Timestamp.now(),
        );
        transaction.set(reservationRef, newReservation);
      }
    });

    debugPrint('[FirestoreService] Reservasi berhasil diproses');
    return reservationRef.id;
  }

  Stream<List<ReservationModel>> getPendingReservations() {
    return getReservationsRef()
        .where('status', isEqualTo: ReservationModel.dipesan)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => doc.data())
          .whereType<ReservationModel>()
          .toList();
      
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<ReservationModel>> getReservationsByUid(String uid) {
    return getReservationsRef()
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => doc.data())
          .whereType<ReservationModel>()
          .toList();
      
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<ReservationModel>> getAllReservations() {
    return getReservationsRef()
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).whereType<ReservationModel>().toList());
  }

  Future<ReservationModel?> getReservation(String reservationId) async {
    final doc = await getReservationsRef().doc(reservationId).get();
    return doc.data();
  }

  Future<void> updateReservationStatus(String reservationId, String status) async {
    if (status != ReservationModel.dipesan && status != ReservationModel.dibatalkan) {
      throw Exception('Status tidak valid');
    }

    final reservationRef = getReservationsRef().doc(reservationId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reservationRef);
      if (!snapshot.exists) {
        throw Exception('Reservasi tidak ditemukan');
      }

      final currentStatus = snapshot.data()?.status;
      if (currentStatus == null) {
        throw Exception('Data reservasi tidak valid');
      }

      bool isValidTransition = false;
      if (currentStatus == ReservationModel.dipesan && status == ReservationModel.dibatalkan) {
        isValidTransition = true;
      }

      if (!isValidTransition) {
        throw Exception('Transisi status tidak valid dari $currentStatus ke $status');
      }

      transaction.update(reservationRef, {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    debugPrint('[FirestoreService] Mengupdate status reservasi $reservationId menjadi $status');
  }

  Future<void> cancelReservation(String reservationId) async {
    debugPrint('[FirestoreService] Membatalkan reservasi: $reservationId');

    final reservationRef = getReservationsRef().doc(reservationId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reservationRef);
      if (!snapshot.exists) {
        throw Exception('Reservasi tidak ditemukan');
      }

      final reservation = snapshot.data();
      if (reservation == null || reservation.status != ReservationModel.dipesan) {
        throw Exception('Hanya reservasi dengan status dipesan yang dapat dibatalkan');
      }

      transaction.update(reservationRef, {
        'status': ReservationModel.dibatalkan,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    debugPrint('[FirestoreService] Reservasi $reservationId berhasil dibatalkan');
  }

  Future<void> deleteReservation(String reservationId) async {
    debugPrint('[FirestoreService] Menghapus reservasi: $reservationId');
    
    final reservationRef = getReservationsRef().doc(reservationId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reservationRef);
      if (!snapshot.exists) {
        throw Exception('Reservasi tidak ditemukan');
      }

      final reservation = snapshot.data();
      if (reservation == null) {
        throw Exception('Data reservasi tidak valid');
      }

      transaction.delete(reservationRef);
    });
  }
}