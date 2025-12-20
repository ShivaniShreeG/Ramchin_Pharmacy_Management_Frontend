import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';
import 'package:flutter/services.dart';
import '../../public/main_navigation.dart';

const Color royalblue = Color(0xFF376EA1);
const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class AddFacilitatorPage extends StatefulWidget {
  const AddFacilitatorPage({super.key});

  @override
  State<AddFacilitatorPage> createState() => _AddFacilitatorPageState();
}

class _AddFacilitatorPageState extends State<AddFacilitatorPage> {
  final _formKey = GlobalKey<FormState>();
  final _facilityController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isFetching = true;
  bool _showForm = false;
  int? _editingFacilitatorId;

  List<Map<String, dynamic>> _facilitators = [];
  Map<String, dynamic>? hallDetails;
  
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    if (lodgeId != null) {
      await _fetchHallDetails(lodgeId);
      await _fetchFacilitators();
    }
  }

  Future<void> _fetchFacilitators() async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    if (lodgeId == null) return;

    try {
      final url = Uri.parse("$baseUrl/facilitator/lodge/$lodgeId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _facilitators = List<Map<String, dynamic>>.from(data["data"] ?? data);
        });
      }
    } catch (e) {
      _showMessage("❌ Error fetching facilitators: $e");
    } finally {
      setState(() => _isFetching = false);
    }
  }

  Future<void> _submitFacilitator() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    if (lodgeId == null) {
      _showMessage("❌ Lodge ID not found");
      setState(() => _isLoading = false);
      return;
    }

    final body = {
      "lodge_id": lodgeId,
      "facility": _facilityController.text.trim(),
      "name": _nameController.text.trim(),
      "phone": _phoneController.text.trim(),
    };

    try {
      http.Response response;
      if (_editingFacilitatorId == null) {
        response = await http.post(
          Uri.parse("$baseUrl/facilitator"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
      } else {
        response = await http.patch(
          Uri.parse("$baseUrl/facilitator/$_editingFacilitatorId"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage(_editingFacilitatorId == null
            ? "✅ Facilitator added successfully"
            : "✅ Facilitator updated successfully");

        _formKey.currentState!.reset();
        _facilityController.clear();
        _nameController.clear();
        _phoneController.clear();

        setState(() {
          _editingFacilitatorId = null;
          _showForm = false;
        });

        _fetchFacilitators();
      } else {
        _showMessage("❌ Failed: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error submitting facilitator: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFacilitator(int id) async {
    try {
      final url = Uri.parse("$baseUrl/facilitator/$id");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() => _facilitators.removeWhere((e) => e["id"] == id));
        _showMessage("✅ Facilitator deleted successfully");
      } else {
        _showMessage("❌ Failed to delete: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error deleting facilitator: $e");
    }
  }

  void _showDeleteDialog(int id, String facility, String name) {
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
        title: Text(
          "Delete Facilitator",
          style: TextStyle(color: royal),
        ),
        content: Text(
          'Do you want to delete "$name" from "$facility"?',
          style: TextStyle(color: royal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: royal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: royal),
            onPressed: () {
              Navigator.pop(context);
              _deleteFacilitator(id);
            },
            child: Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editFacilitator(Map<String, dynamic> facilitator) {
    setState(() {
      _editingFacilitatorId = facilitator["id"];
      _facilityController.text = facilitator["facility"] ?? "";
      _nameController.text = facilitator["name"] ?? "";
      _phoneController.text = facilitator["phone"] ?? "";
      _showForm = true;
    });
  }

  Widget _buildFacilitatorForm() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: royal, width: 1),
      ),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              labeledTanRow(
                label: "Facility",
                controller: _facilityController,
                hintText: "Enter Facility",
                validator: (v) =>
                v == null || v.isEmpty ? "Enter facility" : null,
              ),
              const SizedBox(height: 10),
              labeledTanRow(
                label: "Name",
                controller: _nameController,
                hintText: "Enter Name",
                validator: (v) =>
                v == null || v.isEmpty ? "Enter name" : null,
              ),
              const SizedBox(height: 10),
              labeledTanRow(
                label: "Phone",
                controller: _phoneController,
                inputType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                hintText: "Enter Phone Number",
                validator: (v) {
                  if (v == null || v.isEmpty) return "Enter phone number";
                  if (v.length != 10) return "Phone number must be 10 digits";
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: royal,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isLoading ? null : _submitFacilitator,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_editingFacilitatorId == null
                          ? "Add Facilitator"
                          : "Update Facilitator"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showForm = false;
                        _editingFacilitatorId = null;
                        _facilityController.clear();
                        _nameController.clear();
                        _phoneController.clear();
                      });
                    },
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

  Widget _buildFacilitatorCard(Map<String, dynamic> facilitator) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: royal, width: 1),
        boxShadow: [
          BoxShadow(
            color: royal.withValues(alpha:0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    facilitator["facility"]?.toUpperCase() ?? "-",
                    style: TextStyle(color: royal, fontSize: 14,fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    facilitator["name"] ?? "-",
                    style: TextStyle(
                      color: royal,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    facilitator["phone"] ?? "-",
                    style: TextStyle(color: royal, fontSize: 14),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: royal),
                  onPressed: () => _editFacilitator(facilitator),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: royal),
                  onPressed: () =>
                      _showDeleteDialog(facilitator["id"], facilitator["facility"], facilitator["name"]),
                ),
              ],
            ),
          ],
        ),
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
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    void Function(String)? onChanged,
    Widget? child,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: screenWidth * 0.25,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                color: royal,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              child: child ??
                  TextFormField(
                    controller: controller,
                    keyboardType: inputType,
                    obscureText: obscureText,
                    validator: validator,
                    inputFormatters: inputFormatters,
                    maxLength: maxLength,
                    onChanged: onChanged,
                    style: TextStyle(color: royal),
                    cursorColor: royal,
                    decoration: InputDecoration(
                      counterText: "",
                      isDense: true,
                      hintText: hintText,
                      hintStyle: TextStyle(color: royal.withValues(alpha: 0.6)),
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: royal, width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: royal, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide:
                        const BorderSide(color: Colors.redAccent, width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide:
                        const BorderSide(color: Colors.redAccent, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: royalLight.withValues(alpha: 0.05),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchHallDetails(int lodgeId) async {
    try {
      final url = Uri.parse('$baseUrl/lodges/$lodgeId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        hallDetails = jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Error fetching lodge details: $e");
    } finally {
      setState(() {});
    }
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
                hall['name']?.toString().toUpperCase() ?? "LODGE NAME",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Add Facilitator",
            style: TextStyle(color: Colors.white)),
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
      body: _isFetching
          ? Center(child: CircularProgressIndicator(color: royal))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (hallDetails != null) _buildHallCard(hallDetails!),
            const SizedBox(height: 16),
            if (!_showForm)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: royal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => setState(() => _showForm = true),
                child: const Text("Add Facilitator"),
              ),
            if (_showForm) _buildFacilitatorForm(),
            const SizedBox(height: 16),
            ..._facilitators.map(_buildFacilitatorCard),
          ],
        ),
      ),
    );
  }
}
