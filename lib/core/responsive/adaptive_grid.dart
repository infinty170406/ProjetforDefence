import 'package:flutter/material.dart';
import 'responsive_values.dart';

class AdaptiveGrid {
  static int columns(BuildContext context) {
    return const ResponsiveValue<int>(
      mobile: 1,
      tablet: 2,
      desktop: 3,
      largeDesktop: 4,
    ).value(context);
  }

  static double spacing(BuildContext context) {
    return const ResponsiveValue<double>(
      mobile: 16.0,
      tablet: 20.0,
      desktop: 24.0,
      largeDesktop: 32.0,
    ).value(context);
  }
}
