import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state_manager.dart';

class TimezoneHelper {
  static DateTime adjustToTimezone(DateTime dt, String timezoneStr) {
    // e.g., 'GMT+1 (Paris)', 'GMT-5 (New York)', 'GMT+0 (London)', 'GMT+8 (Singapore)'
    final regExp = RegExp(r'GMT([+-]\d+)');
    final match = regExp.firstMatch(timezoneStr);
    if (match != null) {
      final offsetHours = int.tryParse(match.group(1) ?? '0') ?? 0;
      // Convert the input DateTime to UTC, then apply the offset hours
      final utc = dt.toUtc();
      return utc.add(Duration(hours: offsetHours));
    }
    return dt;
  }

  static DateTime getAdjustedDateTime(BuildContext context, DateTime dt) {
    final stateManager = Provider.of<AppStateManager>(context, listen: false);
    return adjustToTimezone(dt, stateManager.timezone);
  }
}
