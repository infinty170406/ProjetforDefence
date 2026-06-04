import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'app_list_item.dart';

const _kKnownApps = [
  {'pkg': 'com.facebook.katana', 'name': 'Facebook', 'cat': 'Social', 'icon': Icons.facebook},
  {'pkg': 'com.instagram.android', 'name': 'Instagram', 'cat': 'Social', 'icon': Icons.photo_camera},
  {'pkg': 'com.snapchat.android', 'name': 'Snapchat', 'cat': 'Social', 'icon': Icons.remove_red_eye},
  {'pkg': 'com.zhiliaoapp.musically', 'name': 'TikTok', 'cat': 'Social', 'icon': Icons.music_video},
  {'pkg': 'com.twitter.android', 'name': 'Twitter/X', 'cat': 'Social', 'icon': Icons.alternate_email},
  {'pkg': 'com.whatsapp', 'name': 'WhatsApp', 'cat': 'Messaging', 'icon': Icons.chat},
  {'pkg': 'com.discord', 'name': 'Discord', 'cat': 'Messaging', 'icon': Icons.headset},
  {'pkg': 'com.google.android.youtube', 'name': 'YouTube', 'cat': 'Entertainment', 'icon': Icons.play_circle},
  {'pkg': 'com.netflix.mediaclient', 'name': 'Netflix', 'cat': 'Entertainment', 'icon': Icons.live_tv},
  {'pkg': 'com.spotify.music', 'name': 'Spotify', 'cat': 'Entertainment', 'icon': Icons.music_note},
  {'pkg': 'com.roblox.client', 'name': 'Roblox', 'cat': 'Gaming', 'icon': Icons.games},
  {'pkg': 'com.mojang.minecraftpe', 'name': 'Minecraft', 'cat': 'Gaming', 'icon': Icons.grid_view},
  {'pkg': 'com.activision.callofduty.shooter', 'name': 'Call of Duty', 'cat': 'Gaming', 'icon': Icons.sports_esports},
  {'pkg': 'com.google.android.gm', 'name': 'Gmail', 'cat': 'Productivity', 'icon': Icons.email},
  {'pkg': 'com.google.android.apps.maps', 'name': 'Maps', 'cat': 'Utility', 'icon': Icons.map},
  {'pkg': 'com.android.chrome', 'name': 'Chrome', 'cat': 'Browser', 'icon': Icons.language},
  {'pkg': 'com.pinterest', 'name': 'Pinterest', 'cat': 'Social', 'icon': Icons.push_pin},
  {'pkg': 'com.facebook.lite', 'name': 'Lite', 'cat': 'Social', 'icon': Icons.facebook},
  {'pkg': 'com.duolingo', 'name': 'Duolingo', 'cat': 'Education', 'icon': Icons.language},
  {'pkg': 'com.openai.chatgpt', 'name': 'ChatGPT', 'cat': 'Productivity', 'icon': Icons.chat},
  {'pkg': 'cn.wps.moffice_eng', 'name': 'WPS Office', 'cat': 'Productivity', 'icon': Icons.description},
  {'pkg': 'com.radio.fmradio', 'name': 'Radio FM', 'cat': 'Entertainment', 'icon': Icons.radio},
  {'pkg': 'com.miui.gallery', 'name': 'Galerie', 'cat': 'Utility', 'icon': Icons.photo_library},
  {'pkg': 'com.sec.android.gallery3d', 'name': 'Galerie', 'cat': 'Utility', 'icon': Icons.photo_library},
  {'pkg': 'com.miui.securitycenter', 'name': 'Sécurité', 'cat': 'Utility', 'icon': Icons.security},
  {'pkg': 'com.miui.video', 'name': 'Mi Vidéo', 'cat': 'Entertainment', 'icon': Icons.video_library},
];

class AppTileWithDetails extends StatelessWidget {
  final String childId;
  final String packageName;
  final Widget? trailing;
  final bool showProgress;
  final int usageMinutes;
  final double progress;
  final String? category;
  final IconData? fallbackIcon;

  const AppTileWithDetails({
    super.key,
    required this.childId,
    required this.packageName,
    this.trailing,
    this.showProgress = false,
    this.usageMinutes = 0,
    this.progress = 0.0,
    this.category,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FirestoreService().appDetailsStream(childId, packageName),
      builder: (context, snapshot) {
        final data = snapshot.data;
        
        // Extract label: prioritize Firestore, then fallback to local known apps list, then split package
        final lastPart = packageName.split('.').last;
        final knownApp = _kKnownApps.cast<Map<String, dynamic>?>().firstWhere(
          (a) => a?['pkg'] == packageName,
          orElse: () => null,
        );

        final String label = data?['label'] ?? 
                            data?['appName'] ?? 
                            knownApp?['name'] ??
                            (lastPart.isEmpty ? '?' : lastPart[0].toUpperCase() + lastPart.substring(1));
        
        final String? iconBase64 = data?['iconBase64'] ?? data?['icon'];
        final String? cat = category ?? data?['category'] ?? knownApp?['cat'] ?? 'other';
        final IconData? fIcon = fallbackIcon ?? knownApp?['icon'] as IconData?;

        return AppListItem(
          label: label,
          packageName: packageName,
          usageMinutes: usageMinutes,
          progress: progress,
          category: cat!,
          trailing: trailing,
          showProgress: showProgress,
          iconBase64: iconBase64,
          fallbackIcon: fIcon,
        );
      },
    );
  }
}
