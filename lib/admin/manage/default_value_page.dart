import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';
import '../../public/main_navigation.dart';

const Color royalblue = Color(0xFF376EA1);
const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class DefaultValuesPage extends StatefulWidget {
  const DefaultValuesPage({super.key});

  @override
  State<DefaultValuesPage> createState() => _DefaultValuesPageState();
}

class _DefaultValuesPageState extends State<DefaultValuesPage> {
  final _formKey = GlobalKey<FormState>();

  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();
  final _customReasonController = TextEditingController();

  bool _isLoading = false;
  bool isLoadingDefaults = true;
  bool _showForm = false;
  int? _editingDefaultId;

  String? _selectedReason;
  bool _showCustomReasonField = false;
  String? _selectedType;
  List<Map<String, dynamic>> _defaultValues = [];
  Map<String, dynamic>? lodgeDetails;
  List<Map<String, dynamic>> rentEntries = [];
  List<Map<String, dynamic>> roomOptions = [];
  bool _showRoomDropdown = false;
  Map<String, dynamic>? _selectedRoom;

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
      await _fetchLodge(lodgeId);
      await _fetchDefaultValues();
      await _fetchRooms(lodgeId);
    }
  }

  Future<void> _fetchRooms(int lodgeId) async {
    try {
      final url = Uri.parse('$baseUrl/rooms/lodge/$lodgeId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          roomOptions = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      _showMessage("❌ Error fetching rooms: $e");
    }
  }

  Future<void> _fetchDefaultValues() async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    if (lodgeId == null) return;

    try {
      final url = Uri.parse("$baseUrl/default-values/lodge/$lodgeId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _defaultValues = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      _showMessage("❌ Error fetching default amount: $e");
    } finally {
      setState(() => isLoadingDefaults = false);
    }
  }

  Future<void> _submitDefaultValue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    final userId = prefs.getString("userId");

    if (lodgeId == null || userId == null) {
      _showMessage("❌ Lodge ID or User ID not found in session");
      setState(() => _isLoading = false);
      return;
    }

    try {
      if (_showCustomReasonField) {
        String custom = _customReasonController.text.trim();
        if (custom.isNotEmpty) {
          _reasonController.text = custom[0].toUpperCase() + custom.substring(1);
        }
      }

      final body = {
        "user_id": userId,
        "lodge_id": lodgeId,
        "type": _selectedType,
        "reason": _reasonController.text.trim(),
        "amount": double.parse(_amountController.text.trim()),
      };

      http.Response response;
      if (_editingDefaultId == null) {
        final url = Uri.parse("$baseUrl/default-values");
        response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
      } else {
        final url = Uri.parse("$baseUrl/default-values/$_editingDefaultId/$lodgeId");
        response = await http.patch(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        _showMessage(_editingDefaultId == null
            ? "✅ Default value added successfully"
            : "✅ Default value updated successfully");

        setState(() {
          if (_editingDefaultId == null) {
            _defaultValues.insert(0, result);
          } else {
            int index = _defaultValues.indexWhere((d) => d["id"] == result["id"]);
            if (index != -1) _defaultValues[index] = result;
          }
          _fetchDefaultValues();
          _resetForm();

        });
      } else {
        _showMessage("❌ Failed to save: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error submitting default value: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDefault(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    if (lodgeId == null) return;

    try {
      final url = Uri.parse("$baseUrl/default-values/$id/$lodgeId");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() => _defaultValues.removeWhere((d) => d["id"] == id));
        _showMessage("✅ Default value deleted successfully");
      } else {
        _showMessage("❌ Failed to delete: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error deleting default value: $e");
    }
  }

  void _showDeleteDialog(int defaultId, String reason) {
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
        title: Text("Delete Default Amount", style: TextStyle(color: royal)),
        content: Text(
          "Do you want to delete the default amount for \"$reason\"?",
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
              _deleteDefault(defaultId);
            },
            child: Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editDefault(Map<String, dynamic> d) {
    setState(() {
      _editingDefaultId = d["id"];
      _amountController.text = d["amount"]?.toString() ?? "";

      _selectedType = d["type"];

      if (d["reason"] != null && d["reason"]!.startsWith("Rent")) {
        _selectedReason = "Rent";
        _showCustomReasonField = false;
        _showRoomDropdown = true;

        _selectedRoom = roomOptions.isNotEmpty
            ? roomOptions.firstWhere(
              (room) =>
          d["reason"]!.contains(room['room_name'] ?? '') &&
              d["reason"]!.contains(room['room_type'] ?? ''),
          orElse: () => roomOptions.first,
        ) : {};

        final roomName = _selectedRoom?['room_name'] ?? 'null';
        final roomType = _selectedRoom?['room_type'] ?? 'null';
        _reasonController.text = "Rent ($roomName ($roomType))";

      } else if (d["reason"] == "Cancel") {
        _selectedReason = "Cancel";
        _showCustomReasonField = false;
        _showRoomDropdown = false;
        _reasonController.text = "Cancel";
        _selectedRoom = null;

      } else {
        _selectedReason = "Other";
        _showCustomReasonField = true;
        _showRoomDropdown = false;
        _customReasonController.text = d["reason"] ?? "";
        _reasonController.text = d["reason"] ?? "";
        _selectedRoom = null;
      }

      _showForm = true;
    });
  }

  void _resetForm() {
    setState(() {
      _showForm = false;
      _editingDefaultId = null;
      _reasonController.clear();
      _customReasonController.clear();
      _amountController.clear();
      _selectedReason = null;
      _selectedType = null;
      _showCustomReasonField = false;
      _showRoomDropdown = false;
      _selectedRoom = null;
    });
  }

  Widget _buildDefaultForm() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: royal, width: 1),
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
                label: "TYPE",
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  dropdownColor: Colors.white,
                  style: TextStyle(color: royal),
                  iconEnabledColor: royal,
                  hint: Text(
                    "Select Type",
                    style: TextStyle(color: royal),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: "Default",
                      child: Text("Default", style: TextStyle(color: royal)),
                    ),
                    DropdownMenuItem(
                      value: "Peak Hours",
                      child: Text("Peak Hours", style: TextStyle(color: royal)),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value;
                    });
                  },
                  validator: (value) =>
                  value == null ? "Select type" : null,
                  decoration:  InputDecoration(
                      border: InputBorder.none, isDense: true,
                    filled: true,
                    fillColor: royalLight.withValues(alpha: 0.13),
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
                  ),
                ),
              ),

              const SizedBox(height: 10),

              labeledTanRow(
                label: "REASON",
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedReason,
                  dropdownColor: Colors.white,
                  style: TextStyle(color: royal),
                  iconEnabledColor: royal,
                  hint: Text("Select Reason", style: TextStyle(color: royal)),
                  items: [
                    "Rent",
                    "Cancel",
                    "Other",
                    if (_selectedType == "Default") "GST",
                  ].map((reason) => DropdownMenuItem(
                    value: reason,
                    child: Text(reason, style: TextStyle(color: royal)),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                      _showCustomReasonField = value == "Other";
                      _showRoomDropdown = value == "Rent";

                      if (_showRoomDropdown) {
                        _selectedRoom = roomOptions.isNotEmpty ? roomOptions.first : null;
                        if (_selectedRoom != null) {
                          _reasonController.text = "Rent (${_selectedRoom!['room_name']} (${_selectedRoom!['room_type']}))";
                        }
                      } else if (!_showCustomReasonField) {
                        _reasonController.text = value!;
                      }
                    });
                  },
                  validator: (value) =>
                  _showCustomReasonField ? null : value == null ? "Select reason" : null,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    filled: true,
                    fillColor: royalLight.withValues(alpha: 0.13),
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
                  ),
                ),
              ),

              if (_showRoomDropdown && roomOptions.isNotEmpty)
              labeledTanRow(
                label: "ROOM",
                child: DropdownButtonFormField<Map<String, dynamic>>(
                  isExpanded: true,
                  initialValue: _selectedRoom,
                  dropdownColor: Colors.white,
                  style: TextStyle(color: royal),
                  iconEnabledColor: royal,
                  hint: Text("Select Room", style: TextStyle(color: royal)),
                  items: roomOptions.map((room) {
                    final roomName = room['room_name'] ?? 'null';
                    final roomType = room['room_type'] ?? 'null';
                    return DropdownMenuItem(
                      value: room,
                      child: Text(
                        "$roomName ($roomType)",
                        style: TextStyle(color: royal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (room) {
                    setState(() {
                      _selectedRoom = room;
                      if (room != null) {
                        final roomName = room['room_name'] ?? 'null';
                        final roomType = room['room_type'] ?? 'null';
                        _reasonController.text = "Rent ($roomName ($roomType))";
                      }
                    });
                  },
                  validator: (value) => value == null ? "Select room" : null,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    filled: true,
                    fillColor: royalLight.withAlpha(33),
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
                  ),
                ),
              ),

              if (_showCustomReasonField)
                labeledTanRow(
                  label: "",
                  child: TextFormField(
                    controller: _customReasonController,
                    cursorColor: royal,
                    style: TextStyle(color: royal),
                    validator: (value) =>
                    value == null || value.isEmpty ? "Enter custom reason" : null,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Enter Custom Reason",
                      hintStyle: TextStyle(color: royal, fontSize: 15),
                      isDense: true,
                      filled: true,
                      fillColor: royalLight.withValues(alpha: 0.13),
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
                    ),
                  ),
                ),

              labeledTanRow(
                label: (_selectedReason == "GST" || _selectedReason == "Cancel")
                    ? "PERCENTAGE (%)"
                    : "AMOUNT",
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  cursorColor: royal,
                  style: TextStyle(color: royal),
                  validator: (value) {
                    if (value == null || value.isEmpty) return "Enter amount";
                    final doubleAmount = double.tryParse(value);
                    if (doubleAmount == null) return "Enter valid number";

                    if (_selectedReason == "GST" || _selectedReason == "Cancel") {
                      if (doubleAmount > 100) return "Amount cannot exceed 100 for GST/Cancel";
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Enter Default Amount",
                    hintStyle: TextStyle(color: royal, fontSize: 15),
                    isDense: true,
                    filled: true,
                    fillColor: royalLight.withValues(alpha: 0.13),
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
                  ),
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
                      onPressed: _isLoading ? null : _submitDefaultValue,
                      child: _isLoading
                          ? CircularProgressIndicator(color: royal)
                          : Text(
                        _editingDefaultId == null
                            ? "Submit"
                            : "Submit",
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      _resetForm();
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
              child: child ?? Text(
                value ?? "—",
                style: TextStyle(color: royal),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _fetchLodge(int lodgeId) async {
    try {
      final url = Uri.parse('$baseUrl/lodges/$lodgeId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        lodgeDetails = jsonDecode(response.body);
      }
    } catch (e) {
      _showMessage("Error fetching hall details: $e");
    } finally {
      setState(() {});
    }
  }

  Widget _buildDefaultCard(Map<String, dynamic> d) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: royal,
          width: 1.5,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.note_alt, color: royal, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d["type"] ?? "-",
                    style: TextStyle(color: royal, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    d["reason"] ?? "-",
                    style: TextStyle(color: royal, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    d["reason"] == "Cancel" || d["reason"] == "GST"
                        ? "Percentage: ${d["amount"] ?? "-"}%"
                        : "Amount: ${d["amount"] ?? "-"}",
                    style: TextStyle(color: royal),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: royal),
                  onPressed: () => _editDefault(d),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: royal),
                  onPressed: () => _showDeleteDialog(d["id"], d["reason"] ?? "-"),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Default Amount", style: TextStyle(color: Colors.white)),
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
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: royal))
            : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            if (lodgeDetails != null) _buildHallCard(lodgeDetails!),
            const SizedBox(height: 16),
            if (!_showForm)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: royal, foregroundColor: Colors.white),
                onPressed: () => setState(() => _showForm = true),
                child: const Text("Add Default Amount"),
              ),
            if (_showForm) _buildDefaultForm(),
            const SizedBox(height: 16),
            ..._defaultValues.map(_buildDefaultCard),
            if(_defaultValues.isEmpty &&  !_showForm)
              Center(
                child: Text(
                  "No default amount found.",
                  style: TextStyle(
                      color: royal, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
