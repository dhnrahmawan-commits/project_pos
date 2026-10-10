import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'login_screen.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ESBPOSHomeScreen(),
  ));
}

class ESBPOSHomeScreen extends StatefulWidget {
  const ESBPOSHomeScreen({super.key});

  @override
  State<ESBPOSHomeScreen> createState() => _ESBPOSHomeScreenState();
}

class _ESBPOSHomeScreenState extends State<ESBPOSHomeScreen> {
  List<Product> _products = [];
  final List<CartItem> _cart = [];
  
  String _outletName = "Tahu Go! Citra Harmoni";
  String _cashierName = "Belum Login";
  String _deviceId = "Device 02";
  bool _isLoggedIn = false;

  final String _managerPin = "1234";
  String _selectedPaymentMethod = 'Cash';
  final List<String> _paymentMethods = ['Cash', 'Gopay', 'Qris', 'Gofood', 'Grabfood', 'Gojek'];

  String _orderType = '';
  final formatRupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadProducts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDeviceLogin();
    });
  }

  void _loadProducts() async {
    final data = await DatabaseHelper.instance.getProducts();
    setState(() {
      _products = data;
    });
  }

  void _startDeviceLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );

    if (result != null && result is Map<String, String>) {
      setState(() {
        _deviceId = result['deviceId'] ?? 'Device 02';
        _cashierName = result['cashierName'] ?? 'Kasir';
        _isLoggedIn = true;
      });
    }
  }

  Future<bool> _verifyManagerPIN(String titleMessage) async {
    final pinController = TextEditingController();
    bool isAuthorized = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Otorisasi PIN Manajer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titleMessage),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(labelText: 'Masukkan PIN (1234)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (pinController.text == _managerPin) {
                isAuthorized = true;
                Navigator.pop(ctx);
              }
            },
            child: const Text('Verifikasi'),
          )
        ],
      ),
    );
    return isAuthorized;
  }

  void _voidCartItem(int index) async {
    final item = _cart[index];
    bool authorized = await _verifyManagerPIN('Void Item: ${item.product.name}');
    if (!authorized) return;

    if (!mounted) return;
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Alasan Void'),
        content: TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Keterangan Void')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonController.text.isNotEmpty) {
                await DatabaseHelper.instance.logVoid(item.product.name, reasonController.text, _cashierName);
                setState(() { _cart.removeAt(index); });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Konfirmasi Void', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _processPayment() async {
    if (_cart.isEmpty) return;
    await DatabaseHelper.instance.saveTransactionWithPayment(_selectedPaymentMethod, _totalPrice, _cart);
    setState(() { _cart.clear(); _orderType = ''; });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pembayaran via $_selectedPaymentMethod Berhasil!')));
  }

  void _openRecapPage() async {
    final recapData = await DatabaseHelper.instance.getRecapData();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => RecapDetailPage(recapData: recapData, outletName: _outletName, cashierName: _cashierName)));
  }

  void _handleShiftAction() async {
    bool authorized = await _verifyManagerPIN('Akhiri / Ganti Shift Kasir');
    if (!authorized) return;
    setState(() { _isLoggedIn = false; _cart.clear(); _orderType = ''; });
    _startDeviceLogin();
  }

  double get _totalPrice => _cart.fold(0, (sum, item) => sum + item.subtotal);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
            decoration: const BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (value) {
                            if (value == 'shift') _handleShiftAction();
                            if (value == 'recap') _openRecapPage();
                          },
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem(value: 'shift', child: Text('Ganti Shift / Akhiri Shift')),
                            const PopupMenuItem(value: 'recap', child: Text('Detail Rekapitulasi')),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_outletName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(_cashierName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const Text('Shift Open ✓', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          Text(_deviceId, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          const Text(' | ', style: TextStyle(color: Colors.white54)),
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: _isLoggedIn ? Colors.green : Colors.red, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(_isLoggedIn ? 'Online' : 'Offline', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                      icon: const Icon(Icons.grid_view),
                      label: const Text('Transaksi Baru', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        if (!_isLoggedIn) {
                          _startDeviceLogin();
                        } else {
                          setState(() => _orderType = 'Dine-In');
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _orderType.isEmpty
                ? Center(child: Text('Pilih "Transaksi Baru" untuk memulai', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)))
                : Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                          itemCount: _products.length,
                          itemBuilder: (ctx, idx) {
                            final product = _products[idx];
                            return Card(
                              child: InkWell(
                                onTap: () => setState(() => _cart.add(CartItem(product: product))),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(formatRupiah.format(product.price), style: const TextStyle(color: Colors.green)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: DropdownButtonFormField<String>(
                                value: _selectedPaymentMethod,
                                decoration: const InputDecoration(labelText: 'Metode Pembayaran', border: OutlineInputBorder()),
                                items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _cart.length,
                                itemBuilder: (ctx, idx) {
                                  final item = _cart[idx];
                                  return ListTile(
                                    title: Text(item.product.name),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(formatRupiah.format(item.subtotal)),
                                        IconButton(
                                          icon: const Icon(Icons.lock_outline, color: Colors.red, size: 18),
                                          onPressed: () => _voidCartItem(idx),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.white,
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Total:'),
                                      Text(formatRupiah.format(_totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                      onPressed: _cart.isNotEmpty ? _processPayment : null,
                                      child: const Text('BAYAR', style: TextStyle(color: Colors.white)),
                                    ),
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
          )
        ],
      ),
    );
  }
}

class RecapDetailPage extends StatelessWidget {
  final Map<String, dynamic> recapData;
  final String outletName;
  final String cashierName;

  const RecapDetailPage({super.key, required this.recapData, required this.outletName, required this.cashierName});

  @override
  Widget build(BuildContext context) {
    final formatRupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final Map<String, double> omsetPerPayment = recapData['omset'] ?? {};
    final Map<String, List<Map<String, dynamic>>> itemsPerPayment = recapData['items'] ?? {};
    double grandTotal = omsetPerPayment.values.fold(0, (sum, val) => sum + val);

    return Scaffold(
      appBar: AppBar(title: const Text('Hasil Rekapitulasi', style: TextStyle(color: Colors.white)), backgroundColor: Colors.blue),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Outlet: $outletName', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Kasir: $cashierName'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('1. Rekapitulasi Omset Sesuai Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ...['Cash', 'Gopay', 'Qris', 'Gofood', 'Grabfood', 'Gojek'].map((method) {
                    double amount = omsetPerPayment[method] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(method),
                          Text(formatRupiah.format(amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }),
                  const Divider(thickness: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL OMSET', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      Text(formatRupiah.format(grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('2. Detail Penjualan Menu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          ...['Cash', 'Gopay', 'Qris', 'Gofood', 'Grabfood', 'Gojek'].map((method) {
            List items = itemsPerPayment[method] ?? [];
            if (items.isEmpty) return const SizedBox.shrink();
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment: $method', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    const Divider(),
                    ...items.map((item) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${item['name']} (x${item['qty']})'),
                          Text(formatRupiah.format(item['total_price'])),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
