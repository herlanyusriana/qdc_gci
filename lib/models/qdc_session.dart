class QdcSession {
  final int id;
  final int machineId;
  final String machineName;
  final String shift;
  final String operatorName;
  final String? partFrom;
  final String? partTo;
  final String startTime;
  final String endTime;
  final int durationSeconds;
  final int internalSeconds;
  final int externalSeconds;
  final String? notes;
  final bool synced;

  QdcSession({
    required this.id,
    required this.machineId,
    required this.machineName,
    required this.shift,
    required this.operatorName,
    this.partFrom,
    this.partTo,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    this.internalSeconds = 0,
    this.externalSeconds = 0,
    this.notes,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'machineId': machineId,
        'machineName': machineName,
        'shift': shift,
        'operatorName': operatorName,
        'partFrom': partFrom,
        'partTo': partTo,
        'startTime': startTime,
        'endTime': endTime,
        'durationSeconds': durationSeconds,
        'internalSeconds': internalSeconds,
        'externalSeconds': externalSeconds,
        'notes': notes,
        'synced': synced ? 1 : 0,
      };

  factory QdcSession.fromMap(Map<String, dynamic> m) => QdcSession(
        id: m['id'] as int,
        machineId: m['machineId'] as int,
        machineName: m['machineName'] as String,
        shift: m['shift'] as String,
        operatorName: (m['operatorName'] as String?) ?? '',
        partFrom: m['partFrom'] as String?,
        partTo: m['partTo'] as String?,
        startTime: m['startTime'] as String,
        endTime: m['endTime'] as String,
        durationSeconds: m['durationSeconds'] as int,
        internalSeconds: m['internalSeconds'] as int? ?? 0,
        externalSeconds: m['externalSeconds'] as int? ?? 0,
        notes: m['notes'] as String?,
        synced: (m['synced'] as int?) == 1,
      );

  Map<String, dynamic> toSyncJson() => {
        'machine_id': machineId,
        'machine_name': machineName,
        'operator_name': operatorName,
        'shift': shift,
        'part_from': partFrom,
        'part_to': partTo,
        'start_time': startTime,
        'end_time': endTime,
        'duration_seconds': durationSeconds,
        'internal_seconds': internalSeconds,
        'external_seconds': externalSeconds,
        'notes': notes,
      };

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
