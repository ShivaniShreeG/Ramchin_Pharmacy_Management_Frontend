import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'package:flutter/services.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  bool isLoading = true;
  bool submitting = false;
  Map<String, dynamic>? profileData;
  String? errorMessage;

  int? shopId;
  String? userId;
  String? role;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
        content: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: royal, width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            message,
            style: const TextStyle(
              color: royal,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _initializeProfile() async {
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getInt('shopId');
    userId = prefs.getString('userId');
    role = prefs.getString('role');

    if (shopId != null && userId != null && role != null) {
      await _fetchProfile();
    } else {
      setState(() => isLoading = false);
      _showMessage('⚠️ User data not found.');
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final url = Uri.parse('$baseUrl/profile/$role/$shopId/$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          profileData = data;
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _emailController.text = data['email'] ?? '';
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        _showMessage('❌ Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showMessage('❌ Error fetching profile: $e');
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => submitting = true);

    try {
      final url = Uri.parse('$baseUrl/profile/$role/$shopId/$userId');
      final body = {
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "email": _emailController.text.trim(),
      };

      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        _showMessage("✅ Profile updated successfully");
      } else {
        _showMessage("❌ Failed to update: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error: $e");
    } finally {
      setState(() => submitting = false);
    }
  }

  // ✨ Reusable royal-themed input decoration
  InputDecoration royalInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: royal, fontWeight: FontWeight.w600),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: royal, width: 1.2),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: royal, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: royal,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (profileData == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            errorMessage ?? 'No profile data found',
            style: const TextStyle(color: royal),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Form(
                  key: _formKey,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      textSelectionTheme: const TextSelectionThemeData(
                        cursorColor: royal,
                        selectionColor: royalLight,
                        selectionHandleColor: royal,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // User ID (read-only)
                        TextFormField(
                          initialValue: userId.toString(),
                          readOnly: true,
                          style: const TextStyle(color: royal),
                          decoration: royalInputDecoration("User ID").copyWith(
                            fillColor: royalLight.withValues(alpha: 0.05),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Designation (read-only)
                        if (role == 'ADMIN') ...[
                          TextFormField(
                            initialValue: profileData!['designation'] ?? '',
                            readOnly: true,
                            style: const TextStyle(color: royal),
                            decoration: royalInputDecoration("Designation")
                                .copyWith(fillColor: royalLight.withValues(alpha: 0.05)),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Editable fields
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: royal),
                          cursorColor: royal,
                          decoration: royalInputDecoration("Name").copyWith(fillColor: royalLight.withValues(alpha: 0.05)),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              _showMessage("⚠️ Enter name");
                              return "";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _phoneController,
                          style: const TextStyle(color: royal),
                          cursorColor: royal,
                          decoration: royalInputDecoration("Phone").copyWith(fillColor: royalLight.withValues(alpha: 0.05)),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              _showMessage("⚠️ Enter phone number");
                              return "";
                            } else if (value.length != 10) {
                              _showMessage("⚠️ Phone number must be 10 digits");
                              return "";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _emailController,
                          style: const TextStyle(color: royal),
                          cursorColor: royal,
                          decoration: royalInputDecoration("Email").copyWith(fillColor: royalLight.withValues(alpha: 0.05)),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              _showMessage("⚠️ Enter email");
                              return "";
                            } else if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value)) {
                              _showMessage("⚠️ Enter a valid email address");
                              return "";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        if (submitting)
                          const Center(child: CircularProgressIndicator(color: royal))
                        else
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: royal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _updateProfile,
                            child: const Text("Save Changes",
                                style: TextStyle(fontSize: 16)),
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
