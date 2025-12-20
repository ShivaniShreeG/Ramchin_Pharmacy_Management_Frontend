import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';
import '../../public/main_navigation.dart';

const Color royalblue = Color(0xFF376EA1);
const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class HallInstructionsPage extends StatefulWidget {
  const HallInstructionsPage({super.key});

  @override
  State<HallInstructionsPage> createState() => _HallInstructionsPageState();
}

class _HallInstructionsPageState extends State<HallInstructionsPage> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isLoadingInstructions = true;
  bool _showForm = false;

  List<Map<String, dynamic>> _instructions = [];
  List<TextEditingController> _controllers = [];
  Map<String, dynamic>? lodgeDetails;
  List<FocusNode> focusNodes = [];

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
      await _fetchHallDetails(lodgeId); // fetch hall info
      await _fetchInstructions();// fetch admins
    }
  }

  Future<void> _fetchInstructions() async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    if (lodgeId == null) return;

    try {
      final url = Uri.parse("$baseUrl/instructions/lodge/$lodgeId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _instructions = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      _showMessage("❌ Error fetching instructions: $e");
    } finally {
      setState(() => _isLoadingInstructions = false);
    }
  }

  Future<void> _submitInstructions() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    if (lodgeId == null) {
      _showMessage("❌ Lodge ID not found");
      setState(() => _isLoading = false);
      return;
    }

    try {
      final newInstructions = _controllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .map((t) => {"lodge_id": lodgeId, "instruction": t})
          .toList();

      if (newInstructions.isEmpty) {
        _showMessage("⚠️ Please add at least one instruction");
        setState(() => _isLoading = false);
        return;
      }

      final url = Uri.parse("$baseUrl/instructions/bulk");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(newInstructions),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _controllers.clear();
        _showForm = false;
        await _fetchInstructions();
        _showMessage("✅ Instructions added successfully");
      } else {
        _showMessage("❌ Failed: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error submitting instructions");
    } finally {
      setState(() => _isLoading = false);
    }
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

  Future<void> _deleteInstruction(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    if (lodgeId == null) return;

    try {
      final url = Uri.parse("$baseUrl/instructions/$id/lodge/$lodgeId");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        await _fetchInstructions();
        _showMessage("✅ Instruction deleted");
      } else {
        _showMessage("❌ Failed to delete: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error deleting instruction: $e");
    }
  }

  Future<void> _editInstruction(int id, String oldText) async {
    final controller = TextEditingController(text: oldText);

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
        title: Center(
          child: Text(
            "Edit Instruction",
            style: TextStyle(
              color: royal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 300),
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: "Instruction",
                labelStyle: TextStyle(color: royal),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: royal),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: royal),
                ),
              ),
              style: TextStyle(color: royal),
              cursorColor: royal,
              keyboardType: TextInputType.multiline,
              maxLines: null,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: royal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: royal),
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.isEmpty) return;

              Navigator.pop(context);

              final prefs = await SharedPreferences.getInstance();
              final lodgeId = prefs.getInt("lodgeId");
              if (lodgeId == null) return;

              try {
                final url = Uri.parse("$baseUrl/instructions/$id");
                final response = await http.patch(
                  url,
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({"instruction": newText, "lodge_id": lodgeId}),
                );

                if (response.statusCode == 200) {
                  await _fetchInstructions(); // refresh immediately
                 _showMessage("✅ Instruction updated");
                } else {
                 _showMessage("❌ Failed to update: ${response.body}");
                }
              } catch (e) {
                _showMessage("❌ Error updating instruction: $e");
              }
            },
            child: Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard(Map<String, dynamic> d) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: royal,
          width: 1.5,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: royalLight.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.rule, color: royal, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                d["instruction"] ?? "-",
                style: TextStyle(color: royal, fontWeight: FontWeight.bold),
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: royal),
                  onPressed: () => _editInstruction(d["id"], d["instruction"] ?? ""),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: Icon(Icons.delete, color: royal),
                  onPressed: () => _showDeleteDialog(d["id"], d["instruction"] ?? "-"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(int id, String instruction) {
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
        title: Text("Delete Instruction", style: TextStyle(color: royal)),
        content: Text(
          "Do you want to delete the instruction:\n\n\"$instruction\"?",
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
              _deleteInstruction(id);
            },
            child: Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionForm() {
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
              ..._controllers.map((controller) {
                int index = _controllers.indexOf(controller);
                if (focusNodes.length <= index) focusNodes.add(FocusNode());
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: labeledTanRow(
                    label: "Instruction ${index + 1}",
                    child: TextFormField(
                      controller: controller,
                      focusNode: focusNodes[index],
                      decoration:  InputDecoration(
                        border: InputBorder.none,
                        hintText: "Enter Instructions",
                        hintStyle: TextStyle(color: royal,fontSize: 15),
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
                      ),
                      cursorColor: royal,
                      style: TextStyle(color: royal),
                      validator: (value) => value == null || value.isEmpty ? "Enter instruction" : null,
                    ),
                  ),
                );
              }),

              const SizedBox(height: 10),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _controllers.add(TextEditingController());
                      focusNodes.add(FocusNode());
                    });

                    Future.delayed(const Duration(milliseconds: 100), () {
                      focusNodes.last.requestFocus();
                    });
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    "Add another instruction",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: royal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: royal,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isLoading ? null : _submitInstructions,
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : const Text("Save Instructions"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showForm = false;
                        _controllers.clear();
                        focusNodes.clear();
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
        title: const Text("Hall Instructions", style: TextStyle(color: Colors.white)),
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
      body: _isLoadingInstructions
          ? Center(child: CircularProgressIndicator(color: royal))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (lodgeDetails != null) _buildHallCard(lodgeDetails!),
            const SizedBox(height: 16),
            if (!_showForm)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: royal, foregroundColor: Colors.white),
                onPressed: () {
                  setState(() {
                    _showForm = true;
                    _controllers = [TextEditingController()];
                  });
                },
                child: const Text("Add Instructions"),
              ),
            if (_showForm) _buildInstructionForm(),
            const SizedBox(height: 16),
            if (_instructions.isNotEmpty)
              ..._instructions.map(_buildInstructionCard)
            else
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Text("No instructions found.",
                        style: TextStyle(color: royal, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
