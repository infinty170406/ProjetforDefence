import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_config.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

class ApiService extends ChangeNotifier {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  String? _accessToken;
  bool _isOtpVerified = false;
  bool _isKycVerified = false;

  bool get isOtpVerified => _isOtpVerified;
  bool get isKycVerified => _isKycVerified;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'TheGuardianApp/1.0',
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_accessToken != null) {
          debugPrint(
              'API_LOG: Adding Auth Header (Length: ${_accessToken!.length})');
          options.headers['Authorization'] = 'Bearer $_accessToken';
        } else {
          debugPrint('API_LOG: Request WITHOUT Auth Header');
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        String errorMessage = 'An error occurred';

        if (e.response != null && e.response?.data is Map) {
          final data = e.response?.data as Map<String, dynamic>;
          if (data.containsKey('message')) {
            errorMessage = data['message'];
          } else if (data.containsKey('error')) {
            errorMessage = data['error'];
          }
        } else if (e.response?.statusCode == 403) {
          errorMessage = 'Access denied (403). Your session may have expired.';
        } else if (e.response?.statusCode == 503) {
          errorMessage =
              'Server in maintenance or waking up. Please try again.';
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          errorMessage =
              'Slow connection: the server is waking up (first try can take up to 1 min).';
        } else {
          errorMessage =
              'Technical error: ${e.response?.statusCode ?? ""} ${e.message ?? e.toString()}';
        }

        return handler.next(DioException(
          requestOptions: e.requestOptions,
          response: e.response,
          type: e.type,
          error: ApiException(errorMessage, e.response?.statusCode),
        ));
      },
    ));
  }

  void setAccessToken(String token) {
    _accessToken = token;
    StorageService().saveToken(token);
  }

  Future<void> initialize() async {
    _accessToken = await StorageService().getToken();
    if (_accessToken != null) {
      try {
        final profile = await FirestoreService().getMyProfile();
        _isKycVerified = profile['kycStatus'] == 'VERIFIED';
        _isOtpVerified = profile['otpVerified'] == true;
        
        // TRIGGER INIT: Ensure Firestore folders are created immediately at startup
        await FirestoreService().getMyChildren();
      } catch (_) {
        _isKycVerified = false;
        _isOtpVerified = false;
      }
    }
  }


  void clearToken() {
    _accessToken = null;
    StorageService().clearAll();
  }

  T _handleError<T>(Object e) {
    if (e is DioException && e.error is ApiException) {
      throw e.error as ApiException;
    }
    throw e;
  }

  Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> postMultipart(
      String path, FormData formData) async {
    try {
      final response = await _dio.post(
        path,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  // ==================== AUTH ====================

  Future<void> loginWithEmailPassword(String email, String password) async {
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final idToken = await userCredential.user?.getIdToken();
      if (idToken != null) {
        setAccessToken(idToken);
        await getMyProfile(); // Read otpVerified from Firestore -> Dashboard direct if already verified
      }
    } on FirebaseAuthException catch (e) {
      throw ApiException(e.message ?? 'Authentication failed');
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw ApiException(e.message ?? 'Failed to send reset email');
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // Use Firebase Auth's built-in web popup which is more reliable than google_sign_in plugin on web
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // Mobile implementation
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final idToken = await userCredential.user?.getIdToken();

      if (idToken != null) {
        setAccessToken(idToken);
        final name = userCredential.user?.displayName ?? 'Guardian Parent';
        final email = userCredential.user?.email ?? '';
        await StorageService().saveUserName(name);
        await StorageService().saveUserInfo(name, email);
        await FirestoreService().ensureProfileExists(name, email);
        await getMyProfile(); // Read otpVerified -> Dashboard direct if already verified
      }
    } on FirebaseAuthException catch (e) {
      throw ApiException(e.message ?? 'Google Sign-In failed');
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> registerWithEmailPassword(
      String name, String email, String password) async {
    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCredential.user?.updateDisplayName(name);
      final idToken = await userCredential.user?.getIdToken();
      if (idToken != null) {
        setAccessToken(idToken);
        await StorageService().saveUserName(name);
        await StorageService().saveUserInfo(name, email);
        await FirestoreService().ensureProfileExists(name, email);
        // New account: OTP required before accessing dashboard
        _isOtpVerified = false;
        notifyListeners();
      }
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'email-already-in-use' =>
          'This email is already registered. Please log in instead.',
        'weak-password' =>
          'Password is too weak. Please use at least 6 characters.',
        'invalid-email' => 'The email address is invalid.',
        _ => e.message ?? 'Registration failed',
      };
      throw ApiException(msg);
    } catch (e) {
      _handleError(e);
    }
  }

  // ==================== PARENT ====================

  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final data = await FirestoreService().getMyProfile();
      await StorageService().saveUserInfo(
        data['name'] ?? '',
        data['email'] ?? '',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'parent_id', FirebaseAuth.instance.currentUser?.uid ?? '');
      
      _isKycVerified = data['kycStatus'] == 'VERIFIED';
      _isOtpVerified = data['otpVerified'] == true;
      notifyListeners();
      
      return data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<void> updateKycStatus(String status) async {
    try {
      await FirestoreService().updateKycStatus(status);
      _isKycVerified = status == 'VERIFIED';
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> updateOtpStatus(bool value) async {
    await StorageService().saveOtpConfigured(value);
    _isOtpVerified = value;
    notifyListeners();
  }

  // ── OTP ──────────────────────────────────────────────────────────────────

  Future<void> sendOtp() async {
    try {
      await FirestoreService().sendOtpCode();
    } catch (e) {
      _handleError(e);
    }
  }

  Future<bool> verifyOtp(String code) async {
    try {
      final success = await FirestoreService().verifyOtpCode(code);
      if (success) {
        await updateOtpStatus(true);
      }
      return success;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getMyChildren() async {
    try {
      final children = await FirestoreService().getMyChildren();
      return {'children': children};
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createChild({
    required String displayName,
    required int age,
  }) async {
    try {
      final result = await FirestoreService().createChild(
        displayName: displayName,
        age: age,
      );
      notifyListeners();
      return result;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<void> linkChild(String childId) async {
    try {
      await FirestoreService().linkChild(childId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateChild(
    String childId, {
    required String displayName,
    required int age,
  }) async {
    try {
      final result = await FirestoreService().updateChild(
        childId,
        displayName: displayName,
        age: age,
      );
      notifyListeners();
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteChild(String childId) async {
    try {
      await FirestoreService().deleteChild(childId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // ==================== PARENTAL ====================

  Future<Map<String, dynamic>> getParentalProfile(String childId) async {
    try {
      return await FirestoreService().getParentalProfile(childId);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateParentalProfile(
    String childId, {
    required bool enabled,
    required String mode,
    String? timezone,
  }) async {
    try {
      final data = {
        'enabled': enabled,
        'mode': mode,
        if (timezone != null) 'timezone': timezone,
      };
      await FirestoreService().updateParentalProfile(childId, data);
      return data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createSchedule(
    String childId, {
    required List<String> daysOfWeek,
    required String startTime,
    required String endTime,
    required String action,
    bool enabled = true,
  }) async {
    try {
      await FirestoreService().createSchedule(childId, {
        'daysOfWeek': daysOfWeek,
        'startTime': startTime,
        'endTime': endTime,
        'action': action,
        'enabled': enabled,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> upsertContentRule(
    String childId, {
    required String category,
    required String action,
    bool enabled = true,
  }) async {
    try {
      final data = {
        'action': action,
        'enabled': enabled,
      };
      await FirestoreService().updateContentRule(childId, category, data);
      return data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getHistory(String childId) async {
    try {
      return await FirestoreService().getHistory(childId);
    } catch (e) {
      rethrow;
    }
  }

  // ==================== EXECUTE ====================

  Future<Map<String, dynamic>> execute({
    required String childId,
    required String intent,
    required Map<String, dynamic> parameters,
  }) async {
    try {
      final request = {
        'requestId': DateTime.now().millisecondsSinceEpoch.toString(),
        'childId': childId,
        'intent': intent,
        'parameters': parameters,
        'source': 'MOBILE_APP',
      };
      final response = await _dio.post(ApiConfig.execute, data: request);
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  // ==================== GEOFENCES ====================

  Future<List<dynamic>> getGeofences() async {
    try {
      return await FirestoreService().getGeofences();
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createGeofence(Map<String, dynamic> data, {String? childId}) async {
    try {
      return await FirestoreService().createGeofence(data, childId: childId);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<void> deleteGeofence(String id) async {
    try {
      await FirestoreService().deleteGeofence(id);
    } catch (e) {
      _handleError(e);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}
