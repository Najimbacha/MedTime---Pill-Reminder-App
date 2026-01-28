import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/haptic_helper.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_radius.dart';

/// Authentication screen for sign in / sign up
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      await HapticHelper.error();
      return;
    }

    await HapticHelper.selection();
    final authProvider = context.read<AuthProvider>();

    bool success;
    if (_isSignUp) {
      success = await authProvider.createAccount(
        _emailController.text.trim(),
        _passwordController.text,
        displayName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
      );
    } else {
      success = await authProvider.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    if (success && mounted) {
      await HapticHelper.success();
      Navigator.pop(context, true);
    } else {
      await HapticHelper.error();
    }
  }

  Future<void> _signInAnonymously() async {
    await HapticHelper.selection();
    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.signInAnonymously();

    if (success && mounted) {
      await HapticHelper.success();
      Navigator.pop(context, true);
    } else {
      await HapticHelper.error();
    }
  }

  Future<void> _signInWithGoogle() async {
    await HapticHelper.selection();
    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.signInWithGoogle();

    if (success && mounted) {
      await HapticHelper.success();
      Navigator.pop(context, true);
    } else if (!success && authProvider.error != null) {
      await HapticHelper.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true, // Allow gradient to go behind app bar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.surfaceGradientDark : AppColors.surfaceGradientLight,
        ),
        child: SafeArea( // Ensure content is safe
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? AppColors.surface1Dark.withOpacity(0.8) 
                          : Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withOpacity(isDark ? 0.05 : 0.6),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        return Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Hero Logo
                              Center(
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.2),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      )
                                    ]
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/splash_icon.png',
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              Text(
                                _isSignUp ? 'Join MedTime' : 'Welcome Back',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.headlineMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isSignUp
                                    ? 'Create an account to safeguard your data'
                                    : 'Sign in to sync your reminders and logs',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              // Google Sign-In Button
                              OutlinedButton(
                                onPressed: authProvider.isLoading ? null : _signInWithGoogle,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                                  side: BorderSide(
                                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                     Image.network(
                                      'https://www.google.com/favicon.ico',
                                      height: 20,
                                      width: 20,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Divider
                              Row(
                                children: [
                                  Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey.shade300)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        color: isDark ? Colors.white38 : Colors.black38,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey.shade300)),
                                ],
                              ),
                              
                              const SizedBox(height: 24),

                              if (_isSignUp) ...[
                                _buildTextField(
                                  controller: _nameController, 
                                  label: 'Full Name', 
                                  icon: Icons.person_rounded,
                                  isDark: isDark,
                                  textCapitalization: TextCapitalization.words,
                                ),
                                const SizedBox(height: 16),
                              ],

                              _buildTextField(
                                controller: _emailController, 
                                label: 'Email Address', 
                                icon: Icons.email_rounded,
                                isDark: isDark,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Required';
                                  if (!value.contains('@')) return 'Invalid Email';
                                  return null;
                                }
                              ),
                              const SizedBox(height: 16),
                              
                              _buildTextField(
                                controller: _passwordController, 
                                label: 'Password', 
                                icon: Icons.lock_rounded,
                                isDark: isDark,
                                isPassword: true,
                                obscureText: _obscurePassword,
                                onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Required';
                                  if (_isSignUp && value.length < 6) return 'Min 6 chars';
                                  return null;
                                }
                              ),

                              const SizedBox(height: 24),
                              
                              // Error
                              if (authProvider.error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_rounded, color: AppColors.error, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          authProvider.error!,
                                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Main Action Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: authProvider.isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 8,
                                    shadowColor: AppColors.primary.withOpacity(0.4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: authProvider.isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : Text(
                                          _isSignUp ? 'Create Account' : 'Sign In',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Toggle
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isSignUp = !_isSignUp;
                                      authProvider.clearError();
                                    });
                                  },
                                  child: RichText(
                                    text: TextSpan(
                                      text: _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                                      style: TextStyle(
                                        color: isDark ? Colors.white60 : Colors.black54,
                                        fontSize: 14,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: _isSignUp ? 'Sign In' : 'Sign Up',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Anonymous
                              Center(
                                child: TextButton(
                                  onPressed: authProvider.isLoading ? null : _signInAnonymously,
                                  child: Text(
                                    'Continue without account',
                                    style: TextStyle(
                                      color: isDark ? Colors.white38 : Colors.grey[400],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.grey),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        suffixIcon: isPassword 
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
                onPressed: onTogglePassword,
              )
            : null,
      ),
      validator: validator,
    );
  }
}
