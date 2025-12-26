import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';
import '../../public/main_navigation.dart';
import 'package:flutter/services.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class CreateAdminPage extends StatefulWidget {
  const CreateAdminPage({super.key});

  @override
  State<CreateAdminPage> createState() => _CreateAdminPageState();
}

class _CreateAdminPageState extends State<CreateAdminPage> {
  final _formKey = GlobalKey<FormState>();

  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  String _designation = "Staff";
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingAdmins = true;
  bool _showForm = false;
  List<Map<String, dynamic>> _admins = [];
  Map<String, dynamic>? shopDetails;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:  TextStyle(
            color: royal,
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

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId != null) {
      await _fetchHallDetails(shopId);
      await _fetchAdmins();
    }
  }

  Future<void> _fetchAdmins() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId == null) return;

    try {
      final url = Uri.parse("$baseUrl/admins/$shopId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _admins = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      _showMessage("Error fetching admins: $e");
    } finally {
      setState(() {
        _isLoadingAdmins = false;
      });
    }
  }

  Future<void> _createAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId == null) {
      _showMessage("❌ shop ID not found in session");
      setState(() => _isLoading = false);
      return;
    }

    try {
      final url = Uri.parse("$baseUrl/users/$shopId/admin");
      final body = jsonEncode({
        "user_id": _userIdController.text.trim(),
        "password": _passwordController.text.trim(),
        "designation": _designation,
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "email": _emailController.text.trim(),
        "is_active": true
      });

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage("✅ Admin created successfully");
        _formKey.currentState!.reset();
        _userIdController.clear();
        _passwordController.clear();
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        setState(() {
          _designation = "Staff";
          _showForm = false;
        });
        await _fetchAdmins();

      } else {
        _showMessage("❌ Failed: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error creating admin: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAdmin(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId == null) return;

    try {
      final url = Uri.parse("$baseUrl/admins/$shopId/admin/$userId");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() {
          _admins.removeWhere((admin) => admin["user_id"] == userId);
        });
        _showMessage("✅ Admin $userId deleted successfully");
       
      } else {
        _showMessage("❌ Failed to delete admin: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error deleting admin: $e");
    }
  }

  void _showDeleteDialog(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: royal,
            width: 1.5,
          ),
        ),
        title: Text("Delete Admin", style: TextStyle(color: royal)),
        content: Text("Do you want to delete admin with User ID $userId?",
            style: TextStyle(color: royal)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: royal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: royal),
            onPressed: () {
              Navigator.pop(context);
              _deleteAdmin(userId);
            },
            child: Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminForm() {

    return Card(
      elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: royal,
            width: 1,
          ),
        ),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              labeledTanRow(
                label: "USER ID",
                controller: _userIdController,
                inputType: TextInputType.number,
                hintText: "Enter User ID",
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return "Enter user ID";
                  if (!RegExp(r'^\d+$').hasMatch(v)) return "User ID must be numeric";
                  if (v.length > 10) return "Max 10 digits";
                  return null;
                },
              ),

              labeledTanRow(
                label: "PASSWORD",
                controller: _passwordController,
                obscureText: _obscurePassword,
                showPasswordToggle: true,
                hintText: "Enter Password",
                validator: (v) => v == null || v.isEmpty ? "Enter password" : null,
              ),

              labeledTanRow(
                label: "DESIGNATION",
                dropdownItems: const [
                  DropdownMenuItem(value: "Staff", child: Text("Staff")),
                  DropdownMenuItem(value: "Owner", child: Text("Owner")),
                ],
                dropdownValue: _designation,
                onDropdownChanged: (val) => setState(() => _designation = val ?? "Staff"),
              ),

              labeledTanRow(
                label: "NAME",
                controller: _nameController,
                hintText: "(Optional) Enter Name",
              ),

              labeledTanRow(
                label: "PHONE",
                controller: _phoneController,
                inputType: TextInputType.phone,
                hintText: "(Optional) Enter Phone Number",
                maxLength: 10, // ✅ limit typing to 10 digits
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // ✅ only digits allowed
                  LengthLimitingTextInputFormatter(10),   // ✅ block after 10 digits
                ],
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    if (!RegExp(r'^\d+$').hasMatch(v)) return "Digits only";
                    if (v.length != 10) return "10 digits required";
                  }
                  return null;
                },
              ),

              labeledTanRow(
                label: "EMAIL",
                controller: _emailController,
                inputType: TextInputType.emailAddress,
                hintText: "(Optional) Enter Email Address",
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v)) {
                      return "Enter a valid email address";
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: royal, foregroundColor: Colors.white),
                      onPressed: _isLoading ? null : _createAdmin,
                      child: _isLoading ? CircularProgressIndicator(color: royal) : const Text("Create Admin"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => setState(() => _showForm = false),
                    child: Text("Close", style: TextStyle(color: royal)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHallCard(Map<String, dynamic> hall) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      padding: const EdgeInsets.all(16),
      height: 95,
      decoration: BoxDecoration(
        color: royal,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: royal, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: royal.withValues(alpha:0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ClipOval(
            child: hall['logo'] != null
                ? Image.memory(
              base64Decode(hall['logo']),
              width: 70,
              height: 70,
              fit: BoxFit.cover,
            )
                : Container(
              width: 70,
              height: 70,
              color: Colors.white,
              child: const Icon(
                Icons.home_work_rounded,
                color: royal,
                size: 35,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                hall['name']?.toString().toUpperCase() ?? "SHOP NAME",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(Map<String, dynamic> admin) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: royal,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.person, color: royal, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "User ID: ${admin["user_id"] ?? "N/A"}",
                    style: TextStyle(color: royal, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Name: ${admin["name"]?.isNotEmpty == true ? admin["name"] : "-"}",
                    style: TextStyle(color: royal),
                    softWrap: true,
                  ),
                  Text(
                    "Phone: ${admin["phone"]?.isNotEmpty == true ? admin["phone"] : "-"}",
                    style: TextStyle(color: royal),
                    softWrap: true,
                  ),
                  Text(
                    "Email: ${admin["email"]?.isNotEmpty == true ? admin["email"] : "-"}",
                    style: TextStyle(color: royal),
                    softWrap: true,
                  ),
                  Text(
                    "Designation: ${admin["designation"] ?? "-"}",
                    style: TextStyle(color: royal),
                    softWrap: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteDialog(admin["user_id"]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchHallDetails(int shopId) async {
    try {
      final url = Uri.parse('$baseUrl/shops/$shopId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        shopDetails = jsonDecode(response.body);
      }
    } catch (e) {
      _showMessage("Error fetching hall details: $e");
    } finally {
      setState(() {});
    }
  }

  Widget labeledTanRow({
    required String label,
    TextEditingController? controller,
    String? hintText,
    String? Function(String?)? validator,
    TextInputType inputType = TextInputType.text,
    bool obscureText = false,
    bool showPasswordToggle = false,
    void Function(String)? onChanged,
    List<DropdownMenuItem<String>>? dropdownItems,
    String? dropdownValue,
    void Function(String?)? onDropdownChanged,
    double labelWidthFactor = 0.3,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: screenWidth * labelWidthFactor,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(color: royal, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: dropdownItems != null
                ? DropdownButtonFormField<String>(
              initialValue: dropdownValue,
              onChanged: onDropdownChanged,
              items: dropdownItems,
              style: TextStyle(color: royal),
              dropdownColor: Colors.white,
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: royal, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: royal, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: royalLight.withValues(alpha: 0.05),
              ),
            )
                : TextFormField(
              controller: controller,
              validator: validator,
              keyboardType: inputType,
              obscureText: obscureText,
              onChanged: onChanged,
              cursorColor: royal,
              style: TextStyle(color: royal),
              maxLength: maxLength,
              inputFormatters: inputFormatters,
              decoration: InputDecoration(
                counterText: "",
                hintText: hintText,
                hintStyle: TextStyle(color: royalLight),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: royal, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: royal, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.redAccent, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.redAccent, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: royalLight.withValues(alpha: 0.05),
                suffixIcon: showPasswordToggle
                    ? IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: royal,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Admins", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 2)),
              );
            },
          ),
        ],
      ),
      body: _isLoadingAdmins
          ? Center(child: CircularProgressIndicator(color: royal))
          : _admins.isEmpty && !_showForm
          ? Center(

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            if (shopDetails != null) _buildHallCard(shopDetails!),
            const SizedBox(height: 16),
            Text(
              "No admins found.",
              style: TextStyle(
                color: royal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: royal,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() => _showForm = true);
              },
              child: const Text("Create Admin"),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            if (shopDetails != null) _buildHallCard(shopDetails!),
            const SizedBox(height: 16),
            if (!_showForm)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: royal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  setState(() => _showForm = true);
                },
                child: const Text("Create Admin"),
              ),
            if (_showForm) _buildAdminForm(),
            const SizedBox(height: 16),
            ..._admins.map(_buildAdminCard),
          ],
        ),
      ),
    );
  }
}
