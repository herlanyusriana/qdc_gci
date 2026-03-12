import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/downtime.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'machine_select_screen.dart';

const List<String> downtimeReasons = [
  'Refill Material',
  'Material Kendor/Jatuh',
  'Perbaikan Coil',
  'Ganti Tipe/Setting',
  'Breakdown Mesin',
  'Tunggu Material',
  'Quality Check',
  'Cleaning',
  'Lainnya',
];

class DashboardScreen extends StatefulWidget {
  final int machineId;
  final String machineName;
  final String machineCode;
  final String shift;
  final String operatorName;

  const DashboardScreen({
    super.key,
    required this.machineId,
    required this.machineName,
    required this.machineCode,
    required this.shift,
    required this.operatorName,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _clockTimer;
  String _currentTime = '';
  Downtime? _activeDowntime;
  List<Downtime> _todayDowntimes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _loadData();
    SyncService.startAutoSync();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    SyncService.stopAutoSync();
    super.dispose();
  }

  void _updateClock() {
    if (!mounted) return;
    setState(() {
      _currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
    });
  }

  Future<void> _loadData() async {
    final active = await DatabaseService.getActiveDowntime(widget.machineId);
    final today = await DatabaseService.getTodayDowntimes(widget.machineId);
    if (!mounted) return;
    setState(() {
      _activeDowntime = active;
      _todayDowntimes = today;
      _loading = false;
    });
  }

  int _totalDowntimeMinutes() {
    int total = 0;
    for (final dt in _todayDowntimes) {
      total += dt.durationMinutes ?? 0;
    }
    return total;
  }

  Future<void> _startDowntime(
    String reason,
    String? notes, {
    String? refillPartNo,
    String? refillPartName,
    double? refillQty,
  }) async {
    final now = DateTime.now();
    final dt = Downtime(
      id: 0,
      machineId: widget.machineId,
      machineName: widget.machineName,
      shift: widget.shift,
      operatorName: widget.operatorName,
      startTime: now.toIso8601String(),
      reason: reason,
      notes: notes,
      refillPartNo: refillPartNo,
      refillPartName: refillPartName,
      refillQty: refillQty,
    );
    await DatabaseService.insertDowntime(dt);
    await _loadData();
  }

  Future<void> _stopDowntime() async {
    if (_activeDowntime == null) return;
    final now = DateTime.now();
    final start = DateTime.parse(_activeDowntime!.startTime);
    final duration = now.difference(start).inMinutes;

    await DatabaseService.updateDowntime(_activeDowntime!.id, {
      'endTime': now.toIso8601String(),
      'durationMinutes': duration,
    });
    await _loadData();
    SyncService.attemptSync();
  }

  void _showStopReasonDialog() {
    String? selectedReason;
    final notesCtrl = TextEditingController();
    bool showCustomNotes = false;

    // Refill material state
    bool showRefill = false;
    List<Map<String, dynamic>> partResults = [];
    Map<String, dynamic>? selectedPart;
    final searchCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    bool searching = false;
    Timer? debounce;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void searchParts(String query) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 400), () async {
              setModalState(() => searching = true);
              try {
                final results = await ApiService.searchParts(query);
                if (ctx.mounted) {
                  setModalState(() {
                    partResults = results;
                    searching = false;
                  });
                }
              } catch (_) {
                if (ctx.mounted) setModalState(() => searching = false);
              }
            });
          }

          bool canConfirm() {
            if (selectedReason == null) return false;
            if (showRefill && (selectedPart == null || qtyCtrl.text.trim().isEmpty)) {
              return false;
            }
            return true;
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ALASAN MESIN STOP',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ...downtimeReasons.map((reason) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setModalState(() {
                              selectedReason = reason;
                              showCustomNotes = reason == 'Lainnya';
                              showRefill = reason == 'Refill Material';
                              if (!showRefill) {
                                selectedPart = null;
                                qtyCtrl.clear();
                                searchCtrl.clear();
                                partResults = [];
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: selectedReason == reason
                                  ? const Color(0xFF4F46E5)
                                  : const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedReason == reason
                                    ? const Color(0xFF6366F1)
                                    : Colors.white10,
                              ),
                            ),
                            child: Text(
                              reason,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: selectedReason == reason
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      )),

                  // Refill Material form
                  if (showRefill) ...[
                    const SizedBox(height: 8),
                    const Text('PILIH PART RM',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        )),
                    const SizedBox(height: 6),
                    if (selectedPart != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF6366F1)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedPart!['part_no'] ?? '',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  if (selectedPart!['part_name'] != null)
                                    Text(
                                      selectedPart!['part_name'],
                                      style: const TextStyle(
                                          color: Colors.white60, fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white54, size: 20),
                              onPressed: () => setModalState(() {
                                selectedPart = null;
                                searchCtrl.clear();
                              }),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      TextField(
                        controller: searchCtrl,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        onChanged: searchParts,
                        decoration: InputDecoration(
                          hintText: 'Cari part no / nama...',
                          hintStyle:
                              const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search,
                              color: Colors.white54, size: 20),
                          suffixIcon: searching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white38),
                                  ),
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFF334155),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      if (partResults.isNotEmpty)
                        Container(
                          constraints:
                              const BoxConstraints(maxHeight: 150),
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: partResults.length,
                            itemBuilder: (_, i) {
                              final p = partResults[i];
                              return InkWell(
                                onTap: () {
                                  setModalState(() {
                                    selectedPart = p;
                                    partResults = [];
                                    searchCtrl.text =
                                        p['part_no'] ?? '';
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p['part_no'] ?? '-',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  fontSize: 13),
                                            ),
                                            if (p['part_name'] != null)
                                              Text(
                                                p['part_name'],
                                                style: const TextStyle(
                                                    color:
                                                        Colors.white38,
                                                    fontSize: 11),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (p['size'] != null)
                                        Text(p['size'],
                                            style: const TextStyle(
                                                color: Colors.white24,
                                                fontSize: 11)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    const Text('QTY',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        )),
                    const SizedBox(height: 6),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16),
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Jumlah...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF334155),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ],

                  if (showCustomNotes) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesCtrl,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Tulis keterangan...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF334155),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: !canConfirm()
                          ? null
                          : () {
                              Navigator.of(ctx).pop();
                              _startDowntime(
                                selectedReason!,
                                showCustomNotes ? notesCtrl.text : null,
                                refillPartNo: selectedPart?['part_no'],
                                refillPartName: selectedPart?['part_name'],
                                refillQty: qtyCtrl.text.isNotEmpty
                                    ? double.tryParse(qtyCtrl.text)
                                    : null,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        disabledBackgroundColor: Colors.grey.shade800,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'KONFIRMASI STOP',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _finishShift() async {
    // If downtime is active, force stop it first
    if (_activeDowntime != null) {
      await _stopDowntime();
    }

    // Attempt sync
    final synced = await SyncService.attemptSync();

    if (!mounted) return;

    final unsyncedCount =
        _todayDowntimes.where((d) => !d.synced && d.endTime != null).length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'RINGKASAN SHIFT',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ShiftSummaryRow(
              label: 'Mesin',
              value: widget.machineName,
            ),
            _ShiftSummaryRow(
              label: 'Shift',
              value: widget.shift,
            ),
            _ShiftSummaryRow(
              label: 'Operator',
              value: widget.operatorName,
            ),
            const Divider(color: Colors.white24, height: 24),
            _ShiftSummaryRow(
              label: 'Total Stop',
              value:
                  '${_todayDowntimes.where((d) => !d.isRunning).length}x',
              valueColor: Colors.orange,
            ),
            _ShiftSummaryRow(
              label: 'Total Downtime',
              value: '${_totalDowntimeMinutes()} menit',
              valueColor: Colors.red,
            ),
            const Divider(color: Colors.white24, height: 24),
            Row(
              children: [
                Icon(
                  synced && unsyncedCount == 0
                      ? Icons.cloud_done
                      : Icons.cloud_off,
                  color: synced && unsyncedCount == 0
                      ? Colors.green
                      : Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    synced && unsyncedCount == 0
                        ? 'Semua data sudah tersinkronisasi'
                        : '$unsyncedCount data belum tersinkronisasi',
                    style: TextStyle(
                      color: synced && unsyncedCount == 0
                          ? Colors.green
                          : Colors.amber,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!synced || unsyncedCount > 0)
            TextButton(
              onPressed: () async {
                await SyncService.attemptSync();
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  _finishShift(); // retry
                }
              },
              child: const Text('COBA SYNC LAGI',
                  style: TextStyle(color: Colors.amber)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('BATAL',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (_) => const MachineSelectScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('SELESAI',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStopped = _activeDowntime != null;

    return Scaffold(
      backgroundColor:
          isStopped ? const Color(0xFF450A0A) : const Color(0xFF0F172A),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
              child: Column(
                children: [
                  // ─── Header info bar ───
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    color: const Color(0xFF1E293B),
                    child: Row(
                      children: [
                        // Machine + shift + operator
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.machineName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.shift}  •  ${widget.operatorName}',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                        // Live clock
                        Text(
                          _currentTime,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── Status bar ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    color: isStopped
                        ? Colors.red.shade900
                        : Colors.green.shade900,
                    child: Row(
                      children: [
                        Icon(
                          isStopped
                              ? Icons.pause_circle
                              : Icons.play_circle,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isStopped
                                ? 'MESIN STOP - ${_activeDowntime!.reason}'
                                : 'MESIN BERJALAN',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (isStopped)
                          _RunningTimer(
                              startTime: DateTime.parse(
                                  _activeDowntime!.startTime)),
                      ],
                    ),
                  ),

                  // ─── Summary cards ───
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        _SummaryCard(
                          label: 'Total Stop',
                          value:
                              '${_todayDowntimes.where((d) => !d.isRunning).length}x',
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 10),
                        _SummaryCard(
                          label: 'Total Downtime',
                          value: '${_totalDowntimeMinutes()} mnt',
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ─── History header ───
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'RIWAYAT HARI INI',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white54,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ─── History list (scrollable) ───
                  Expanded(
                    child: _todayDowntimes.isEmpty
                        ? const Center(
                            child: Text(
                              'Belum ada downtime hari ini',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _todayDowntimes.length,
                            itemBuilder: (context, index) {
                              final dt = _todayDowntimes[index];
                              final start = DateTime.parse(dt.startTime);
                              final startStr =
                                  DateFormat('HH:mm').format(start);
                              final endStr = dt.endTime != null
                                  ? DateFormat('HH:mm')
                                      .format(DateTime.parse(dt.endTime!))
                                  : 'Berlangsung...';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: dt.isRunning
                                        ? Colors.red.shade800
                                        : Colors.white10,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: dt.isRunning
                                            ? Colors.red
                                            : dt.synced
                                                ? Colors.green
                                                : Colors.amber,
                                        borderRadius:
                                            BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dt.reason,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (dt.notes != null &&
                                              dt.notes!.isNotEmpty)
                                            Text(
                                              dt.notes!,
                                              style: const TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 11),
                                            ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$startStr - $endStr',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (dt.durationMinutes != null)
                                          Text(
                                            '${dt.durationMinutes} mnt',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                        if (dt.isRunning)
                                          _RunningTimer(
                                              startTime: start),
                                        Icon(
                                          dt.synced
                                              ? Icons.cloud_done
                                              : Icons.cloud_off,
                                          color: dt.synced
                                              ? Colors.green
                                              : Colors.white24,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // ─── Bottom action bar (sticky) ───
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Selesai Shift button
                        SizedBox(
                          height: 60,
                          child: OutlinedButton.icon(
                            onPressed: _finishShift,
                            icon: const Icon(Icons.logout, size: 22),
                            label: const Text(
                              'SELESAI\nSHIFT',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Main action button
                        Expanded(
                          child: SizedBox(
                            height: 60,
                            child: ElevatedButton.icon(
                              onPressed: isStopped
                                  ? _stopDowntime
                                  : _showStopReasonDialog,
                              icon: Icon(
                                isStopped ? Icons.play_arrow : Icons.stop,
                                size: 32,
                              ),
                              label: Text(
                                isStopped ? 'START MESIN' : 'MESIN STOP',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isStopped
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(16)),
                                elevation: 6,
                              ),
                            ),
                          ),
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

class _ShiftSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ShiftSummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunningTimer extends StatefulWidget {
  final DateTime startTime;
  const _RunningTimer({required this.startTime});

  @override
  State<_RunningTimer> createState() => _RunningTimerState();
}

class _RunningTimerState extends State<_RunningTimer> {
  Timer? _timer;
  String _elapsed = '0:00';

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _update() {
    final diff = DateTime.now().difference(widget.startTime);
    final min = diff.inMinutes;
    final sec = diff.inSeconds % 60;
    if (!mounted) return;
    setState(() {
      _elapsed = '$min:${sec.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _elapsed,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: Colors.amber,
        fontFamily: 'monospace',
      ),
    );
  }
}
