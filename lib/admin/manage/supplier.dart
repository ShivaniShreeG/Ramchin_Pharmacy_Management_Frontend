import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';
import '../../public/main_navigation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class SupplierPage extends StatefulWidget {
  const SupplierPage({super.key});

  @override
  State<SupplierPage> createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingSuppliers = true;
  bool _showForm = false;
  Map<String, dynamic>? shopDetails;
  List<Map<String, dynamic>> _suppliers = [];
  int? editingSupplierId;

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
   _fetchHallDetails();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: royal)),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: royal, width: 2),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _fetchHallDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getInt("shopId");
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

  Future<void> _callSupplier(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showMessage("Could not open dialer");
    }
  }

  Future<void> _fetchSuppliers() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId == null) return;

    try {
      final url = Uri.parse("$baseUrl/suppliers/$shopId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _suppliers =
          List<Map<String, dynamic>>.from(jsonDecode(response.body));
        });
      }
    } catch (e) {
      _showMessage("Error loading suppliers");
    } finally {
      setState(() => _isLoadingSuppliers = false);
    }
  }

  void _confirmDeleteSupplier({
    required int id,
    required String name,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          "Delete Supplier",
          style: TextStyle(color: royal, fontWeight: FontWeight.bold),
        ),
        content: RichText(
          text: TextSpan(
            style: TextStyle(color: royal, fontSize: 15),
            children: [
              const TextSpan(text: "Are you sure you want to delete "),
              TextSpan(
                text: name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const TextSpan(text: " ?\n\nThis action cannot be undone."),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: royal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteSupplier(id);
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId == null) return;

    try {
      final url = Uri.parse("$baseUrl/suppliers/$shopId");
      final body = jsonEncode({
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "email": _emailController.text.trim(),
        "address": _addressController.text.trim(),
      });

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showMessage("✅ Supplier created");
        _formKey.currentState!.reset();
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        _addressController.clear();
        setState(() => _showForm = false);
        await _fetchSuppliers();
      } else {
        _showMessage(response.body);
      }
    } catch (e) {
      _showMessage("Error creating supplier");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSupplier(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId == null) return;

    try {
      final url = Uri.parse("$baseUrl/suppliers/$shopId/$id");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() {
          _suppliers.removeWhere((s) => s["id"] == id);
        });
        _showMessage("Supplier deleted");
      }
    } catch (e) {
      _showMessage("Error deleting supplier");
    }
  }

  Widget _supplierForm() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: royal),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              labeledTanRow(
                label: "NAME",
                controller: _nameController,
                hintText: "Enter Supplier Name",
                validator: (v) =>
                v == null || v.trim().isEmpty ? "Name is required" : null,
              ),
              labeledTanRow(
                label: "PHONE",
                controller: _phoneController,
                inputType: TextInputType.phone,
                hintText: "Enter Phone Number",
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return "Phone number required";
                  if (!RegExp(r'^\d{10}$').hasMatch(v)) return "10 digits required";
                  return null;
                },
              ),

              labeledTanRow(
                label: "EMAIL",
                controller: _emailController,
                inputType: TextInputType.emailAddress,
                hintText: "Enter Email Address",
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v)) {
                      return "Enter a valid email address";
                    }
                  }
                  return null;
                },
              ),
              labeledTanRow(
                label: "ADDRESS",
                controller: _addressController,
                hintText: "Enter Supplier address",
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: royal),
                onPressed: _isLoading
                    ? null
                    : editingSupplierId == null
                    ? _createSupplier
                    : _updateSupplier,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                  editingSupplierId == null
                      ? "Save Supplier"
                      : "Update Supplier",
                  style: const TextStyle(color: Colors.white),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId == null || editingSupplierId == null) return;

    try {
      final url =
      Uri.parse("$baseUrl/suppliers/$shopId/$editingSupplierId");
      final body = jsonEncode({
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "email": _emailController.text.trim(),
        "address": _addressController.text.trim(),
      });

      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        _showMessage("✅ Supplier updated");
        _resetForm();
        await _fetchSuppliers();
      } else {
        _showMessage(response.body);
      }
    } catch (e) {
      _showMessage("Error updating supplier");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _addressController.clear();

    setState(() {
      editingSupplierId = null;
      _showForm = false;
    });
  }

  void _editSupplier(Map<String, dynamic> s) {
    setState(() {
      editingSupplierId = s["id"];
      _showForm = true;

      _nameController.text = s["name"] ?? "";
      _phoneController.text = s["phone"] ?? "";
      _emailController.text = s["email"] ?? "";
      _addressController.text = s["address"] ?? "";
    });
  }

  Widget _supplierCard(Map<String, dynamic> s) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: royal.withValues(alpha:0.6), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 🔹 Supplier Icon / Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: royalLight.withValues(alpha:0.15),
              child: Icon(Icons.local_shipping_rounded, color: royal, size: 28),
            ),

            const SizedBox(width: 14),

            // 🔹 Supplier Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    s["name"] ?? "-",
                    style: TextStyle(
                      color: royal,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Phone
                  Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: royalLight),
                      const SizedBox(width: 6),
                      Text(
                        s["phone"] ?? "-",
                        style: TextStyle(color: royal),
                      ),
                    ],
                  ),

                  // Optional Email
                  if (s["email"] != null && s["email"].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.email, size: 16, color: royalLight),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s["email"],
                              style: TextStyle(color: royal),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Optional Address
                  if (s["address"] != null && s["address"].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on, size: 16, color: royalLight),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s["address"],
                              style: TextStyle(color: royal),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // 🔹 Action Buttons
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Edit
                IconButton(
                  icon: const Icon(Icons.edit),
                  color: Colors.blueGrey,
                  tooltip: "Edit",
                  onPressed: () => _editSupplier(s),
                ),
                // Call
                IconButton(
                  icon: const Icon(Icons.call),
                  color: Colors.green,
                  tooltip: "Call",
                  onPressed: () => _callSupplier(s["phone"]),
                ),
                // Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  tooltip: "Delete",
                  onPressed: () => _confirmDeleteSupplier(
                    id: s["id"],
                    name: s["name"] ?? "this supplier",
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHallCard(Map<String, dynamic> hall) {
    return Container(
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
              color: Colors.white, // 👈 soft teal background
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
                hall['name']?.toString().toUpperCase() ?? "HALL NAME",
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
      appBar: AppBar(
        title: const Text("Suppliers "),
        backgroundColor: royal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            color: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 2)),
              );
            },
          ),
        ],
      ),

      body: _isLoadingSuppliers
          ? Center(child: CircularProgressIndicator(color: royal))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (shopDetails != null) _buildHallCard(shopDetails!),
            const SizedBox(height: 16,),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: royal),
              onPressed: () =>
                  setState(() => _showForm = !_showForm),
              child: Text(
                _showForm ? "Close" : "Add Supplier",
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (_showForm) _supplierForm(),
            const SizedBox(height: 16),
            ..._suppliers.map(_supplierCard),
          ],
        ),
      ),
    );
  }
}
