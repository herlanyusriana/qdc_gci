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

  factory WorkOrder.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0;
    }

    return WorkOrder(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      woNumber: (json['wo_number'] ?? json['transaction_no'] ?? '-').toString(),
      transactionNo: json['transaction_no']?.toString(),
      partNo: json['part_no']?.toString(),
      partName: json['part_name']?.toString(),
      model: json['model']?.toString(),
      qtyPlanned: parseNum(json['qty_planned']),
      qtyActual: parseNum(json['qty_actual']),
      qtyNg: parseNum(json['qty_ng']),
      status: (json['status'] ?? 'planned').toString(),
      workflowStage: json['workflow_stage']?.toString(),
      shift: json['shift']?.toString(),
      productionSequence: json['production_sequence'] is int 
          ? json['production_sequence'] 
          : int.tryParse(json['production_sequence']?.toString() ?? ''),
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
    );
  }

  bool get isRunning => status == 'in_production';
  bool get isCompleted => status == 'completed';
  bool get canStart => !isRunning && !isCompleted && status != 'cancelled';
  double get progressPercent => qtyPlanned > 0 ? (qtyActual / qtyPlanned * 100).clamp(0, 100) : 0;
}
