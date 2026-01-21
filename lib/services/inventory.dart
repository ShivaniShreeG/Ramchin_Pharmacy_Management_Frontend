import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class InventoryService {
  final int shopId;

  InventoryService({required this.shopId});

  Future<List<Map<String, dynamic>>> fetchMedicines() async {
    final url = Uri.parse("$baseUrl/inventory/medicine/shop/$shopId");
    final response = await http.get(url);

    if (response.statusCode == 200||response.statusCode == 201) {
      final List data = jsonDecode(response.body);
      return data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      throw Exception("Failed to fetch medicines");
    }
  }

  Future<void> updateInventoryStatus({
    required int medicineId,
    int? batchId,
    required bool isActive,
  }) async {
    final url = Uri.parse("$baseUrl/inventory/status");
    final response = await http.patch(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "shop_id": shopId,
        "medicine_id": medicineId,
        if (batchId != null) "batch_id": batchId,
        "is_active": isActive,
      }),
    );

    if (response.statusCode != 200||response.statusCode != 201) {
      throw Exception("Failed to update status");
    }
  }

  Future<void> addMedicine(Map<String, dynamic> medicineData) async {
    final url = Uri.parse("$baseUrl/inventory/medicine");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(medicineData),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Failed to add medicine");
    }
  }

  Future<bool> checkMedicineNameExists(String name) async {
    final url = Uri.parse("$baseUrl/inventory/medicine/check-name/$shopId?name=$name");
    final response = await http.get(url);
    if (response.statusCode == 200||response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['exists'] ?? false;
    }
    return false;
  }

  Future<Map<String, dynamic>?> getSupplierByPhone(String phone) async {
    final url = Uri.parse("$baseUrl/suppliers/search/by-phone/$shopId?phone=$phone");
    final response = await http.get(url);
    if (response.statusCode == 200||response.statusCode == 201) {
      final data = jsonDecode(response.body) as List;
      if (data.isNotEmpty) return data[0];
    }
    return null;
  }
}
