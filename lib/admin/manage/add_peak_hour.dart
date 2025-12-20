import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../public/config.dart';
import '../../public/main_navigation.dart';

const Color royalblue = Color(0xFF376EA1);
const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class PeakHoursPage extends StatefulWidget {
  const PeakHoursPage({super.key});

  @override
  State<PeakHoursPage> createState() => _PeakHoursPageState();
}

class _PeakHoursPageState extends State<PeakHoursPage> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showForm = false;
  List<Map<String, dynamic>> _peakHours = [];
  Map<String, dynamic>? lodgeDetails;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _customReasonController = TextEditingController();

  String? _selectedReason;
  bool _showCustomReasonField = false;


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
      await _fetchPeakHours();
    }
  }


  Future<void> _fetchPeakHours() async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    if (lodgeId == null) return;

    try {
      final url = Uri.parse("$baseUrl/peak-hours/$lodgeId");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _peakHours = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      _showMessage("❌ Error fetching peak hours: $e");
    } finally {
      setState(() => _isLoading = false);
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

  Future<void> _fetchHallDetails(int lodgeId) async {
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

  void _toggleForm({bool clearFields = false}) {
    setState(() {
      _showForm = !_showForm;
      if (clearFields) {
        _dateController.clear();
        _customReasonController.clear();
        _selectedReason = null;
        _showCustomReasonField = false;
      }
    });
  }

  Future<void> _createPeakHour() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    final userId = prefs.getString("userId");
    if (lodgeId == null || userId == null) return;

    setState(() => _isSubmitting = true);

    String reason = _selectedReason == "Other"
        ? _customReasonController.text.trim()
        : _selectedReason ?? "";

    if (reason.isNotEmpty) {
      reason = reason[0].toUpperCase() + reason.substring(1);
    }

    final body = {
      "lodge_id": lodgeId,
      "user_id": userId,
      "date": _dateController.text.trim(),
      "reason": reason,
    };

    try {
      final url = Uri.parse("$baseUrl/peak-hours");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final newPeak = jsonDecode(response.body);
        setState(() {
          _peakHours.add(newPeak);
          _toggleForm(clearFields: true);
        });
        _showMessage("✅ Peak hour created successfully");
      } else {
        final body = jsonDecode(response.body);
        final message = body['message'] ?? 'Something went wrong';
        _showMessage("❌ Failed: $message");
      }
    } catch (e) {
      _showMessage("❌ Error creating peak hour");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deletePeakHour(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    if (lodgeId == null) return;

    try {
      final url = Uri.parse("$baseUrl/peak-hours/lodge/$lodgeId/$id");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() {
          _peakHours.removeWhere((peak) => peak['id'] == id);
        });
        _showMessage("✅ Peak hour deleted successfully");
      } else {
        _showMessage("❌ Failed to delete peak hour: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error deleting peak hour");
    }
  }

  void _showDeleteDialog(Map<String, dynamic> peak) {
    String formattedDate = "";
    if (peak['date'] != null) {
      DateTime parsedDate = DateTime.parse(peak['date']);
      formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: royal, width: 1),
        ),
        title: Text("Delete Peak Hour", style: TextStyle(color: royal)),
        content: Text(
          "${peak['reason']}\nDate: $formattedDate",
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
              _deletePeakHour(peak['id']);
              Navigator.pop(context);
            },

            child: Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
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
                label: "DATE",
                child: GestureDetector(
                  onTap: () async {
                    DateTime firstDate = DateTime.now().add(const Duration(days: 1));
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: firstDate,
                      firstDate: firstDate,
                      lastDate: DateTime(2100),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: royal,
                              onPrimary: Colors.white,
                              onSurface: royal,
                              surface: Colors.white,
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(foregroundColor: royal),
                            ), dialogTheme: DialogThemeData(backgroundColor: Colors.white),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (pickedDate != null) {
                      _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                    }
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: _dateController,
                      validator: (value) => value == null || value.isEmpty ? "Select a date" : null,
                      style: TextStyle(color: royal),
                      decoration: InputDecoration(border: InputBorder.none, hintText: "Tap to select a date",
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: royal, width: 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: royal, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          hintStyle: TextStyle(color: royal,fontSize: 15),
                          filled:true,
                          fillColor:royalLight.withValues(alpha: 0.05),
                          isDense: true),
                    ),
                  ),
                ),
              ),

              labeledTanRow(
                label: "REASON",
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedReason,
                  dropdownColor: Colors.white,
                  style: TextStyle(color: royal),
                  hint: Text(
                    "Select a reason",
                    style: TextStyle(
                      color: royal,
                      fontSize: 15,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: "Vacation",
                      child: Text("Vacation", style: TextStyle(color: royal)),
                    ),
                    DropdownMenuItem(
                      value: "Other",
                      child: Text("Other", style: TextStyle(color: royal)),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                      _showCustomReasonField = value == "Other";
                    });
                  },
                  validator: (value) => value == null ? "Select a reason" : null,
                  decoration:  InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: royal, width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: royal, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                      filled:true,
                      fillColor:royalLight.withValues(alpha: 0.05)
                  ),
                ),
              ),

              if (_showCustomReasonField)
                labeledTanRow(
                  label: "",
                  child: TextFormField(
                    controller: _customReasonController,
                    style: TextStyle(color: royal),
                    validator: (value) => value == null || value.isEmpty ? "Enter custom reason" : null,
                    decoration: InputDecoration(border: InputBorder.none,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: royal, width: 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: royal, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: "Enter Reason",
                        hintStyle: TextStyle(color: royal,fontSize: 15),isDense: true,
                         filled:true,
                         fillColor:royalLight.withValues(alpha: 0.05)),
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
                      onPressed: _isSubmitting ? null : _createPeakHour,
                      child: _isSubmitting
                          ? CircularProgressIndicator(color: Colors.white)
                          : const Text("Add Peak Hour"),
                    ),
                  ),
                  const SizedBox(width: 40),
                  TextButton(
                    onPressed: () => _toggleForm(clearFields: true),
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

  Widget _buildPeakCard(Map<String, dynamic> peak) {
    String formattedDate = "";
    if (peak['date'] != null) {
      DateTime parsedDate = DateTime.parse(peak['date']);
      formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: royal, width: 1),
      ),
      child: ListTile(
        title: Text(
          peak['reason'] ?? "No reason",
          style: TextStyle(color: royal),
        ),
        subtitle: Text(
          "Date: $formattedDate",
          style: TextStyle(color: royal),
        ),
        leading: Icon(Icons.event, color: royal),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _showDeleteDialog(peak),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text(
          "Peak Hours",
          style: TextStyle(color: Colors.white),
        ),
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
                  backgroundColor: royal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _toggleForm(clearFields: true),
                child: const Text("Add Peak Hour"),
              ),
            if (_showForm) _buildForm(),
            const SizedBox(height: 16),
            if (_peakHours.isEmpty)
              Text(
                "No peak hours found.",
                style: TextStyle(color: royal, fontSize: 16),
              ),
            ..._peakHours.map(_buildPeakCard),
          ],
        ),
      ),
    );
  }
}
