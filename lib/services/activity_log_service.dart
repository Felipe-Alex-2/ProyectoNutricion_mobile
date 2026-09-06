import 'package:flutter/foundation.dart';
import '../models/activity_log.dart';
import 'api_service.dart';

class ActivityLogService extends ChangeNotifier {
  final ApiService _apiService;

  List<ActivityLog> _logs = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ActivityLog> get logs => _logs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ActivityLogService(this._apiService);

  Future<void> fetchLogs() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _apiService.get('/activity-logs?limit=100');
      if (data is List) {
        _logs = data
            .map((item) => ActivityLog.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> recordLog({
    required String action,
    required String description,
    String category = 'SISTEMA',
  }) async {
    try {
      final response = await _apiService.post(
        '/activity-logs',
        body: {
          'action': action,
          'description': description,
          'category': category,
        },
      );
      final newLog = ActivityLog.fromJson(response as Map<String, dynamic>);
      _logs.insert(0, newLog);
      notifyListeners();
    } catch (_) {
      // Background recording failure shouldn't crash UI
    }
  }

  Future<void> clearLogsOnServer() async {
    try {
      await _apiService.delete('/activity-logs');
    } catch (_) {}
    _logs = [];
    notifyListeners();
  }

  void clearLogs() {
    _logs = [];
    notifyListeners();
  }
}
