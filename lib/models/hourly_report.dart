class HourlyReport {
  final int? id;
  final int productionOrderId;
  final String timeRange;
  final int target;
  final int actual;
  final int ng;
  final String? operatorName;
  final String? shift;
  final bool synced;

  HourlyReport({
    this.id,
    required this.productionOrderId,
    required this.timeRange,
    required this.target,
    required this.actual,
    required this.ng,
    this.operatorName,
    this.shift,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'productionOrderId': productionOrderId,
        'timeRange': timeRange,
        'target': target,
        'actual': actual,
        'ng': ng,
        'operatorName': operatorName,
        'shift': shift,
        'synced': synced ? 1 : 0,
      };

  factory HourlyReport.fromMap(Map<String, dynamic> m) => HourlyReport(
        id: m['id'] as int?,
        productionOrderId: m['productionOrderId'] as int,
        timeRange: m['timeRange'] as String,
        target: m['target'] as int? ?? 0,
        actual: m['actual'] as int? ?? 0,
        ng: m['ng'] as int? ?? 0,
        operatorName: m['operatorName'] as String?,
        shift: m['shift'] as String?,
        synced: (m['synced'] as int?) == 1,
      );

  Map<String, dynamic> toSyncJson() => {
        'id': id,
        'productionOrderId': productionOrderId,
        'timeRange': timeRange,
        'target': target,
        'actual': actual,
        'ng': ng,
        'operatorName': operatorName,
        'shift': shift,
      };
}
