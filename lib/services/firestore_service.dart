import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> create(String path, Map<String, dynamic> data) async {
    await _db.collection(path).add(data);
  }

  Stream<QuerySnapshot> stream(String path) {
    return _db.collection(path).snapshots();
  }
}
