import 'package:flutter/material.dart';
import 'wo_list_screen.dart';
import 'qdc_timer_screen.dart';
import 'machine_select_screen.dart';
import '../services/sync_service.dart';
import 'downtime_report_screen.dart';

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
  @override
  void initState() {
    super.initState();
    SyncService.startAutoSync();
  }

  @override
  void dispose() {
    SyncService.stopAutoSync();
    super.dispose();
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
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

            // Menu label
            const Text(
              'MENU',
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
                    subtitle: 'Pilih & Monitor WO',
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
                    label: 'Downtime Report',
                    subtitle: 'Riwayat downtime hari ini',
                    color: const Color(0xFFEF4444),
                    onTap: () => _navigateTo(DowntimeReportScreen(
                      machineId: widget.machineId,
                      machineName: widget.machineName,
                    )),
                  ),
                  _MenuCard(
                    icon: Icons.timer,
                    label: 'QDC Timer',
                    subtitle: 'Die Change',
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
                    subtitle: 'Upload ke Server',
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
