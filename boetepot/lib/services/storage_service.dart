import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static Future<String> uploadProfileJpeg(String uid, Uint8List bytes) async {
    final ref = FirebaseStorage.instance.ref('users/$uid/profile.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}