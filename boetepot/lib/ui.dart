import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Palette and shared UI widgets to mirror the SwiftUI `AppUI` look.
class AppTheme {
  // Base colors
  static const Color bgTop = Color.fromRGBO(23, 23, 28, 1); // 0.09,0.09,0.11
  static const Color bgBottom = Color.fromRGBO(7, 7, 13, 1); // 0.03,0.03,0.05
  static const Color gold = Color.fromRGBO(250, 189, 66, 1); // warm gold

  // Card styling
  static const Color cardFill = Color.fromRGBO(255, 255, 255, 0.06);
  static const Color cardStroke = Color.fromRGBO(255, 255, 255, 0.10);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color.fromRGBO(255, 255, 255, 0.65);

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
        color: cardFill,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: cardStroke, width: 1),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color.fromRGBO(18, 18, 22, 1),
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: cardStroke, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardFill,
        hintStyle: base.textTheme.bodyMedium?.copyWith(color: textSecondary),
        labelStyle: base.textTheme.bodySmall?.copyWith(color: textSecondary, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardStroke, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
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
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.cardFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppTheme.cardStroke, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.35 * 255).round()),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppTheme.gold.withAlpha((0.08 * 255).round()),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AppPill extends StatelessWidget {
  const AppPill({super.key, required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardStroke, width: 1),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: fg,
            ),
      ),
    );
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
        color: AppTheme.cardFill,
        border: Border.all(color: AppTheme.cardStroke, width: 1),
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
        color: AppTheme.cardFill,
        border: Border.all(color: AppTheme.cardStroke, width: 1),
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
    late final Color bg;
    late final Color fg;

    switch (normalized) {
      case 'open':
        bg = AppTheme.gold.withAlpha((0.16 * 255).round());
        fg = AppTheme.gold;
        break;
      case 'closed':
        bg = Colors.green.withAlpha((0.16 * 255).round());
        fg = Colors.green.shade400;
        break;
      default:
        bg = AppTheme.cardFill;
        fg = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardStroke, width: 1),
      ),
      child: Text(
        normalized.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: fg,
            ),
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
        foregroundColor: Colors.black,
        shape: const CircleBorder(),
        elevation: 8,
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: Material(
                color: const Color(0xFF121216),
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
