import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'login_page/login_page.dart';
import 'profile_page/dashboard_page.dart';
import 'services/local_storage_service.dart';
import 'state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState(LocalStorageService());
  await appState.initialize();

  runApp(MatnasAradApp(appState: appState));
}

class MatnasAradApp extends StatelessWidget {
  const MatnasAradApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B7285),
      brightness: Brightness.light,
    );

    final textTheme = GoogleFonts.assistantTextTheme();

    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'מתנ"ס ערד - נוכחות',
        locale: const Locale('he', 'IL'),
        supportedLocales: const [Locale('he', 'IL')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: colorScheme,
          textTheme: textTheme,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF4F6F8),
          appBarTheme: AppBarTheme(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 1,
            titleTextStyle: textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: colorScheme.primary,
            contentTextStyle: textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              textStyle: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
          cardTheme: CardThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          ),
        ),
        home: const _AppHomeRouter(),
      ),
    );
  }
}

class _AppHomeRouter extends StatelessWidget {
  const _AppHomeRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (!appState.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (appState.currentUser == null) {
          return const LoginPage();
        }

        return const DashboardPage();
      },
    );
  }
}
