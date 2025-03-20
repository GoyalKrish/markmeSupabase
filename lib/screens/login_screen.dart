import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../components/markme_logo.dart';
import '../theme/markme_theme.dart';
import 'dart:ui';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    
    _animationController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_authService.currentUser != null) {
        Navigator.pushReplacementNamed(context, '/');
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } on AuthException catch (error) {
      if (mounted) {
        _showErrorSnackBar(error.message);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('An unexpected error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade800,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: MarkMeTheme.darkBackground,
        body: Container(
          decoration: BoxDecoration(
            gradient: MarkMeTheme.backgroundGradient,
            boxShadow: [
              BoxShadow(
                color: MarkMeTheme.primaryYellow.withOpacity(0.09),
                blurRadius: 200,
                spreadRadius: 100,
                offset: const Offset(0, -100),
              ),
            ],
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo and Branding
                        Align(
                          alignment: Alignment.center,
                          child: Hero(
                            tag: 'markme_logo',
                            child: const MarkMeLogo(
                              size: 150,
                              variant: LogoVariant.icon,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Welcome Header
                        Container(
                          width: double.infinity,
                          child: Text(
                            'Welcome to MarkMe',
                            style: MarkMeTheme.headingStyle,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          child: Text(
                            'The Next Generation of Attendance Tracking',
                            style: MarkMeTheme.subheadingStyle.copyWith(
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                            softWrap: false,
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        // Login Form
                        Form(
            key: _formKey,
            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                              Text('Email', style: MarkMeTheme.labelStyle),
                              const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: MarkMeTheme.primaryWhite),
                                cursorColor: MarkMeTheme.primaryYellow,
                                decoration: MarkMeTheme.getInputDecoration(
                                  hintText: 'Enter your email',
                                  prefixIcon: Icons.email_outlined,
                                ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                              const SizedBox(height: 24),
                              
                              Text('Password', style: MarkMeTheme.labelStyle),
                              const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(color: MarkMeTheme.primaryWhite),
                                cursorColor: MarkMeTheme.primaryYellow,
                                decoration: MarkMeTheme.getInputDecoration(
                                  hintText: 'Enter your password',
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: MarkMeTheme.primaryWhite.withOpacity(0.7),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                              const SizedBox(height: 32),
                              
                              // Sign In Button
                              Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: MarkMeTheme.primaryYellow.withOpacity(0.25),
                                      blurRadius: 12,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _isLoading ? null : _submitForm,
                                      splashColor: Colors.white24,
                                      highlightColor: Colors.white10,
                                      child: Ink(
                                        decoration: BoxDecoration(
                                          gradient: _isLoading 
                                              ? LinearGradient(
                                                  colors: [
                                                    MarkMeTheme.primaryYellow.withOpacity(0.7),
                                                    MarkMeTheme.primaryYellow.withOpacity(0.5),
                                                  ],
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                )
                                              : LinearGradient(
                                                  colors: [
                                                    const Color(0xFFFFB800),
                                                    const Color(0xFFFFA000),
                                                  ],
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                ),
                                        ),
                                        child: Center(
                                          child: _isLoading 
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    valueColor: AlwaysStoppedAnimation<Color>(MarkMeTheme.darkBackground),
                                                  ),
                                                )
                                              : Text(
                                                  'Sign In',
                                                  style: MarkMeTheme.buttonTextStyle.copyWith(
                                                    letterSpacing: 0.6,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // App version and copyright
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            '© ${DateTime.now().year} MarkMe • Version 1.0.0',
                            style: TextStyle(
                              color: MarkMeTheme.primaryWhite.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 