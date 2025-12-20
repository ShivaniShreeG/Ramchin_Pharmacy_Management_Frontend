import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../public/config.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class EditHallPage extends StatefulWidget {
  final dynamic hall;

  const EditHallPage({super.key, required this.hall});

  @override
  State<EditHallPage> createState() => _EditHallPageState();
}

class _EditHallPageState extends State<EditHallPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _dueDateController;


  String? _base64Logo;
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.hall['name']);
    _phoneController = TextEditingController(text: widget.hall['phone']);
    _emailController = TextEditingController(text: widget.hall['email']);
    _addressController = TextEditingController(text: widget.hall['address']);
    _base64Logo = widget.hall['logo'];
    _dueDateController = TextEditingController(
      text: widget.hall['duedate'] != null
          ? widget.hall['duedate'].toString().split('T').first
          : '',
    );

  }

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

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }


  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImage = File(picked.path);
        _base64Logo = base64Encode(bytes);
      });
    }
  }
  Future<void> _selectDueDate(BuildContext context) async {
    DateTime initialDate;
    try {
      initialDate = DateTime.parse(_dueDateController.text);
    } catch (_) {
      initialDate = DateTime.now();
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        final theme = Theme.of(context);

        return Theme(
          data: theme.copyWith(
            colorScheme: const ColorScheme.light(
              primary: royal,
              onPrimary: Colors.white,
              onSurface: royal,
            ),

            inputDecorationTheme: InputDecorationTheme(
              filled: false,
              fillColor: Colors.transparent,

              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: royal, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: royal, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),

              labelStyle: const TextStyle(color: royal),
              hintStyle: const TextStyle(color: royal),
              suffixIconColor: royal,
            ),

            textTheme: theme.textTheme.copyWith(
              bodySmall:const TextStyle(color: royal) ,
              bodyMedium: const TextStyle(color: royal),
              bodyLarge: const TextStyle(color: royal),
              titleMedium: const TextStyle(color: royal),
            ),

            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: royal,
              selectionColor: Colors.white,
              selectionHandleColor: royal,
            ),

            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: royal,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dueDateController.text = picked.toIso8601String().split('T').first;
      });
    }
  }

  Future<void> _updateHall(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final hallData = {
      "name": _nameController.text.trim(),
      "phone": _phoneController.text.trim(),
      "email": _emailController.text.trim(),
      "address": _addressController.text.trim(),
      if (_base64Logo != null) "logo": _base64Logo,
      "duedate": _dueDateController.text.trim(),

    };

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/shops/${widget.hall['shop_id']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(hallData),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        _showMessage("Shop updated successfully!");
      } else {
        _showMessage("Failed to update shop: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Error updating shop: $e");
    }
  }

  Widget _buildTextField(
      {required TextEditingController controller,
        required String label,
        TextInputType type = TextInputType.text,
        int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        validator: (value) =>
        value == null || value.isEmpty ? 'Please enter $label' : null,
        cursorColor: royal,
        style: TextStyle(color: royal),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: royal),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Edit Shop",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
            side: const BorderSide(
              color: royal,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: royal,
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (_base64Logo != null
                          ? MemoryImage(base64Decode(_base64Logo!))
                          : null) as ImageProvider?,
                      child: _selectedImage == null && _base64Logo == null
                          ? const Icon(Icons.add_a_photo,
                          color: Colors.white, size: 40)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Tap to change logo",
                    style: TextStyle(
                      color: royal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(controller: _nameController, label: 'Name'),
                  _buildTextField(
                      controller: _phoneController,
                      label: 'Phone',
                      type: TextInputType.phone),
                  _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      type: TextInputType.emailAddress),
                  _buildTextField(
                      controller: _addressController,
                      label: 'Address',
                      maxLines: 2),
                  GestureDetector(
                    onTap: () => _selectDueDate(context),
                    child: AbsorbPointer(
                      child: _buildTextField(
                        controller: _dueDateController,
                        label: 'Due Date (YYYY-MM-DD)',
                        type: TextInputType.datetime,
                      ),
                    ),
                  ),


                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: royal,
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _updateHall(context),
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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
}
