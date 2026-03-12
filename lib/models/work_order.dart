class WorkOrder {
  final int id;
  final String woNumber;
  final String? transactionNo;
  final String? partNo;
  final String? partName;
  final String? model;
  final double qtyPlanned;
  final double qtyActual;
  final double qtyNg;
  final String status;
  final String? workflowStage;
  final String? shift;
  final int? productionSequence;
  final String? startTime;
  final String? endTime;

  WorkOrder({
    required this.id,
    required this.woNumber,
    this.transactionNo,
    this.partNo,
    this.partName,
    this.model,
    required this.qtyPlanned,
    this.qtyActual = 0,
    this.qtyNg = 0,
    required this.status,
    this.workflowStage,
    this.shift,
    this.productionSequence,
    this.startTime,
    this.endTime,
  });

  factory WorkOrder.fromJson(Map<String, dynamic> json) => WorkOrder(
        id: json['id'] as int,
        woNumber: json['wo_number'] as String? ?? json['transaction_no'] as String? ?? '-',
        transactionNo: json['transaction_no'] as String?,
        partNo: json['part_no'] as String?,
        partName: json['part_name'] as String?,
        model: json['model'] as String?,
        qtyPlanned: (json['qty_planned'] as num?)?.toDouble() ?? 0,
        qtyActual: (json['qty_actual'] as num?)?.toDouble() ?? 0,
        qtyNg: (json['qty_ng'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'planned',
        workflowStage: json['workflow_stage'] as String?,
        shift: json['shift'] as String?,
        productionSequence: json['production_sequence'] as int?,
        startTime: json['start_time'] as String?,
        endTime: json['end_time'] as String?,
      );

  bool get isRunning => status == 'in_production';
  bool get isCompleted => status == 'completed';
  bool get canStart => !isRunning && !isCompleted && status != 'cancelled';
  double get progressPercent => qtyPlanned > 0 ? (qtyActual / qtyPlanned * 100).clamp(0, 100) : 0;
}
