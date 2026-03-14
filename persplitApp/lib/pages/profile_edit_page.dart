import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _upiIdController = TextEditingController();

  // UI State
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _errorMessage;
  String? _currentAvatar;

  // Focus Nodes
  final _nameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _upiIdFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _upiIdController.dispose();
    _nameFocus.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _upiIdFocus.dispose();
    super.dispose();
  }

  /// Load current user data
  Future<void> _loadUserData() async {
    setState(() => _isInitializing = true);

    try {
      final userInfo = await AuthService.getCurrentUserInfo();

      setState(() {
        _nameController.text = userInfo['name'] ?? '';
        _usernameController.text = userInfo['username'] ?? '';
        _emailController.text = userInfo['email'] ?? '';
        _upiIdController.text = userInfo['upiId'] ?? '';
        _currentAvatar = userInfo['avatar'];
        _isInitializing = false;
      });
    } catch (e) {
      setState(() => _isInitializing = false);
      _showSnackBar('Failed to load user data', isError: true);
    }
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

  /// UPI ID Validator (optional field)
  String? _validateUpiId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }

    // Basic UPI ID format: username@bank
    final upiRegex = RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z]+$');
    if (!upiRegex.hasMatch(value.trim())) {
      return 'Please enter a valid UPI ID (e.g., user@bank)';
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

  /// Update Profile Handler
  Future<void> _updateProfile() async {
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
      final res = await AuthService.updateProfile(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        upiId: _upiIdController.text.trim().isEmpty
            ? null
            : _upiIdController.text.trim(),
        avatar: _currentAvatar,
      );

      setState(() => _isLoading = false);

      if (res['success']) {
        _showSnackBar('Profile updated successfully!');

        // Navigate back after short delay
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          context.pop();
        }
      } else {
        final errorMsg = res['message'] ?? 'Update failed';
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
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF26C68C), Color(0xFF1E88A8)],
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isInitializing
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF26C68C)),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF26C68C).withOpacity(0.1),
                    Colors.white,
                  ],
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Avatar Section
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: const Color(0xFF26C68C),
                                backgroundImage:
                                    _currentAvatar != null &&
                                        _currentAvatar!.isNotEmpty
                                    ? NetworkImage(_currentAvatar!)
                                    : null,
                                child:
                                    _currentAvatar == null ||
                                        _currentAvatar!.isEmpty
                                    ? Text(
                                        _nameController.text.isNotEmpty
                                            ? _nameController.text[0]
                                                  .toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 48,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF26C68C),
                                      width: 2,
                                    ),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.camera_alt,
                                      color: Color(0xFF26C68C),
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      // TODO: Implement image picker
                                      _showSnackBar(
                                        'Avatar upload coming soon!',
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Error Message
                        if (_errorMessage != null) ...[
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
                          const SizedBox(height: 16),
                        ],

                        // Name Field
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

                        // Username Field
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

                        // Email Field
                        _buildTextField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          nextFocus: _upiIdFocus,
                          label: "Email",
                          hint: "Enter your email",
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 16),

                        // UPI ID Field (Optional)
                        _buildTextField(
                          controller: _upiIdController,
                          focusNode: _upiIdFocus,
                          label: "UPI ID (Optional)",
                          hint: "e.g., yourname@bank",
                          icon: Icons.payment_outlined,
                          validator: _validateUpiId,
                        ),
                        const SizedBox(height: 32),

                        // Save Button
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              disabledBackgroundColor: Colors.grey.withOpacity(
                                0.3,
                              ),
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
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.save_outlined,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            "Save Changes",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Cancel Button
                        SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => context.pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFF26C68C),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                color: Color(0xFF26C68C),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
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
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: nextFocus != null
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted: nextFocus != null
          ? (_) => FocusScope.of(context).requestFocus(nextFocus)
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF26C68C)),
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
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
    );
  }
}
