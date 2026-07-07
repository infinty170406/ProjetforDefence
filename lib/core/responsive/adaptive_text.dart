import 'package:flutter/material.dart';
import 'responsive_values.dart';

class AdaptiveText {
  static double bodySmall(BuildContext context) => const ResponsiveValue<double>(
        mobile: 11.0,
        tablet: 12.0,
        desktop: 13.0,
      ).value(context);

  static double bodyMedium(BuildContext context) => const ResponsiveValue<double>(
        mobile: 13.0,
        tablet: 14.0,
        desktop: 15.0,
      ).value(context);

  static double bodyLarge(BuildContext context) => const ResponsiveValue<double>(
        mobile: 15.0,
        tablet: 16.0,
        desktop: 18.0,
      ).value(context);

  static double headingSmall(BuildContext context) => const ResponsiveValue<double>(
        mobile: 18.0,
        tablet: 20.0,
        desktop: 22.0,
      ).value(context);

  static double headingMedium(BuildContext context) => const ResponsiveValue<double>(
        mobile: 22.0,
        tablet: 24.0,
        desktop: 28.0,
      ).value(context);

  static double headingLarge(BuildContext context) => const ResponsiveValue<double>(
        mobile: 28.0,
        tablet: 32.0,
        desktop: 40.0,
        largeDesktop: 48.0,
      ).value(context);

  static TextStyle style(
    BuildContext context, {
    required double fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    String? fontFamily,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      fontFamily: fontFamily ?? 'Outfit',
    );
  }
}
