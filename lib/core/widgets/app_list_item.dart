import 'package:flutter/material.dart';
import 'dart:convert';
import '../theme/app_theme.dart';

class AppListItem extends StatelessWidget {
  final String label;
  final String packageName;
  final int usageMinutes;
  final double progress; // 0.0 to 1.0
  final String category;
  final String? trailingText;
  final Widget? trailing;
  final bool showProgress;
  final String? iconUrl;
  final String? iconBase64;
  final IconData? fallbackIcon;

  const AppListItem({
    super.key,
    required this.label,
    required this.packageName,
    this.usageMinutes = 0,
    this.progress = 0.0,
    this.category = 'other',
    this.trailingText,
    this.trailing,
    this.showProgress = true,
    this.iconUrl,
    this.iconBase64,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    // Resolve icon: explicit fallback > category icon > smart heuristic based on label+package
    final IconData catIcon = _categoryIcon(category);
    final icon = fallbackIcon ??
        (catIcon == Icons.apps
            ? AppListItem.smartFallbackIcon(label, packageName)
            : catIcon);
    final String timeStr = trailingText ?? _formatMinutes(usageMinutes);
    final String? cleanBase64 = _getCleanBase64(iconBase64);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Premium Icon Container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
                ),
                child: Center(
                  child: cleanBase64 != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(cleanBase64),
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(icon, size: 24, color: color),
                          ),
                        )
                      : iconUrl != null && iconUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                iconUrl!,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(icon, size: 24, color: color),
                              ),
                            )
                          : Icon(icon, size: 24, color: color),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Removed packageName display as requested
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null)
                trailing!
              else
                Text(
                  timeStr,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 10),
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat.toLowerCase().trim()) {
      case 'social_media':
      case 'social':
        return Colors.pinkAccent;
      case 'gaming':
      case 'game':
      case 'jeux':
        return Colors.purpleAccent;
      case 'education':
      case 'school':
      case 'educational':
        return Colors.greenAccent;
      case 'browser':
      case 'web':
      case 'internet':
        return Colors.blueAccent;
      case 'messaging':
      case 'message':
      case 'chat':
      case 'communication':
        return Colors.tealAccent;
      default:
        return AppColors.primary;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat.toLowerCase().trim()) {
      case 'social_media':
      case 'social':
        return Icons.thumb_up;
      case 'gaming':
      case 'game':
      case 'jeux':
        return Icons.videogame_asset;
      case 'education':
      case 'school':
      case 'educational':
        return Icons.school;
      case 'browser':
      case 'web':
      case 'internet':
        return Icons.language;
      case 'messaging':
      case 'message':
      case 'chat':
      case 'communication':
        return Icons.chat;
      case 'productivity':
        return Icons.work;
      case 'utility':
        return Icons.build;
      case 'entertainment':
        return Icons.play_circle;
      default:
        return Icons.apps;
    }
  }

  /// Returns a smarter fallback icon by inspecting the app label and package name.
  /// Used when no Base64 icon is available from Firestore.
  static IconData smartFallbackIcon(String label, String packageName) {
    final lbl = label.toLowerCase();
    final pkg = packageName.toLowerCase();

    // Phone / Dialer
    if (lbl.contains('dialer') || lbl.contains('phone') || pkg.contains('dialer') || pkg.contains('.phone') || pkg.contains('.call')) {
      return Icons.phone;
    }
    // Gallery / Photos
    if (lbl.contains('photo') || lbl.contains('gallery') || lbl.contains('image') ||
        pkg.contains('gallery') || pkg.contains('photos') || pkg.contains('.miui.gallery') || pkg.contains('sec.android.gallery')) {
      return Icons.photo_library;
    }
    // Camera
    if (lbl.contains('camera') || pkg.contains('camera')) {
      return Icons.camera_alt;
    }
    // Browser / Web
    if (lbl.contains('browser') || lbl.contains('chrome') || lbl.contains('firefox') ||
        pkg.contains('browser') || pkg.contains('chrome') || pkg.contains('firefox') || pkg.contains('opera')) {
      return Icons.language;
    }
    // Maps / GPS
    if (lbl.contains('maps') || lbl.contains('gps') || pkg.contains('.maps') || pkg.contains('navigation')) {
      return Icons.map;
    }
    // Music / Audio
    if (lbl.contains('music') || lbl.contains('spotify') || lbl.contains('radio') ||
        pkg.contains('music') || pkg.contains('spotify') || pkg.contains('radio') || pkg.contains('audio')) {
      return Icons.music_note;
    }
    // Video
    if (lbl.contains('video') || lbl.contains('youtube') || lbl.contains('netflix') ||
        pkg.contains('video') || pkg.contains('youtube') || pkg.contains('netflix')) {
      return Icons.play_circle;
    }
    // Messaging / SMS
    if (lbl.contains('message') || lbl.contains('sms') || lbl.contains('chat') || lbl.contains('whatsapp') ||
        pkg.contains('mms') || pkg.contains('sms') || pkg.contains('message') || pkg.contains('whatsapp')) {
      return Icons.chat_bubble;
    }
    // Email
    if (lbl.contains('email') || lbl.contains('mail') || lbl.contains('gmail') ||
        pkg.contains('email') || pkg.contains('mail') || pkg.contains('gmail')) {
      return Icons.email;
    }
    // Settings
    if (lbl.contains('settings') || lbl.contains('paramètre') || pkg.contains('settings') || pkg.contains('config')) {
      return Icons.settings;
    }
    // Security / Antivirus
    if (lbl.contains('security') || lbl.contains('antivirus') || pkg.contains('security')) {
      return Icons.security;
    }
    // Files / Documents
    if (lbl.contains('file') || lbl.contains('document') || lbl.contains('office') ||
        pkg.contains('files') || pkg.contains('document') || pkg.contains('office')) {
      return Icons.folder;
    }
    // Calculator
    if (lbl.contains('calculator') || lbl.contains('calcul') || pkg.contains('calculator')) {
      return Icons.calculate;
    }
    // Clock / Alarm
    if (lbl.contains('clock') || lbl.contains('alarm') || lbl.contains('timer') ||
        pkg.contains('clock') || pkg.contains('alarm')) {
      return Icons.alarm;
    }
    // Contacts
    if (lbl.contains('contact') || pkg.contains('contacts')) {
      return Icons.contacts;
    }
    // Store / Shopping
    if (lbl.contains('store') || lbl.contains('shop') || lbl.contains('play') ||
        pkg.contains('vending') || pkg.contains('store')) {
      return Icons.store;
    }
    return Icons.apps;
  }

  String _formatMinutes(int mins) {
    if (mins == 0) return '0m';
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
  }

  String? _getCleanBase64(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    String clean = base64Str;
    if (clean.contains(',')) {
      clean = clean.split(',').last;
    }
    clean = clean.replaceAll(RegExp(r'\s+'), '');
    while (clean.length % 4 != 0) {
      clean += '=';
    }
    return clean.isEmpty ? null : clean;
  }
}
