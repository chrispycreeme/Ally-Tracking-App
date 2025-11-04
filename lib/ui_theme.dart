import 'package:flutter/material.dart';

/// Centralized theme configuration for consistent UI across the app
class AllyTheme {
  static const String fontFamilyPrimary = 'ProductSans';
  static const List<String> fontFamilyFallback = ['Inter', 'sans-serif'];

  // Color palette
  static const Color primaryColor = Color(0xFF6366F1);
  static const Color secondaryColor = Color(0xFF8B5CF6);
  static const Color accentColor = Color(0xFF06B6D4);
  static const Color surfaceColor = Color(0xFFF8FAFC);
  static const Color darkTextColor = Color(0xFF1E293B);
  static const Color lightTextColor = Color(0xFF64748B);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color borderColor = Color(0xFFE2E8F0);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, secondaryColor],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
  );

  // Border radius
  static const double radiusXS = 6.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;
  static const double radius2XL = 24.0;

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 12.0;
  static const double spacingLG = 16.0;
  static const double spacingXL = 24.0;
  static const double spacing2XL = 32.0;

  // Shadow
  static const BoxShadow shadowSM = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 4,
    offset: Offset(0, 1),
  );

  static const BoxShadow shadowMD = BoxShadow(
    color: Color(0x1F000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  static const BoxShadow shadowLG = BoxShadow(
    color: Color(0x24000000),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static const List<BoxShadow> elevationShadow = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x19000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  // Text styles
  static const TextStyle headingXL = TextStyle(
    fontFamily: fontFamilyPrimary,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: darkTextColor,
  );

  static const TextStyle headingLG = TextStyle(
    fontFamily: fontFamilyPrimary,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: darkTextColor,
  );

  static const TextStyle headingMD = TextStyle(
    fontFamily: fontFamilyPrimary,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: darkTextColor,
  );

  static const TextStyle bodyLG = TextStyle(
    fontFamily: fontFamilyPrimary,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: darkTextColor,
  );

  static const TextStyle bodyMD = TextStyle(
    fontFamily: fontFamilyPrimary,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: darkTextColor,
  );

  static const TextStyle bodySM = TextStyle(
    fontFamily: fontFamilyPrimary,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: lightTextColor,
  );

  static const TextStyle captionSM = TextStyle(
    fontFamily: fontFamilyPrimary,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: lightTextColor,
  );

  // Get ThemeData for MaterialApp
  static ThemeData getTheme({bool isDark = false}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamilyPrimary,
      fontFamilyFallback: fontFamilyFallback,
      textTheme: _buildTextTheme(colorScheme, isDark),
      scaffoldBackgroundColor: isDark ? const Color(0xFF0F172A) : surfaceColor,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: headingMD.copyWith(
          color: isDark ? Colors.white : darkTextColor,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : darkTextColor,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
        ),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shadowColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: spacingXL, vertical: spacingMD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMD),
          ),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF334155) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF475569) : borderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingLG,
          vertical: spacingMD,
        ),
        hintStyle: bodySM.copyWith(
          color: isDark ? const Color(0xFF94A3B8) : lightTextColor,
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(ColorScheme colorScheme, bool isDark) {
    final base = isDark
        ? Typography.material2021().white
        : Typography.material2021().black;

    final displayColor = isDark ? Colors.white : darkTextColor;
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF1E293B);

    return base.apply(
      fontFamily: fontFamilyPrimary,
      bodyColor: bodyColor,
      displayColor: displayColor,
    ).copyWith(
      displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w700),
      displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
      headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.w500),
      bodyLarge: base.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      bodyMedium: base.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
      bodySmall: base.bodySmall?.copyWith(fontWeight: FontWeight.w400),
    );
  }
}

/// Helper widget for building consistent card layouts
class AllyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double borderRadius;
  final List<BoxShadow>? shadows;
  final Gradient? gradient;
  final Border? border;

  const AllyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AllyTheme.spacingLG),
    this.onTap,
    this.borderRadius = AllyTheme.radiusLG,
    this.shadows,
    this.gradient,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: gradient,
          color: gradient == null ? Colors.white : null,
          border: border,
          boxShadow: shadows ?? [AllyTheme.shadowMD],
        ),
        child: child,
      ),
    );
  }
}

/// Helper widget for status badge
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool isAnimated;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.isAnimated = false,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AllyTheme.spacingMD,
        vertical: AllyTheme.spacingSM,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(AllyTheme.radiusXL),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AllyTheme.spacingSM),
          ],
          Text(
            label,
            style: AllyTheme.captionSM.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (isAnimated) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        builder: (context, value, child) {
          return Opacity(opacity: value, child: child);
        },
        child: badge,
      );
    }

    return badge;
  }
}

/// Loading skeleton placeholder
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = AllyTheme.radiusSM,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade100,
                Colors.grey.shade200,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
            ),
          ),
        );
      },
    );
  }
}
