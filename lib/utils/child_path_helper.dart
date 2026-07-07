import 'package:shared_preferences/shared_preferences.dart';

/// Normalise le chemin Firestore d'un enfant lu depuis SharedPreferences.
String? normalizeChildPath(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
}

/// Lit et normalise [child_path] depuis SharedPreferences.
Future<String?> readChildPath(SharedPreferences prefs) async {
  await prefs.reload();
  return normalizeChildPath(prefs.getString('child_path'));
}
