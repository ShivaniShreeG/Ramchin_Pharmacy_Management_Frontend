import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main_navigation.dart';
import 'config.dart';
import 'forgot_password.dart';
import 'register.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _shopIdController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
  }

  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('rememberMe') ?? false;
      if (_rememberMe) {
        _shopIdController.text = prefs.getInt('shopId')?.toString() ?? '';
        _userIdController.text = prefs.getString('userId') ?? '';
        _passwordController.text = prefs.getString('password') ?? '';
      }
    });
  }

  void _showMessage(String message) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    final double paddingScale = isTablet ? 1.4 : 1.0;
    final double fontScale = isTablet ? 1.2 : 1.0;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
            border: Border.all(color: royal, width: isTablet ? 2.5 : 2),
          ),

          padding: EdgeInsets.symmetric(
            horizontal: 16 * paddingScale,
            vertical: 12 * paddingScale,
          ),

          child: Text(
            message,
            style: TextStyle(
              color: royal,
              fontSize: 16 * fontScale,
              fontWeight: FontWeight.w600,
            ),
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ),
      ),
    );
  }

  Future<void> _saveUserData(
      String role, int shopId, String userId, String designation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', role);
    await prefs.setInt('shopId', shopId);
    await prefs.setString('userId', userId);
    await prefs.setString('designation', designation);

    if (_rememberMe) {
      await prefs.setBool('rememberMe', true);
      await prefs.setString('password', _passwordController.text);
    } else {
      await prefs.setBool('rememberMe', false);
      await prefs.remove('password');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse("$baseUrl/auth/login");

      Map<String, dynamic> body = {
        "userId": _userIdController.text.trim(),
        "password": _passwordController.text.trim(),
      };
      if (_shopIdController.text.trim().isNotEmpty) {
        body["shopId"] = int.tryParse(_shopIdController.text.trim());
      }

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      setState(() => _isLoading = false);

      if (response.statusCode != 200) {
        _showMessage("Server error: ${response.statusCode}");
        return;
      }

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        final user = data['user'];
        final message = data['message'] ?? "Login successful";

        _showMessage(message);

        await _saveUserData(
          user['role']?.toString() ?? '',
          user['shopId'] is int ? user['shopId'] : int.tryParse(user['shopId']?.toString() ?? '0') ?? 0,
          user['userId']?.toString() ?? '',
          user['designation']?.toString() ?? '',
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      }
      else {
        _showMessage(data['message'] ?? "Login failed");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Error connecting to server: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;

        final double maxCardWidth = isTablet ? 450 : constraints.maxWidth * 0.9;
        final double verticalPadding = isTablet ? 32 : 20;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [royalblue, royalLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: verticalPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxCardWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // TITLE
                      Text(
                        "PHARMACY",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 32 : 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                          fontFamily: 'Good Times',
                        ),
                      ),
                      Text(
                        "MANAGEMENT",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 32 : 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.1,
                          fontFamily: 'Good Times',
                        ),
                      ),
                      const SizedBox(height: 20),

                      // LOGIN CARD
                      Container(
                        padding: EdgeInsets.all(isTablet ? 32 : 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              Icon(Icons.lock_outline,
                                  color: royal, size: isTablet ? 50 : 40),
                              const SizedBox(height: 12),
                              Text(
                                "Login",
                                style: TextStyle(
                                  fontSize: isTablet ? 30 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: royal,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // shop ID
                              _buildTextField(
                                controller: _shopIdController,
                                icon: Icons.home_work_rounded,
                                label: "Shop ID",
                                keyboard: TextInputType.number,
                                validator: (v) {
                                  if (v != null &&
                                      v.isNotEmpty &&
                                      int.tryParse(v) == null) {
                                    return "Enter a valid Shop ID";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // User ID
                              _buildTextField(
                                controller: _userIdController,
                                icon: Icons.person,
                                label: "User ID",
                                keyboard: TextInputType.number,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? "User ID is required"
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Password
                              _buildTextField(
                                controller: _passwordController,
                                icon: Icons.lock,
                                label: "Password",
                                obscure: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: royal,
                                  ),
                                  onPressed: () {
                                    setState(() =>
                                    _obscurePassword = !_obscurePassword);
                                  },
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? "Password is required"
                                    : null,
                              ),
                              const SizedBox(height: 20),

                              // Login Button
                              SizedBox(
                                width: double.infinity,
                                height: isTablet ? 55 : 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: royal,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _isLoading ? null : _login,
                                  child: _isLoading
                                      ? const CircularProgressIndicator(
                                      color: Colors.white)
                                      : Text(
                                    "Login",
                                    style: TextStyle(
                                      fontSize: isTablet ? 20 : 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                        const ForgotPasswordPage()),
                                  );
                                },
                                child: Text(
                                  "Forgot Password?",
                                  style:
                                  TextStyle(color: royal, fontSize: 14),
                                ),
                              ),

                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                        const CreateHallOwnerPage()),
                                  );
                                },
                                child: Text(
                                  "Not registered yet? Register",
                                  style:
                                  TextStyle(color: royal, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Text(
                        "© ${DateTime.now().year} Ramchin Technologies Private Limited",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: royal, fontSize: 14),
      cursorColor: royal, // 👈 Makes typing pointer royal
      keyboardType: keyboard,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: royal),
        suffixIcon: suffixIcon,
        labelText: label,
        labelStyle: const TextStyle(color: royal),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: royal, width: 1.2),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: royal, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true, // 💙 Enables background color
        fillColor: royalLight.withValues(alpha: 0.05),
      ),
      validator: validator,
    );
  }

}
