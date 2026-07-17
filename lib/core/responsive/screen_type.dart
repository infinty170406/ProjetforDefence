enum ScreenType {
  mobile,
  tablet,
  desktop,
  largeDesktop,
}

ScreenType getScreenType(double width) {
  if (width < 600) {
    return ScreenType.mobile;
  } else if (width < 1024) {
    return ScreenType.tablet;
  } else if (width < 1440) {
    return ScreenType.desktop;
  } else {
    return ScreenType.largeDesktop;
  }
}
