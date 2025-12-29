import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';
import '../../public/main_navigation.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class SubmitTicketPage extends StatefulWidget {
  const SubmitTicketPage({super.key});

  @override
  State<SubmitTicketPage> createState() => _SubmitTicketPageState();
}

class _SubmitTicketPageState extends State<SubmitTicketPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _issueController = TextEditingController();
  bool _isLoading = false;

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

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getInt("shopId");
      final userId = prefs.getString("userId");

      if (shopId == null || userId == null) {
        _showMessage("❌ Shop ID or User ID not found");
        setState(() => _isLoading = false);
        return;
      }

      final body = {
        "shop_id": shopId,
        "user_id": userId,
        "issue": _issueController.text.trim(),
      };

      final response = await http.post(
        Uri.parse("$baseUrl/submit-ticket"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage("✅ Ticket submitted successfully");
        _issueController.clear();
      } else {
        _showMessage("❌ Failed: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Submit Ticket"),
        backgroundColor: royal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            color: Colors.white,
            onPressed: () {
              Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 2)),
            );
              },
          ),
        ],
      ),

        body: SingleChildScrollView(
            child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 600, // 👈 ideal for all screen sizes
                    ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Icon(Icons.support_agent, color: royal, size: 60),
              const SizedBox(height: 20),
              Text(
                "Submit a Support Ticket",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: royal,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Describe the issue you are facing, and our support team will get back to you.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: royal.withValues(alpha:0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 25),

              TextFormField(
                controller: _issueController,
                maxLines: 5,
                style: TextStyle(color: royal),
                cursorColor: royal,
                decoration: InputDecoration(
                  hintText: "Describe the issue",
                  hintStyle: TextStyle(color: royal.withValues(alpha:0.6)),
                  filled: true,
                  fillColor: royalLight.withValues(alpha: 0.2),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: royal.withValues(alpha:0.8),
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: royal,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty
                    ? "Please describe the issue"
                    : null,
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: royal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  icon: _isLoading
                      ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.send),
                  label: Text(
                    _isLoading ? "Submitting..." : "Submit Ticket",
                    style: const TextStyle(fontSize: 16),
                  ),
                  onPressed: _isLoading ? null : _submitTicket,
                ),
              ),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
                ),
            ),
        ),
    );
  }
}
