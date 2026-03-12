import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/work_order.dart';
import 'database_service.dart';

class ApiService {
  static const String baseUrl = 'https://incoming.nooneasku.online/api';

  static Future<String?> get _token async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> get _headers async {
    final token = await _token;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Auth
  static Future<Map<String, dynamic>> login(
      String login, String password) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'login': login, 'password': password}),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', data['token']);
      await prefs.setString('user_name', data['user']['name']);
      await prefs.setInt('user_id', data['user']['id']);
      return data;
    }
    throw Exception(jsonDecode(resp.body)['message'] ?? 'Login gagal');
  }

  static Future<void> logout() async {
    try {
      await http.post(Uri.parse('$baseUrl/auth/logout'),
          headers: await _headers);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_name');
    await prefs.remove('user_id');
  }

  // Machines
  static Future<List<Map<String, dynamic>>> getMachines() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/production-gci/machines'),
      headers: await _headers,
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return List<Map<String, dynamic>>.from(data['data']);
    }
    throw Exception('Gagal memuat daftar mesin');
  }

  // Parts (RM)
  static Future<List<Map<String, dynamic>>> searchParts(String search) async {
    final uri = Uri.parse('$baseUrl/production-gci/parts')
        .replace(queryParameters: {
      'classification': 'RM',
      if (search.isNotEmpty) 'search': search,
    });
    final resp = await http.get(uri, headers: await _headers);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return List<Map<String, dynamic>>.from(data['data']);
    }
    return [];
  }

  // Work Orders
  static Future<List<WorkOrder>> getWorkOrders(int machineId, {String? date}) async {
    final params = <String, String>{
      'machine_id': machineId.toString(),
    };
    if (date != null) params['date'] = date;
    final uri = Uri.parse('$baseUrl/production-gci/work-orders')
        .replace(queryParameters: params);
    final resp = await http.get(uri, headers: await _headers);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return (data['data'] as List).map((j) => WorkOrder.fromJson(j)).toList();
    }
    return [];
  }

  // Start WO
  static Future<bool> startWorkOrder(int woId) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/production-gci/wo/$woId/start'),
      headers: await _headers,
    );
    return resp.statusCode == 200;
  }

  // Finish WO
  static Future<bool> finishWorkOrder(int woId) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/production-gci/wo/$woId/finish'),
      headers: await _headers,
    );
    return resp.statusCode == 200;
  }

  // Sync downtimes + hourly reports + qdc sessions to server
  static Future<bool> syncToServer() async {
    final downtimes = await DatabaseService.getUnsyncedDowntimes();
    final hourlyReports = await DatabaseService.getUnsyncedHourlyReports();
    final qdcSessions = await DatabaseService.getUnsyncedQdcSessions();

    if (downtimes.isEmpty && hourlyReports.isEmpty && qdcSessions.isEmpty) {
      return true;
    }

    final body = <String, dynamic>{};

    if (downtimes.isNotEmpty) {
      body['downtimes'] = downtimes.map((d) => d.toSyncJson()).toList();
    }
    if (hourlyReports.isNotEmpty) {
      body['hourly_reports'] = hourlyReports.map((h) => h.toSyncJson()).toList();
    }

    try {
      // Sync downtimes + hourly reports via main sync endpoint
      if (body.isNotEmpty) {
        final resp = await http.post(
          Uri.parse('$baseUrl/production-gci/sync'),
          headers: await _headers,
          body: jsonEncode(body),
        );

        if (resp.statusCode == 200) {
          for (final d in downtimes) {
            await DatabaseService.markDowntimeSynced(d.id);
          }
          for (final h in hourlyReports) {
            await DatabaseService.markHourlyReportSynced(h.id);
          }
        }
      }

      // Sync QDC sessions via separate endpoint
      for (final qs in qdcSessions) {
        final resp = await http.post(
          Uri.parse('$baseUrl/production-gci/qdc-session'),
          headers: await _headers,
          body: jsonEncode(qs.toSyncJson()),
        );
        if (resp.statusCode == 200) {
          await DatabaseService.markQdcSessionSynced(qs.id);
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
