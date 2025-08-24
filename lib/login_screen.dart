import 'dart:ui';

import 'package:flutter/material.dart';

import 'login_service.dart';
import 'map_handlers/student_model.dart';
import 'map_screen.dart';

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
    super.dispose();
  }

  void _handleLrnPasswordSignIn() async {
    try {
      final String lrn = _lrnController.text.trim();
      final String password = _passwordController.text.trim();

      if (lrn.isEmpty || password.isEmpty) {
        _showSnackBar('Please enter both LRN and password.');
        return;
      }

      final Student student = await _loginService.signInAuto(lrn, password);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FixedMapScreen(student: student),
          ),
        );
      }
    } catch (e) {
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF894DFF);
    const Color gradientEndColor = Color(0xFFAB8AED);

    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;
    final isSmallScreen = screenHeight < 700 || screenWidth < 400;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
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
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w800,
                                            fontSize: isSmallScreen ? 38 : 55,
                                            color: Color(0xFF2D2D2D),
                                            height: 1.2,
                                          ),
                                        ),
                                        SizedBox(height: isSmallScreen ? 8 : 16),
                                        Text(
                                          "Precision in Presence, \nPowered by ALLY.",
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w300,
                                            fontSize: isSmallScreen ? 20 : 26,
                                            color: Color(0xFF2D2D2D),
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
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(height: isSmallScreen ? 20 : 35),
                                            _buildStaggeredWidget(
                                              delay: 0.0,
                                              child: Text(
                                                "Log In to Continue",
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: isSmallScreen ? 18 : 22,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: isSmallScreen ? 18 : 27),
                                            _buildStaggeredWidget(
                                              delay: 0.2,
                                              child: _buildTextField(
                                                controller: _lrnController,
                                                hint: "Enter Student LRN or Teacher ID",
                                                label: "Account ID",
                                                icon: Icons.numbers_outlined,
                                                iconColor: primaryColor,
                                                keyboardType: TextInputType.text,
                                              ),
                                            ),
                                            SizedBox(height: isSmallScreen ? 12 : 16),
                                            _buildStaggeredWidget(
                                              delay: 0.4,
                                              child: _buildTextField(
                                                controller: _passwordController,
                                                hint: "••••••••••••",
                                                label: "Password",
                                                obscureText: true,
                                                icon: Icons.key_outlined,
                                                iconColor: primaryColor,
                                              ),
                                            ),
                                            SizedBox(height: isSmallScreen ? 18 : 24),
                                            _buildStaggeredWidget(
                                              delay: 0.6,
                                              child: _buildSignInButton(
                                                primaryColor: primaryColor,
                                                gradientEndColor: gradientEndColor,
                                                buttonText: "Sign In",
                                                onPressed: _handleLrnPasswordSignIn,
                                              ),
                                            ),
                                            SizedBox(height: isSmallScreen ? 12 : 20),
                                            _buildStaggeredWidget(
                                              delay: 0.8,
                                              child: const Center(
                                                child: Text(
                                                  "By signing in, you consent to the use of your\nlocation for accurate attendance tracking.",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.black54,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: isSmallScreen ? 12 : 20),
                                          ],
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
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(50)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 24, bottom: 24, left: 35, right: 35),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.4),
            borderRadius: const BorderRadius.all(Radius.circular(25)),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700 || screenSize.width < 400;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(35.0),
      ),
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 20 : 25, vertical: 0),
      child: SizedBox(
        height: isSmallScreen ? 75 : (60 + 15 + 14),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: isSmallScreen ? 12 : 16, top: isSmallScreen ? 12 : 15),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(
                  height: isSmallScreen ? 48 : 56,
                  child: TextField(
                    controller: controller,
                    obscureText: obscureText,
                    keyboardType: keyboardType,
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(color: Colors.black.withOpacity(0.4)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: isSmallScreen ? 12 : 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: isSmallScreen ? 14.0 : 18.0),
                  child: icon == Icons.key_outlined
                      ? Icon(
                          Icons.key,
                          color: const Color(0xFF894DFF),
                          size: isSmallScreen ? 24 : 32,
                        )
                      : icon == Icons.email_outlined
                          ? Icon(
                              Icons.email,
                              color: const Color(0xFF894DFF),
                              size: isSmallScreen ? 24 : 32,
                            )
                          : Icon(
                              icon,
                              color: iconColor,
                              size: isSmallScreen ? 24 : 32,
                            ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInButton({
    required Color primaryColor,
    required Color gradientEndColor,
    String buttonText = "Sign In",
    VoidCallback? onPressed,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700 || screenSize.width < 400;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, gradientEndColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: ElevatedButton(
        onPressed: onPressed ?? () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 16 : 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
        ),
        child: Text(
          buttonText,
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
