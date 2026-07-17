import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/parent_invite_service.dart';
import '../../core/models/app_state_manager.dart';
import '../../core/localization/app_localizations.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  // State for toggles
  bool _appLock = false;
  bool _biometrics = false;
  bool _antiUninstall = false;

  bool _sosNotif = true;
  bool _geofenceNotif = true;
  bool _offlineNotif = true;
  bool _reportsNotif = true;

  String _pin = '1234';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _appLock = prefs.getBool('settings_app_lock') ?? false;
        _biometrics = prefs.getBool('settings_biometrics') ?? false;
        _antiUninstall = prefs.getBool('settings_anti_uninstall') ?? false;

        _sosNotif = prefs.getBool('settings_sos_notif') ?? true;
        _geofenceNotif = prefs.getBool('settings_geofence_notif') ?? true;
        _offlineNotif = prefs.getBool('settings_offline_notif') ?? true;
        _reportsNotif = prefs.getBool('settings_reports_notif') ?? true;

        _pin = prefs.getString('settings_parent_pin') ?? '1234';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Déconnexion',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text('Voulez-vous vraiment vous déconnecter ?',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: AppColors.primary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusDanger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Déconnexion',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ApiService().clearToken();
      await FirebaseAuth.instance.signOut();
      await StorageService().clearAll();
      if (mounted) context.go('/login');
    }
  }

  Future<void> _handleDeleteAccount() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🚨 SUPPRIMER LE COMPTE',
            style: TextStyle(
                color: AppColors.statusDanger, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cette action est irréversible et supprimera définitivement toutes les données de vos enfants.',
              style: TextStyle(color: AppColors.statusDanger),
            ),
            const SizedBox(height: 16),
            Text('Tapez "SUPPRIMER" pour confirmer :',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'SUPPRIMER',
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: AppColors.primary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim() == 'SUPPRIMER') {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusDanger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child:
                const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.delete();
          ApiService().clearToken();
          await StorageService().clearAll();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Compte supprimé avec succès.')),
            );
            context.go('/login');
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Erreur : Reconnectez-vous pour supprimer votre compte. $e')),
          );
        }
      }
    }
  }

  void _showChangePinSheet() {
    final pinController = TextEditingController(text: _pin);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modifier le PIN',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'Le code PIN protège l\'accès aux réglages sensibles de l\'application.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Nouveau Code PIN (4 chiffres)',
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final newPin = pinController.text.trim();
                  if (newPin.length == 4 && int.tryParse(newPin) != null) {
                    await _saveString('settings_parent_pin', newPin);
                    setState(() => _pin = newPin);
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code PIN mis à jour ✓')),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Le code PIN doit comporter 4 chiffres.')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Enregistrer',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActivateLockSheet() {
    final pinController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activer le Verrouillage',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'Définissez un code PIN à 4 chiffres. Ce code sera demandé à chaque ouverture de l\'application.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Code PIN (4 chiffres)',
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final newPin = pinController.text.trim();
                  if (newPin.length == 4 && int.tryParse(newPin) != null) {
                    await _saveString('settings_parent_pin', newPin);
                    await _saveBool('settings_app_lock', true);
                    setState(() {
                      _pin = newPin;
                      _appLock = true;
                    });
                    if (mounted) {
                      context.read<AppStateManager>().setAppLocked(false);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Verrouillage activé avec le code PIN ✓')),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Le code PIN doit comporter 4 chiffres.')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Activer',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      _loadSettings();
    });
  }

  void _showDeactivateLockSheet() {
    final pinController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Désactiver le Verrouillage',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'Entrez votre code PIN parent pour désactiver le verrouillage.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Code PIN actuel',
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final enteredPin = pinController.text.trim();
                  if (enteredPin == _pin) {
                    await _saveBool('settings_app_lock', false);
                    setState(() {
                      _appLock = false;
                    });
                    if (mounted) {
                      context.read<AppStateManager>().setAppLocked(false);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Verrouillage désactivé ✓')),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code PIN incorrect ❌'),
                        backgroundColor: AppColors.statusDanger,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusDanger,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Désactiver',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      _loadSettings();
    });
  }

  void _showInviteParentSheet() {
    String? generatedCode;
    bool isLoadingCode = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheetState) {
          // Generate real code on first build
          if (isLoadingCode) {
            isLoadingCode = false;
            ParentInviteService().generateInviteCode().then((code) {
              setSheetState(() => generatedCode = code);
            });
          }
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Inviter un autre parent',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text(
                    'Partagez ce code (valide 48h). Le second parent l\'entre dans son application pour rejoindre votre famille.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: generatedCode == null
                        ? const Center(child: CircularProgressIndicator())
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                generatedCode!,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy,
                                    color: AppColors.primary),
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: generatedCode!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Code copié ✓')),
                                  );
                                },
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  // Also allow entering a received code
                  _buildJoinCodeEntry(ctx),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildJoinCodeEntry(BuildContext ctx) {
    final joinController = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text('Rejoindre une famille existante',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: joinController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Code à 6 caractères',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final code = joinController.text.trim();
                if (code.isEmpty) return;
                Navigator.pop(ctx);
                final result =
                    await ParentInviteService().acceptInviteCode(code);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.message)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Rejoindre',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }

  void _showLanguageSelector() {
    final stateManager = context.read<AppStateManager>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Langue de l\'application',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              title: Text('Français',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
              trailing: stateManager.language == 'Français'
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () async {
                await stateManager.setLanguage('Français');
                if (mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: Text('English',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
              trailing: stateManager.language == 'English'
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () async {
                await stateManager.setLanguage('English');
                if (mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTimezoneSelector() {
    final stateManager = context.read<AppStateManager>();
    final zones = [
      'GMT+1 (Paris)',
      'GMT+0 (London)',
      'GMT-5 (New York)',
      'GMT+8 (Singapore)'
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fuseau horaire',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...zones.map((zone) => ListTile(
                  title: Text(zone,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface)),
                  trailing: stateManager.timezone == zone
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () async {
                    await stateManager.setTimezone(zone);
                    if (mounted) Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showThemeSelector() {
    final stateManager = context.read<AppStateManager>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thème de l\'application',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.settings_suggest_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              title: Text('Système',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
              trailing: stateManager.themeMode == ThemeMode.system
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                stateManager.setThemeMode(ThemeMode.system);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.light_mode_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              title: Text('Clair',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
              trailing: stateManager.themeMode == ThemeMode.light
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                stateManager.setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.dark_mode_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              title: Text('Sombre',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
              trailing: stateManager.themeMode == ThemeMode.dark
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                stateManager.setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileSheet() {
    final user = FirebaseAuth.instance.currentUser;
    final nameController =
        TextEditingController(text: user?.displayName ?? 'Parent');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profil Utilisateur',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom d\'affichage',
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            Text('Adresse email : ${user?.email ?? ""}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  if (newName.isNotEmpty) {
                    await user?.updateDisplayName(newName);
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profil mis à jour ✓')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Enregistrer',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordSheet() {
    final passwordController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modifier le mot de passe',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nouveau mot de passe',
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final newPass = passwordController.text.trim();
                  if (newPass.length >= 6) {
                    await FirebaseAuth.instance.currentUser
                        ?.updatePassword(newPass);
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Mot de passe mis à jour ✓')),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Le mot de passe doit comporter au moins 6 caractères.')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Mettre à jour',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode, BuildContext context) {
    switch (mode) {
      case ThemeMode.system:
        return 'Système'.tr(context);
      case ThemeMode.light:
        return 'Clair'.tr(context);
      case ThemeMode.dark:
        return 'Sombre'.tr(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateManager = context.watch<AppStateManager>();

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back,
                            color: Theme.of(context).colorScheme.onSurface),
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/dashboard');
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '⚙️ PARAMÈTRES'.tr(context),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.grey),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        // SECTION 1: 🛡️ Sécurité
                        _buildSectionHeader('🛡️ Sécurité'.tr(context)),
                        _buildSettingsCard([
                          _buildSwitchItem(
                            'Verrouillage de l\'application'.tr(context),
                            _appLock,
                            (val) {
                              if (val) {
                                _showActivateLockSheet();
                              } else {
                                _showDeactivateLockSheet();
                              }
                            },
                          ),
                          _buildNavigationItem(
                            'Modifier le PIN'.tr(context),
                            onTap: _showChangePinSheet,
                          ),
                          _buildSwitchItem(
                            'Biométrie'.tr(context),
                            _biometrics,
                            (val) {
                              _saveBool('settings_biometrics', val);
                              setState(() => _biometrics = val);
                            },
                          ),
                          _buildSwitchItem(
                            'Protection contre la désinstallation'.tr(context),
                            _antiUninstall,
                            (val) {
                              _saveBool('settings_anti_uninstall', val);
                              setState(() => _antiUninstall = val);
                            },
                          ),
                        ]),

                        // SECTION 2: 👨‍👩‍👧 Famille
                        _buildSectionHeader('👨‍👩‍👧 Famille'.tr(context)),
                        _buildSettingsCard([
                          _buildNavigationItem(
                            'Gérer les enfants'.tr(context),
                            onTap: () {
                              context.go('/dashboard');
                            },
                          ),
                          _buildNavigationItem(
                            'Inviter un autre parent'.tr(context),
                            onTap: _showInviteParentSheet,
                          ),
                        ]),

                        // SECTION 3: 🔔 Notifications
                        _buildSectionHeader('🔔 Notifications'.tr(context)),
                        _buildSettingsCard([
                          _buildSwitchItem(
                            'SOS',
                            _sosNotif,
                            (val) async {
                              await _saveBool('settings_sos_notif', val);
                              setState(() => _sosNotif = val);
                              await NotificationService()
                                  .updateNotificationPreference(
                                      'settings_sos_notif', val);
                            },
                          ),
                          _buildSwitchItem(
                            'Géofence',
                            _geofenceNotif,
                            (val) async {
                              await _saveBool('settings_geofence_notif', val);
                              setState(() => _geofenceNotif = val);
                              await NotificationService()
                                  .updateNotificationPreference(
                                      'settings_geofence_notif', val);
                            },
                          ),
                          _buildSwitchItem(
                            'Hors ligne'.tr(context),
                            _offlineNotif,
                            (val) async {
                              await _saveBool('settings_offline_notif', val);
                              setState(() => _offlineNotif = val);
                              await NotificationService()
                                  .updateNotificationPreference(
                                      'settings_offline_notif', val);
                            },
                          ),
                          _buildSwitchItem(
                            'Rapports'.tr(context),
                            _reportsNotif,
                            (val) async {
                              await _saveBool('settings_reports_notif', val);
                              setState(() => _reportsNotif = val);
                              await NotificationService()
                                  .updateNotificationPreference(
                                      'settings_reports_notif', val);
                            },
                          ),
                        ]),

                        // SECTION 4: 🌍 Préférences
                        _buildSectionHeader('🌍 Préférences'.tr(context)),
                        _buildSettingsCard([
                          _buildNavigationItem(
                            'Langue'.tr(context),
                            subtitle: stateManager.language.tr(context),
                            onTap: _showLanguageSelector,
                          ),
                          _buildNavigationItem(
                            'Thème'.tr(context),
                            subtitle: _themeModeLabel(
                                stateManager.themeMode, context),
                            onTap: _showThemeSelector,
                          ),
                          _buildNavigationItem(
                            'Fuseau horaire'.tr(context),
                            subtitle: stateManager.timezone,
                            onTap: _showTimezoneSelector,
                          ),
                        ]),

                        // SECTION 5: 👤 Compte
                        _buildSectionHeader('👤 Compte'.tr(context)),
                        _buildSettingsCard([
                          _buildNavigationItem(
                            'Profil'.tr(context),
                            onTap: _showProfileSheet,
                          ),
                          _buildNavigationItem(
                            'Mon abonnement'.tr(context),
                            onTap: () => context.push('/settings/subscription'),
                          ),
                          _buildNavigationItem(
                            'Mot de passe'.tr(context),
                            onTap: _showChangePasswordSheet,
                          ),
                          _buildNavigationItem(
                            'Déconnexion'.tr(context),
                            onTap: _handleLogout,
                            isDestructive: true,
                          ),
                          _buildNavigationItem(
                            'Supprimer le compte'.tr(context),
                            onTap: _handleDeleteAccount,
                            isDestructive: true,
                          ),
                        ]),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, top: 20.0, bottom: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark
        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.04)
        : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.08)
        : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          if (index == items.length - 1) return items[index];
          return Column(
            children: [
              items[index],
              Divider(height: 1, thickness: 1, color: borderColor),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSwitchItem(
      String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItem(
    String title, {
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final textColor = isDestructive
        ? AppColors.statusDanger
        : Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDestructive
                  ? AppColors.statusDanger
                  : Colors.grey.withOpacity(0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
