import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';
import '../models/debt.dart';

class ApiConfig extends ChangeNotifier {
  // Default URL: Vercel standard placeholder or local development API
  String _baseUrl = 'http://127.0.0.1:8000';

  String get baseUrl => _baseUrl;

  void updateBaseUrl(String newUrl) {
    if (newUrl.endsWith('/')) {
      _baseUrl = newUrl.substring(0, newUrl.length - 1);
    } else {
      _baseUrl = newUrl;
    }
    notifyListeners();
  }
}

class ApiService {
  final ApiConfig config;

  ApiService(this.config);

  String get _url => config.baseUrl;

  // --- Transactions ---

  Future<List<AppTransaction>> getTransactions() async {
    final response = await http.get(Uri.parse('$_url/api/transactions'));
    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => AppTransaction.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load transactions: ${response.body}');
    }
  }

  Future<AppTransaction> createTransaction({
    required String type,
    required double amount,
    required String description,
    required DateTime timestamp,
  }) async {
    final response = await http.post(
      Uri.parse('$_url/api/transactions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': type,
        'amount': amount,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
      }),
    );

    if (response.statusCode == 200) {
      return AppTransaction.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create transaction: ${response.body}');
    }
  }

  Future<void> deleteTransaction(String id) async {
    final response = await http.delete(Uri.parse('$_url/api/transactions/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete transaction: ${response.body}');
    }
  }

  // --- Debts ---

  Future<List<Debt>> getDebts() async {
    final response = await http.get(Uri.parse('$_url/api/debts'));
    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => Debt.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load debts: ${response.body}');
    }
  }

  Future<Debt> createDebt({
    required String personName,
    required double originalAmount,
    required double interestRate,
    required DateTime createdAt,
  }) async {
    final response = await http.post(
      Uri.parse('$_url/api/debts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'person_name': personName,
        'original_amount': originalAmount,
        'interest_rate': interestRate,
        'created_at': createdAt.toIso8601String(),
      }),
    );

    if (response.statusCode == 200) {
      return Debt.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create debt: ${response.body}');
    }
  }

  Future<Debt> updateDebt({
    required String id,
    required String personName,
    required double originalAmount,
    required double interestRate,
    required DateTime createdAt,
  }) async {
    final response = await http.put(
      Uri.parse('$_url/api/debts/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'person_name': personName,
        'original_amount': originalAmount,
        'interest_rate': interestRate,
        'created_at': createdAt.toIso8601String(),
      }),
    );

    if (response.statusCode == 200) {
      return Debt.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update debt: ${response.body}');
    }
  }

  Future<void> deleteDebt(String id) async {
    final response = await http.delete(Uri.parse('$_url/api/debts/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete debt: ${response.body}');
    }
  }

  // --- Reports ---

  Future<Map<String, dynamic>> getReports(String timeframe) async {
    final response = await http.get(Uri.parse('$_url/api/reports?timeframe=$timeframe'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load reports: ${response.body}');
    }
  }
}
