import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
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
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.dispose();
    for (final s in _slots) {
      s.actualController.dispose();
      s.ngController.dispose();
    }
    super.dispose();
  }

  Future<void> _initSlots() async {
    final List<Map<String, String>> allRanges = [];
    _shiftSlots.forEach((shift, ranges) {
      for (var r in ranges) {
        allRanges.add({'shift': shift, 'range': r});
      }
    });

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
    for (final item in allRanges) {
      final range = item['range']!;
      final shift = item['shift']!;
      final existing = await DatabaseService.getHourlyReport(_wo.id, range);
      slots.add(_TimeSlot(
        timeRange: range,
        shiftName: shift,
        actualController: TextEditingController(text: existing?.actual.toString() ?? ''),
        ngController: TextEditingController(text: existing?.ng.toString() ?? ''),
        localId: existing?.id,
        synced: existing?.synced ?? false,
      ));
    }
    
    if (!mounted) return;
    setState(() => _slots = slots);
    _recalcTotals();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = _slots.indexWhere((s) => _isCurrentSlot(s.timeRange));
      if (index != -1 && _scrollController.hasClients) {
        _scrollController.animateTo(
          index * 110.0, 
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
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
        const SnackBar(content: Text('WO dimulai!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal start: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _saveSlot(_TimeSlot slot) async {
    final actual = int.tryParse(slot.actualController.text) ?? 0;
    final ng = int.tryParse(slot.ngController.text) ?? 0;
    final targetPerSlot = _slots.isNotEmpty ? (_wo.qtyPlanned / 24).round() : 0;

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

  void _showDowntimeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('ALASAN DOWNTIME', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _downtimeReasons.length,
                    itemBuilder: (c, i) {
                      final reason = _downtimeReasons[i];
                      return ListTile(
                        leading: _getReasonIcon(reason),
                        title: Text(reason, style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _startDowntime(reason);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Icon _getReasonIcon(String reason) {
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
        icon = Icons.warning;
        color = Colors.amber;
    }
    return Icon(icon, color: color);
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
      id: newId, machineId: dt.machineId, machineName: dt.machineName,
      shift: dt.shift, operatorName: dt.operatorName, startTime: dt.startTime,
      reason: dt.reason, productionOrderId: dt.productionOrderId,
    );
    setState(() => _activeDowntime = saved);
    _startDowntimeCounter(saved);
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
    setState(() { _activeDowntime = null; _downtimeSeconds = 0; });
    await _loadDowntimeState();
  }

  String _formatSeconds(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  int get _totalDowntimeMinutes {
    int total = _todayDowntimes.where((d) => d.reason != 'Istirahat').fold(0, (sum, d) => sum + (d.durationMinutes ?? 0));
    if (_activeDowntime != null && _activeDowntime!.reason != 'Istirahat') {
      total += _downtimeSeconds ~/ 60;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final isDown = _activeDowntime != null;
    final progress = _wo.progressPercent;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: isDown ? const Color(0xFF7F1D1D) : const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_wo.woNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            Text('${_wo.partNo ?? '-'} • ${_wo.partName ?? '-'}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Color(0xFF3B82F6)),
            onPressed: () async {
              final ok = await SyncService.attemptSync();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Sync Berhasil ✓' : 'Sync Gagal ✗')));
              }
            },
          ),
        ],
      ),
      floatingActionButton: _wo.isRunning
          ? FloatingActionButton.extended(
              onPressed: isDown ? _stopDowntime : _showDowntimeSheet,
              icon: Icon(isDown ? Icons.play_arrow : Icons.warning_amber_rounded),
              label: Text(isDown ? 'MESIN JALAN' : 'CATAT DOWNTIME', style: const TextStyle(fontWeight: FontWeight.w900)),
              backgroundColor: isDown ? Colors.green : Colors.red,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Column(
        children: [
          if (isDown)
            Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: _activeDowntime?.reason == 'Istirahat' ? Colors.blue : Colors.red,
              child: Row(
                children: [
                  Icon(_activeDowntime?.reason == 'Istirahat' ? Icons.free_breakfast : Icons.warning, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_activeDowntime!.reason.toUpperCase()} — ${_formatSeconds(_downtimeSeconds)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            )
          else if (_wo.isRunning)
            Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: const Color(0xFF15803D),
              child: const Row(
                children: [
                  Icon(Icons.play_circle_filled, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'STATUS: PRODUKSI BERJALAN (RUNNING)',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryTile(label: 'TARGET', value: _wo.qtyPlanned.toInt().toString(), color: Colors.white),
                    _SummaryTile(label: 'ACTUAL', value: _wo.qtyActual.toInt().toString(), color: Colors.green),
                    _SummaryTile(label: 'REMAINING', value: (_wo.qtyPlanned - _wo.qtyActual).toInt().toString(), color: Colors.amber),
                    _SummaryTile(label: 'DOWNTIME', value: '${_totalDowntimeMinutes}m', color: Colors.orange),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress / 100, backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation(progress >= 100 ? Colors.green : Colors.blue)),
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerRight, child: Text('${progress.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold))),
                if (_wo.canStart) ...[
                   const SizedBox(height: 12),
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton(
                       onPressed: _starting ? null : _startWo,
                       style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                       child: const Text('MULAI PRODUKSI', style: TextStyle(fontWeight: FontWeight.bold)),
                     ),
                   )
                ]
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: _slots.length,
              itemBuilder: (ctx, i) {
                final slot = _slots[i];
                final isCurrent = _isCurrentSlot(slot.timeRange);
                final showHeader = i == 0 || _slots[i].shiftName != _slots[i-1].shiftName;
                
                return Column(
                  children: [
                    if (showHeader)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Text(slot.shiftName, style: TextStyle(color: slot.shiftName == widget.shift ? Colors.amber : Colors.white24, fontWeight: FontWeight.bold)),
                            const Expanded(child: Divider(indent: 8, color: Colors.white10)),
                          ],
                        ),
                      ),
                    Card(
                      color: isCurrent ? const Color(0xFF334155) : const Color(0xFF1E293B),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: isCurrent ? const BorderSide(color: Colors.blue, width: 2) : BorderSide.none),
                      child: ListTile(
                        title: Text(slot.timeRange, style: TextStyle(color: isCurrent ? Colors.white : Colors.white70, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                        subtitle: isCurrent ? const Text('Jam Sekarang', style: TextStyle(color: Colors.blue, fontSize: 10)) : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _CompactInput(controller: slot.actualController, label: 'OK', color: Colors.green),
                            const SizedBox(width: 8),
                            _CompactInput(controller: slot.ngController, label: 'NG', color: Colors.red),
                            IconButton(
                              icon: Icon(slot.synced ? Icons.cloud_done : Icons.save, color: slot.synced ? Colors.green : Colors.blue),
                              onPressed: () => _saveSlot(slot),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isCurrentSlot(String timeRange) {
    final parts = timeRange.split('-');
    if (parts.length != 2) return false;
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    final start = _parseTime(parts[0]);
    final end = _parseTime(parts[1]);
    if (start == null || end == null) return false;
    return end > start ? (nowMin >= start && nowMin < end) : (nowMin >= start || nowMin < end);
  }

  int? _parseTime(String t) {
    final p = t.trim().split(':'); if (p.length != 2) return null;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }
}

class _TimeSlot {
  final String timeRange;
  final String shiftName;
  final TextEditingController actualController;
  final TextEditingController ngController;
  int? localId;
  bool synced;
  _TimeSlot({required this.timeRange, required this.shiftName, required this.actualController, required this.ngController, this.localId, this.synced = false});
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryTile({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _CompactInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color color;
  const _CompactInput({required this.controller, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          labelText: label, labelStyle: const TextStyle(fontSize: 10),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
        ),
      ),
    );
  }
}
