import 'package:flutter/material.dart';
import 'breakpoints.dart';
import 'screen_type.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? largeDesktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < Breakpoints.mobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= Breakpoints.mobile && width < Breakpoints.tablet;
  }

  static bool isDesktop(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= Breakpoints.tablet && width < Breakpoints.desktop;
  }

  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= Breakpoints.desktop;

  static ScreenType screenType(BuildContext context) {
    return getScreenType(MediaQuery.sizeOf(context).width);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final type = getScreenType(width);
        switch (type) {
          case ScreenType.mobile:
            return mobile;
          case ScreenType.tablet:
            return tablet ?? mobile;
          case ScreenType.desktop:
            return desktop ?? tablet ?? mobile;
          case ScreenType.largeDesktop:
            return largeDesktop ?? desktop ?? tablet ?? mobile;
        }
      },
    );
  }
}
