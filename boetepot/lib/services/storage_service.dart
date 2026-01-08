import 'dart:typed_data';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static Future<String> uploadProfileJpeg(String uid, Uint8List bytes) async {
    // Keep parity with the original iOS app path: `userphotos/{uid}.jpg`.
    final ref = FirebaseStorage.instance.ref('userphotos/$uid.jpg');
    try {
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      // Occasionally `getDownloadURL()` can throw `object-not-found` right after upload.
      // Retry briefly to avoid a false-negative.
      var delay = const Duration(milliseconds: 120);
      for (var attempt = 0; attempt < 4; attempt++) {
        try {
          return await ref.getDownloadURL();
        } on FirebaseException catch (e) {
          if (e.code != 'object-not-found' || attempt == 3) rethrow;
          await Future<void>.delayed(delay);
          delay *= 2;
        }
      }
      // Should be unreachable.
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      final msg = e.message ?? e.toString();
      if (e.code == 'unauthorized' || e.code == 'permission-denied') {
        throw Exception(
          'Firebase Storage (${e.code}): $msg. '
          'Controleer je Storage Rules voor pad `userphotos/{uid}.jpg` (de bestandsnaam is letterlijk `${uid}.jpg`).',
        );
      }
      throw Exception('Firebase Storage (${e.code}): $msg');
    }
  }
}
