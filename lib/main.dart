import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import '../services/auth_service.dart';
import '../services/folder_service.dart';
import 'package:provider/provider.dart';
import '../services/lobby_service.dart';
import '../providers/lobby_provider.dart';
import '../services/notification_service.dart';
import '../components/notification_overlay.dart';
import 'screens/create_lobby_screen.dart';
import 'screens/active_lobby_screen.dart';
import 'theme/markme_theme.dart';
import '../services/attendance_service.dart';

// Global navigator key to allow for navigation from outside the widget tree (e.g., from AuthService).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // No need to create an instance here, Provider will handle it.
  // final authService = AuthService();
  // if (authService.currentUser != null && await authService.isUserBanned()) {
  //   await authService.signOut();
  // }

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
          dispose: (_, authService) => authService.dispose(),
        ),
        Provider<FolderService>(create: (_) => FolderService()),
        ChangeNotifierProvider<LobbyProvider>(create: (_) => LobbyProvider()),
        ChangeNotifierProvider<NotificationService>(create: (_) => NotificationService()),
        
        // These services now depend on AuthService, so we use ProxyProvider.
        ProxyProvider<AuthService, LobbyService>(
          update: (_, authService, __) => LobbyService(authService),
        ),
        ProxyProvider<AuthService, AttendanceService>(
          update: (_, authService, __) => AttendanceService(authService),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return NotificationOverlay(
      child: StreamBuilder<User?>(
        stream: authService.authStateChanges.map((event) => event.session?.user),
        builder: (context, snapshot) {
          return MaterialApp(
            navigatorKey: navigatorKey, // Assign the global key
            debugShowCheckedModeBanner: false,
            title: 'MarkMe',
            theme: ThemeData(
              colorScheme: ColorScheme.dark(
                primary: MarkMeTheme.primaryYellow,
                secondary: MarkMeTheme.primaryYellow,
                surface: MarkMeTheme.surfaceDark,
              ),
              scaffoldBackgroundColor: MarkMeTheme.darkBackground,
              appBarTheme: AppBarTheme(
                backgroundColor: MarkMeTheme.surfaceDark,
                foregroundColor: MarkMeTheme.primaryWhite,
                elevation: 0,
              ),
              textTheme: TextTheme(
                headlineLarge: MarkMeTheme.headingStyle,
                headlineMedium: MarkMeTheme.subheadingStyle,
                bodyLarge: MarkMeTheme.labelStyle,
              ),
            ),
            initialRoute: snapshot.hasData ? '/' : '/login',
            routes: {
              '/login': (context) => const LoginScreen(),
              '/': (context) => HomeScreen(
                    authService: Provider.of<AuthService>(context),
                    folderService: Provider.of<FolderService>(context),
                  ),
              '/create-lobby': (context) => const CreateLobbyScreen(),
              '/active-lobby': (context) => ActiveLobbyScreen(
                    lobbyId: ModalRoute.of(context)!.settings.arguments as String,
                  ),
            },
          );
        },
      ),
    );
  }
}