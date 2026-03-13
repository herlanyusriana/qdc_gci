import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/downtime.dart';
import '../services/database_service.dart';

class DowntimeReportScreen extends StatefulWidget {
  final int machineId;
  final String machineName;

  const DowntimeReportScreen({
    super.key, 
    required this.machineId,
    required this.machineName,
  });

  @override
  State<DowntimeReportScreen> createState() => _DowntimeReportScreenState();
}

class _DowntimeReportScreenState extends State<DowntimeReportScreen> {
  List<Downtime> _todayDowntimes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    
    // Get all downtimes for today on this machine
    final dt = await DatabaseService.getTodayDowntimes(widget.machineId);
    
    if (!mounted) return;
    setState(() {
      _todayDowntimes = dt.reversed.toList(); // Show newest first
      _loading = false;
    });
  }

  int _totalDowntimeMinutes() {
    return _todayDowntimes.fold(0, (sum, dt) => sum + (dt.durationMinutes ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Downtime Report Today', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFEF4444),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // Summary Card
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Total Downtime Hari Ini',
                            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_totalDowntimeMinutes()} Menit',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Mesin: ${widget.machineName}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // List Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Riwayat Downtime',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            '${_todayDowntimes.length} Kejadian',
                            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // List items
                  _todayDowntimes.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline, size: 64, color: Colors.green.withValues(alpha: 0.5)),
                                const SizedBox(height: 16),
                                const Text(
                                  'Bagus! Tidak ada downtime hari ini.',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final dt = _todayDowntimes[index];
                                return _buildDowntimeCard(dt);
                              },
                              childCount: _todayDowntimes.length,
                            ),
                          ),
                        ),
                ],
              ),
      ),
    );
  }

  Widget _buildDowntimeCard(Downtime dt) {
    final startTime = DateTime.parse(dt.startTime);
    final endTimeStr = dt.endTime != null ? DateFormat('HH:mm').format(DateTime.parse(dt.endTime!)) : 'Running';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: dt.endTime == null ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              dt.endTime == null ? Icons.play_arrow_rounded : Icons.history,
              color: dt.endTime == null ? const Color(0xFFEF4444) : const Color(0xFF64748B),
            ),
          ),
          title: Text(
            dt.reason,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          subtitle: Text(
            '${DateFormat('HH:mm').format(startTime)} - $endTimeStr (${dt.durationMinutes ?? 0} mnt)',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          trailing: dt.synced 
            ? const Icon(Icons.cloud_done, color: Colors.green, size: 20)
            : const Icon(Icons.cloud_off, color: Colors.orange, size: 20),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 72, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dt.productionOrderId != null)
                   _infoRow(Icons.confirmation_number_outlined, 'WO ID: ${dt.productionOrderId}'),
                  if (dt.notes != null && dt.notes!.isNotEmpty)
                    _infoRow(Icons.notes, dt.notes!),
                  if (dt.refillPartNo != null)
                    _infoRow(Icons.inventory_2_outlined, 'Refill: ${dt.refillPartNo} (${dt.refillQty} qty)'),
                  const SizedBox(height: 8),
                  Text(
                    'Operator: ${dt.operatorName}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }
}
