import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'dart:convert';

class ShopService {
  Future<int?> getShopId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('shopId');
  }

  Future<Map<String, dynamic>> fetchShopDetails(int shopId) async {
    final url = Uri.parse('$baseUrl/shops/$shopId');
    final response = await http.get(url);

    if (response.statusCode == 200||response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load shop details");
    }
  }
}
