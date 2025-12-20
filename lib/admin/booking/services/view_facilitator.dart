import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../public/config.dart';
import '../../../public/main_navigation.dart';
import 'package:url_launcher/url_launcher_string.dart';

const Color royalblue = Color(0xFF376EA1);
const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class ViewFacilitatorPage extends StatefulWidget {
  const ViewFacilitatorPage({super.key});

  @override
  State<ViewFacilitatorPage> createState() => _ViewFacilitatorPageState();
}

class _ViewFacilitatorPageState extends State<ViewFacilitatorPage> {
  bool _isFetching = true;
  List<Map<String, dynamic>> _facilitators = [];
  List<Map<String, dynamic>> _filteredFacilitators = [];
  Map<String, dynamic>? hallDetails;
  final TextEditingController _searchController = TextEditingController();

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
    _searchController.addListener(_onSearchChanged);
  }

  void _launchPhoneDialer(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    try {
      await launchUrlString(url, mode: LaunchMode.platformDefault);
    } catch (e) {
      _showMessage('Error launching dialer: $e');
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    if (lodgeId != null) {
      await _fetchHallDetails(lodgeId);
      await _fetchFacilitators(lodgeId);
    }
  }

  Future<void> _fetchFacilitators(int lodgeId) async {
    try {
      final url = Uri.parse("$baseUrl/facilitator/lodge/$lodgeId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["success"] == true && data["data"] is List) {
          setState(() {
            _facilitators = List<Map<String, dynamic>>.from(data["data"]);
            _filteredFacilitators = _facilitators;
          });
        } else {
          setState(() {
            _facilitators = [];
            _filteredFacilitators = [];
          });
        }
      } else {
        _showMessage("❌ Failed to fetch facilitators: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error fetching facilitators: $e");
    } finally {
      setState(() => _isFetching = false);
    }
  }

  Future<void> _fetchHallDetails(int lodgeId) async {
    try {
      final url = Uri.parse('$baseUrl/lodges/$lodgeId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        hallDetails = jsonDecode(response.body);
      }
    } catch (e) {
      _showMessage("Error fetching lodge details: $e");
    } finally {
      setState(() {});
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFacilitators = _facilitators.where((facilitator) {
        final name = facilitator["name"]?.toString().toLowerCase() ?? "";
        final facility = facilitator["facility"]?.toString().toLowerCase() ?? "";
        return name.contains(query) || facility.contains(query);
      }).toList();
    });
  }

  Widget _buildFacilitatorCard(Map<String, dynamic> facilitator) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: royalLight.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: royal,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  facilitator["facility"]?.toString() ?? "FACILITY",
                  style: TextStyle(
                    color: royal,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if ((facilitator["phone"] ?? "").toString().isNotEmpty)
                IconButton(
                  icon: Icon(Icons.call, color: royal),
                  onPressed: () {
                    final phone = facilitator["phone"].toString();
                    _launchPhoneDialer(phone);
                  },
                ),
            ],
          ),

          const SizedBox(height: 8),
          Container(
            height: 1,
            color: royal.withValues(alpha:0.3),
            margin: const EdgeInsets.only(bottom: 8),
          ),
          Row(
            children: [
              const Icon(Icons.person, size: 18, color: royal),
              const SizedBox(width: 6),
              Text(
                facilitator["name"]?.toString().toUpperCase() ?? "-",
                style: TextStyle(
                  color: royal,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.phone, size: 18, color: royal),
              const SizedBox(width: 6),
              Text(
                facilitator["phone"]?.toString() ?? "-",
                style: TextStyle(
                  color: royal,
                  fontSize: 15,
                ),
              ),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("View Facilitators",
            style: TextStyle(color: Colors.white)),
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
            if (hallDetails != null) _buildHallCard(hallDetails!),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by name or facility...",
                hintStyle: TextStyle(color: royal),
                prefixIcon: Icon(Icons.search, color: royal),
                filled: true,
                fillColor: royalLight.withValues(alpha:0.05),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: royal, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: royal, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_filteredFacilitators.isEmpty)
              Center(
                child: Text(
                  "No facilitators found",
                  style: TextStyle(color: royal, fontSize: 16),
                ),
              )
            else
              ..._filteredFacilitators.map(_buildFacilitatorCard),
          ],
        ),
      ),
    );
  }
}
