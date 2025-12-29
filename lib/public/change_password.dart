import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  int? shopId;
  String? userId;

  bool _oldPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _showMessage(String message, {bool success = false}) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w > 600;

    final Color borderColor = success ? Colors.green : royal;
    final IconData icon = success ? Icons.check_circle : Icons.error_outline;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.symmetric(
            horizontal: isTablet ? 40 : 16,
            vertical: isTablet ? 20 : 12,
          ),
          duration: const Duration(seconds: 3),
          content: Container(
            padding: EdgeInsets.all(isTablet ? 18 : 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
              border: Border.all(color: borderColor, width: isTablet ? 2.5 : 2),
            ),
            child: Row(
              children: [
                Icon(icon, color: borderColor, size: isTablet ? 26 : 22),
                SizedBox(width: isTablet ? 14 : 10),
                Expanded(
                  child: Text(
                    message,
                    textScaler: MediaQuery.textScalerOf(context),
                    style: TextStyle(
                      color: borderColor,
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getInt('shopId');
    userId = prefs.getString('userId');
  }

  InputDecoration _royalInputDecoration({
    required String label,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onToggleVisibility,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: royal),
      suffixIcon: onToggleVisibility != null
          ? IconButton(
        icon: Icon(
          obscure ? Icons.visibility : Icons.visibility_off,
          color: royal,
        ),
        onPressed: onToggleVisibility,
      )
          : null,
      labelStyle: const TextStyle(color: royalblue, fontWeight: FontWeight.w600),
      filled: true,
      fillColor: royalLight.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: royalLight, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: royal, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_oldPasswordController.text == _newPasswordController.text) {
      _showMessage("⚠️ Old password and new password cannot be the same");
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showMessage("⚠️ New password and confirm password do not match");
      return;
    }

    if (shopId == null || userId == null) {
      _showMessage("⚠️ User not found. Please login again.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('$baseUrl/auth/change-password');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "shopId": shopId,
          "userId": userId,
          "oldPassword": _oldPasswordController.text,
          "newPassword": _newPasswordController.text,
        }),
      );

      if (response.body.isEmpty) {
        _showMessage("❌ No response from server");
      } else {
        final data = jsonDecode(response.body);
        final msg = data['message'] ?? 'Operation completed';

        if (response.statusCode == 200) {
          _showMessage("✅ $msg", success: true);
          _oldPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        } else {
          _showMessage("❌ $msg");
        }
      }
    } catch (e) {
      _showMessage("❌ Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Change Password',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: royal,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: royal, width: 2),
              ),
              color: Colors.white,
              shadowColor: royal.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _oldPasswordController,
                        obscureText: !_oldPasswordVisible,
                        cursorColor: royal,
                        style: const TextStyle(color: royal, fontWeight: FontWeight.w500),
                        decoration: _royalInputDecoration(
                          label: 'Old Password',
                          icon: Icons.lock,
                          obscure: _oldPasswordVisible,
                          onToggleVisibility: () {
                            setState(() => _oldPasswordVisible = !_oldPasswordVisible);
                          },
                        ),
                        validator: (v) =>
                        v == null || v.isEmpty ? 'Enter old password' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: !_newPasswordVisible,
                        cursorColor: royal,
                        style: const TextStyle(color: royal, fontWeight: FontWeight.w500),
                        decoration: _royalInputDecoration(
                          label: 'New Password',
                          icon: Icons.lock_outline,
                          obscure: _newPasswordVisible,
                          onToggleVisibility: () {
                            setState(() => _newPasswordVisible = !_newPasswordVisible);
                          },
                        ),
                        validator: (v) =>
                        v == null || v.isEmpty ? 'Enter new password' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: !_confirmPasswordVisible,
                        cursorColor: royal,
                        style: const TextStyle(color: royal, fontWeight: FontWeight.w500),
                        decoration: _royalInputDecoration(
                          label: 'Confirm New Password',
                          icon: Icons.lock_outline,
                          obscure: _confirmPasswordVisible,
                          onToggleVisibility: () {
                            setState(() =>
                            _confirmPasswordVisible = !_confirmPasswordVisible);
                          },
                        ),
                        validator: (v) =>
                        v == null || v.isEmpty ? 'Confirm new password' : null,
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: royal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading ? null : _changePassword,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                            'Change Password',
                            style: TextStyle(fontSize: 16),
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
    );
  }
}
