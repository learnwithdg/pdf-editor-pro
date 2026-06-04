import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'blocs/pdf_bloc.dart';
import 'blocs/theme_bloc.dart';
import 'screens/home_screen.dart';
import 'services/ads_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const PdfEditorApp());

  if (!AdsService.isRunningInWidgetTest) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        Future<void>.delayed(const Duration(seconds: 20))
            .then((_) => AdsService().init())
            .catchError((Object error) {
          debugPrint('AdMob initialization will retry later: $error');
        }),
      );
    });
  }
}

class PdfEditorApp extends StatelessWidget {
  const PdfEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => PdfBloc()),
        BlocProvider(create: (_) => ThemeBloc()..add(LoadThemeEvent())),
      ],
      child: BlocBuilder<ThemeBloc, ThemeMode>(
        builder: (context, mode) {
          final headingTheme = GoogleFonts.soraTextTheme();
          final bodyTheme = GoogleFonts.manropeTextTheme();
          final baseTextTheme = bodyTheme.copyWith(
            displayLarge: headingTheme.displayLarge,
            displayMedium: headingTheme.displayMedium,
            displaySmall: headingTheme.displaySmall,
            headlineLarge: headingTheme.headlineLarge,
            headlineMedium: headingTheme.headlineMedium,
            headlineSmall: headingTheme.headlineSmall,
            titleLarge: headingTheme.titleLarge,
            titleMedium: headingTheme.titleMedium,
            titleSmall: headingTheme.titleSmall,
          );

          const lightScheme = ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFFC84D31),
            onPrimary: Colors.white,
            secondary: Color(0xFFD6A45F),
            onSecondary: Color(0xFF24170B),
            error: Color(0xFFB3261E),
            onError: Colors.white,
            surface: Color(0xFFF6F0E8),
            onSurface: Color(0xFF1F1A17),
            surfaceContainerHighest: Color(0xFFEDE3D6),
            onSurfaceVariant: Color(0xFF5D5248),
            outline: Color(0xFFD8CBBE),
            shadow: Color(0x1A000000),
            scrim: Color(0x52000000),
            inverseSurface: Color(0xFF2B2521),
            onInverseSurface: Color(0xFFF9EFE5),
            inversePrimary: Color(0xFFFFB39C),
            tertiary: Color(0xFF264653),
            onTertiary: Colors.white,
            tertiaryContainer: Color(0xFFD6E6EC),
            onTertiaryContainer: Color(0xFF112832),
            primaryContainer: Color(0xFFF6D0C5),
            onPrimaryContainer: Color(0xFF43160C),
            secondaryContainer: Color(0xFFF5E1BF),
            onSecondaryContainer: Color(0xFF39250D),
            errorContainer: Color(0xFFF9DEDC),
            onErrorContainer: Color(0xFF410E0B),
            surfaceDim: Color(0xFFE7DED4),
            surfaceBright: Color(0xFFFFF8F4),
            surfaceContainerLowest: Color(0xFFFFFFFF),
            surfaceContainerLow: Color(0xFFF8F2EB),
            surfaceContainer: Color(0xFFF2EAE0),
            surfaceContainerHigh: Color(0xFFEEE5DA),
            outlineVariant: Color(0xFFE8DCCF),
          );

          const darkScheme = ColorScheme(
            brightness: Brightness.dark,
            primary: Color(0xFFFF8E6B),
            onPrimary: Color(0xFF5B2211),
            secondary: Color(0xFFE0B675),
            onSecondary: Color(0xFF3F2A0D),
            error: Color(0xFFF2B8B5),
            onError: Color(0xFF601410),
            surface: Color(0xFF171412),
            onSurface: Color(0xFFF5ECE3),
            surfaceContainerHighest: Color(0xFF2A241F),
            onSurfaceVariant: Color(0xFFD0C4B8),
            outline: Color(0xFF6F6257),
            shadow: Color(0x99000000),
            scrim: Color(0x99000000),
            inverseSurface: Color(0xFFF5ECE3),
            onInverseSurface: Color(0xFF2A241F),
            inversePrimary: Color(0xFFC84D31),
            tertiary: Color(0xFF85AFC0),
            onTertiary: Color(0xFF10252F),
            tertiaryContainer: Color(0xFF193743),
            onTertiaryContainer: Color(0xFFCFE3EC),
            primaryContainer: Color(0xFF7A301C),
            onPrimaryContainer: Color(0xFFFFDBD1),
            secondaryContainer: Color(0xFF5C4520),
            onSecondaryContainer: Color(0xFFFEE7C3),
            errorContainer: Color(0xFF8C1D18),
            onErrorContainer: Color(0xFFF9DEDC),
            surfaceDim: Color(0xFF151210),
            surfaceBright: Color(0xFF3A332D),
            surfaceContainerLowest: Color(0xFF100D0B),
            surfaceContainerLow: Color(0xFF1D1916),
            surfaceContainer: Color(0xFF211C19),
            surfaceContainerHigh: Color(0xFF2A241F),
            outlineVariant: Color(0xFF4F463F),
          );

          ThemeData buildTheme(ColorScheme scheme, bool isDark) {
            return ThemeData(
              useMaterial3: true,
              colorScheme: scheme,
              scaffoldBackgroundColor: scheme.surface,
              textTheme: isDark
                  ? GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme).copyWith(
                      displayLarge: GoogleFonts.soraTextTheme(ThemeData.dark().textTheme).displayLarge,
                      displayMedium: GoogleFonts.soraTextTheme(ThemeData.dark().textTheme).displayMedium,
                      displaySmall: GoogleFonts.soraTextTheme(ThemeData.dark().textTheme).displaySmall,
                      headlineLarge: GoogleFonts.soraTextTheme(ThemeData.dark().textTheme).headlineLarge,
                      headlineMedium: GoogleFonts.soraTextTheme(ThemeData.dark().textTheme).headlineMedium,
                      headlineSmall: GoogleFonts.soraTextTheme(ThemeData.dark().textTheme).headlineSmall,
                      titleLarge: GoogleFonts.soraTextTheme(ThemeData.dark().textTheme).titleLarge,
                      titleMedium: GoogleFonts.soraTextTheme(ThemeData.dark().textTheme).titleMedium,
                      titleSmall: GoogleFonts.soraTextTheme(ThemeData.dark().textTheme).titleSmall,
                    )
                  : baseTextTheme,
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                centerTitle: true,
                titleTextStyle: (isDark
                        ? GoogleFonts.soraTextTheme(ThemeData.dark().textTheme)
                        : headingTheme)
                    .titleLarge
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: scheme.onSurface,
                    ),
                iconTheme: IconThemeData(color: scheme.onSurface),
              ),
              cardTheme: CardThemeData(
                elevation: 0,
                color: scheme.surfaceContainerLow,
                surfaceTintColor: Colors.transparent,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.85)),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: scheme.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: scheme.primary, width: 1.4),
                ),
              ),
              chipTheme: ChipThemeData(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide.none,
                labelStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
                backgroundColor: scheme.surfaceContainerHigh,
              ),
              dividerTheme: DividerThemeData(color: scheme.outlineVariant),
            );
          }

          return MaterialApp(
            title: 'PDF Editor Pro',
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: buildTheme(lightScheme, false),
            darkTheme: buildTheme(darkScheme, true),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
