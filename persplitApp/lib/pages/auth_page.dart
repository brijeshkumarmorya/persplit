import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

class AuthPage extends StatefulWidget {
  final bool isLogin;

  const AuthPage({super.key, this.isLogin = true});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late bool _isLogin;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // UI State
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Focus Nodes for better UX
  final _nameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameFocus.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  /// Toggle between Login and Register
  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _nameController.clear();
      _usernameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmController.clear();
      _obscure1 = true;
      _obscure2 = true;
      _errorMessage = null;
    });
  }

  /// Email Validator
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }

    return null;
  }

  /// Username Validator
  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }

    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters';
    }

    if (value.trim().length > 20) {
      return 'Username must be less than 20 characters';
    }

    // Only alphanumeric and underscores
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(value.trim())) {
      return 'Username can only contain letters, numbers, and underscores';
    }

    return null;
  }

  /// Password Validator
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  /// Name Validator
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }

    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }

    return null;
  }

  /// Confirm Password Validator
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  /// Show Snackbar
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Login Handler
  Future<void> _login() async {
    // Clear previous errors
    setState(() => _errorMessage = null);

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Unfocus all fields
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final res = await AuthService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      setState(() => _isLoading = false);

      if (res['success']) {
        _showSnackBar('Login successful!');

        if (mounted) {
          // Small delay for UX
          await Future.delayed(const Duration(milliseconds: 500));
          context.go('/');
        }
      } else {
        final errorMsg = res['message'] ?? 'Login failed';
        setState(() => _errorMessage = errorMsg);
        _showSnackBar(errorMsg, isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred';
      });
      _showSnackBar('An unexpected error occurred', isError: true);
    }
  }

  /// Register Handler
  Future<void> _register() async {
    // Clear previous errors
    setState(() => _errorMessage = null);

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Unfocus all fields
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final res = await AuthService.register(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      setState(() => _isLoading = false);

      if (res['success']) {
        _showSnackBar('Registration successful! Please login.');

        // Switch to login mode and clear sensitive fields
        setState(() {
          _isLogin = true;
          _passwordController.clear();
          _confirmController.clear();
          _nameController.clear();
          _usernameController.clear();
        });
      } else {
        final errorMsg = res['message'] ?? 'Registration failed';
        setState(() => _errorMessage = errorMsg);
        _showSnackBar(errorMsg, isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred';
      });
      _showSnackBar('An unexpected error occurred', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5F1), // Very light mint/teal
              Color(0xFFF0F8FF), // Very light blue (alice blue)
              Color(0xFFF5FFFE), // Very light cyan
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Illustration Container
                  Hero(
                    tag: 'auth_banner',
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Image.asset(
                        'assets/Picture1.png',
                        width: 240,
                        fit: BoxFit.contain,
                        // No background and no border, so it blends with page gradient
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // White Card Container
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Welcome Text
                          Text(
                            _isLogin ? "Welcome Back!" : "Create Account",
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isLogin
                                ? "Log in to continue"
                                : "Sign up to get started",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),

                          // Error Message
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                border: Border.all(color: Colors.red.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Name Field (Register only)
                          if (!_isLogin) ...[
                            _buildTextField(
                              controller: _nameController,
                              focusNode: _nameFocus,
                              nextFocus: _usernameFocus,
                              label: "Full Name",
                              hint: "Enter your full name",
                              icon: Icons.person_outline,
                              validator: _validateName,
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Username Field (Register only)
                          if (!_isLogin) ...[
                            _buildTextField(
                              controller: _usernameController,
                              focusNode: _usernameFocus,
                              nextFocus: _emailFocus,
                              label: "Username",
                              hint: "Choose a unique username",
                              icon: Icons.account_circle_outlined,
                              validator: _validateUsername,
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Email Field
                          _buildTextField(
                            controller: _emailController,
                            focusNode: _emailFocus,
                            nextFocus: _passwordFocus,
                            label: "Email",
                            hint: "Enter your email",
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          _buildTextField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            nextFocus: _isLogin ? null : _confirmFocus,
                            label: "Password",
                            hint: "Enter your password",
                            icon: Icons.lock_outline,
                            obscureText: _obscure1,
                            validator: _validatePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure1
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure1 = !_obscure1),
                            ),
                            onSubmit: _isLogin ? (_) => _login() : null,
                          ),

                          // Confirm Password Field (Register only)
                          if (!_isLogin) ...[
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _confirmController,
                              focusNode: _confirmFocus,
                              label: "Confirm Password",
                              hint: "Re-enter your password",
                              icon: Icons.lock_outline,
                              obscureText: _obscure2,
                              validator: _validateConfirmPassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure2
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure2 = !_obscure2),
                              ),
                              onSubmit: (_) => _register(),
                            ),
                          ],

                          const SizedBox(height: 28),

                          // Login/Register Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : (_isLogin ? _login : _register),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                disabledBackgroundColor: Colors.grey
                                    .withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: _isLoading
                                      ? null
                                      : const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF26C68C),
                                            Color(0xFF1E88A8),
                                          ],
                                        ),
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Center(
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Text(
                                          _isLogin ? "Log In" : "Register",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Toggle Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isLogin
                                    ? "Don't have an account? "
                                    : "Already have an account? ",
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: _isLoading ? null : _toggleAuthMode,
                                child: Text(
                                  _isLogin ? "Sign Up" : "Log In",
                                  style: TextStyle(
                                    color: _isLoading
                                        ? Colors.grey
                                        : const Color(0xFF26C68C),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build Text Field Widget
  Widget _buildTextField({
    required TextEditingController controller,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    void Function(String)? onSubmit,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      textInputAction: nextFocus != null
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted:
          onSubmit ??
          (nextFocus != null
              ? (_) => FocusScope.of(context).requestFocus(nextFocus)
              : null),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF26C68C)),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF26C68C), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }
}
