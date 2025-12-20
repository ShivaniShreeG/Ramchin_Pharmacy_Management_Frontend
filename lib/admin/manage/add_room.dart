import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';
import '../../public/main_navigation.dart';

const Color royalblue = Color(0xFF376EA1);
const Color royal = Color(0xFF19527A);
const Color royalLight = Color(0xFF629AC1);

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingRooms = true;
  bool _showForm = false;
  String? selectedRoomType;
  bool isCustomType = false;
  TextEditingController customRoomTypeController = TextEditingController();

  List<Map<String, dynamic>> _rooms = [];
  List<TextEditingController> _roomNameControllers = [];
  List<TextEditingController> _roomTypeControllers = [];
  List<TextEditingController> roomNumberControllers = [];
  List<FocusNode> roomFocusNodes = [];

  Map<String, dynamic>? lodgeDetails;
  Map<String, dynamic>? _editingRoom;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: royal, fontSize: 16)),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: royal, width: 2)),
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

  @override
  void dispose() {
    for (final c in roomNumberControllers) {
      c.dispose();
    }
    for (final n in roomFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final lodgeId = prefs.getInt("lodgeId");
    if (lodgeId != null) {
      await _fetchHallDetails(lodgeId);
      await _fetchRooms(lodgeId);
    }
  }

  Future<void> _fetchHallDetails(int lodgeId) async {
    try {
      final url = Uri.parse('$baseUrl/lodges/$lodgeId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        lodgeDetails = jsonDecode(response.body);
      }
    } catch (_) {}
    setState(() {});
  }

  void _resetRoomFields({bool addEmpty = false}) {
    for (final c in roomNumberControllers) {
      c.dispose();
    }
    for (final f in roomFocusNodes) {
      f.dispose();
    }

    roomNumberControllers.clear();
    roomFocusNodes.clear();

    if (addEmpty) {
      roomNumberControllers.add(TextEditingController());
      roomFocusNodes.add(FocusNode());
    }
  }

  Future<void> _fetchRooms(int lodgeId) async {
    try {
      final url = Uri.parse("$baseUrl/rooms/lodge/$lodgeId");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _rooms = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      _showMessage("❌ Error fetching rooms: $e");
    } finally {
      setState(() => _isLoadingRooms = false);
    }
  }

  Future<void> _deleteRoom(int id, int lodgeId) async {
    try {
      final url = Uri.parse("$baseUrl/rooms/$id/$lodgeId");
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        await _fetchRooms(lodgeId);
        _showMessage("✅ Room deleted");
      } else {
        _showMessage("❌ Failed to delete: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error deleting room: $e");
    }
  }

  void _editRoom(Map<String, dynamic> room) {
    setState(() {
      _showForm = true;
      _editingRoom = room;

      _roomNameControllers = [
        TextEditingController(text: room["room_name"] ?? "")
      ];

      final roomType = room["room_type"] ?? "";
      final predefinedTypes = ["AC", "Non AC", "Others"];

      if (predefinedTypes.contains(roomType)) {
        _roomTypeControllers = [TextEditingController(text: roomType)];
        selectedRoomType = roomType;
        isCustomType = roomType == "Others";
        customRoomTypeController.text = "";
      } else {
        _roomTypeControllers = [TextEditingController(text: "Others")];
        selectedRoomType = "Others";
        isCustomType = true;
        customRoomTypeController.text = roomType;
      }

      final numbers = (room["room_number"] as List?)?.map((e) => e.toString()).toList() ?? [];
      _resetRoomFields();
      for (final num in numbers) {
        roomNumberControllers.add(TextEditingController(text: num));
        roomFocusNodes.add(FocusNode());
      }

      if (roomNumberControllers.isEmpty) {
        roomNumberControllers.add(TextEditingController());
        roomFocusNodes.add(FocusNode());
      }
    });
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
                style: const TextStyle(
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

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final roomNumbers = (room["room_number"] as List?) ?? [];
    final numbers = roomNumbers.isNotEmpty ? roomNumbers.join(", ") : "-";
    final count = roomNumbers.length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: royal, width: 1.5),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: royalLight.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room["room_name"] ?? "-",
                    style: const TextStyle(
                      color: royal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Room Type: ${room["room_type"] ?? "-"}",
                    style: const TextStyle(color: royal),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Room Numbers ($count): $numbers",
                    style: const TextStyle(color: royal),
                  ),
                ],
              ),
            ),

            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: royal),
                  tooltip: "Edit Room",
                  onPressed: () => _editRoom(room),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: royal),
                  tooltip: "Delete Room",
                  onPressed: () =>
                      _showDeleteDialog(room["id"], room["room_name"] ?? "-"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: royal, width: 1.5),
        ),
        title: const Text("Delete Room", style: TextStyle(color: royal)),
        content: Text("Do you want to delete the room:\n\n\"$name\"?", style: const TextStyle(color: royal)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: royal))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: royal),
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              final lodgeId = prefs.getInt("lodgeId");
              if (lodgeId != null) await _deleteRoom(id, lodgeId);
            },
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomForm() {
    final roomNameController = _roomNameControllers.isNotEmpty ? _roomNameControllers.first : TextEditingController();
    final roomTypeController = _roomTypeControllers.isNotEmpty ? _roomTypeControllers.first : TextEditingController();

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: royal, width: 1),
      ),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: roomNameController,
                decoration:  InputDecoration(
                  labelText: "Room Name",
                  labelStyle: TextStyle(color: royal),
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
                  filled: true,
                  fillColor: royalLight.withValues(alpha: 0.05),
                ),
                cursorColor: royal,
                style: TextStyle(color: royal),
                validator: (v) => v == null || v.isEmpty ? "Enter room name" : null,
              ),
              const SizedBox(height: 12),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedRoomType,
                    decoration: InputDecoration(
                      labelText: "Room Type",
                      labelStyle: const TextStyle(color: royal),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: royal, width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: royal, width: 2),
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
                      filled: true,
                      fillColor: royalLight.withValues(alpha: 0.05),
                    ),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: royal, fontSize: 16),
                    iconEnabledColor: royal,
                    items: const [
                      DropdownMenuItem(value: "AC", child: Text("AC")),
                      DropdownMenuItem(value: "Non AC", child: Text("Non AC")),
                      DropdownMenuItem(value: "Others", child: Text("Others")),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Select room type";
                      }
                      if (value == "Others" && customRoomTypeController.text.trim().isEmpty) {
                        return "Enter custom room type";
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        selectedRoomType = value;
                        isCustomType = value == "Others";
                      });
                    },
                  ),

                  const SizedBox(height: 10),

                  if (isCustomType)
                    TextFormField(
                      controller: customRoomTypeController,
                      decoration: InputDecoration(
                        labelText: "Custom Room Type",
                        labelStyle: const TextStyle(color: royal),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: royal, width: 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: royal, width: 2),
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
                        filled: true,
                        fillColor: royalLight.withValues(alpha: 0.05),
                      ),
                      cursorColor: royal,
                      style: const TextStyle(color: royal),
                      validator: (v) {
                        if (isCustomType && (v == null || v.trim().isEmpty)) {
                          return "Enter room type";
                        }
                        return null;
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),

              const Center(
                child: Text(
                  "Room Numbers",
                  style: TextStyle(
                    color: royal,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              for (int i = 0; i < roomNumberControllers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: roomNumberControllers[i],
                          focusNode: roomFocusNodes[i],
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            if (i < roomFocusNodes.length - 1) {
                              roomFocusNodes[i + 1].requestFocus();
                            } else {
                              setState(() {
                                final newController = TextEditingController();
                                final newFocusNode = FocusNode();
                                roomNumberControllers.add(newController);
                                roomFocusNodes.add(newFocusNode);
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                roomFocusNodes.last.requestFocus();
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: "Room ${i + 1}",
                            labelStyle: const TextStyle(color: royal),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: royal, width: 1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: royal, width: 2),
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
                            filled: true,
                            fillColor: royalLight.withValues(alpha: 0.05),
                          ),
                          cursorColor: royal,
                          style: const TextStyle(color: royal),
                          validator: (v) => v == null || v.isEmpty ? "Enter room number" : null,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: royal),
                        onPressed: () {
                          setState(() {
                            roomNumberControllers.removeAt(i);
                            roomFocusNodes.removeAt(i);
                          });
                        },
                      ),
                    ],
                  ),
                ),

              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      final newController = TextEditingController();
                      final newFocusNode = FocusNode();
                      roomNumberControllers.add(newController);
                      roomFocusNodes.add(newFocusNode);
                    });

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      roomFocusNodes.last.requestFocus();
                    });
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("Add Room Number", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: royal),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: royal),
                      onPressed: _isLoading
                          ? null
                          : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _isLoading = true);

                        final prefs = await SharedPreferences.getInstance();
                        final lodgeId = prefs.getInt("lodgeId");
                        final userId = prefs.getString("userId");

                        if (lodgeId == null || userId == null) {
                          _showMessage("❌ Missing user or lodge ID");
                          setState(() => _isLoading = false);
                          return;
                        }

                        final roomNumbers = roomNumberControllers
                            .map((ctrl) => ctrl.text.trim())
                            .where((n) => n.isNotEmpty)
                            .toList();

                        final roomTypeToSend = selectedRoomType == "Others"
                            ? customRoomTypeController.text.trim()
                            : selectedRoomType ?? roomTypeController.text.trim();

                        final roomData = {
                          "user_id": userId,
                          "lodge_id": lodgeId,
                          "room_name": roomNameController.text.trim(),
                          "room_type": roomTypeToSend,
                          "room_number": roomNumbers,
                        };


                        http.Response response;

                        if (_editingRoom != null) {
                          final roomId = _editingRoom!["id"];
                          final url = Uri.parse("$baseUrl/rooms/$roomId/$lodgeId");
                          response = await http.patch(
                            url,
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode(roomData),
                          );
                        } else {
                          final url = Uri.parse("$baseUrl/rooms");
                          response = await http.post(
                            url,
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode(roomData),
                          );
                        }

                        if (response.statusCode == 200 || response.statusCode == 201) {
                          await _fetchRooms(lodgeId);
                          _showMessage(_editingRoom != null
                              ? "✅ Room updated successfully"
                              : "✅ Room added successfully");
                          setState(() {
                            _showForm = false;
                            _editingRoom = null;
                            _roomNameControllers.clear();
                            _roomTypeControllers.clear();
                            roomNumberControllers.clear();

                            selectedRoomType = null;
                            isCustomType = false;
                            customRoomTypeController.clear();
                          });
                        } else {
                          _showMessage("❌ Failed: ${response.body}");
                        }

                        setState(() => _isLoading = false);
                      },
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                        _editingRoom != null ? "Update Room" : "Save Room",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showForm = false;
                        _editingRoom = null;
                        _roomNameControllers.clear();
                        _roomTypeControllers.clear();
                        roomNumberControllers.clear();

                        selectedRoomType = null;
                        isCustomType = false;
                        customRoomTypeController.clear();
                      });
                    },
                    child: const Text("Close", style: TextStyle(color: royal)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Rooms", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 2)),
              );
            },
          ),
        ],
      ),
      body: _isLoadingRooms
          ? const Center(child: CircularProgressIndicator(color: royal))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (lodgeDetails != null) _buildHallCard(lodgeDetails!),
            const SizedBox(height: 10),
            if (!_showForm)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: royal),
                onPressed: () {
                  setState(() {
                    _showForm = true;
                    _editingRoom = null;
                    _roomNameControllers = [TextEditingController()];
                    _roomTypeControllers = [TextEditingController()];
                    _resetRoomFields(addEmpty: true);

                  });
                },
                child: const Text("Add Room", style: TextStyle(color: Colors.white)),
              ),
            if (_showForm) _buildRoomForm(),
            const SizedBox(height: 16),
            if (_rooms.isNotEmpty)
              ..._rooms.map(_buildRoomCard)
            else
              const Center(
                child: Text("No rooms found", style: TextStyle(color: royal, fontSize: 18)),
              ),
          ],
        ),
      ),
    );
  }
}
