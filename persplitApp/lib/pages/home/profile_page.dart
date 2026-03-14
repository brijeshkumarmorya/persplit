// lib/pages/home/profile_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _upiIdController;

  bool _isEditing = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  Map<String, dynamic> _userInfo = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _upiIdController = TextEditingController();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await AuthService.getCurrentUserInfo();
    if (mounted) {
      setState(() {
        _userInfo = userInfo;
        _nameController.text = userInfo['name'] ?? '';
        _usernameController.text = userInfo['username'] ?? '';
        _emailController.text = userInfo['email'] ?? '';
        _upiIdController.text = userInfo['upiId'] ?? '';
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final result = await AuthService.updateProfile(
      name: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      upiId: _upiIdController.text.trim().isEmpty
          ? null
          : _upiIdController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      setState(() {
        _isEditing = false;
        _successMessage = 'Profile updated successfully!';
      });
      await _loadUserInfo();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Failed to update profile';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to update profile'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              context.pop();
              final result = await AuthService.logout();
              if (result['success'] == true && mounted) {
                context.go('/auth');
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () {
            if (_isEditing) {
              setState(() => _isEditing = false);
              _loadUserInfo();
            } else {
              context.pop();
            }
          },
        ),
        title: const Text(
          "My Profile",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black87),
              onPressed: () {
                setState(() => _isEditing = true);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),

              // Profile Picture
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  const CircleAvatar(
                    radius: 55,
                    backgroundColor: Color(0xFFE5E5E5),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Color(0xFFD9CDBF),
                      child: Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                  ),
                  if (_isEditing)
                    Container(
                      height: 30,
                      width: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFF48C67B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 15),

              // Name
              Text(
                _userInfo['name'] ?? 'User',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 5),

              // Email
              Text(
                _userInfo['email'] ?? '',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),

              const SizedBox(height: 25),

              // Error Message
              if (_errorMessage != null)
                _buildMessageBox(
                  _errorMessage!,
                  Colors.red.shade50,
                  Colors.red,
                ),

              if (_successMessage != null)
                _buildMessageBox(
                  _successMessage!,
                  Colors.green.shade50,
                  Colors.green,
                ),

              const SizedBox(height: 15),

              // Edit or View Mode
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: _isEditing ? _buildEditForm() : _buildViewMode(),
              ),

              const SizedBox(height: 30),

              // Logout Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Color(0xFFE94B3C)),
                    label: const Text(
                      "Logout",
                      style: TextStyle(
                        color: Color(0xFFE94B3C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFF0F0F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Reusable Widgets ----------

  Widget _buildMessageBox(String message, Color bgColor, Color borderColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(color: borderColor, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        _buildTextField(_nameController, 'Full Name', Icons.person_outline),
        const SizedBox(height: 16),
        _buildTextField(
          _usernameController,
          'Username',
          Icons.account_box_outlined,
        ),
        const SizedBox(height: 16),
        _buildTextField(_emailController, 'Email', Icons.email_outlined),
        const SizedBox(height: 16),
        _buildTextField(
          _upiIdController,
          'UPI ID (Optional)',
          Icons.account_balance_wallet,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _updateProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF48C67B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildViewMode() {
    return Column(
      children: [
        _buildInfoTile(
          icon: Icons.account_box_outlined,
          label: 'Username',
          value: _userInfo['username'] ?? 'N/A',
        ),
        const SizedBox(height: 12),
        _buildInfoTile(
          icon: Icons.account_balance_wallet,
          label: 'UPI ID',
          value: _userInfo['upiId'] ?? 'N/A',
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEAFBF3),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: const Color(0xFF48C67B), size: 22),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
