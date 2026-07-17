import 'package:flutter/material.dart';
import 'responsive_values.dart';

class AdaptiveSpacing {
  static double xs(BuildContext context) => const ResponsiveValue<double>(
        mobile: 4.0,
        tablet: 6.0,
        desktop: 8.0,
      ).value(context);

  static double sm(BuildContext context) => const ResponsiveValue<double>(
        mobile: 8.0,
        tablet: 12.0,
        desktop: 16.0,
      ).value(context);

  static double md(BuildContext context) => const ResponsiveValue<double>(
        mobile: 16.0,
        tablet: 20.0,
        desktop: 24.0,
      ).value(context);

  static double lg(BuildContext context) => const ResponsiveValue<double>(
        mobile: 24.0,
        tablet: 32.0,
        desktop: 40.0,
      ).value(context);

  static double xl(BuildContext context) => const ResponsiveValue<double>(
        mobile: 32.0,
        tablet: 48.0,
        desktop: 64.0,
      ).value(context);

  static EdgeInsets paddingXs(BuildContext context) =>
      EdgeInsets.all(xs(context));
  static EdgeInsets paddingSm(BuildContext context) =>
      EdgeInsets.all(sm(context));
  static EdgeInsets paddingMd(BuildContext context) =>
      EdgeInsets.all(md(context));
  static EdgeInsets paddingLg(BuildContext context) =>
      EdgeInsets.all(lg(context));
  static EdgeInsets paddingXl(BuildContext context) =>
      EdgeInsets.all(xl(context));
}
