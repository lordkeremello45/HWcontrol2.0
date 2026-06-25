import 'dart:convert';
import 'dart:io';
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
  Socket? _socket;
  String _status = "Bağlı Değil";
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectToBridge();
  }

  // Go Bridge Servisine Bağlan
  Future<void> _connectToBridge() async {
    try {
      _socket = await Socket.connect('127.0.0.1', 8080);
      setState(() {
        _isConnected = true;
        _status = "Bridge Aktif";
      });
    } catch (e) {
      setState(() => _status = "Bağlantı Hatası: $e");
    }
  }

  // Komut Gönder
  void _sendCommand(String action, double value) {
    if (_socket != null) {
      final cmd = jsonEncode({'action': action, 'value': value});
      _socket!.writeln(cmd);
    }
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
            _buildControlCard("Fan Hızı", Icons. вентилятор, 50.0),
            _buildControlCard("AI İşlem Gücü", Icons.memory, 80.0),
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
              onPressed: () => _sendCommand(title, value),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
              child: const Text("Uygula"),
            ),
          ],
        ),
      ),
    );
  }
}
