import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../public/config.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class CreateAdminPage extends StatefulWidget {
  final dynamic hall;
  const CreateAdminPage({super.key, required this.hall});

  @override
  State<CreateAdminPage> createState() => _CreateAdminPageState();
}

class _CreateAdminPageState extends State<CreateAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool submitting = false;
  String? message;

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:  TextStyle(
            color: isError ? Colors.redAccent.shade400 : royal,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: royal,width: 2)
        ),
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _addAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      submitting = true;
      message = null;
    });

    try {

      final response = await http.post(
        Uri.parse("$baseUrl/users/${widget.hall['shop_id']}/admin"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": _userIdController.text.trim(),
          "password": _passwordController.text.trim(),
          "designation": "Owner",
          "name": _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
          "phone": _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          "email": _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        setState(() {
          _showMessage("✅ Admin created successfully for ${widget.hall['name']}");
          _userIdController.clear();
          _passwordController.clear();
          _nameController.clear();
          _phoneController.clear();
          _emailController.clear();
        });
      } else {
        _showMessage("❌ Failed: ${response.body}");
      }
    } catch (e) {
          _showMessage("❌ Error: $e");
    } finally {
      setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Create Admin - ${widget.hall['name'] ?? 'Hall'}",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: royal,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: royal,width: 1)
                ),
                child: Column(
                  children: [
                    Text(
                      "Shop ID: ${widget.hall['shop_id']}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: royal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Shop Name: ${widget.hall['name'] ?? ''}",
                      style: const TextStyle(
                        fontSize: 16,
                        color: royal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _userIdController,
                cursorColor: royal,
                decoration:  InputDecoration(
                  filled: true,
                  fillColor: royalLight.withValues(alpha: 0.03),
                  labelText: "New Admin User ID",
                  labelStyle: TextStyle(color: royal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: royal, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: royal, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: royal),
                validator: (v) => v == null || v.isEmpty ? "Enter user ID" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                cursorColor: royal,
                decoration:  InputDecoration(
                  filled: true,
                  fillColor: royalLight.withValues(alpha: 0.03),
                  labelText: "Password",
                  labelStyle: TextStyle(color: royal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: royal, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: royal, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                obscureText: true,
                style: const TextStyle(color: royal),
                validator: (v) => v == null || v.length < 4 ? "Min 4 characters" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                cursorColor: royal,
                decoration:  InputDecoration(
                  filled: true,
                  fillColor: royalLight.withValues(alpha: 0.03),
                  labelText: "Name (optional)",
                  labelStyle: TextStyle(color: royal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: royal, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: royal, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: const TextStyle(color: royal),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration:  InputDecoration(
                  filled: true,
                  fillColor: royalLight.withValues(alpha: 0.03),
                  labelText: "Phone (optional)",
                  labelStyle: TextStyle(color: royal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: royal, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: royal, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.phone,
                cursorColor: royal,
                style: const TextStyle(color: royal),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration:  InputDecoration(
                  filled: true,
                  fillColor: royalLight.withValues(alpha: 0.03),
                  labelText: "Email (optional)",
                  labelStyle: TextStyle(color: royal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: royal, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: royal, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                cursorColor: royal,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: royal),
              ),
              const SizedBox(height: 24),

              submitting
                  ? const Center(child: CircularProgressIndicator(color: royal))
                  : ElevatedButton(
                onPressed: _addAdmin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: royal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Add Admin",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 20),
                Text(
                  message!,
                  style: const TextStyle(
                    color: royal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
