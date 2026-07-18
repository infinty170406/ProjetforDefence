import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/pairing_link_service.dart';
import '../../features/subscription/domain/subscription_model.dart';
import '../../features/subscription/services/subscription_service.dart';

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  int _currentStep =
      0; // 0: Parent Profile, 1: Create Family, 2: First Child, 3: Pair Device, 4: Premium Trial
  bool _isLoading = false;

  // Step 1: Parent Profile
  final _parentNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  String _parentRelation = 'Mère';

  // Step 2: Create Family
  final _familyNameController = TextEditingController();

  // Step 3: First Child
  final _childNameController = TextEditingController();
  final _childAgeController = TextEditingController();
  String _childRelation = 'Fils';
  String _childAvatar = '👦';

  // Step 4: Device Pairing
  String _linkageCode = '';

  @override
  void initState() {
    super.initState();
    _loadParentProfile();
  }

  Future<void> _loadParentProfile() async {
    try {
      final profile = await FirestoreService().getMyProfile();
      setState(() {
        _parentNameController.text = profile['name'] ?? '';
        _familyNameController.text = profile['name'] != null
            ? 'Famille ${profile['name'].toString().split(' ').last.toUpperCase()}'
            : 'Famille DUPONT';
      });
    } catch (e) {
      // Ignore
    }
  }

  @override
  void dispose() {
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    _familyNameController.dispose();
    _childNameController.dispose();
    _childAgeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
      if (_currentStep == 3) {
        _startPairingSimulation();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _startPairingSimulation() async {
    setState(() {
      _isLoading = true;
      _linkageCode = '';
    });

    try {
      final age = int.tryParse(_childAgeController.text) ?? 10;
      final childData = await FirestoreService().createChild(
        displayName: _childNameController.text.trim(),
        age: age,
        avatar: _childAvatar,
        relation: _childRelation,
      );

      final token = PairingLinkService.extractToken(
        childData['invitationToken']?.toString(),
      );
      if (token == null) {
        throw StateError('Le serveur n’a pas renvoyé de jeton valide.');
      }

      if (mounted) {
        setState(() => _linkageCode = token);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de génération du lien : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyPairingLink() {
    final pairingLink = PairingLinkService.buildPairingLink(_linkageCode);
    Clipboard.setData(ClipboardData(text: pairingLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Lien de jumelage copié dans le presse-papiers !'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _saveParentProfileAndFamily() async {
    if (_parentNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner votre nom')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirestoreService().updateProfile({
        'name': _parentNameController.text.trim(),
        'phone': _parentPhoneController.text.trim(),
        'relation': _parentRelation,
      });

      final famName = _familyNameController.text.trim().isEmpty
          ? 'Famille ${_parentNameController.text.trim().split(' ').last.toUpperCase()}'
          : _familyNameController.text.trim();

      await FirestoreService().createFamily(famName);
      _nextStep();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _activatePremiumTrial(bool activate) async {
    setState(() => _isLoading = true);
    try {
      if (activate) {
        // Grant a 14-day premium trial
        final now = DateTime.now();
        final endDate = now.add(const Duration(days: 14));
        final trialSub = SubscriptionModel(
          plan: 'guardian_premium',
          status: 'trial',
          billingCycle: 'monthly',
          startDate: now,
          endDate: endDate,
          trialUsed: true,
          childrenLimit: 999,
          devicesLimit: 999,
          features: {
            'realTimeLocation': true,
            'geofencing': true,
            'screenTime': true,
            'appManagement': true,
            'aiReports': true,
            'cyberbullyingDetection': true,
            'webDashboard': true,
            'prioritySupport': true,
            'cloudBackup': true,
            'advancedAi': true,
            'familyManagement': false,
          },
        );

        await SubscriptionService().updateSubscription(trialSub);
        await SubscriptionService().recordPayment({
          'plan': 'guardian_premium',
          'amount': 0.0,
          'cycle': 'trial',
          'method': 'FREE_TRIAL',
        });

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.stars, color: Colors.amber, size: 28),
                  SizedBox(width: 8),
                  Text('Essai Premium activé !'),
                ],
              ),
              content: const Text(
                'Félicitations ! Vous disposez de 14 jours d\'accès gratuit à Guardian Premium.\nExplorez toutes les fonctionnalités sans limite dès maintenant.',
                style: TextStyle(height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/dashboard');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                  ),
                  child: const Text('Découvrir le Dashboard'),
                ),
              ],
            ),
          );
        }
      } else {
        context.go('/dashboard');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
      context.go('/dashboard');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          const Positioned.fill(child: LiquidBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // Step Indicator Header
                  _buildHeader(),
                  const SizedBox(height: 28),

                  // Active Step Content
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildStepContent(isDark, size),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final stepTitles = ['Parent', 'Famille', 'Enfant', 'Jumelage', 'Premium'];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CONFIGURATION INITIALE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: AppColors.primary,
              ),
            ),
            Text(
              'Étape ${_currentStep + 1} sur 5',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Progress Dots & Labels
        Row(
          children: List.generate(5, (index) {
            final active = index <= _currentStep;
            final current = index == _currentStep;
            return Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: active
                      ? (current
                          ? AppColors.primary
                          : AppColors.primary.withOpacity(0.5))
                      : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
            final active = index == _currentStep;
            return Text(
              stepTitles[index],
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? AppColors.primary : Colors.grey,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStepContent(bool isDark, Size size) {
    switch (_currentStep) {
      case 0:
        return _buildStepParentProfile(isDark);
      case 1:
        return _buildStepCreateFamily(isDark);
      case 2:
        return _buildStepAddChild(isDark);
      case 3:
        return _buildStepPairDevice(isDark);
      case 4:
        return _buildStepPremiumTrial(isDark);
      default:
        return const SizedBox();
    }
  }

  Widget _buildStepParentProfile(bool isDark) {
    return GlassCard(
      key: const ValueKey('step_parent'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complétez votre profil Parent',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Configurez vos informations personnelles de sécurité pour commencer à piloter l\'application.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _parentNameController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Nom complet',
              prefixIcon:
                  const Icon(Icons.person_outline, color: AppColors.primary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _parentPhoneController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Numéro de téléphone',
              prefixIcon:
                  const Icon(Icons.phone_outlined, color: AppColors.primary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Votre rôle familial',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: ['Mère', 'Père', 'Tuteur'].map((role) {
              final active = _parentRelation == role;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(role),
                  selected: active,
                  onSelected: (val) {
                    if (val) setState(() => _parentRelation = role);
                  },
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: active ? AppColors.primary : Colors.grey,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveParentProfileAndFamily,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Enregistrer et Continuer',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCreateFamily(bool isDark) {
    return GlassCard(
      key: const ValueKey('step_family'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Créez l\'entité Famille',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'L\'entité Famille centralise les profils de tous vos enfants et permet à plusieurs parents ou tuteurs de co-gérer la sécurité.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _familyNameController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Nom de la Famille',
              hintText: 'Ex: Famille DUPONT, Famille NGONO',
              prefixIcon:
                  const Icon(Icons.group_outlined, color: AppColors.primary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              TextButton(
                onPressed: _prevStep,
                child:
                    const Text('Retour', style: TextStyle(color: Colors.grey)),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Étape Suivante',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepAddChild(bool isDark) {
    return GlassCard(
      key: const ValueKey('step_child'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ajoutez votre premier Enfant',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Créez le profil de votre enfant pour générer sa configuration de protection.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _childNameController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Prénom de l\'enfant',
              prefixIcon:
                  const Icon(Icons.face_outlined, color: AppColors.primary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _childAgeController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Âge de l\'enfant',
              prefixIcon:
                  const Icon(Icons.cake_outlined, color: AppColors.primary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Lien de parenté',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: ['Fils', 'Fille', 'Autre'].map((rel) {
              final active = _childRelation == rel;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(rel),
                  selected: active,
                  onSelected: (val) {
                    if (val) setState(() => _childRelation = rel);
                  },
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: active ? AppColors.primary : Colors.grey,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            'Choisissez un avatar',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: ['👦', '👧', '🦖', '🦄', '🐱', '🐶'].map((avatar) {
              final active = _childAvatar == avatar;
              return GestureDetector(
                onTap: () => setState(() => _childAvatar = avatar),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary.withOpacity(0.15)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Text(avatar, style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              TextButton(
                onPressed: _prevStep,
                child:
                    const Text('Retour', style: TextStyle(color: Colors.grey)),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  if (_childNameController.text.trim().isEmpty ||
                      _childAgeController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Veuillez remplir tous les champs')),
                    );
                    return;
                  }
                  _nextStep();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Créer le profil',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepPairDevice(bool isDark) {
    return GlassCard(
      key: const ValueKey('step_pair'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Associez le téléphone de l\'enfant',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Téléchargez l\'application Guardian Enfant sur son téléphone, lancez-la et entrez le code ci-dessous.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Code Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Text(
              _linkageCode.isNotEmpty
                  ? PairingLinkService.formatTokenForDisplay(_linkageCode)
                  : 'Génération...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                height: 1.35,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // QR Code simulation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.qr_code_2, size: 160, color: Colors.black),
                const SizedBox(height: 8),
                Text(
                  'Scannez le QR Code',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Copy link option
          ElevatedButton.icon(
            onPressed: _linkageCode.isNotEmpty ? _copyPairingLink : null,
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copier le lien de jumelage'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 28),

          Row(
            children: [
              TextButton(
                onPressed: _prevStep,
                child:
                    const Text('Retour', style: TextStyle(color: Colors.grey)),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _linkageCode.isNotEmpty ? _nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Continuer',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepPremiumTrial(bool isDark) {
    return GlassCard(
      key: const ValueKey('step_premium'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.stars, color: Colors.amber, size: 48),
          ),
          const SizedBox(height: 20),
          const Text(
            'Profitez de 14 jours gratuits !',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Essayez Guardian Premium sans engagement. Protégez votre famille de manière optimale avec toutes les fonctionnalités débloquées.',
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Feature Grid Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEBEEF8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildTrialFeatureItem(
                    'Localisation & Zones de sécurité en temps réel'),
                const Divider(height: 16),
                _buildTrialFeatureItem(
                    'Rapports d\'activité IA & Alertes prédictives'),
                const Divider(height: 16),
                _buildTrialFeatureItem(
                    'Détection Cyberharcèlement & Contenus Sensibles'),
                const Divider(height: 16),
                _buildTrialFeatureItem(
                    'Nombre d\'enfants et d\'appareils illimité'),
              ],
            ),
          ),
          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => _activatePremiumTrial(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Activer l\'essai gratuit de 14 jours',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isLoading ? null : () => _activatePremiumTrial(false),
            child: Text(
              'Plus tard, démarrer avec Guardian Free',
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                  decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialFeatureItem(String label) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
