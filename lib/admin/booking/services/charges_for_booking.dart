import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../public/config.dart';
import '../../../public/main_navigation.dart';

const Color royalblue = Color(0xFF376EA1);
const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class AddChargesPage extends StatefulWidget {
  const AddChargesPage({super.key});

  @override
  State<AddChargesPage> createState() => _AddChargesPageState();
}

class _AddChargesPageState extends State<AddChargesPage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();
  final _bookingIdController = TextEditingController();
  final _searchController = TextEditingController();
  String? _searchBookingId;
  bool _bookingExists = false;
  String _bookingCheckMessage = "";


  bool _isLoading = false;
  bool _isFetching = true;
  bool _showForm = false;
  int? _editingChargeId;

  List<Map<String, dynamic>> _charges = [];
  Map<String, dynamic>? hallDetails;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    if (lodgeId != null) {
      await _fetchHallDetails();
      await _fetchCharges();
    }
  }

  Future<void> _checkBookingStatus(String bookingId) async {
    if (bookingId.isEmpty) {
      setState(() {
        _bookingExists = false;
        _bookingCheckMessage = "";
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lodgeId = prefs.getInt("lodgeId"); // Lodges are required in backend
      if (lodgeId == null) return;

      final res = await http.get(Uri.parse(
          '$baseUrl/charges/check?booking_id=$bookingId&lodge_id=$lodgeId'));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        final exists = data['exists'] ?? false;
        final isBooked = data['isBooked'] ?? false;

        setState(() {
          _bookingExists = exists && isBooked;

          _bookingCheckMessage = !exists
              ? "❌ Booking ID not found"
              : !isBooked
              ? "⚠️ Booking is invalid"
              : "✅ Booking is valid";
        });
      }
    } catch (e) {
      setState(() {
        _bookingExists = false;
        _bookingCheckMessage = "❌ Network error while checking Booking ID";
      });
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

  Future<void> _fetchCharges() async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    if (lodgeId == null) return;

    try {
      final url = Uri.parse("$baseUrl/charges/lodge/$lodgeId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _charges = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      _showMessage("❌ Error fetching charges: $e");
    } finally {
      setState(() => _isFetching = false);
    }
  }

  Future<void> _submitCharge() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    final userId = prefs.getString("userId");
    if (lodgeId == null || userId == null) {
      _showMessage("❌ Lodge ID or User ID not found");
      setState(() => _isLoading = false);
      return;
    }

    final body = {
      "lodge_id": lodgeId,
      "user_id": userId,
      "booking_id": int.tryParse(_bookingIdController.text.trim()) ?? 0,
      "reason": _reasonController.text.trim(),
      "amount": double.parse(_amountController.text.trim()),
    };

    try {
      http.Response response;
      if (_editingChargeId == null) {
        response = await http.post(
          Uri.parse("$baseUrl/charges"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
      } else {
        response = await http.patch(
          Uri.parse("$baseUrl/charges/$_editingChargeId"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage(_editingChargeId == null
            ? "✅ Charge added successfully"
            : "✅ Charge updated successfully");

        _formKey.currentState!.reset();
        _bookingIdController.clear();
        _reasonController.clear();
        _amountController.clear();

        setState(() {
          _editingChargeId = null;
          _showForm = false;
        });

        _fetchCharges();
      } else {
        _showMessage("❌ Failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Error submitting charge: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCharge(int chargeId) async {
    try {
      final url = Uri.parse("$baseUrl/charges/$chargeId");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() => _charges.removeWhere((e) => e["id"] == chargeId));
        _showMessage("✅ Charge deleted successfully");
      } else {
        _showMessage("❌ Failed to delete: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Error deleting charge: $e");
    }
  }

  void _showDeleteDialog(int chargeId, int bookingId, String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("Delete Charge", style: TextStyle(color: royal)),
        content: Text(
          "Do you want to delete the charge for Booking ID \"$bookingId\" with reason \"$reason\"?",
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
              _deleteCharge(chargeId);
            },
            child: Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editCharge(Map<String, dynamic> charge) {
    setState(() {
      _editingChargeId = charge["id"];
      _bookingIdController.text = charge["booking_id"]?.toString() ?? "";
      _reasonController.text = charge["reason"] ?? "";
      _amountController.text = charge["amount"]?.toString() ?? "";
      _showForm = true;
    });
  }

  Widget _buildChargeForm() {
    final isEditing = _editingChargeId != null;

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
                label: "Booking ID",
                child: TextFormField(
                  controller: _bookingIdController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: royal,
                  ),
                  cursorColor: royal,
                  readOnly: _editingChargeId != null, // ✅ Read-only for edits
                  decoration: InputDecoration(
                    hintText: "Enter Booking ID",
                    hintStyle: TextStyle(color: royal),
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
                    fillColor: royalLight.withValues(alpha: 0.05),
                    filled: true,
                    helperText: _bookingCheckMessage,
                    helperStyle: TextStyle(
                      color: _bookingExists ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? "Enter booking ID" : null,
                  onChanged: (value) {
                    _checkBookingStatus(value.trim());
                  },
                ),
              ),
              const SizedBox(height: 16),
              labeledTanRow(
                label: "Reason",
                child: TextFormField(
                  controller: _reasonController,
                  style: TextStyle(color: royal),
                  textCapitalization: TextCapitalization.sentences, // ✅ Capitalizes first letter
                  cursorColor: royal,
                  decoration: InputDecoration(hintText: "Enter Reason",
                    hintStyle: TextStyle(color: royal),
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
                    fillColor: royalLight.withValues(alpha: 0.05),
                    filled: true,
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
                  decoration: InputDecoration(hintText: "Enter Amount",
                    hintStyle: TextStyle(color: royal),
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
                      onPressed: !_bookingExists ? null : _submitCharge,
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(isEditing ? "Update Charge" : "Add Charge"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showForm = false;
                        _editingChargeId = null;
                        _bookingIdController.clear();
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

  Widget _buildChargesList() {
    // Filter charges if search applied
    final filteredCharges = _searchBookingId != null
        ? _charges.where((c) => c["booking_id"].toString() == _searchBookingId).toList()
        : _charges;

    // Group by booking_id
    final Map<int, List<Map<String, dynamic>>> groupedCharges = {};
    for (var charge in filteredCharges) {
      final bookingId = charge["booking_id"] as int;
      groupedCharges.putIfAbsent(bookingId, () => []);
      groupedCharges[bookingId]!.add(charge);
    }

    return Column(
      children: groupedCharges.entries.map((entry) {
        final bookingId = entry.key;
        final charges = entry.value;

        return Stack(
          clipBehavior: Clip.none, // Allow badge to overflow
          children: [
            // The main card
            Card(
              elevation: 0,
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: royal, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: charges.map(_buildChargeCard).toList(),
                ),
              ),
            ),
            // Booking ID badge centered
            Positioned(
              top: 2, // Slightly above the card
              left: 1,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: royal,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: royal, width: 1),
                  ),
                  child: Text(
                    "Booking ID: $bookingId",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildChargeCard(Map<String, dynamic> charge) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: royal, width: 0.5),
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
                    charge["reason"]?.toUpperCase() ?? "-",
                    style: TextStyle(
                      color: royal,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "₹${charge["amount"] ?? "-"}",
                    style: TextStyle(
                      color: royal,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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
                  onPressed: () => _editCharge(charge),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: royal),
                  onPressed: () =>
                      _showDeleteDialog(charge["id"],charge["booking_id"] ?? 0, charge["reason"] ?? "-",),
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
          Expanded(child: child ?? const SizedBox()),
        ],
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
            color: royal.withValues(alpha: 0.15),
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

  Future<void> _fetchHallDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lodgeId = prefs.getInt("lodgeId");

      final url = Uri.parse('$baseUrl/lodges/$lodgeId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        hallDetails = jsonDecode(response.body);
      }
    } catch (e) {
      _showMessage("Error fetching hall details: $e");
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
        title: const Text("Add Charges", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => MainNavigation(initialIndex: 0)),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                controller: _searchController,
                keyboardType: TextInputType.number,
                cursorColor: royal,
                style: TextStyle(color: royal),
                decoration: InputDecoration(
                  hintText: "Search by Booking ID",
                  hintStyle: TextStyle(color: royal),
                  prefixIcon: Icon(Icons.search, color: royal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: royal),
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
                onChanged: (value) {
                  setState(() {
                    _searchBookingId = value.isEmpty ? null : value;
                  });
                },
              ),
            ),

            if (!_showForm)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: royal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => setState(() => _showForm = true),
                child: const Text("Add Charge"),
              ),
            if (_showForm) _buildChargeForm(),
            const SizedBox(height: 16),
            ...[
              _buildChargesList(),
            ],
          ],
        ),
      ),
    );
  }
}
