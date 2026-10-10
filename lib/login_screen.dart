import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'database_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isScanned = false;
  final String _currentDeviceId = "Device 02"; // ID Perangkat ini

  void _onQRScanned(String qrCode) {
    if (_isScanned) return;
    _isScanned = true;

    List<String> data = qrCode.split('|');
    if (data.length == 2) {
      Navigator.pop(context, {
        'role': 'Cashier',
        'deviceId': data[0].trim(),
        'cashierName': data[1].trim(),
      });
    } else {
      _isScanned = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format QR Code Kasir Tidak Valid!')),
      );
    }
  }

  void _showManagerKeyDialog() {
    final keyController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Login Keys (Manajer Eksklusif)'),
        content: TextField(
          controller: keyController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Masukkan Key Unik Manajer',
            hintText: 'Contoh: KEY-MGR-01',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              String inputKey = keyController.text.trim();
              
              var validation = await DatabaseHelper.instance.validateAndBindKey(inputKey, _currentDeviceId);

              if (!mounted) return;
              Navigator.pop(ctx);

              if (validation != null && validation['status'] == 'success') {
                Navigator.pop(context, {
                  'role': 'Manager',
                  'deviceId': _currentDeviceId,
                  'cashierName': validation['manager'],
                });
              } else if (validation != null && validation['status'] == 'device_mismatch') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Key ini sudah terikat di perangkat lain (${validation['bound_device']})!')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Key Manajer tidak valid!')),
                );
              }
            },
            child: const Text('Verifikasi Key', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktivasi Perangkat / Login', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _onQRScanned(barcode.rawValue!);
                    break;
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Arahkan kamera ke QR Code Kartu Kasir', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.vpn_key),
                      label: const Text('Login Keys (Manajer Eksklusif)'),
                      onPressed: _showManagerKeyDialog,
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
