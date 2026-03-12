import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/work_order.dart';
import '../models/hourly_report.dart';
import '../models/downtime.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class HourlyInputScreen extends StatefulWidget {
  final WorkOrder workOrder;
  final int machineId;
  final String machineName;
  final String shift;
  final String operatorName;

  const HourlyInputScreen({
    super.key,
    required this.workOrder,
    required this.machineId,
    required this.machineName,
    required this.shift,
    required this.operatorName,
  });

  @override
  State<HourlyInputScreen> createState() => _HourlyInputScreenState();
}

class _HourlyInputScreenState extends State<HourlyInputScreen> {
  late WorkOrder _wo;
  List<_TimeSlot> _slots = [];
  bool _starting = false;
  final _formKey = GlobalKey<FormState>();

  // Downtime tracking
  Downtime? _activeDowntime;
  int _downtimeSeconds = 0;
  Timer? _downtimeTimer;
  List<Downtime> _todayDowntimes = [];

  static const _downtimeReasons = [
    'Mesin Rusak',
    'Robot Trouble',
    'Dies Trouble',
    'Material NG Quality',
    'Tooling Trouble',
    'Listrik Trouble / Mati Lampu',
    'Maintenance',
    'Ganti Type',
    'Ganti Material / Reffil Material',
    'Cleaning Machine',
    'Briefing',
    'Trial',
    'Istirahat',
    'Lainnya',
  ];

  // Shift slots
  static const _shiftSlots = {
    'Shift 1': [
      '07:30-08:30', '08:30-09:30', '09:30-10:30', '10:30-11:30',
      '11:30-12:30', '12:30-13:30', '13:30-14:30', '14:30-15:30',
    ],
    'Shift 2': [
      '15:30-16:30', '16:30-17:30', '17:30-18:30', '18:30-19:30',
      '19:30-20:30', '20:30-21:30', '21:30-22:30', '22:30-23:30',
    ],
    'Shift 3': [
      '23:30-00:30', '00:30-01:30', '01:30-02:30', '02:30-03:30',
      '03:30-04:30', '04:30-05:30', '05:30-06:30', '06:30-07:30',
    ],
  };

  @override
  void initState() {
    super.initState();
    _wo = widget.workOrder;
    _initSlots();
    _loadDowntimeState();
  }

  @override
  void dispose() {
    _downtimeTimer?.cancel();
    for (final s in _slots) {
      s.actualController.dispose();
      s.ngController.dispose();
    }
    super.dispose();
  }

  Future<void> _initSlots() async {
    final shiftKey = widget.shift.startsWith('Shift')
        ? widget.shift
        : 'Shift ${widget.shift}';
    final ranges = _shiftSlots[shiftKey] ?? _shiftSlots['Shift 1']!;

    // Fetch from server first to sync data from other users
    try {
      final serverReports = await ApiService.getHourlyReports(_wo.id);
      for (final json in serverReports) {
        final range = json['time_range'] as String;
        final actual = json['actual'] as int;
        final ng = json['ng'] as int;
        final target = json['target'] as int;

        final existing = await DatabaseService.getHourlyReport(_wo.id, range);
        if (existing == null) {
          await DatabaseService.insertHourlyReport(HourlyReport(
            productionOrderId: _wo.id,
            timeRange: range,
            target: target,
            actual: actual,
            ng: ng,
            synced: true,
          ));
        } else if (existing.synced) {
          // Update local if already synced (to get latest from other users)
          await DatabaseService.updateHourlyReport(existing.id!, {
            'actual': actual,
            'ng': ng,
            'target': target,
          });
        }
      }
    } catch (e) {
      debugPrint('Sync hourly reports error: $e');
    }

    final slots = <_TimeSlot>[];
    for (final range in ranges) {
      final existing = await DatabaseService.getHourlyReport(_wo.id, range);
      slots.add(_TimeSlot(
        timeRange: range,
        actualController:
            TextEditingController(text: existing?.actual.toString() ?? ''),
        ngController:
            TextEditingController(text: existing?.ng.toString() ?? ''),
        localId: existing?.id,
        synced: existing?.synced ?? false,
      ));
    }
    if (!mounted) return;
    setState(() => _slots = slots);
    _recalcTotals();
  }

  Future<void> _loadDowntimeState() async {
    final active = await DatabaseService.getActiveDowntime(widget.machineId);
    final today = await DatabaseService.getTodayDowntimes(widget.machineId);
    if (!mounted) return;
    setState(() {
      _activeDowntime = active;
      _todayDowntimes = today.where((d) => d.endTime != null).toList();
    });
    if (active != null) {
      _startDowntimeCounter(active);
    }
  }

