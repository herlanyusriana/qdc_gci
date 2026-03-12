import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'machine_select_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    if (_loginCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Username dan password harus diisi');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiService.login(_loginCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MachineSelectScreen()),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.precision_manufacturing,
                  size: 80, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                'GCI Production',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'QDC Operator App',
                style: TextStyle(fontSize: 16, color: Colors.white54),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _loginCtrl,
                style: const TextStyle(fontSize: 18, color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Username / Email',
                  labelStyle: const TextStyle(color: Colors.white60),
                  prefixIcon:
                      const Icon(Icons.person, color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                style: const TextStyle(fontSize: 18, color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: Colors.white60),
                  prefixIcon:
                      const Icon(Icons.lock, color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _login(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('LOGIN',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
