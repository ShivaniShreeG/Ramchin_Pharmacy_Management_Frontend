import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../public/config.dart';
import '../../../public/main_navigation.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class AddDrawingPage extends StatefulWidget {
  const AddDrawingPage({super.key});

  @override
  State<AddDrawingPage> createState() => _AddDrawingPageState();
}

class _AddDrawingPageState extends State<AddDrawingPage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedType = "OUT";

  bool _isLoading = false;
  bool _isFetching = true;
  bool _showForm = false;
  int? _editingDrawingId;
  double currentBalance = 0.0;

  List<Map<String, dynamic>> _drawings = [];
  Map<String, dynamic>? shopDetails;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId != null) {
      await _fetchShopDetails();
      await _fetchDrawings();
      await fetchCurrentBalance(shopId);
    }
  }

  Future<void> fetchCurrentBalance(int shopId) async {
    try {
      final url = Uri.parse('$baseUrl/home/current-balance/$shopId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          currentBalance = (data['currentBalance'] ?? 0).toDouble();
        });
      } else {
        _showMessage("Failed to fetch current balance");
      }
    } catch (e) {
      _showMessage("Error fetching current balance: $e");
    }
  }

  Future<void> _fetchDrawings() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId == null) return;

    try {
      final url = Uri.parse("$baseUrl/finance/drawing/$shopId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _drawings = List<Map<String, dynamic>>.from(data.reversed);
        });
      }
    } catch (e) {
      _showMessage("❌ Error fetching drawings: $e");
    } finally {
      setState(() => _isFetching = false);
    }
  }

  Future<void> _submitDrawing() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    final userId = prefs.getString("userId");
    if (shopId == null || userId == null) {
      _showMessage("❌ Shop ID or User ID not found");
      setState(() => _isLoading = false);
      return;
    }

    final amount = double.parse(_amountController.text.trim());

    if (_selectedType == "OUT" && amount > currentBalance) {
      _showMessage("❌ OUT amount cannot exceed current balance (₹$currentBalance)");
      setState(() => _isLoading = false);
      return;
    }

    try {
      http.Response response;

      if (_editingDrawingId == null) {
        // ✅ CREATE (send type)
        final createBody = {
          "shop_id": shopId,
          "user_id": userId,
          "reason": _reasonController.text.trim(),
          "amount": amount,
          "type": _selectedType, // IN / OUT
        };

        response = await http.post(
          Uri.parse("$baseUrl/finance/drawing"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(createBody),
        );
      } else {
        // ✅ UPDATE (DO NOT send type/state)
        final updateBody = {
          "reason": _reasonController.text.trim(),
          "amount": amount,
        };

        response = await http.patch(
          Uri.parse("$baseUrl/finance/$_editingDrawingId"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(updateBody),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage(_editingDrawingId == null
            ? "✅ Drawing added successfully"
            : "✅ Drawing updated successfully");
        _formKey.currentState!.reset();
        _reasonController.clear();
        _amountController.clear();

        setState(() {
          _editingDrawingId = null;
          _showForm = false;
        });

        _fetchDrawings();
      } else {
        _showMessage("❌ Failed: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error submitting drawing: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: royal)),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: royal, width: 2),
        ),
      ),
    );
  }

  Future<void> _deleteDrawing(int drawingId) async {
    try {
      final url = Uri.parse("$baseUrl/finance/$drawingId");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() => _drawings.removeWhere((e) => e["id"] == drawingId));
        _showMessage("✅ Drawing deleted successfully");
      } else {
        _showMessage("❌ Failed to delete: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error deleting drawing: $e");
    }
  }

  void _showDeleteDialog(int drawingId, String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("Delete Drawing", style: TextStyle(color: royal)),
        content: Text(
          "Do you want to delete the drawing for \"$reason\"?",
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
              _deleteDrawing(drawingId);
            },
            child: Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editDrawing(Map<String, dynamic> drawing) {
    setState(() {
      _editingDrawingId = drawing["id"];
      _reasonController.text = drawing["reason"] ?? "";
      _amountController.text = drawing["amount"]?.toString() ?? "";
      _showForm = true;
    });
  }

  Widget _buildDrawingForm() {
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
                label: "Type",
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  dropdownColor: Colors.white,
                  decoration: InputDecoration(
                    isDense: true,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: royal, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: royal, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: _editingDrawingId != null
                        ? Colors.grey.withValues(alpha: 0.15) // disabled look
                        : royalLight.withValues(alpha: 0.05),
                  ),
                  style: TextStyle(
                    color: royal,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  iconEnabledColor: royal,
                  items: const [
                    DropdownMenuItem(value: "IN", child: Text("IN")),
                    DropdownMenuItem(value: "OUT", child: Text("OUT")),
                  ],

                  // ✅ Disable when editing
                  onChanged: _editingDrawingId != null
                      ? null
                      : (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                ),

              ),
              const SizedBox(height: 16),
              labeledTanRow(
                label: "Reason",
                child: TextFormField(
                  controller: _reasonController,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(color: royal),
                  cursorColor: royal,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: "Enter Reason",
                    hintStyle: TextStyle(color: royal, fontSize: 15),
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
                  validator: (value) =>
                  value == null || value.isEmpty ? "Enter reason" : null,
                ),
              ),
              const SizedBox(height: 16),
              labeledTanRow(
                label: "Amount",
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: royal),
                  cursorColor: royal,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: "Enter Amount",
                    hintStyle: TextStyle(color: royal, fontSize: 15),
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
                  validator: (value) =>
                  value == null || value.isEmpty ? "Enter amount" : null,
                ),
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
                      onPressed: _isLoading ? null : _submitDrawing,
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(_editingDrawingId == null
                          ? "Add Drawing"
                          : "Update Drawing"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showForm = false;
                        _editingDrawingId = null;
                        _reasonController.clear();
                        _amountController.clear();
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

  Widget _buildDrawingCard(Map<String, dynamic> drawing) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: royal, width: 0.5),
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
                    drawing["reason"]?.toUpperCase() ?? "-",
                    style: TextStyle(
                      color: royal,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "₹${drawing["amount"] ?? "-"}",
                    style: TextStyle(
                      color: royal,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: drawing["type"] == "DRAWIN"
                          ? Colors.green.withValues(alpha:0.15)
                          : Colors.red.withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: drawing["type"] == "DRAWIN"
                            ? Colors.green
                            : Colors.red,
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      drawing["type"] ?? "-",
                      style: TextStyle(
                        color: drawing["type"] == "DRAWIN"
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
      ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: royal),
                  onPressed: () => _editDrawing(drawing),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: royal),
                  onPressed: () => _showDeleteDialog(
                    drawing["id"],
                    drawing["reason"] ?? "-",
                  ),
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
    String? value,
    Widget? child,
    String? hint,
    double labelWidthFactor = 0.25,
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
              style: TextStyle(
                color: royal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: child ??
                  Text(
                    value ?? "—",
                    style: TextStyle(color: royal),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shop) {
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
            child: shop['logo'] != null
                ? Image.memory(
              base64Decode(shop['logo']),
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
                shop['name']?.toString().toUpperCase() ?? "SHOP NAME",
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

  Future<void> _fetchShopDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getInt("shopId");

      final url = Uri.parse('$baseUrl/shops/$shopId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        shopDetails = jsonDecode(response.body);
      }
    } catch (e) {
      _showMessage("Error fetching shop details: $e");
    } finally {
      setState(() {});
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text(
          "Add Drawing",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 0)),
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
            if (shopDetails != null) _buildShopCard(shopDetails!),
            const SizedBox(height: 16),
            if (!_showForm)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: royal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _showForm = true;
                    if (_reasonController.text.isEmpty) {
                      _reasonController.text = "Drawing";
                    }
                  });
                },
                child: const Text("Add Drawing"),
              ),
            if (_showForm) _buildDrawingForm(),
            const SizedBox(height: 16),
            ..._drawings.map(_buildDrawingCard),
          ],
        ),
      ),
    );
  }
}
