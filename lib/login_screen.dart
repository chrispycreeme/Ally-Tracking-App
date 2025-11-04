import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';

import 'login_service.dart';
import 'map_handlers/student_model.dart';
import 'map_screen.dart';
import 'background_location_service.dart';
import 'notification_service.dart';
import 'ui_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _headingController;
  late AnimationController _modalController;
  late AnimationController _formController;

  late Animation<double> _backgroundAnimation;
  late Animation<Offset> _headingSlideAnimation;
  late Animation<double> _headingFadeAnimation;
  late Animation<double> _modalFadeAnimation;
  late Animation<Offset> _modalSlideAnimation;
  late Animation<double> _formStaggerAnimation;

  final TextEditingController _lrnController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final LoginService _loginService = LoginService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FocusNode _idFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _headingController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _modalController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _formController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _backgroundAnimation = CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    );

    _headingFadeAnimation = CurvedAnimation(
      parent: _headingController,
      curve: Curves.easeOut,
    );

    _headingSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headingController,
      curve: Curves.easeOutCubic,
    ));

    _modalFadeAnimation = CurvedAnimation(
      parent: _modalController,
      curve: Curves.easeOut,
    );

    _modalSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _modalController,
      curve: Curves.easeOutCubic,
    ));

    _formStaggerAnimation = CurvedAnimation(
      parent: _formController,
      curve: Curves.easeOutCubic,
    );

    _startAnimations();
  }

  void _startAnimations() async {
    _backgroundController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _headingController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _modalController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _formController.forward();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _headingController.dispose();
    _modalController.dispose();
    _formController.dispose();
    _lrnController.dispose();
    _passwordController.dispose();
    _idFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLrnPasswordSignIn() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final String lrn = _lrnController.text.trim();
    final String password = _passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      final Student student = await _loginService.signInAuto(lrn, password);

      // Set user as logged in for notification control
      NotificationService().setLoggedIn(true);

      if (!student.isTeacher) {
        unawaited(updateBackgroundTracking(
          studentId: student.id,
          classHours: student.classHours,
        ));
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FixedMapScreen(student: student),
          ),
        );
      }
    } on TimeoutException {
      _showSnackBar('Login timed out. Please check your connection.');
    } catch (e) {
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateIdentifier(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Please enter your account ID.';
    }
    if (trimmed.length < 5) {
      return 'Account ID must be at least 5 characters.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Password is required.';
    }
    if (trimmed.length < 6) {
      return 'Use at least 6 characters.';
    }
    return null;
  }

  void _showSupportDialog() {
    if (!mounted) return;
    if (_isLoading) {
      _showSnackBar('Finish signing in before requesting support.');
      return;
    }

    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AllyTheme.primaryColor, AllyTheme.secondaryColor],
                        ),
                      ),
                      child: const Icon(Icons.support_agent, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Need assistance?',
                        style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Reach out to the ALLY support team to reset your password or update your account details.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AllyTheme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 20, color: AllyTheme.primaryColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'support@ally-app.io',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AllyTheme.primaryColor,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 20, color: AllyTheme.primaryColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '+63 912 345 6789',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AllyTheme.primaryColor,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Support is available on school days from 8:00 AM to 5:00 PM.',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AllyTheme.primaryColor;

    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;
    final isSmallScreen = screenHeight < 700 || screenWidth < 400;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return Positioned.fill(
                child: Transform.scale(
                  scale: 2.5 * _backgroundAnimation.value,
                  child: Opacity(
                    opacity: _backgroundAnimation.value,
                    child: Image.asset(
                      'assets/background.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16.0 : 0.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          SizedBox(height: isSmallScreen ? screenHeight * 0.05 : screenHeight * 0.1),
                          AnimatedBuilder(
                            animation: _headingController,
                            builder: (context, child) {
                              final textTheme = Theme.of(context).textTheme;
                              return SlideTransition(
                                position: _headingSlideAnimation,
                                child: FadeTransition(
                                  opacity: _headingFadeAnimation,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 32),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Track.\nTrust.\nTransform.",
                                          style: textTheme.displayMedium?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                height: 1.2,
                                                fontSize: isSmallScreen ? 38 : 55,
                                                color: const Color(0xFF1E1E1E),
                                              ) ??
                                              TextStyle(
                                                fontSize: isSmallScreen ? 38 : 55,
                                                fontWeight: FontWeight.w800,
                                                height: 1.2,
                                                color: const Color(0xFF1E1E1E),
                                              ),
                                        ),
                                        SizedBox(height: isSmallScreen ? 8 : 16),
                                        Text(
                                          "Precision in Presence, \nPowered by ALLY.",
                                          style: textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.w400,
                                                fontSize: isSmallScreen ? 20 : 26,
                                                color: const Color(0xFF1E1E1E),
                                              ) ??
                                              TextStyle(
                                                fontSize: isSmallScreen ? 20 : 26,
                                                fontWeight: FontWeight.w400,
                                                color: const Color(0xFF1E1E1E),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: isSmallScreen ? screenHeight * 0.04 : screenHeight * 0.08),
                          AnimatedBuilder(
                            animation: _modalController,
                            builder: (context, child) {
                              return SlideTransition(
                                position: _modalSlideAnimation,
                                child: FadeTransition(
                                  opacity: _modalFadeAnimation,
                                  child: _buildGlassmorphicContainer(
                                    child: AnimatedBuilder(
                                      animation: _formController,
                                      builder: (context, child) {
                                        final textTheme = Theme.of(context).textTheme;
                                        return Form(
                                          key: _formKey,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(height: isSmallScreen ? 20 : 35),
                                              _buildStaggeredWidget(
                                                delay: 0.0,
                                                child: Text(
                                                  "Log In to Continue",
                                                  style: textTheme.titleLarge?.copyWith(
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.black87,
                                                      ) ??
                                                      const TextStyle(
                                                        fontSize: 22,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.black87,
                                                      ),
                                                ),
                                              ),
                                              SizedBox(height: isSmallScreen ? 18 : 27),
                                              AutofillGroup(
                                                child: Column(
                                                  children: [
                                                    _buildStaggeredWidget(
                                                      delay: 0.2,
                                                      child: _buildTextField(
                                                        controller: _lrnController,
                                                        hint: "Enter Student LRN or Teacher ID",
                                                        label: "Account ID",
                                                        icon: Icons.badge_outlined,
                                                        iconColor: primaryColor,
                                                        keyboardType: TextInputType.text,
                                                        focusNode: _idFocusNode,
                                                        textInputAction: TextInputAction.next,
                                                        autofillHints: const [AutofillHints.username],
                                                        validator: _validateIdentifier,
                                                        onEditingComplete: () => _passwordFocusNode.requestFocus(),
                                                      ),
                                                    ),
                                                    SizedBox(height: isSmallScreen ? 12 : 16),
                                                    _buildStaggeredWidget(
                                                      delay: 0.4,
                                                      child: _buildTextField(
                                                        controller: _passwordController,
                                                        hint: "Your secure password",
                                                        label: "Password",
                                                        obscureText: true,
                                                        icon: Icons.key_outlined,
                                                        iconColor: primaryColor,
                                                        keyboardType: TextInputType.visiblePassword,
                                                        focusNode: _passwordFocusNode,
                                                        textInputAction: TextInputAction.done,
                                                        autofillHints: const [AutofillHints.password],
                                                        validator: _validatePassword,
                                                        onEditingComplete: _handleLrnPasswordSignIn,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(height: isSmallScreen ? 18 : 24),
                                              _buildStaggeredWidget(
                                                delay: 0.6,
                                                child: _buildSignInButton(
                                                  primaryColor: primaryColor,
                                                  gradientEndColor: AllyTheme.secondaryColor,
                                                  buttonText: "Sign In",
                                                  onPressed: _handleLrnPasswordSignIn,
                                                  isLoading: _isLoading,
                                                ),
                                              ),
                                              SizedBox(height: isSmallScreen ? 12 : 18),
                                              _buildStaggeredWidget(
                                                delay: 0.7,
                                                child: TextButton(
                                                  onPressed: _showSupportDialog,
                                                  child: Text(
                                                    "Need help signing in?",
                                                    style: textTheme.labelLarge?.copyWith(
                                                          color: primaryColor,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              _buildStaggeredWidget(
                                                delay: 0.8,
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                                  child: Text(
                                                    "By signing in, you consent to the use of your location for accurate attendance tracking.",
                                                    textAlign: TextAlign.center,
                                                    style: textTheme.bodySmall?.copyWith(
                                                          color: Colors.black54,
                                                        ) ??
                                                        const TextStyle(
                                                          color: Colors.black54,
                                                          fontSize: 12,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: isSmallScreen ? 12 : 20),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildStaggeredWidget({
    required double delay,
    required Widget child,
  }) {
    final begin = delay.clamp(0.0, 0.99);
    final end = (begin + 0.5).clamp(begin + 0.01, 1.0);

    final adjustedAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _formStaggerAnimation,
      curve: Interval(
        begin,
        end,
        curve: Curves.easeOutCubic,
      ),
    ));

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _formStaggerAnimation,
      curve: Interval(
        begin,
        end,
        curve: Curves.easeOutCubic,
      ),
    ));

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: adjustedAnimation,
        child: child,
      ),
    );
  }

  Widget _buildGlassmorphicContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 28, bottom: 28, left: 36, right: 36),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF894DFF).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(26)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    FocusNode? focusNode,
    TextInputAction textInputAction = TextInputAction.next,
    Iterable<String>? autofillHints,
    String? Function(String?)? validator,
    VoidCallback? onEditingComplete,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700 || screenSize.width < 400;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 20),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        validator: validator,
        obscureText: obscureText ? _obscurePassword : false,
        obscuringCharacter: '•',
        style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ) ??
            const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
        cursorColor: iconColor,
        onEditingComplete: onEditingComplete,
        autocorrect: false,
        enableSuggestions: !obscureText,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: isSmallScreen ? 20 : 24),
          ),
          suffixIcon: obscureText
              ? IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: iconColor,
                  ),
                )
              : null,
          labelStyle: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black.withOpacity(0.35),
                fontWeight: FontWeight.w400,
              ),
          contentPadding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 16 : 20,
            horizontal: isSmallScreen ? 4 : 8,
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: iconColor.withOpacity(0.6), width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.error.withOpacity(0.7)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton({
    required Color primaryColor,
    required Color gradientEndColor,
    String buttonText = "Sign In",
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700 || screenSize.width < 400;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, gradientEndColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.0),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : (onPressed ?? () {}),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 18 : 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchOutCurve: Curves.easeInBack,
          switchInCurve: Curves.easeOut,
          child: isLoading
              ? Row(
                  key: const ValueKey('loading'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: isSmallScreen ? 18 : 20,
                      height: isSmallScreen ? 18 : 20,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 10 : 14),
                    Text(
                      'Signing you in...',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 15 : 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                )
              : Text(
                  key: const ValueKey('idle'),
                  buttonText,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}
