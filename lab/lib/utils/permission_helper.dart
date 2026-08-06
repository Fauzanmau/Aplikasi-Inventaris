import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {

  static Future<bool> requestStorage() async {

    if (!Platform.isAndroid) {
      return true; 
    }

    // Android 11+ (API 30+)
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }

    // Android < 11
    if (await Permission.storage.isGranted) {
      return true;
    }

    if (await Permission.storage.request().isGranted) {
      return true;
    }

    return false;
  }
}
