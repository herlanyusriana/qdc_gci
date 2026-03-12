import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class MachineSelectScreen extends StatefulWidget {
  const MachineSelectScreen({super.key});

  @override
  State<MachineSelectScreen> createState() => _MachineSelectScreenState();
}

class _MachineSelectScreenState extends State<MachineSelectScreen> {
  List<Map<String, dynamic>> _machines = [];
  bool _loading = true;
  String? _error;
  String _userName = '';
  Map<String, dynamic>? _selectedMachine;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('user_name') ?? '';

    try {
      final machines = await ApiService.getMachines();
      if (!mounted) return;
      setState(() {
        _machines = machines;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _currentShift() {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute; // total minutes since midnight
    if (minutes >= 450 && minutes < 930) return 'Shift 1';   // 07:30 - 15:30
    if (minutes >= 930 && minutes < 1410) return 'Shift 2';  // 15:30 - 23:30
    return 'Shift 3';                                         // 23:30 - 07:30
  }

  Future<void> _start() async {
    if (_selectedMachine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih mesin terlebih dahulu')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          machineId: _selectedMachine!['id'] as int,
          machineName: _selectedMachine!['name'] as String,
          machineCode: _selectedMachine!['code'] as String? ?? '',
          shift: _currentShift(),
          operatorName: _userName,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('GCI Production',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_userName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(_userName,
                    style: const TextStyle(color: Colors.white70)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _load();
                        },
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Shift info
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _currentShift(),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.amber,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _shiftTimeRange(),
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Machine dropdown
                      const Text(
                        'MESIN',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedMachine?['id'] as int?,
                            hint: const Text('Pilih mesin...',
                                style: TextStyle(color: Colors.white38)),
                            isExpanded: true,
                            dropdownColor: const Color(0xFF334155),
                            icon: const Icon(Icons.keyboard_arrow_down,
                                color: Colors.white54),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                            items: _machines.map((m) {
                              return DropdownMenuItem<int>(
                                value: m['id'] as int,
                                child: Row(
                                  children: [
                                    const Icon(Icons.precision_manufacturing,
                                        color: Colors.white54, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        m['name'] ?? '-',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    if (m['code'] != null)
                                      Text(
                                        m['code'],
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (id) {
                              setState(() {
                                _selectedMachine = _machines
                                    .firstWhere((m) => m['id'] == id);
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Operator name (from login)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Colors.amber),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('OPERATOR',
                                    style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1)),
                                Text(_userName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Start button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _start,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          child: const Text('MULAI'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _shiftTimeRange() {
    final shift = _currentShift();
    switch (shift) {
      case 'Shift 1':
        return '07:30 - 15:30';
      case 'Shift 2':
        return '15:30 - 23:30';
      case 'Shift 3':
        return '23:30 - 07:30';
      default:
        return '';
    }
  }
}
