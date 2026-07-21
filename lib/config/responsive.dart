import 'package:flutter/material.dart';

/// Utility class for responsive layout support across different screen sizes.
///
/// Breakpoints:
///  - Small phone  : < 360px  (e.g., small Android phones)
///  - Normal phone : 360–599px (standard target device)
///  - Large phone  : 600–899px (tablets / large phones in landscape)
///  - Tablet       : ≥ 900px
class R {
  R._();

  // ── Breakpoints ──────────────────────────────────────────────────────────────
  static bool isSmall(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360;

  static bool isNormal(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 360 && w < 600;
  }

  static bool isLarge(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 600 && w < 900;
  }

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  // ── Adaptive Font Sizes ───────────────────────────────────────────────────────
  /// Returns a font size scaled relative to screen width.
  static double fs(BuildContext context, double base) {
    final w = MediaQuery.sizeOf(context).width;
    // Reference width = 390 (iPhone 14 / design baseline)
    final scale = (w / 390).clamp(0.80, 1.20);
    return base * scale;
  }

  // ── Adaptive Spacing ─────────────────────────────────────────────────────────
  /// Responsive spacing: returns a value scaled to screen width.
  static double sp(BuildContext context, double base) {
    final w = MediaQuery.sizeOf(context).width;
    final scale = (w / 390).clamp(0.80, 1.15);
    return base * scale;
  }

  // ── Adaptive Padding ─────────────────────────────────────────────────────────
  /// Horizontal page padding that tightens on very small screens.
  static double hPad(BuildContext context, {double base = 16}) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 360) return base * 0.85;
    if (w < 400) return base;
    return base * (w / 390).clamp(1.0, 1.15);
  }

  // ── Grid Cross-Axis Count ────────────────────────────────────────────────────
  /// Number of columns for a product grid.
  static int gridCols(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 900) return 4;
    if (w >= 600) return 3;
    return 2;
  }

  // ── Grid Item Extent (height) ────────────────────────────────────────────────
  /// Recommended item extent for product cards.
  static double gridItemExtent(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 360) return 240;
    if (w < 400) return 260;
    return 280;
  }

  // ── Banner Height ─────────────────────────────────────────────────────────────
  static double bannerHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 360) return 140;
    if (w < 400) return 155;
    return 170;
  }

  // ── Avatar / Logo size ───────────────────────────────────────────────────────
  static double logoSize(BuildContext context, {double base = 100}) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 360) return base * 0.80;
    if (w < 400) return base * 0.90;
    return base;
  }

  // ── Button Height ─────────────────────────────────────────────────────────────
  static double btnHeight(BuildContext context, {double base = 50}) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 360) return base * 0.88;
    return base;
  }
}

/// A convenience extension so you can write `context.r.gridCols()` if preferred.
extension ResponsiveContext on BuildContext {
  bool get isSmallScreen => R.isSmall(this);
  bool get isNormalScreen => R.isNormal(this);
  bool get isLargeScreen => R.isLarge(this);
  bool get isTabletScreen => R.isTablet(this);
}
