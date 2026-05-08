import 'package:cloud_firestore/cloud_firestore.dart';

/// Profil minimal de l'enfant tel que stocké dans Firestore.
class ChildProfile {
  final String id;
  final String? parentId;
  final String name;
  final String? deviceId;

  ChildProfile({
    required this.id,
    this.parentId,
    required this.name,
    this.deviceId,
  });

  factory ChildProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChildProfile(
      id:       doc.id,
      parentId: data['parentId'] as String?,
      name:     data['name'] ?? data['displayName'] ?? '',
      deviceId: data['deviceId'] as String?,
    );
  }
}
