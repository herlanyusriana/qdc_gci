import 'dart:async';
import '../services/api_service.dart';

class SyncService {
  static Timer? _timer;
  static bool _syncing = false;

  static void startAutoSync() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => attemptSync());
  }

  static void stopAutoSync() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<bool> attemptSync() async {
    if (_syncing) return false;
    _syncing = true;
    try {
      return await ApiService.syncToServer();
    } catch (_) {
      return false;
    } finally {
      _syncing = false;
    }
  }
}
