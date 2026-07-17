import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/kyc_models.dart';
import '../services/kyc_service.dart';
import '../repositories/kyc_repository.dart';
import '../services/api_service.dart';

/// Contrôle le workflow KYC étape par étape.
class KycController extends ChangeNotifier {
  final KycService _service = KycService();
  final KycRepository _repo = KycRepository();
  final ImagePicker _picker = ImagePicker();

  int _step =
      0; // 0=welcome 1=why 2=privacy 3=docChoice 4=tips 5=capture 6=selfie 7=analysing 8=result
  int get step => _step;

  String _selectedDocType = 'CNI';
  String get selectedDocType => _selectedDocType;

  File? _documentImageFront;
  File? get documentImageFront => _documentImageFront;

  File? _documentImageBack;
  File? get documentImageBack => _documentImageBack;

  File? _documentImageSelfie;
  File? get documentImageSelfie => _documentImageSelfie;

  KycAnalysisResult? _result;
  KycAnalysisResult? get result => _result;

  KycStatus _status = KycStatus.notStarted;
  KycStatus get status => _status;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _storagePath;

  void init() {
    _service.loadModel();
    _loadCurrentStatus();
    _loadStateFromPrefs();
  }

  Future<void> _loadCurrentStatus() async {
    _status = await _repo.getCurrentStatus();
    if (_status == KycStatus.verified || _status == KycStatus.pending) {
      _step = 8;
    }
    notifyListeners();
  }

