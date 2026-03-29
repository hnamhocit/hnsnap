import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const seedColor = Color(0xFFD97706);
const _lightScaffoldColor = Color(0xFFF6F3EE);
const _darkScaffoldColor = Color(0xFF111315);

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFFB86A17),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFFFDDB7),
  onPrimaryContainer: Color(0xFF3D2100),
  secondary: Color(0xFF755845),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFFFDCC7),
  onSecondaryContainer: Color(0xFF2A1709),
  tertiary: Color(0xFF5F6238),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFE5E8B2),
  onTertiaryContainer: Color(0xFF1B1D00),
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),
  surface: Color(0xFFFFF8F4),
  onSurface: Color(0xFF1F1B16),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFFCF2EA),
  surfaceContainer: Color(0xFFF6ECE4),
  surfaceContainerHigh: Color(0xFFF1E6DD),
  surfaceContainerHighest: Color(0xFFEBE0D8),
  onSurfaceVariant: Color(0xFF52443A),
  outline: Color(0xFF857469),
  outlineVariant: Color(0xFFD8C2B4),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFF352F2A),
  onInverseSurface: Color(0xFFFAEEE6),
  inversePrimary: Color(0xFFFFB957),
  surfaceTint: Color(0xFFB86A17),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFFFB957),
  onPrimary: Color(0xFF633A00),
  primaryContainer: Color(0xFF8F5200),
  onPrimaryContainer: Color(0xFFFFDDB7),
  secondary: Color(0xFFE4BFA7),
  onSecondary: Color(0xFF432B1B),
  secondaryContainer: Color(0xFF5B412F),
  onSecondaryContainer: Color(0xFFFFDCC7),
  tertiary: Color(0xFFC9CC98),
  onTertiary: Color(0xFF31350D),
  tertiaryContainer: Color(0xFF484C22),
  onTertiaryContainer: Color(0xFFE5E8B2),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF181A1C),
  onSurface: Color(0xFFECE0D7),
  surfaceContainerLowest: Color(0xFF0C0E10),
  surfaceContainerLow: Color(0xFF1B1D1F),
  surfaceContainer: Color(0xFF202326),
  surfaceContainerHigh: Color(0xFF2A2D30),
  surfaceContainerHighest: Color(0xFF35383B),
  onSurfaceVariant: Color(0xFFD6C3B8),
  outline: Color(0xFF9F8D82),
  outlineVariant: Color(0xFF52443A),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFFECE0D7),
  onInverseSurface: Color(0xFF352F2A),
  inversePrimary: Color(0xFFB86A17),
  surfaceTint: Color(0xFFFFB957),
);

TextTheme _textTheme(Color textColor) => GoogleFonts.beVietnamProTextTheme()
    .apply(bodyColor: textColor, displayColor: textColor);

ThemeData _buildTheme({
  required ColorScheme colorScheme,
  required Color scaffoldBackgroundColor,
}) {
  final textTheme = _textTheme(colorScheme.onSurface);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    canvasColor: scaffoldBackgroundColor,
    dividerColor: colorScheme.outlineVariant,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: scaffoldBackgroundColor,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        highlightColor: colorScheme.primary.withValues(alpha: 0.12),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHigh,
      selectedColor: colorScheme.primaryContainer,
      disabledColor: colorScheme.surfaceContainer,
      deleteIconColor: colorScheme.onSurfaceVariant,
      labelStyle: textTheme.labelLarge!,
      secondaryLabelStyle: textTheme.labelLarge!,
      brightness: colorScheme.brightness,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(color: colorScheme.outlineVariant),
    ),
  );
}

final lightTheme = _buildTheme(
  colorScheme: _lightScheme,
  scaffoldBackgroundColor: _lightScaffoldColor,
);

final darkTheme = _buildTheme(
  colorScheme: _darkScheme,
  scaffoldBackgroundColor: _darkScaffoldColor,
);