  void _startDowntimeCounter(Downtime dt) {
    final start = DateTime.parse(dt.startTime);
    _downtimeTimer?.cancel();
    _downtimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _downtimeSeconds = DateTime.now().difference(start).inSeconds;
      });
    });
    setState(() {
      _downtimeSeconds = DateTime.now().difference(start).inSeconds;
    });
  }

  // ─── Start WO ───
  Future<void> _startWo() async {
    setState(() => _starting = true);
    try {
      await ApiService.startWorkOrder(_wo.id);
      if (!mounted) return;
      setState(() {
        _wo = WorkOrder(
          id: _wo.id,
          woNumber: _wo.woNumber,
          transactionNo: _wo.transactionNo,
          partNo: _wo.partNo,
          partName: _wo.partName,
          model: _wo.model,
          qtyPlanned: _wo.qtyPlanned,
          qtyActual: _wo.qtyActual,
          qtyNg: _wo.qtyNg,
          status: 'in_production',
          workflowStage: 'mass_production',
          shift: _wo.shift,
          productionSequence: _wo.productionSequence,
          startTime: DateTime.now().toIso8601String(),
          endTime: _wo.endTime,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('WO dimulai!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gagal start: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  // ─── Save hourly slot ───
  Future<void> _saveSlot(_TimeSlot slot) async {
    final actual = int.tryParse(slot.actualController.text) ?? 0;
    final ng = int.tryParse(slot.ngController.text) ?? 0;
    final targetPerSlot =
        _slots.isNotEmpty ? (_wo.qtyPlanned / _slots.length).round() : 0;

    if (slot.localId != null) {
      await DatabaseService.updateHourlyReport(slot.localId!, {
        'actual': actual,
        'ng': ng,
        'target': targetPerSlot,
        'synced': 0,
      });
    } else {
      final hr = HourlyReport(
        productionOrderId: _wo.id,
        timeRange: slot.timeRange,
        target: targetPerSlot,
        actual: actual,
        ng: ng,
      );
      final newId = await DatabaseService.insertHourlyReport(hr);
      slot.localId = newId;
    }
    slot.synced = false;
    _recalcTotals();

    // Trigger immediate sync
    SyncService.attemptSync();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('${slot.timeRange} disimpan ✓'),
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFF22C55E)),
    );
  }

  void _recalcTotals() {
    int totalActual = 0;
    int totalNg = 0;
    for (final s in _slots) {
      totalActual += int.tryParse(s.actualController.text) ?? 0;
      totalNg += int.tryParse(s.ngController.text) ?? 0;
    }
    setState(() {
      _wo = WorkOrder(
        id: _wo.id,
        woNumber: _wo.woNumber,
        transactionNo: _wo.transactionNo,
        partNo: _wo.partNo,
        partName: _wo.partName,
        model: _wo.model,
        qtyPlanned: _wo.qtyPlanned,
        qtyActual: totalActual.toDouble(),
        qtyNg: totalNg.toDouble(),
        status: _wo.status,
        workflowStage: _wo.workflowStage,
        shift: _wo.shift,
        productionSequence: _wo.productionSequence,
        startTime: _wo.startTime,
        endTime: _wo.endTime,
      );
    });
  }

  // ─── Downtime: show reason picker & start ───
  void _showDowntimeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('ALASAN DOWNTIME',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('WO: ${_wo.woNumber}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 16),
              ..._downtimeReasons.map((reason) {
                IconData icon;
                Color color;
                switch (reason) {
                  case 'Mesin Rusak':
                    icon = Icons.settings_suggest;
                    color = const Color(0xFFEF4444);
                    break;
                  case 'Robot Trouble':
                    icon = Icons.precision_manufacturing;
                    color = const Color(0xFFEF4444);
                    break;
                  case 'Dies Trouble':
                    icon = Icons.architecture;
                    color = const Color(0xFFEF4444);
                    break;
                  case 'Material NG Quality':
                    icon = Icons.report_problem;
                    color = const Color(0xFFF59E0B);
                    break;
                  case 'Tooling Trouble':
                    icon = Icons.build_circle;
                    color = const Color(0xFFEF4444);
                    break;
                  case 'Listrik Trouble / Mati Lampu':
                    icon = Icons.flash_off;
                    color = const Color(0xFFEF4444);
                    break;
                  case 'Maintenance':
                    icon = Icons.engineering;
                    color = const Color(0xFF14B8A6);
                    break;
                  case 'Ganti Type':
                    icon = Icons.swap_horiz;
                    color = const Color(0xFF8B5CF6);
                    break;
                  case 'Ganti Material / Reffil Material':
                    icon = Icons.inventory_2;
                    color = const Color(0xFF8B5CF6);
                    break;
                  case 'Cleaning Machine':
                    icon = Icons.cleaning_services;
                    color = const Color(0xFF10B981);
                    break;
                  case 'Briefing':
                    icon = Icons.groups;
                    color = const Color(0xFF3B82F6);
                    break;
                  case 'Trial':
                    icon = Icons.science;
                    color = const Color(0xFFF97316);
                    break;
                  case 'Istirahat':
                    icon = Icons.free_breakfast;
                    color = const Color(0xFF60A5FA);
                    break;
                  default:
                    icon = Icons.more_horiz;
                    color = Colors.white54;
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _startDowntime(reason);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(icon, color: color, size: 22),
                            const SizedBox(width: 14),
                            Text(reason,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startDowntime(String reason) async {
    final dt = Downtime(
      id: 0,
      machineId: widget.machineId,
      machineName: widget.machineName,
      shift: widget.shift,
      operatorName: widget.operatorName,
      startTime: DateTime.now().toIso8601String(),
      reason: reason,
      productionOrderId: _wo.id,
    );
    final newId = await DatabaseService.insertDowntime(dt);
    final saved = Downtime(
      id: newId,
      machineId: dt.machineId,
      machineName: dt.machineName,
      shift: dt.shift,
      operatorName: dt.operatorName,
      startTime: dt.startTime,
      reason: dt.reason,
      productionOrderId: dt.productionOrderId,
    );
    setState(() => _activeDowntime = saved);
    _startDowntimeCounter(saved);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('⚠ Downtime dimulai: $reason'),
          backgroundColor: const Color(0xFFDC2626)),
    );
  }

  Future<void> _stopDowntime() async {
    if (_activeDowntime == null) return;

    _downtimeTimer?.cancel();
    final endTime = DateTime.now();
    final start = DateTime.parse(_activeDowntime!.startTime);
    final durationMinutes = endTime.difference(start).inMinutes;

    await DatabaseService.updateDowntime(_activeDowntime!.id, {
      'endTime': endTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'synced': 0,
    });

    setState(() {
      _activeDowntime = null;
      _downtimeSeconds = 0;
    });
    await _loadDowntimeState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('✓ Downtime selesai ($durationMinutes menit)'),
          backgroundColor: const Color(0xFF22C55E)),
    );
  }

  String _formatSeconds(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  int get _totalDowntimeMinutes {
    int total = 0;
    for (final dt in _todayDowntimes) {
      if (dt.reason != 'Istirahat') {
        total += dt.durationMinutes ?? 0;
      }
    }
    if (_activeDowntime != null && _activeDowntime!.reason != 'Istirahat') {
      total += _downtimeSeconds ~/ 60;
    }
    return total;
  }

  // ─── Build UI ───
  @override
  Widget build(BuildContext context) {
    final progress = _wo.progressPercent;
    final now = DateFormat('HH:mm').format(DateTime.now());
    final isDown = _activeDowntime != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: isDown ? const Color(0xFF7F1D1D) : const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_wo.woNumber,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            Text('${_wo.partNo ?? '-'} • ${_wo.partName ?? '-'}',
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Color(0xFF3B82F6)),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Menyinkronkan data...')),
              );
              final success = await SyncService.attemptSync();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Sync Berhasil ✓' : 'Sync Gagal ✗'),
                    backgroundColor: success ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  ),
                );
              }
            },
            tooltip: 'Sinkron data sekarang',
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white70),
            onPressed: () {
              // TODO: Implement history view
            },
          ),
        ],
      ),
      // FAB for downtime
      floatingActionButton: _wo.isRunning
          ? FloatingActionButton.extended(
              onPressed: isDown ? _stopDowntime : _showDowntimeSheet,
              icon: Icon(isDown ? Icons.play_arrow : Icons.warning_amber_rounded),
              label: Text(
                isDown ? 'MESIN JALAN' : 'CATAT DOWNTIME',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              backgroundColor: isDown
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFDC2626),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Active downtime banner
            if (isDown)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                color: _activeDowntime?.reason == 'Istirahat' ? const Color(0xFF3B82F6) : const Color(0xFFDC2626),
                child: Row(
                  children: [
                    Icon(
                      _activeDowntime?.reason == 'Istirahat' ? Icons.free_breakfast : Icons.warning,
                      color: Colors.white, 
                      size: 20
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _activeDowntime?.reason == 'Istirahat' 
                              ? '☕ BREAK — ${_activeDowntime!.reason}'
                              : '⚠ DOWNTIME — ${_activeDowntime!.reason}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Durasi: ${_formatSeconds(_downtimeSeconds)}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatSeconds(_downtimeSeconds),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ],
                ),
              ),

            // Summary header
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: _wo.isRunning
                        ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SummaryTile(
                          label: 'Target',
                          value: _wo.qtyPlanned.toInt().toString(),
                          color: Colors.white),
                      _SummaryTile(
                          label: 'Actual',
                          value: _wo.qtyActual.toInt().toString(),
                          color: const Color(0xFF22C55E)),
                      _SummaryTile(
                          label: 'NG',
                          value: _wo.qtyNg.toInt().toString(),
                          color: const Color(0xFFEF4444)),
                      _SummaryTile(
                          label: 'DT',
                          value: '${_totalDowntimeMinutes}m',
                          color: const Color(0xFFF59E0B)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 100
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF3B82F6),
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${progress.toStringAsFixed(0)}%',
                      style: TextStyle(
                          color: progress >= 100
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF3B82F6),
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Start WO button
                  if (_wo.canStart)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _starting ? null : _startWo,
                        icon: _starting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.play_arrow),
                        label: const Text('MULAI PRODUKSI',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Hourly input list label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('INPUT PER JAM',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                  const Spacer(),
                  if (_todayDowntimes.isNotEmpty)
                    Text('DT: ${_todayDowntimes.length}x (${_totalDowntimeMinutes}m)',
                        style: const TextStyle(
                            color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text('Sekarang: $now',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Slots list
            Expanded(
              child: _slots.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                      itemCount: _slots.length,
                      itemBuilder: (ctx, i) {
                        final slot = _slots[i];
                        final isCurrentHour = _isCurrentSlot(slot.timeRange);
                        return Card(
                          color: isCurrentHour
                              ? const Color(0xFF1E3A5F)
                              : const Color(0xFF1E293B),
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isCurrentHour
                                ? const BorderSide(
                                    color: Color(0xFF3B82F6), width: 1.5)
                                : BorderSide.none,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                // Time range
                                SizedBox(
                                  width: 90,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(slot.timeRange,
                                          style: TextStyle(
                                              color: isCurrentHour
                                                  ? Colors.white
                                                  : Colors.white70,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700)),
                                      if (isCurrentHour)
                                        const Text('▶ Sekarang',
                                            style: TextStyle(
                                                color: Color(0xFF3B82F6),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ),
                                // OK input
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    child: TextField(
                                      controller: slot.actualController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                          color: Color(0xFF22C55E),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800),
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        labelText: 'OK',
                                        labelStyle: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11),
                                        filled: true,
                                        fillColor: Colors.white
                                            .withValues(alpha: 0.05),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 10),
                                      ),
                                    ),
                                  ),
                                ),
                                // NG input
                                SizedBox(
                                  width: 60,
                                  child: TextField(
                                    controller: slot.ngController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800),
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      labelText: 'NG',
                                      labelStyle: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11),
                                      filled: true,
                                      fillColor: Colors.white
                                          .withValues(alpha: 0.05),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Save button
                                IconButton(
                                  icon: Icon(
                                    slot.synced
                                        ? Icons.cloud_done
                                        : Icons.save,
                                    color: slot.synced
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFF3B82F6),
                                    size: 22,
                                  ),
                                  onPressed: () => _saveSlot(slot),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isCurrentSlot(String timeRange) {
    final parts = timeRange.split('-');
    if (parts.length != 2) return false;
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    final start = _parseTime(parts[0]);
    final end = _parseTime(parts[1]);

    if (start == null || end == null) return false;

    if (end > start) {
      return nowMinutes >= start && nowMinutes < end;
    } else {
      return nowMinutes >= start || nowMinutes < end;
    }
  }

  int? _parseTime(String t) {
    final p = t.trim().split(':');
    if (p.length != 2) return null;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }
}

class _TimeSlot {
  final String timeRange;
  final TextEditingController actualController;
  final TextEditingController ngController;
  int? localId;
  bool synced;

  _TimeSlot({
    required this.timeRange,
    required this.actualController,
    required this.ngController,
    this.localId,
    this.synced = false,
  });
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
