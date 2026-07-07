import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  Future<Map<String, dynamic>> fetchProfile(String email) async {
    final response = await http.get(Uri.parse('$baseUrl/driver/profile?email=$email'));
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> checkActiveOrder(String email) async {
    final response = await http.get(Uri.parse('$baseUrl/driver/order/active?email=$email'));
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> fetchOrders(String email) async {
    final response = await http.get(Uri.parse('$baseUrl/driver/orders?email=$email'));
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> setOnline(String email, String playerId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/driver/set-online'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'onesignal_player_id': playerId,
      }),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> logout(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/driver/logout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
      }),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> withdraw({
    required int driverId,
    required String bankName,
    required String accountNumber,
    required double amount,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/driver/withdraw'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'driver_id': driverId,
        'bank_name': bankName,
        'account_number': accountNumber,
        'amount': amount,
      }),
    );
    return jsonDecode(response.body);
  }
}
