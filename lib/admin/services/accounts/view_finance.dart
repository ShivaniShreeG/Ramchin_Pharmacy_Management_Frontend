import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../public/config.dart';
import '../../../public/main_navigation.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class ViewFinancePage extends StatefulWidget {
  const ViewFinancePage({super.key});

  @override
  State<ViewFinancePage> createState() => _ViewFinancePageState();
}

class _ViewFinancePageState extends State<ViewFinancePage> {
  bool _isFetching = true;

  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> billings = [];
  List<Map<String, dynamic>> _filteredData = [];
  Map<String, dynamic>? shopDetails;
  List<Map<String, dynamic>> bookings = [];
  List<Map<String, dynamic>> _incomes = [];
  List<Map<String, dynamic>> _drawing = [];
  Map<String, double> _calculateTotals() {
    double totalIncome = 0;
    double totalExpense = 0;
    double totalDrawingIn = 0;
    double totalDrawingOut = 0;

    for (var item in _filteredData) {
      final amount = double.tryParse(item["amount"].toString()) ?? 0;
      switch (item["type"]) {
        case "Income":
          totalIncome += amount;
          break;
        case "Expense":
          totalExpense += amount;
          break;
        case "Drawing In":
          totalDrawingIn += amount;
          break;
        case "Drawing Out":
          totalDrawingOut += amount;
          break;
      }
    }

    return {
      "income": totalIncome,
      "expense": totalExpense,
      "drawingIn": totalDrawingIn,
      "drawingOut": totalDrawingOut,
    };
  }


