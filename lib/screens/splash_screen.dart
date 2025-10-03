import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/markme_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // This await is crucial. It pauses here until the auth service has finished
    // its async initialization (including fetching the initial session).
    await Provider.of<AuthService>(context, listen: false).isInitialized;

    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null) {
      // If user is logged in, go to home screen.
      Navigator.of(context).pushReplacementNamed('/');
    } else {
      // If user is not logged in, go to login screen.
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // While the _redirect function is awaiting, this is the screen that will be shown.
    return const Scaffold(
      backgroundColor: MarkMeTheme.darkBackground,
      body: Center(
        child: CircularProgressIndicator(color: MarkMeTheme.primaryYellow),
      ),
    );
  }
}
