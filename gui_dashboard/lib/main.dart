import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

void main() => runApp(const HWControlApp());

class HWControlApp extends StatelessWidget {
  const HWControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.cyanAccent,
        cardColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.blueAccent,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _sharedKey = String.fromEnvironment('HWCONTROL_KEY');
  Socket? _socket;
  StreamIterator<String>? _responses;
  String _status = 'Bağlı Değil';
  bool _isConnected = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _connectToBridge();
  }

  // Go Bridge Servisine Bağlan
  Future<void> _connectToBridge() async {
    try {
      final socket = await Socket.connect('127.0.0.1', 8080,
          timeout: const Duration(seconds: 3));
      _socket = socket;
      _responses = StreamIterator(
        socket.map(utf8.decode).transform(const LineSplitter()),
      );
      socket.done.whenComplete(() {
        if (!mounted) return;
        setState(() {
          _isConnected = false;
          _status = 'Bağlantı Koptu';
        });
      });
      if (!mounted) return;
      setState(() {
        _isConnected = true;
        _status = 'Bridge Aktif';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Bağlantı Hatası');
    }
  }

  // Komut Gönder
  Future<void> _sendCommand(String action, double value) async {
    final socket = _socket;
    if (!_isConnected || socket == null) {
      setState(() => _status = 'Bridge bağlı değil');
      return;
    }
    if (_isSending) return;
    if (_sharedKey.isEmpty) {
      setState(() => _status = 'Güvenlik anahtarı ayarlı değil');
      return;
    }

    setState(() => _isSending = true);
    try {
      final payload = '$action\n${value.toStringAsFixed(6)}';
      final auth = Hmac(sha256, utf8.encode(_sharedKey))
          .convert(utf8.encode(payload))
          .toString();
      socket.write('${jsonEncode({
        'action': action,
        'value': value,
        'auth': auth,
      })}\n');
      final responses = _responses;
      if (responses == null || !await responses.moveNext().timeout(const Duration(seconds: 3))) {
        throw StateError('Bridge response missing');
      }
      final response = responses.current;
      final payload = jsonDecode(response) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _status = payload['message'] as String? ?? 'Yanıt alındı');
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = 'Bridge yanıt vermedi');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _responses?.cancel();
    _socket?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HWControl 2.0 Dashboard", style: TextStyle(color: Colors.cyanAccent)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 20),
            _buildControlCard('Fan Hızı', Icons.air, 50.0),
            _buildControlCard('AI İşlem Gücü', Icons.memory, 80.0),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.cyanAccent)),
      child: ListTile(
        leading: Icon(Icons.hub, color: _isConnected ? Colors.cyanAccent : Colors.red),
        title: Text("Sistem Durumu", style: TextStyle(color: Colors.white70)),
        trailing: Text(_status, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildControlCard(String title, IconData icon, double value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.cyanAccent),
            Text(title, style: const TextStyle(fontSize: 18, color: Colors.white)),
            ElevatedButton(
              onPressed: _isSending ? null : () => _sendCommand(title, value),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
              child: const Text("Uygula"),
            ),
          ],
        ),
      ),
    );
  }
}
