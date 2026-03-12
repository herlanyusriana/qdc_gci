class Downtime {
  final int id;
  final int machineId;
  final String machineName;
  final String shift;
  final String operatorName;
  final String startTime;
  final String? endTime;
  final int? durationMinutes;
  final String reason;
  final String? notes;
  final String? refillPartNo;
  final String? refillPartName;
  final double? refillQty;
  final int? productionOrderId;
  final bool synced;

  Downtime({
    required this.id,
    required this.machineId,
    required this.machineName,
    required this.shift,
    this.operatorName = '',
    required this.startTime,
    this.endTime,
    this.durationMinutes,
    required this.reason,
    this.notes,
    this.refillPartNo,
    this.refillPartName,
    this.refillQty,
    this.productionOrderId,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'machineId': machineId,
        'machineName': machineName,
        'shift': shift,
        'operatorName': operatorName,
        'startTime': startTime,
        'endTime': endTime,
        'durationMinutes': durationMinutes,
        'reason': reason,
        'notes': notes,
        'refillPartNo': refillPartNo,
        'refillPartName': refillPartName,
        'refillQty': refillQty,
        'productionOrderId': productionOrderId,
        'synced': synced ? 1 : 0,
      };

  factory Downtime.fromMap(Map<String, dynamic> m) => Downtime(
        id: m['id'] as int,
        machineId: m['machineId'] as int,
        machineName: m['machineName'] as String,
        shift: m['shift'] as String,
        operatorName: (m['operatorName'] as String?) ?? '',
        startTime: m['startTime'] as String,
        endTime: m['endTime'] as String?,
        durationMinutes: m['durationMinutes'] as int?,
        reason: m['reason'] as String,
        notes: m['notes'] as String?,
        refillPartNo: m['refillPartNo'] as String?,
        refillPartName: m['refillPartName'] as String?,
        refillQty: m['refillQty'] != null
            ? (m['refillQty'] as num).toDouble()
            : null,
        productionOrderId: m['productionOrderId'] as int?,
        synced: (m['synced'] as int?) == 1,
      );

  bool get isRunning => endTime == null;

  Map<String, dynamic> toSyncJson() => {
        'id': id,
        'machineId': machineId,
        'machineName': machineName,
        'shift': shift,
        'operatorName': operatorName,
        'startTime': startTime,
        'endTime': endTime,
        'durationMinutes': durationMinutes,
        'reason': reason,
        'notes': notes,
        'refillPartNo': refillPartNo,
        'refillPartName': refillPartName,
        'refillQty': refillQty,
        'productionOrderId': productionOrderId,
      };
}
