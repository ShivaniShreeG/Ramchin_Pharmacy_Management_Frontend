import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../public/config.dart';
import '../../../public/main_navigation.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();

  bool _isLoading = false;
  bool _isFetching = true;
  bool _showForm = false;
  int? _editingExpenseId;

  List<Map<String, dynamic>> _expenses = [];
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
      await _fetchExpenses();
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


  Future<void> _fetchExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId == null) return;

    try {
      final url = Uri.parse("$baseUrl/finance/expense/$shopId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _expenses = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching expenses: $e");
    } finally {
      setState(() => _isFetching = false);
    }
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    final userId = prefs.getString("userId");
    if (shopId == null||userId == null) {
      _showMessage("❌ Shop ID or User ID not found");
      setState(() => _isLoading = false);
      return;
    }

    final body = {
      "shop_id": shopId,
      "user_id":userId,
      "reason": _reasonController.text.trim(),
      "amount": double.parse(_amountController.text.trim())
    };

    try {
      http.Response response;
      if (_editingExpenseId == null) {
        response = await http.post(
          Uri.parse("$baseUrl/finance/expense"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
      } else {
        response = await http.patch(
          Uri.parse("$baseUrl/finance/$_editingExpenseId"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage(_editingExpenseId == null
            ? "✅ Expense added successfully"
            : "✅ Expense updated successfully");
        _fetchExpenses();

        _formKey.currentState!.reset();
        _reasonController.clear();
        _amountController.clear();

        setState(() {
          _editingExpenseId = null;
          _showForm = false;
        });

      } else {
        _showMessage("❌ Failed: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error submitting expense: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteExpense(int expenseId) async {
    try {
      final url = Uri.parse("$baseUrl/finance/$expenseId");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() => _expenses.removeWhere((e) => e["id"] == expenseId));
        _showMessage("✅ Expense deleted successfully");
      } else {
        _showMessage("❌ Failed to delete: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error deleting expense: $e");
    }
  }

  void _showDeleteDialog(int expenseId, String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("Delete Expense", style: TextStyle(color: royal)),
        content: Text("Do you want to delete the expense for \"$reason\"?",
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
              _deleteExpense(expenseId);
            },
            child: Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editExpense(Map<String, dynamic> expense) {
    setState(() {
      _editingExpenseId = expense["id"];
      _reasonController.text = expense["reason"] ?? "";
      _amountController.text = expense["amount"]?.toString() ?? "";
      _showForm = true;
    });
  }

  Widget _buildExpenseForm() {
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
                label: "Reason",
                controller: _reasonController,
                hintText: "Enter Reason",
                validator: (value) =>
                value == null || value.isEmpty ? "Enter reason" : null,
                inputType: TextInputType.text,
              ),
              const SizedBox(height: 16),
              labeledTanRow(
                label: "Amount",
                controller: _amountController,
                hintText: "Enter Amount",
                validator: (value) =>
                value == null || value.isEmpty ? "Enter amount" : null,
                inputType: TextInputType.number,
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
                      onPressed: _isLoading ? null : _submitExpense,
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                        _editingExpenseId == null
                            ? "Add Expense"
                            : "Update Expense",
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showForm = false;
                        _editingExpenseId = null;
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

  Widget _buildExpenseCard(Map<String, dynamic> expense) {
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
                    expense["reason"]?.toUpperCase() ?? "-",
                    style: TextStyle(
                      color: royal,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "₹${expense["amount"] ?? "-"}",
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
                  onPressed: () => _editExpense(expense),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: royal),
                  onPressed: () =>
                      _showDeleteDialog(expense["id"], expense["reason"] ?? "-"),
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
            width: screenWidth * 0.2,
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
            child: child ??
                TextFormField(
                  controller: controller,
                  keyboardType: inputType,
                  obscureText: obscureText,
                  validator: validator,
                  onChanged: onChanged,
                  style: TextStyle(color: royal),
                  cursorColor: royal,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(color: royal.withValues(alpha: 0.6)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: royalLight.withValues(alpha: 0.05),
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
        title: const Text("Add Expenses", style: TextStyle(color: Colors.white)),
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

            // ➕ Add Expense button
            if (!_showForm)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: royal,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => setState(() => _showForm = true),
                      child: const Text("Add Expense"),
                    ),
                  ),
                ),
              ),

            // 🧾 Expense form
            if (_showForm)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SizedBox(
                    width: double.infinity,
                    child: _buildExpenseForm(),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 💳 Expense cards (responsive)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;

                if (!isWide) {
                  // 📱 Mobile → 1 per row
                  return Column(
                    children: _expenses.map(_buildExpenseCard).toList(),
                  );
                }

                // 💻 Tablet/Web → 2 per row
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _expenses.map((expense) {
                    return SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: _buildExpenseCard(expense),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),

    );
  }
}