  DateTime _selectedMonth = DateTime.now();
  String _selectedFilter = "All";
  

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
      await Future.wait([
        _fetchExpenses(shopId),
        _fetchIncomes(shopId),
        _fetchDrawing(shopId)
      ]);
      _filterCombinedData();
    }
  }
  Future<void> _fetchDrawing(int shopId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/finance/drawing/$shopId"));
      if (response.statusCode == 200) {
        _drawing = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      _showMessage("❌ Error fetching drawing: $e");
    }
  }

  Future<void> _fetchIncomes(int shopId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/finance/income/$shopId"));
      if (response.statusCode == 200) {
        _incomes = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      _showMessage("❌ Error fetching incomes: $e");
    }
  }

  Future<void> _fetchExpenses(int shopId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/finance/expense/$shopId"));
      if (response.statusCode == 200) {
        _expenses = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      _showMessage("❌ Error fetching expenses: $e");
    }
  }


  void _filterCombinedData() {
    List<Map<String, dynamic>> combined = [];

    if (_selectedFilter == "All" || _selectedFilter == "Income") {
      combined.addAll(_incomes.where((inc) {
        final date = DateTime.tryParse(inc["created_at"] ?? "");
        return date != null &&
            date.month == _selectedMonth.month &&
            date.year == _selectedMonth.year;
      }).map((inc) => {
        "type": "Income",
        "title": inc["reason"] ?? "Income",
        "amount": inc["amount"] ?? 0,
        "date": inc["created_at"],
      }));

      combined.addAll(billings.where((b) {
        final date = DateTime.tryParse(b["updated_at"] ?? "");
        return date != null &&
            date.month == _selectedMonth.month &&
            date.year == _selectedMonth.year;
      }).map((b) => {
        "type": "Income",
        "title": "Billing for Booking ID: ${b["booking_id"] ?? "-"}",
        "amount": b["total"] ?? 0,
        "date": b["updated_at"],
      }));

      combined.addAll(bookings.where((bk) {
        final date = DateTime.tryParse(bk["created_at"] ?? "");
        return date != null &&
            date.month == _selectedMonth.month &&
            date.year == _selectedMonth.year &&
            (double.tryParse(bk["advance"].toString()) ?? 0) > 0;
      }).map((bk) => {
        "type": "Income",
        "title": "Advance for Booking ID: ${bk["booking_id"] ?? "-"}",
        "amount": bk["advance"] ?? 0,
        "date": bk["created_at"],
      }));
    }

    if (_selectedFilter == "All" || _selectedFilter == "Expense") {
      combined.addAll(_expenses.where((e) {
        final date = DateTime.tryParse(e["created_at"] ?? "");
        return date != null &&
            date.month == _selectedMonth.month &&
            date.year == _selectedMonth.year;
      }).map((e) => {
        "type": "Expense",
        "title": e["reason"] ?? "-",
        "amount": e["amount"] ?? 0,
        "date": e["created_at"],
      }));
    }

    if (_selectedFilter == "All" || _selectedFilter == "Drawing In") {
      combined.addAll(_drawing.where((d) {
        final date = DateTime.tryParse(d["created_at"] ?? "");
        return date != null &&
            date.month == _selectedMonth.month &&
            date.year == _selectedMonth.year &&
            (d["type"].toString().toLowerCase() == "drawin");
      }).map((d) => {
        "type": "Drawing In",
        "title": d["reason"] ?? "Drawing In",
        "amount": d["amount"] ?? 0,
        "date": d["created_at"],
      }));
    }

    if (_selectedFilter == "All" || _selectedFilter == "Drawing Out") {
      combined.addAll(_drawing.where((d) {
        final date = DateTime.tryParse(d["created_at"] ?? "");
        return date != null &&
            date.month == _selectedMonth.month &&
            date.year == _selectedMonth.year &&
            (d["type"].toString().toLowerCase() == "drawout");
      }).map((d) => {
        "type": "Drawing Out",
        "title": d["reason"] ?? "Drawing Out",
        "amount": d["amount"] ?? 0,
        "date": d["created_at"],
      }));
    }

    combined.sort((a, b) {
      DateTime da = DateTime.tryParse(a["date"] ?? "") ?? DateTime.now();
      DateTime db = DateTime.tryParse(b["date"] ?? "") ?? DateTime.now();
      return db.compareTo(da);
    });

    setState(() {
      _filteredData = combined;
      _isFetching = false;
    });
  }

  Future<void> _pickMonthYear() async {
    int selectedYear = _selectedMonth.year;
    int selectedMonth = _selectedMonth.month;

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Select Month and Year",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: royal)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _monthDropdown(selectedMonth, (val) => selectedMonth = val)),
                  ],
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(child: _yearDropdown(selectedYear, (val) => selectedYear = val)),
                  ],
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: royal))),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: royal, foregroundColor: Colors.white),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(selectedYear, selectedMonth);
                          _filterCombinedData();
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _monthDropdown(int value, Function(int) onChanged) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: "Month",
        labelStyle: TextStyle(color: royal),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dropdownColor: Colors.white,
      items: List.generate(12, (index) {
        final m = index + 1;
        return DropdownMenuItem(value: m, child: Text(DateFormat.MMMM().format(DateTime(0, m))));
      }),
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }

  Widget _yearDropdown(int value, Function(int) onChanged) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: "Year",
        labelStyle: TextStyle(color: royal),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dropdownColor: Colors.white,
      items: List.generate(30, (index) {
        final y = DateTime.now().year - 10 + index;
        return DropdownMenuItem(value: y, child: Text(y.toString()));
      }),
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
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

  Widget _buildFinanceCard(Map<String, dynamic> item) {
    late Color amountColor;
    late IconData iconData;

    switch (item["type"]) {
      case "Income":
        amountColor = Colors.green.shade700;
        iconData = Icons.arrow_downward;
        break;
      case "Expense":
        amountColor = Colors.red.shade700;
        iconData = Icons.arrow_upward;
        break;
      case "Drawing In":
        amountColor = Colors.teal.shade700;
        iconData = Icons.south_west;
        break;
      case "Drawing Out":
        amountColor = Colors.orange;
        iconData = Icons.north_east;
        break;
      default:
        amountColor = Colors.grey.shade700;
        iconData = Icons.info_outline;
    }

    return Card(
      color: Colors.white,
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(iconData, color: amountColor),
        title: Text(
          item["title"],
          style: TextStyle(
            color: royal,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          item["date"] != null
              ? DateFormat('dd/MM/yyyy').format(DateTime.parse(item["date"]))
              : "",
          style: TextStyle(
            color: royal,
            fontSize: 13,
          ),
        ),
        trailing: Text(
          "₹${item["amount"]}",
          style: TextStyle(
            color: amountColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totals = _calculateTotals();

    final income = totals["income"] ?? 0.0;
    final expense = totals["expense"] ?? 0.0;
    final drawingIn = totals["drawingIn"] ?? 0.0;
    final drawingOut = totals["drawingOut"] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Income",
                    style: TextStyle(
                      color: royal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹${income.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Expense",
                    style: TextStyle(
                      color: royal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹${expense.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Drawing In",
                    style: TextStyle(
                      color: royal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹${drawingIn.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Drawing Out",
                    style: TextStyle(
                      color: royal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹${drawingOut.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
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

  Widget _buildFilterChips() {
    final row1Filters = ["All", "Income", "Expense"];
    final row2Filters = ["Drawing In", "Drawing Out"];

    Widget buildRow(List<String> filters) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = filter;
                  _filterCombinedData();
                });
              },
              selectedColor: royal,
              checkmarkColor: Colors.white,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : royal,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      children: [
        buildRow(row1Filters),
        buildRow(row2Filters),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Finance Overview", style: TextStyle(color: Colors.white)),
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
          : RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (shopDetails != null) _buildShopCard(shopDetails!),
            const SizedBox(height: 16),
            _buildMonthPickerButton(),
            const SizedBox(height: 10),
            _buildFilterChips(),
            const SizedBox(height: 12),
            _buildSummaryCard(),
            const SizedBox(height: 12),
            if (_filteredData.isEmpty)
              Center(
                child: Text(
                  "No records found for ${DateFormat('MMMM yyyy').format(_selectedMonth)}.",
                  style: TextStyle(color: royal, fontSize: 16),
                ),
              )
            else
              ..._filteredData.map(_buildFinanceCard),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthPickerButton() {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: royal,
          foregroundColor: Colors.white,
        ),
        onPressed: _pickMonthYear,
        child: Text(DateFormat('MMMM yyyy').format(_selectedMonth)),
      ),
    );
  }
}
