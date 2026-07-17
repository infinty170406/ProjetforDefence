import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state_manager.dart';
import 'app_translations.dart';

extension TranslateExtension on String {
  String tr(BuildContext context) {
    // Watch AppStateManager so changes to the language trigger rebuilds of this text
    final language = Provider.of<AppStateManager>(context).language;
    return AppTranslations.translate(this, language);
  }
}
