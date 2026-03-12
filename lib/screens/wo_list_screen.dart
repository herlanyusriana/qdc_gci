import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/work_order.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'hourly_input_screen.dart';

class WoListScreen extends StatefulWidget {
  final int machineId;
  final String machineName;
  final String shift;
  final String operatorName;

  const WoListScreen({
    super.key,
    required this.machineId,
    required this.machineName,
    required this.shift,
    required this.operatorName,
  });

  @override
  State<WoListScreen> createState() => _WoListScreenState();
}

class _WoListScreenState extends State<WoListScreen> {
  List<WorkOrder> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final apiOrders =
          await ApiService.getWorkOrders(widget.machineId, date: today);
      
      // Merge with local data to ensure unsynced changes are reflected
      final mergedOrders = <WorkOrder>[];
      for (var wo in apiOrders) {
        final localReports = await DatabaseService.getHourlyReportsFor(wo.id);
        if (localReports.isNotEmpty) {
          double localActual = localReports.fold(0, (sum, r) => sum + r.actual);
          double localNg = localReports.fold(0, (sum, r) => sum + r.ng);
          
          // Trust local data if reports exist for this WO
          mergedOrders.add(WorkOrder(
            id: wo.id,
            woNumber: wo.woNumber,
            transactionNo: wo.transactionNo,
            partNo: wo.partNo,
            partName: wo.partName,
            model: wo.model,
            qtyPlanned: wo.qtyPlanned,
            qtyActual: localActual,
            qtyNg: localNg,
            status: wo.status,
            workflowStage: wo.workflowStage,
            shift: wo.shift,
            productionSequence: wo.productionSequence,
            startTime: wo.startTime,
            endTime: wo.endTime,
          ));
        } else {
          mergedOrders.add(wo);
        }
      }

      if (!mounted) return;
      setState(() {
        _orders = mergedOrders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'in_production':
        return const Color(0xFF22C55E);
      case 'completed':
        return const Color(0xFF60A5FA);
      case 'planned':
        return const Color(0xFFFBBF24);
      case 'released':
      case 'kanban_released':
        return const Color(0xFFA78BFA);
      default:
        return Colors.white38;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_production':
        return 'RUNNING';
      case 'completed':
        return 'SELESAI';
      case 'planned':
        return 'PLANNED';
      case 'released':
      case 'kanban_released':
        return 'RELEASED';
      default:
        return status.toUpperCase();
    }
  }

  void _openWo(WorkOrder wo) {
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => HourlyInputScreen(
        workOrder: wo,
        machineId: widget.machineId,
        machineName: widget.machineName,
        shift: widget.shift,
        operatorName: widget.operatorName,
      ),
    ))
        .then((_) => _loadOrders());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) {
          SyncService.attemptSync();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Work Order',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(widget.machineName,
                style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text('Gagal memuat WO',
                          style: TextStyle(color: Colors.white54)),
                      TextButton(
                          onPressed: _loadOrders,
                          child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : _orders.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox,
                              size: 64, color: Colors.white24),
                          SizedBox(height: 12),
                          Text('Tidak ada WO hari ini',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (ctx, i) {
                          final wo = _orders[i];
                          final statusColor = _statusColor(wo.status);
                          return Card(
                            color: const Color(0xFF1E293B),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color: wo.isRunning
                                      ? const Color(0xFF22C55E)
                                      : Colors.transparent,
                                  width: wo.isRunning ? 2.0 : 0.0),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openWo(wo),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Header
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            wo.woNumber,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _statusLabel(wo.status),
                                            style: TextStyle(
                                                color: statusColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Part info
                                    Text(
                                      '${wo.partNo ?? '-'} — ${wo.partName ?? '-'}',
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14),
                                    ),
                                    if (wo.model != null &&
                                        wo.model!.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2),
                                        child: Text('Model: ${wo.model}',
                                            style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 12)),
                                      ),

                                    const SizedBox(height: 12),

                                    // Progress
                                    Row(
                                      children: [
                                        _InfoChip(
                                            label: 'Target',
                                            value:
                                                wo.qtyPlanned.toInt().toString(),
                                            color: Colors.white60),
                                        const SizedBox(width: 12),
                                        _InfoChip(
                                            label: 'Actual',
                                            value:
                                                wo.qtyActual.toInt().toString(),
                                            color: const Color(0xFF22C55E)),
                                        const SizedBox(width: 12),
                                        _InfoChip(
                                            label: 'NG',
                                            value:
                                                wo.qtyNg.toInt().toString(),
                                            color: const Color(0xFFEF4444)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Progress bar
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: wo.progressPercent / 100,
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.1),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                statusColor),
                                        minHeight: 6,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '${wo.progressPercent.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                            color: statusColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    ),
  );
}
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
