import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/config.dart';
import '../../public/main_navigation.dart';

const Color royal = Color(0xFF875C3F);

class ReceivedOrdersHistoryPage extends StatefulWidget {
  const ReceivedOrdersHistoryPage({super.key});

  @override
  State<ReceivedOrdersHistoryPage> createState() => _ReceivedOrdersHistoryPageState();
}

class _ReceivedOrdersHistoryPageState extends State<ReceivedOrdersHistoryPage> {
  bool isLoading = true;
  int? shopId;
  Map<String, dynamic>? shopDetails;

  List<Map<String, dynamic>> history = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // ✅ Month/Year filters (null = no filter)
  DateTime? _orderedMonthYear;
  DateTime? _receivedMonthYear;

  static const List<String> _months = [
    "January","February","March","April","May","June",
    "July","August","September","October","November","December"
  ];

  @override
  void initState() {
    super.initState();
    _loadShopIdAndFetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchHallDetails() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/shops/$shopId'),
      );

      if (res.statusCode == 200) {
        shopDetails = jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint("Error fetching shop details: $e");
    }
  }

  Widget _buildHallCard(Map<String, dynamic> hall) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 95,
      decoration: BoxDecoration(
        color: royal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            child: hall['logo'] != null
                ? ClipOval(
              child: Image.memory(
                base64Decode(hall['logo']),
                fit: BoxFit.cover,
                width: 64,
                height: 64,
              ),
            )
                : const Icon(Icons.home_work, color: royal, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hall['name']?.toString().toUpperCase() ?? "SHOP",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadShopIdAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getInt('shopId');

    if (shopId != null) {
      await _fetchHistory();
      await _fetchHallDetails();
    }

    setState(() => isLoading = false);
  }

  Future<void> _fetchHistory() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/order/received-history/$shopId'));

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        history = data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        debugPrint("History failed: ${res.statusCode} ${res.body}");
        history = [];
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
      history = [];
    }
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _fmtDate(dynamic v) {
    final d = _parseDate(v);
    if (d == null) return "-";
    return d.toString().split(' ')[0];
  }

  bool _matchesMonthYear(DateTime date, DateTime filter) {
    return date.year == filter.year && date.month == filter.month;
  }

  String _monthYearLabel(DateTime? d) {
    if (d == null) return "All";
    return "${_months[d.month - 1]} ${d.year}";
  }

  Future<DateTime?> _pickMonthYear({
    required String title,
    DateTime? initial,
  }) async
  {
    final now = DateTime.now();
    int selectedMonth = initial?.month ?? now.month;
    int selectedYear = initial?.year ?? now.year;

    final int minYear = 2020;
    final int maxYear = now.year + 1;

    final outlineEnabled = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: royal.withAlpha(120), width: 1.2),
    );

    final outlineFocused = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: royal, width: 1.6),
    );

    return showDialog<DateTime>(
      context: context,
      builder: (context) {
        final screenW = MediaQuery.of(context).size.width;
        final dialogW = screenW < 420 ? screenW * 0.92 : 360.0;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: dialogW),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: royal,
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<int>(
                    value: selectedMonth,
                    dropdownColor: Colors.white,
                    iconEnabledColor: royal,   // ✅ arrow color
                    iconDisabledColor: royal,  // ✅ if disabled
                    style: const TextStyle(color: royal),
                    decoration: InputDecoration(
                      labelText: "Month",
                      labelStyle: const TextStyle(color: royal),
                      enabledBorder: outlineEnabled,
                      focusedBorder: outlineFocused,
                      border: outlineEnabled,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: List.generate(12, (i) {
                      final m = i + 1;
                      return DropdownMenuItem(value: m, child: Text(_months[i]));
                    }),
                    onChanged: (v) => selectedMonth = v ?? selectedMonth,
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<int>(
                    value: selectedYear,
                    dropdownColor: Colors.white,
                    iconEnabledColor: royal,   // ✅ arrow color
                    iconDisabledColor: royal,  // ✅ if disabled
                    style: const TextStyle(color: royal),
                    decoration: InputDecoration(
                      labelText: "Year",
                      labelStyle: const TextStyle(color: royal),
                      enabledBorder: outlineEnabled,
                      focusedBorder: outlineFocused,
                      border: outlineEnabled,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: [
                      for (int y = maxYear; y >= minYear; y--)
                        DropdownMenuItem(value: y, child: Text(y.toString())),
                    ],
                    onChanged: (v) => selectedYear = v ?? selectedYear,
                  ),

                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: const Text('Cancel', style: TextStyle(color: royal)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: royal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context, DateTime(selectedYear, selectedMonth, 1));
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filterChip({
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: royal.withAlpha(120)),
          borderRadius: BorderRadius.circular(24),
          color: royal,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 6),
            Text(
              "$label: $value",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, color: royal, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> item) {
    final med = item['medicine'] ?? {};
    final sup = item['supplier'] ?? {};

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: royal.withAlpha(120)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (med['name'] ?? 'Unknown Medicine').toString(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: royal,
              ),
            ),
            const SizedBox(height: 6),
            if ((med['category'] ?? '').toString().isNotEmpty)
              Text("Category: ${med['category']}"),
            const Divider(height: 18, color: royal, thickness: 0.5),
            Text(
              "Ordered Quantity: ${item['quantity'] ?? '-'}",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text("Ordered Date: ${_fmtDate(item['order_date'])}"),
            Text("Received Date: ${_fmtDate(item['received_date'])}"),
            const Divider(height: 18, color: royal, thickness: 0.5),
            if ((sup['name'] ?? '').toString().isNotEmpty)
              const Text("Supplier",
                  style: TextStyle(fontWeight: FontWeight.bold, color: royal)),
            if ((sup['name'] ?? '').toString().isNotEmpty)
              Text("Name: ${sup['name']}"),
            if ((sup['phone'] ?? '').toString().isNotEmpty)
              Text("Phone: ${sup['phone']}"),
            if ((sup['email'] ?? '').toString().isNotEmpty)
              Text("Email: ${sup['email']}"),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = history.where((h) {
      final medName = (h['medicine']?['name'] ?? '').toString().toLowerCase();
      final supName = (h['supplier']?['name'] ?? '').toString().toLowerCase();
      final matchesSearch = medName.contains(_searchQuery) || supName.contains(_searchQuery);

      if (!matchesSearch) return false;

      // ✅ Ordered month/year filter
      if (_orderedMonthYear != null) {
        final od = _parseDate(h['order_date']);
        if (od == null || !_matchesMonthYear(od, _orderedMonthYear!)) return false;
      }

      // ✅ Received month/year filter
      if (_receivedMonthYear != null) {
        final rd = _parseDate(h['received_date']);
        if (rd == null || !_matchesMonthYear(rd, _receivedMonthYear!)) return false;
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Received Orders History", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MainNavigation(initialIndex: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (shopDetails != null) _buildHallCard(shopDetails!),
            const SizedBox(height: 30),
            TextField(
              controller: _searchController,
              cursorColor: royal,
              style: const TextStyle(color: royal),
              decoration: InputDecoration(
                hintText: "Search by medicine or supplier...",
                hintStyle: TextStyle(color: royal.withAlpha(150)),
                prefixIcon: const Icon(Icons.search, color: royal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: royal.withAlpha(100)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: royal.withAlpha(150)),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
            const SizedBox(height: 12),

            // ✅ Filters Row
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _filterChip(
                  label: "Ordered",
                  value: _monthYearLabel(_orderedMonthYear),
                  onTap: () async {
                    final picked = await _pickMonthYear(
                      title: "Select Ordered Month & Year",
                      initial: _orderedMonthYear,
                    );
                    if (picked != null) {
                      setState(() {
                        _orderedMonthYear = picked;
                        _receivedMonthYear = null; // ✅ clear received filter
                      });
                    }
                  },
                  onClear: _orderedMonthYear == null
                      ? null
                      : () => setState(() => _orderedMonthYear = null),
                ),
                _filterChip(
                  label: "Received",
                  value: _monthYearLabel(_receivedMonthYear),
                  onTap: () async {
                    final picked = await _pickMonthYear(
                      title: "Select Received Month & Year",
                      initial: _receivedMonthYear,
                    );
                    if (picked != null) {
                      setState(() {
                        _receivedMonthYear = picked;
                        _orderedMonthYear = null; // ✅ clear ordered filter
                      });
                    }
                  },
                  onClear: _receivedMonthYear == null
                      ? null
                      : () => setState(() => _receivedMonthYear = null),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: filtered.isEmpty
                      ? const Center(
                    child: Text(
                      "No received orders found",
                      style: TextStyle(color: royal),
                    ),
                  )
                      : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _historyCard(filtered[i]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
