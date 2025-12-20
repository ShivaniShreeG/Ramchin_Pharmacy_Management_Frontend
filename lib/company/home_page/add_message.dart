import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../public/config.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class HallMessagesPage extends StatefulWidget {
  final dynamic hall;

  const HallMessagesPage({super.key, required this.hall});

  @override
  State<HallMessagesPage> createState() => _HallMessagesPageState();
}

class _HallMessagesPageState extends State<HallMessagesPage> {
  
  bool _isLoading = true;
  List<dynamic> _messages = [];
  String? _errorMessage;

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:  TextStyle(
            color: isError ? Colors.redAccent.shade400 : royal,
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
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/message/shop/${widget.hall['shop_id']}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages = data is List ? data : [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _showMessage("Failed to load messages (Code: ${response.statusCode})");
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _showMessage("Error fetching messages: $e");
        _isLoading = false;
      });
    }
  }

  Future<void> _addMessage(String message) async {
    final body = jsonEncode({
      'shop_id': widget.hall['shop_id'],
      'message': message,
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/message'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 201) {
        _fetchMessages();
      } else {
        _showMessage("Failed to add message (${response.statusCode})");
      }
    } catch (e) {
      _showMessage("Error adding message: $e");
    }
  }

  Future<void> _editMessage(int messageId, String newText) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/message/$messageId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': newText}),
      );

      if (response.statusCode == 200) {
        _fetchMessages();
      } else {
        _showMessage("Failed to edit message (${response.statusCode})");
      }
    } catch (e) {
      _showMessage("Error editing message: $e");
    }
  }

  Future<void> _deleteMessage(int messageId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/message/$messageId'),
      );

      if (response.statusCode == 200) {
        _fetchMessages();
      } else {
        _showMessage("Failed to delete message (${response.statusCode})");
      }
    } catch (e) {
      _showMessage("Error deleting message: $e");
    }
  }

  Future<void> _showMessageDialog({String? existingText, int? messageId}) async {
    final controller = TextEditingController(text: existingText ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          existingText == null ? "Add Message" : "Edit Message",
          style: TextStyle(color: royal, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          cursorColor: royal,
          style: TextStyle(color: royal),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Enter your message...",
            hintStyle: TextStyle(color: royal),
            filled: true,
            fillColor: royalLight.withValues(alpha: 0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: royal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: royal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(context);
              if (messageId == null) {
                _addMessage(text);
              } else {
                _editMessage(messageId, text);
              }
            },
            child: const Text("Save"),
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
        title: Text(
          "Messages - ${widget.hall['name']}",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMessages,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: royal,
        onPressed: () => _showMessageDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: royal,))
          : _errorMessage != null
          ? Center(
        child: Text(
          _errorMessage!,
          style: TextStyle(color: royal),
        ),
      )
          : _messages.isEmpty
          ? Center(
        child: Text(
          "No messages for this hall yet.",
          style: TextStyle(color: royal),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          return Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: royal, width: 1),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                msg['message'] ?? 'No content',
                style: TextStyle(color: royal),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    color: royal,
                    onPressed: () => _showMessageDialog(
                      existingText: msg['message'],
                      messageId: msg['id'],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    color: Colors.red[700],
                    onPressed: () => _deleteMessage(msg['id']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
