import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Palette and shared UI widgets to mirror the SwiftUI `AppUI` look.
class AppTheme {
  // Design tokens
  static const double radiusS = 10; // chips/badges
  static const double radiusM = 14; // icon buttons / small buttons
  static const double radiusL = 16; // cards / large containers

  static const double borderWidth = 1;
  static const Color borderColor = Color.fromRGBO(255, 255, 255, 0.12);

  // Surfaces
  static const Color surface = Color(0xFF151824);
  static const Color surface2 = Color(0xFF1A1E2B);

  // Accent
  static const Color gold = Color.fromRGBO(250, 189, 66, 1); // warm gold

  // Background (keep subtle gradient behind surfaces)
  static const Color bgTop = Color(0xFF0F1118);
  static const Color bgBottom = Color(0xFF07070D);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color.fromRGBO(255, 255, 255, 0.65);
  static const Color textTertiary = Color.fromRGBO(255, 255, 255, 0.45);
  static const Color textOnAccent = Color(0xFF0E0F14);
  static const Color textOnBadge = Color.fromRGBO(255, 255, 255, 0.75);

  static ThemeData themeData() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: gold,
        secondary: gold,
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3, height: 1.1),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.25, height: 1.15),
        titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.15, height: 1.2),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(letterSpacing: -0.15, height: 1.25),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(letterSpacing: -0.1, height: 1.25),
        bodySmall: base.textTheme.bodySmall?.copyWith(letterSpacing: -0.05, height: 1.2),
        labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.1),
        labelMedium: base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.05),
        labelSmall: base.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0),
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
        fontFamily: 'Inter',
      ),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
      ),
      cardTheme: const CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusL)),
          side: BorderSide(color: borderColor, width: borderWidth),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: textOnAccent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: base.textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: surface2,
          side: const BorderSide(color: borderColor, width: borderWidth),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: base.textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: gold,
          textStyle: base.textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color.fromRGBO(255, 255, 255, 0.10),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        hintStyle: base.textTheme.bodyMedium?.copyWith(color: textSecondary),
        labelStyle: base.textTheme.bodySmall?.copyWith(color: textSecondary, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusM), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: borderColor, width: borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: gold, width: 1.2),
        ),
      ),
    );
  }
}

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final gradient = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.bgTop, AppTheme.bgBottom],
        ),
      ),
    );

    final glow = Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [AppTheme.gold.withAlpha((0.35 * 255).round()), Colors.transparent],
          center: Alignment.topRight,
          radius: 0.85,
        ),
      ),
    );

    return Stack(
      children: [
        gradient,
        glow,
        if (child != null) child!,
      ],
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppTheme.radiusL,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const AppCard.dense({
    super.key,
    required this.child,
    this.radius = AppTheme.radiusL,
  }) : padding = const EdgeInsets.all(12);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppTheme.borderColor, width: AppTheme.borderWidth),
      ),
      child: child,
    );
  }
}

enum AppBadgeStyle { neutral, accent, success }

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.text,
    this.style = AppBadgeStyle.neutral,
  });

  final String text;
  final AppBadgeStyle style;

  @override
  Widget build(BuildContext context) {
    late final Color fg;
    late final Color bg;
    late final Color border;

    switch (style) {
      case AppBadgeStyle.accent:
        fg = AppTheme.gold;
        bg = AppTheme.gold.withAlpha((0.14 * 255).round());
        border = AppTheme.gold.withAlpha((0.35 * 255).round());
        break;
      case AppBadgeStyle.success:
        fg = const Color(0xFF4ADE80);
        bg = fg.withAlpha((0.14 * 255).round());
        border = fg.withAlpha((0.35 * 255).round());
        break;
      case AppBadgeStyle.neutral:
        fg = AppTheme.textOnBadge;
        bg = AppTheme.surface2;
        border = AppTheme.borderColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: border, width: AppTheme.borderWidth),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class AppPill extends StatelessWidget {
  const AppPill({super.key, required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = (color == AppTheme.gold) ? AppBadgeStyle.accent : AppBadgeStyle.neutral;
    return AppBadge(text: text, style: style);
  }
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({super.key, required this.title, this.size = 34});
  final String title;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = title.trim().isNotEmpty ? title.trim()[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.surface2,
        border: Border.all(color: AppTheme.borderColor, width: AppTheme.borderWidth),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.gold,
            ),
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.title,
    this.photoUrl,
    this.size = 34,
  });

  final String title;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmedTitle = title.trim();
    final letter = trimmedTitle.isNotEmpty ? trimmedTitle[0].toUpperCase() : '?';

    Widget fallback() {
      return Center(
        child: Text(
          letter,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.gold,
              ),
        ),
      );
    }

    final url = photoUrl?.trim();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.surface2,
        border: Border.all(color: AppTheme.borderColor, width: AppTheme.borderWidth),
      ),
      child: (url != null && url.isNotEmpty)
          ? Image(
              image: CachedNetworkImageProvider(url),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback(),
            )
          : fallback(),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final badgeStyle = normalized == 'open' ? AppBadgeStyle.accent : AppBadgeStyle.neutral;
    final label = switch (normalized) {
      'open' => 'OPEN',
      'closed' => 'GESLOTEN',
      _ => normalized.toUpperCase(),
    };
    return AppBadge(text: label, style: badgeStyle);
  }
}

class AmountPill extends StatelessWidget {
  const AmountPill({
    super.key,
    required this.text,
    this.accent = false,
  });

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final fg = accent ? AppTheme.gold : AppTheme.textPrimary.withAlpha((0.92 * 255).round());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: AppTheme.borderColor, width: AppTheme.borderWidth),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.surface2,
        foregroundColor: AppTheme.textPrimary,
        fixedSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM)),
        side: BorderSide(color: AppTheme.borderColor, width: AppTheme.borderWidth),
      ),
    );
  }
}

class GoldFab extends StatelessWidget {
  const GoldFab({super.key, this.onPressed, required this.icon});
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: 52,
      child: FloatingActionButton(
        onPressed: onPressed ?? () {},
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.textOnAccent,
        shape: const CircleBorder(),
        elevation: 2,
        child: Icon(icon, size: 22),
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.body,
    this.bottomBar,
    this.topPadding = 0,
  });

  final Widget body;
  final Widget? bottomBar;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: body,
          ),
        ),
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}

typedef AppBottomSheetChildBuilder = Widget Function(BuildContext context, ScrollController scrollController);

class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.childBuilder,
    this.initialChildSize = 0.72,
    this.minChildSize = 0.40,
    this.maxChildSize = 0.96,
  });

  final AppBottomSheetChildBuilder childBuilder;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        builder: (context, scrollController) {
          return SafeArea(
            top: false,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusL)),
              child: Material(
                color: AppTheme.surface,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.14 * 255).round()),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: childBuilder(context, scrollController)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
