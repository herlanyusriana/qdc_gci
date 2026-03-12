import 'dart:async';
import 'package:flutter/material.dart';
import 'wo_list_screen.dart';
import 'qdc_timer_screen.dart';
import 'machine_select_screen.dart';
import 'hourly_input_screen.dart';
import '../services/sync_service.dart';
import '../services/api_service.dart';
import '../models/work_order.dart';
import 'downtime_report_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  final int machineId;
  final String machineName;
  final String machineCode;
  final String shift;
  final String operatorName;

  const HomeScreen({
    super.key,
    required this.machineId,
    required this.machineName,
    required this.machineCode,
    required this.shift,
    required this.operatorName,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WorkOrder? _activeWo;
  bool _loadingActive = true;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    SyncService.startAutoSync();
    _checkActiveWo();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkActiveWo());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    SyncService.stopAutoSync();
    super.dispose();
  }

  Future<void> _checkActiveWo() async {
    if (!mounted) return;
    setState(() => _loadingActive = true);
    try {
      final orders = await ApiService.getWorkOrders(widget.machineId);
      final active = orders.where((o) => o.status == 'in_production').firstOrNull;
      if (mounted) {
        setState(() {
          _activeWo = active;
          _loadingActive = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingActive = false);
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) => _checkActiveWo());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.machineName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text('${widget.shift}  •  ${widget.operatorName}',
                style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Ganti Mesin',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MachineSelectScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Machine info card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.precision_manufacturing,
                      color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.machineName,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                            '${widget.machineCode}  •  ${widget.shift}',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (!_loadingActive && _activeWo != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AKTIF SEKARANG',
                    style: TextStyle(
                      color: Color(0xFF22C55E),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF22C55E), width: 1),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: Color(0xFF22C55E)),
                        SizedBox(width: 4),
                        Text('LIVE', style: TextStyle(color: Color(0xFF22C55E), fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFF22C55E), width: 2),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _navigateTo(HourlyInputScreen(
                    workOrder: _activeWo!,
                    machineId: widget.machineId,
                    machineName: widget.machineName,
                    shift: widget.shift,
                    operatorName: widget.operatorName,
                  )),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_activeWo!.woNumber,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text('${_activeWo!.partNo} - ${_activeWo!.partName}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.play_circle_filled,
                            color: Color(0xFF22C55E), size: 40),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Menu label
            const Text(
              'MENU UTAMA',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),

            // Menu grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _MenuCard(
                    icon: Icons.assignment,
                    label: 'Work Order',
                    subtitle: 'Daftar WO Hari Ini',
                    color: const Color(0xFF3B82F6),
                    onTap: () => _navigateTo(WoListScreen(
                      machineId: widget.machineId,
                      machineName: widget.machineName,
                      shift: widget.shift,
                      operatorName: widget.operatorName,
                    )),
                  ),
                   _MenuCard(
                    icon: Icons.warning_amber_rounded,
                    label: 'Downtime',
                    subtitle: 'Masalah & Istirahat',
                    color: const Color(0xFFEF4444),
                    onTap: () => _navigateTo(DowntimeReportScreen(
                      machineId: widget.machineId,
                      machineName: widget.machineName,
                    )),
                  ),
                  _MenuCard(
                    icon: Icons.timer,
                    label: 'QDC Timer',
                    subtitle: 'Die Change / Preparation',
                    color: const Color(0xFFF59E0B),
                    onTap: () => _navigateTo(QdcTimerScreen(
                      machineId: widget.machineId,
                      machineName: widget.machineName,
                      shift: widget.shift,
                      operatorName: widget.operatorName,
                    )),
                  ),
                  _MenuCard(
                    icon: Icons.sync,
                    label: 'Sync Data',
                    subtitle: 'Paksa Upload',
                    color: const Color(0xFF10B981),
                    onTap: () async {
                      final ok = await SyncService.attemptSync();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? 'Data berhasil disinkronkan!'
                              : 'Gagal sync, coba lagi nanti'),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ),
                      );
                    },
                  ),
                  _MenuCard(
                    icon: Icons.dashboard_rounded,
                    label: 'Live Monitoring',
                    subtitle: 'Status Mesin & WO',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => _navigateTo(DashboardScreen(
                      machineId: widget.machineId,
                      machineName: widget.machineName,
                      machineCode: widget.machineCode,
                      shift: widget.shift,
                      operatorName: widget.operatorName,
                    )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 14),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
