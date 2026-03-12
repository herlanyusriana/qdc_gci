import 'dart:async';
import 'package:flutter/material.dart';
import '../models/qdc_session.dart';
import '../services/database_service.dart';

class QdcTimerScreen extends StatefulWidget {
  final int machineId;
  final String machineName;
  final String shift;
  final String operatorName;

  const QdcTimerScreen({
    super.key,
    required this.machineId,
    required this.machineName,
    required this.shift,
    required this.operatorName,
  });

  @override
  State<QdcTimerScreen> createState() => _QdcTimerScreenState();
}

class _QdcTimerScreenState extends State<QdcTimerScreen> {
  final _partFromCtrl = TextEditingController();
  final _partToCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _running = false;
  DateTime? _startTime;
  int _elapsedSeconds = 0;
  Timer? _timer;

  // Phase tracking: internal vs external
  String _currentPhase = 'internal'; // 'internal' or 'external'
  int _internalSeconds = 0;
  int _externalSeconds = 0;

  // History
  List<QdcSession> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _partFromCtrl.dispose();
    _partToCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final sessions =
        await DatabaseService.getTodayQdcSessions(widget.machineId);
    if (!mounted) return;
    setState(() => _history = sessions);
  }

  void _startTimer() {
    if (_partFromCtrl.text.isEmpty && _partToCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Isi minimal Part Dari atau Part Tujuan'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _running = true;
      _startTime = DateTime.now();
      _elapsedSeconds = 0;
      _internalSeconds = 0;
      _externalSeconds = 0;
      _currentPhase = 'internal';
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
        if (_currentPhase == 'internal') {
          _internalSeconds++;
        } else {
          _externalSeconds++;
        }
      });
    });
  }

  void _switchPhase() {
    setState(() {
      _currentPhase =
          _currentPhase == 'internal' ? 'external' : 'internal';
    });
  }

  Future<void> _stopTimer() async {
    _timer?.cancel();
    final endTime = DateTime.now();

    final session = QdcSession(
      id: 0,
      machineId: widget.machineId,
      machineName: widget.machineName,
      shift: widget.shift,
      operatorName: widget.operatorName,
      partFrom: _partFromCtrl.text.isNotEmpty ? _partFromCtrl.text : null,
      partTo: _partToCtrl.text.isNotEmpty ? _partToCtrl.text : null,
      startTime: _startTime!.toIso8601String(),
      endTime: endTime.toIso8601String(),
      durationSeconds: _elapsedSeconds,
      internalSeconds: _internalSeconds,
      externalSeconds: _externalSeconds,
      notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
    );

    await DatabaseService.insertQdcSession(session);
    await _loadHistory();

    if (!mounted) return;
    setState(() {
      _running = false;
      _startTime = null;
    });

    _partFromCtrl.clear();
    _partToCtrl.clear();
    _notesCtrl.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('QDC Session disimpan ✓'),
          backgroundColor: Color(0xFF22C55E)),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
            const Text('QDC Timer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text('${widget.machineName} • ${widget.shift}',
                style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Timer display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _running
                      ? [const Color(0xFFDC2626), const Color(0xFFEA580C)]
                      : [const Color(0xFF1E293B), const Color(0xFF334155)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: _running
                    ? [
                        BoxShadow(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2)
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  const Icon(Icons.timer, color: Colors.white54, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    _formatDuration(_elapsedSeconds),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (_running) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _currentPhase == 'internal'
                            ? '🔧 INTERNAL ACTIVITY'
                            : '📦 EXTERNAL ACTIVITY',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PhaseChip(
                            label: 'Internal',
                            seconds: _internalSeconds,
                            active: _currentPhase == 'internal',
                            color: const Color(0xFFFBBF24)),
                        const SizedBox(width: 16),
                        _PhaseChip(
                            label: 'External',
                            seconds: _externalSeconds,
                            active: _currentPhase == 'external',
                            color: const Color(0xFF60A5FA)),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Input fields
            if (!_running) ...[
              TextField(
                controller: _partFromCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Part Dari (sebelumnya)',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon:
                      const Icon(Icons.output, color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _partToCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Part Tujuan (yang mau dijalankan)',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon:
                      const Icon(Icons.input, color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Catatan (opsional)',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon:
                      const Icon(Icons.notes, color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                if (!_running)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _startTimer,
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: const Text('MULAI DIE CHANGE',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                if (_running) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _switchPhase,
                      icon: const Icon(Icons.swap_horiz, size: 24),
                      label: Text(
                        _currentPhase == 'internal'
                            ? 'KE EXTERNAL'
                            : 'KE INTERNAL',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _stopTimer,
                      icon: const Icon(Icons.stop, size: 28),
                      label: const Text('SELESAI',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 28),

            // History
            if (_history.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('RIWAYAT HARI INI',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
              ),
              const SizedBox(height: 10),
              ..._history.map((s) => Card(
                    color: const Color(0xFF1E293B),
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.timer,
                                color: Color(0xFFF59E0B), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${s.partFrom ?? '?'} → ${s.partTo ?? '?'}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Int: ${_formatDuration(s.internalSeconds)} • Ext: ${_formatDuration(s.externalSeconds)}',
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                s.formattedDuration,
                                style: const TextStyle(
                                    color: Color(0xFFF59E0B),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900),
                              ),
                              Icon(
                                s.synced
                                    ? Icons.cloud_done
                                    : Icons.cloud_off,
                                color: s.synced
                                    ? const Color(0xFF22C55E)
                                    : Colors.white24,
                                size: 16,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  final String label;
  final int seconds;
  final bool active;
  final Color color;

  const _PhaseChip({
    required this.label,
    required this.seconds,
    required this.active,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: active ? Border.all(color: color, width: 1.5) : null,
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: active ? color : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
          Text(
              '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
              style: TextStyle(
                  color: active ? color : Colors.white24,
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
