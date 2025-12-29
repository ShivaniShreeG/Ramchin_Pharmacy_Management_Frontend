import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'login_page.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class CreateHallOwnerPage extends StatefulWidget {
  const CreateHallOwnerPage({super.key});

  @override
  State<CreateHallOwnerPage> createState() => _CreateHallOwnerPageState();
}

class _CreateHallOwnerPageState extends State<CreateHallOwnerPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  File? _pickedImage;
  String? _pickedImageBase64;
  bool verifying = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _shopExists = false;
  String _shopCheckMessage = "";

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent, // Let border container show
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
        content: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: royal, width: 2), // 💙 Royal blue border
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

  final Map<String, TextEditingController> _controllers = {
    'shop_id': TextEditingController(),
    'shop_name': TextEditingController(),
    'shop_phone': TextEditingController(),
    'shop_email': TextEditingController(),
    'shop_address': TextEditingController(),
    'user_id': TextEditingController(),
    'password': TextEditingController(),
    'confirm_password': TextEditingController(),
    'admin_name': TextEditingController(),
    'admin_phone': TextEditingController(),
    'admin_email': TextEditingController(),
  };

  final RegExp _emailRegex = RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,4}$');

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _pickedImage = File(pickedFile.path);
        _pickedImageBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _checkHallExists(String shopId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/register/check-shop/$shopId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _shopExists = data['exists'] ?? false;
          _shopCheckMessage = _shopExists
              ? "⚠️ This Shop ID already exists"
              : "✅ Shop ID is available";
        });
      }
    } catch (e) {
      setState(() {
        _shopExists = false;
        _shopCheckMessage = "❌ Network error while checking Hall ID";
      });
    }
  }

  Future<bool> _sendEmailOtp(String email) async {
    try {
      final otp = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();

      final res = await http.post(
        Uri.parse('$baseUrl/register/send_otp'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      final data = jsonDecode(res.body);
      return data['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  Future<bool> _verifyEmailOtp(String email, String otp) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/register/verify_otp'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      final data = jsonDecode(res.body);
      return data['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final email = _controllers['admin_email']!.text.trim();

    final otpSent = await _sendEmailOtp(email);
    if (!otpSent) {
      _showMessage("❌ Failed to send OTP. Try again.");
      setState(() => _loading = false);
      return;
    }

    final otpController = TextEditingController();
    if(!mounted) return;
    bool? verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {

          String otpError = "";

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Center(
              child: Text(
                "Verify Email OTP",
                style: TextStyle(
                  color: royal,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Enter the 6-digit OTP sent to $email",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: royal.withValues(alpha: 0.8), fontSize: 15),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: otpController,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  cursorColor: royal,
                  style: TextStyle(
                    color: royal,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3,
                  ),
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "Enter OTP",
                    hintStyle: TextStyle(color: royal.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.6),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: royal.withValues(alpha: 0.5), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: royal, width: 2),
                    ),
                  ),
                ),
                if (otpError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      otpError,
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text("Cancel", style: TextStyle(color: royal, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: royal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 4,
                ),
                onPressed: verifying
                    ? (){}
                    : () async {
                  setState(() => verifying = true);
                  final ok = await _verifyEmailOtp(email, otpController.text.trim());
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.pop(context, true);
                  } else {
                    setState(() {
                      verifying = false;
                      otpError = "Invalid or expired OTP. Please try again.";
                    });
                  }
                },
                child: verifying
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text("Verify", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        });
      },
    );

    if (verified != true) {
      _showMessage("❌ OTP verification failed.");
      setState(() => _loading = false);
      return;
    }

    await _registerHall();
  }

  Future<void> _registerHall() async {
    final body = {
      'shop_name': _controllers['shop_name']!.text.trim(),
      'shop_phone': _controllers['shop_phone']!.text.trim(),
      'shop_email': _controllers['shop_email']!.text.trim(),
      'shop_address': _controllers['shop_address']!.text.trim(),
      'password': _controllers['password']!.text.trim(),
      'admin_name': _controllers['admin_name']!.text.trim(),
      'admin_phone': _controllers['admin_phone']!.text.trim(),
      'admin_email': _controllers['admin_email']!.text.trim(),
      'shop_id': int.tryParse(_controllers['shop_id']!.text.trim()) ?? 0,
      'user_id': _controllers['user_id']!.text.trim(),
    };

    if (_pickedImageBase64 != null) body['shop_logo'] = _pickedImageBase64!;

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/register/create'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );
      final data = jsonDecode(res.body);

      if (res.statusCode == 201 || res.statusCode == 200) {
        _showMessage("✅ Shop & Owner Registered Successfully!");
        await Future.delayed(const Duration(seconds: 3));

        if (!mounted) return; // ✅ only this one check is needed

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } else {
        _showMessage("❌ ${data['message'] ?? 'Failed to register.'}");
      }

    } catch (e) {
      _showMessage("❌ Network Error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: royal.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
        filled: true,
        fillColor: royalLight.withValues(alpha: 0.05), // 💙 consistent background        enabledBorder: OutlineInputBorder(
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: royal.withValues(alpha: 0.5), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: royal, width: 2),
        ),
        suffixIcon: suffixIcon,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Register Shop", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
        body: SingleChildScrollView(
            child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 600, // 👈 ideal for all screen sizes
                    ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Shop Details"),
              _buildTextField(
                'shop_id',
                'Shop Id',
                type: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (val) {
                  if (val.isNotEmpty) {
                    _checkHallExists(val);
                  } else {
                    setState(() {
                      _shopExists = false;
                      _shopCheckMessage = "";
                    });
                  }
                },
              ),
              if (_shopCheckMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _shopCheckMessage,
                    style: TextStyle(
                      color: _shopExists ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              _buildTextField('shop_name', 'Shop Name'),
              _buildTextField('shop_phone', 'Shop Phone',
                  type: TextInputType.phone,
                  validator: _validateNumeric10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10)
                  ]),
              _buildTextField('shop_email', 'Shop Email',
                  type: TextInputType.emailAddress, validator: _validateEmail),
              _buildTextField('shop_address', 'Shop Address'),
              const SizedBox(height: 20),
              _buildSectionTitle("Shop Logo"),
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: royal.withValues(alpha: 0.3),
                        backgroundImage:
                        _pickedImage != null ? FileImage(_pickedImage!) : null,
                        child: _pickedImage == null
                            ? Icon(Icons.add_a_photo, color: royal, size: 40)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Tap to upload shop logo",
                      style:
                      TextStyle(color: royal.withValues(alpha: 0.7), fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle("User Account"),
              _buildTextField('user_id', 'User ID',
                  type: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10)
                  ]),
              _buildPasswordField('password', 'Password', true),
              _buildPasswordField('confirm_password', 'Confirm Password', false),
              const SizedBox(height: 20),
              _buildSectionTitle("Owner Details"),
              _buildTextField('admin_name', 'Owner Name', onChanged: (val) {
                if (val.isNotEmpty) {
                  final fixed = val[0].toUpperCase() + val.substring(1);
                  if (val != fixed) {
                    _controllers['admin_name']!.value = TextEditingValue(text: fixed);
                  }
                }
              }),
              _buildTextField('admin_phone', 'Owner Phone',
                  type: TextInputType.phone,
                  validator: _validateNumeric10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10)
                  ]),
              _buildTextField('admin_email', 'Owner Email',
                  type: TextInputType.emailAddress, validator: _validateEmail),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: royal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 5,
                    shadowColor: royal.withValues(alpha: 0.4),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    "Register",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
                ),
            ),
        ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10.0, top: 5),
    child: Text(
      title,
      style: TextStyle(
        color: royal,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    ),
  );

  Widget _buildTextField(
      String key,
      String label, {
        TextInputType? type,
        List<TextInputFormatter>? inputFormatters,
        String? Function(String?)? validator,
        void Function(String)? onChanged,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: _controllers[key],
        keyboardType: type,
        inputFormatters: inputFormatters,
        validator: validator,
        onChanged: onChanged,
        style: const TextStyle(
          color: royal,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: royal,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: royalblue,
            fontWeight: FontWeight.w600,
          ),
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
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(String key, String label, bool isMainPassword) {
    bool isObscured =
    isMainPassword ? _obscurePassword : _obscureConfirmPassword;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: _controllers[key],
        obscureText: isObscured,
        cursorColor: royal,
        validator: (v) {
          if (v == null || v.isEmpty) return "Enter $label";
          if (!isMainPassword && v != _controllers['password']!.text.trim()) {
            return "Passwords do not match";
          }
          return null;
        },
        decoration: _inputDecoration(
          label,
          suffixIcon: IconButton(
            icon: Icon(
              isObscured ? Icons.visibility_off : Icons.visibility,
              color: royal,
            ),
            onPressed: () {
              setState(() {
                if (isMainPassword) {
                  _obscurePassword = !_obscurePassword;
                } else {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                }
              });
            },
          ),
        ),
        style: const TextStyle(color: royal, fontWeight: FontWeight.w500),
      ),
    );
  }

  String? _validateNumeric10(String? value) {
    if (value == null || value.isEmpty) return "Required field";
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) return "Enter only numbers";
    if (value.length != 10) return "Must be exactly 10 digits";
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Enter email";
    if (!_emailRegex.hasMatch(value)) return "Enter valid email";
    return null;
  }
}
