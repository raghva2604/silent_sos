import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  /// Upload [file] to Firebase Storage under [remotePath] and return the
  /// public download URL. Throws on failure.
  static Future<String> uploadFile(File file, String remotePath) async {
    final ref = FirebaseStorage.instance.ref(remotePath);

    // Use putFile with default metadata. Exponential retry/policy can be added.
    final uploadTask = ref.putFile(file);

    // Wait for completion
    final snapshot = await uploadTask.whenComplete(() {});

    if (snapshot.state == TaskState.success) {
      final url = await ref.getDownloadURL();
      return url;
    }

    throw Exception('Upload failed with state: ${snapshot.state}');
  }
}
