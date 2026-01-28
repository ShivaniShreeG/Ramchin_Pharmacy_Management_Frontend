import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/config.dart';

const Color royal = Color(0xFF875C3F);

class EditHallPage extends StatefulWidget {
  const EditHallPage({super.key});

  @override
  State<EditHallPage> createState() => _EditHallPageState();
}

class _EditHallPageState extends State<EditHallPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _gstController;
  late TextEditingController _dlController;
  late TextEditingController _tinController;

  Map<String, dynamic>? shopDetails;
  bool _isFetching = true;
  bool _isLoading = false;
  String? _base64Logo;
  File? selectedImage;
  int? shopId;

  @override
  void initState() {
    super.initState();
    _gstController = TextEditingController();
    _dlController = TextEditingController();
    _tinController = TextEditingController();
    _loadShopDetails();
  }

  Future<void> _loadShopDetails() async {
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getInt("shopId");
    if (shopId == null) {
      _showMessage("Shop ID not found in SharedPreferences", isError: true);
      return;
    }
    await _fetchShopDetails(shopId!);
  }

  Future<void> _fetchShopDetails(int shopId) async {
    try {
      final url = Uri.parse('$baseUrl/shops/$shopId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        shopDetails = jsonDecode(response.body);

        // Populate editable fields
        _gstController.text = shopDetails?['gst_number'] ?? '';
        _dlController.text = shopDetails?['dl_number'] ?? '';
        _tinController.text = shopDetails?['tin_number'] ?? '';
        _base64Logo = shopDetails?['logo'];
      } else {
        _showMessage("Failed to fetch shop details: ${response.statusCode}", isError: true);
      }
    } catch (e) {
      _showMessage("Error fetching shop details: $e", isError: true);
    } finally {
      setState(() {
        _isFetching = false;
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError ? Colors.redAccent.shade400 : royal,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: royal, width: 2)),
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        selectedImage = File(picked.path);
        _base64Logo = base64Encode(bytes);
      });
    }
  }

  Future<void> _updateHall() async {
    if (shopId == null) return;

    setState(() => _isLoading = true);

    final hallData = {
      if (_gstController.text.trim().isNotEmpty) "gst_number": _gstController.text.trim(),
      if (_dlController.text.trim().isNotEmpty) "dl_number": _dlController.text.trim(),
      if (_tinController.text.trim().isNotEmpty) "tin_number": _tinController.text.trim(),
      if (_base64Logo != null) "logo": _base64Logo,
    };

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/shops/$shopId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(hallData),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        _showMessage("Shop updated successfully!");
      } else {
        _showMessage("Failed to update shop: ${response.statusCode}", isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Error updating shop: $e", isError: true);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        // No validator => all optional
        cursorColor: royal,
        style: const TextStyle(color: royal),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: royal),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: royal, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: royal, width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetching) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Edit Shop",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          color: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: royal, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: royal,
                      backgroundImage: _base64Logo != null
                          ? MemoryImage(base64Decode(_base64Logo!))
                          : null,
                      child: _base64Logo == null
                          ? const Icon(Icons.add_a_photo, color: Colors.white, size: 40)
                          : null,
                    ),

                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    "Tap to change logo",
                    style: TextStyle(color: royal, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 20),

                // Show name, phone, email, address (non-editable)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        "Name: ${shopDetails?['name'] ?? ''}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: royal),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        "Phone: ${shopDetails?['phone'] ?? ''}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: royal),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        "Email: ${shopDetails?['email'] ?? ''}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: royal),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        "Address: ${shopDetails?['address'] ?? ''}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: royal),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(controller: _gstController, label: 'GST Number'),
                      _buildTextField(controller: _dlController, label: 'DL Number'),
                      _buildTextField(controller: _tinController, label: 'TIN Number'),
                      const SizedBox(height: 30),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                        width: 200,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: royal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _updateHall,
                          child: const Text(
                            "Save Changes",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