  // ── Persistance de l'état pour parer à la destruction de l'activité Android ──
  Future<void> _saveStateToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('kyc_step', _step);
      await prefs.setString('kyc_selected_doc_type', _selectedDocType);
      if (_documentImageFront != null) {
        await prefs.setString(
            'kyc_image_front_path', _documentImageFront!.path);
      } else {
        await prefs.remove('kyc_image_front_path');
      }
      if (_documentImageBack != null) {
        await prefs.setString('kyc_image_back_path', _documentImageBack!.path);
      } else {
        await prefs.remove('kyc_image_back_path');
      }
      if (_documentImageSelfie != null) {
        await prefs.setString(
            'kyc_image_selfie_path', _documentImageSelfie!.path);
      } else {
        await prefs.remove('kyc_image_selfie_path');
      }
      debugPrint('KYC_CTRL: État sauvegardé (step=$_step)');
    } catch (e) {
      debugPrint('KYC_CTRL: Erreur sauvegarde état: $e');
    }
  }

  Future<void> _loadStateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('kyc_step')) {
        _step = prefs.getInt('kyc_step') ?? _step;
        _selectedDocType =
            prefs.getString('kyc_selected_doc_type') ?? _selectedDocType;
        final frontPath = prefs.getString('kyc_image_front_path');
        if (frontPath != null) {
          _documentImageFront = File(frontPath);
        }
        final backPath = prefs.getString('kyc_image_back_path');
        if (backPath != null) {
          _documentImageBack = File(backPath);
        }
        final selfiePath = prefs.getString('kyc_image_selfie_path');
        if (selfiePath != null) {
          _documentImageSelfie = File(selfiePath);
        }
        debugPrint(
            'KYC_CTRL: État restauré (step=$_step, front=${_documentImageFront != null}, back=${_documentImageBack != null}, selfie=${_documentImageSelfie != null})');
      }
      // Lancer la récupération des données perdues
      await _retrieveLostData();
    } catch (e) {
      debugPrint('KYC_CTRL: Erreur chargement état: $e');
    }
  }

  Future<void> _clearStateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('kyc_step');
      await prefs.remove('kyc_selected_doc_type');
      await prefs.remove('kyc_image_front_path');
      await prefs.remove('kyc_image_back_path');
      await prefs.remove('kyc_image_selfie_path');
      debugPrint('KYC_CTRL: État nettoyé des préférences');
    } catch (e) {
      debugPrint('KYC_CTRL: Erreur nettoyage état: $e');
    }
  }

  Future<void> _retrieveLostData() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty) return;
      if (response.file != null) {
        final lostFile = File(response.file!.path);
        debugPrint('KYC_CTRL: Image perdue récupérée : ${lostFile.path}');

        if (_step == 6) {
          // Étape selfie
          _documentImageSelfie = lostFile;
          _step = 7; // go to analysing
          await _saveStateToPrefs();
          notifyListeners();
          await analyseDocument();
        } else {
          // Étape document
          if (_selectedDocType == 'PASSPORT') {
            _documentImageFront = lostFile;
            _step = 6; // Go to selfie capture
            await _saveStateToPrefs();
            notifyListeners();
          } else {
            if (_documentImageFront == null) {
              _documentImageFront = lostFile;
              _step = 5; // Reste à la capture pour prendre le verso
              await _saveStateToPrefs();
              notifyListeners();
            } else {
              _documentImageBack = lostFile;
              _step = 6; // Go to selfie capture
              await _saveStateToPrefs();
              notifyListeners();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('KYC_CTRL: Erreur retrieveLostData: $e');
    }
  }

  void setStep(int s) {
    _step = s;
    _saveStateToPrefs();
    notifyListeners();
  }

  void nextStep() {
    _step++;
    _saveStateToPrefs();
    notifyListeners();
  }

  void prevStep() {
    if (_step > 0) {
      _step--;
      _saveStateToPrefs();
      notifyListeners();
    }
  }

  void selectDocType(String type) {
    _selectedDocType = type;
    _saveStateToPrefs();
    notifyListeners();
  }

  Future<void> captureDocument() async {
    try {
      final isSelfieStep = _step == 6;
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice:
            isSelfieStep ? CameraDevice.front : CameraDevice.rear,
      );
      if (picked != null) {
        final capturedFile = File(picked.path);
        if (isSelfieStep) {
          _documentImageSelfie = capturedFile;
          _step = 7; // go to analysing
          await _saveStateToPrefs();
          notifyListeners();
          await analyseDocument();
        } else {
          if (_selectedDocType == 'PASSPORT') {
            _documentImageFront = capturedFile;
            _step = 6; // Go to selfie capture
            await _saveStateToPrefs();
            notifyListeners();
          } else {
            if (_documentImageFront == null) {
              _documentImageFront = capturedFile;
              _step = 5; // Rester pour guider le verso
              await _saveStateToPrefs();
              notifyListeners();
            } else {
              _documentImageBack = capturedFile;
              _step = 6; // Go to selfie capture
              await _saveStateToPrefs();
              notifyListeners();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('KYC_CTRL: Erreur capture: $e');
    }
  }

  Future<void> analyseDocument() async {
    if (_documentImageFront == null) return;
    _isLoading = true;
    notifyListeners();

    await _repo.updateStatus(KycStatus.analysing);
    _result = await _service.analyseDocument(_documentImageFront!);

    if (_result!.isAccepted) {
      // Upload recto, verso (si existant), et selfie (si existant)
      _storagePath = await _repo.uploadDocument(
        _documentImageFront!,
        _selectedDocType,
        imageFileBack: _documentImageBack,
        imageFileSelfie: _documentImageSelfie,
      );
      await _repo.recordAttempt(
        result: _result!,
        selectedDocType: _selectedDocType,
        storagePath: _storagePath,
      );
      await _repo.updateStatus(KycStatus.pending);
      await ApiService().updateKycStatus('PENDING');
      _status = KycStatus.pending;
    } else {
      await _repo.recordAttempt(
          result: _result!, selectedDocType: _selectedDocType);
      await _repo.updateStatus(KycStatus.inProgress);
    }

    // Nettoyage fichiers temporaires
    await _repo.deleteTemporaryFile(_documentImageFront!);
    _documentImageFront = null;
    if (_documentImageBack != null) {
      await _repo.deleteTemporaryFile(_documentImageBack!);
      _documentImageBack = null;
    }
    if (_documentImageSelfie != null) {
      await _repo.deleteTemporaryFile(_documentImageSelfie!);
      _documentImageSelfie = null;
    }

    await _clearStateFromPrefs();

    _isLoading = false;
    _step = 8;
    notifyListeners();
  }

  void retake() {
    _result = null;
    _documentImageFront = null;
    _documentImageBack = null;
    _documentImageSelfie = null;
    _step = 4; // retour aux conseils
    _saveStateToPrefs();
    notifyListeners();
  }

  Future<void> resetKycStatus() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repo.updateStatus(KycStatus.notStarted);
      await ApiService().updateKycStatus('NOT_STARTED');
      _status = KycStatus.notStarted;
      _step = 0;
      _result = null;
      _documentImageFront = null;
      _documentImageBack = null;
      _documentImageSelfie = null;
      await _clearStateFromPrefs();
    } catch (e) {
      debugPrint('KYC_CTRL: Erreur reset: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
