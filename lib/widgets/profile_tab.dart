import 'package:flutter/material.dart';
import '../utils/formatter.dart';
import 'custom_pull_to_refresh.dart';

class ProfileTab extends StatefulWidget {
  final String driverName;
  final String driverEmail;
  final String driverPhone;
  final double driverBalance;
  final String driverId;
  final bool isDarkMode;
  final bool isRefreshing;
  final Color titleColor;
  final Color subTitleColor;
  final Color cardBg;
  final Color dividerColor;

  final VoidCallback onLogoutTap;
  final Future<void> Function() onRefresh;
  final Future<Map<String, dynamic>> Function(String bank, String acc, double amount) onWithdraw;

  const ProfileTab({
    super.key,
    required this.driverName,
    required this.driverEmail,
    required this.driverPhone,
    required this.driverBalance,
    required this.driverId,
    required this.isDarkMode,
    required this.isRefreshing,
    required this.titleColor,
    required this.subTitleColor,
    required this.cardBg,
    required this.dividerColor,
    required this.onLogoutTap,
    required this.onRefresh,
    required this.onWithdraw,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedBank;
  final _accController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _banks = ['BCA', 'BRI', 'Mandiri', 'BNI', 'GoPay', 'Dana'];

  @override
  void dispose() {
    _accController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _showWithdrawBottomSheet(BuildContext context) {
    _accController.clear();
    _amountController.clear();
    setState(() {
      _selectedBank = null;
      _isSubmitting = false;
    });

    final Color inputTextColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final Color labelColor = widget.isDarkMode ? Colors.white70 : Colors.black54;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: widget.isDarkMode ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Simulasi Penarikan Dana',
                        style: TextStyle(
                          color: widget.titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Saldo saat ini: Rp ${formatPrice(widget.driverBalance.toString().split('.')[0])}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Dropdown Pilihan Bank
                      DropdownButtonFormField<String>(
                        value: _selectedBank,
                        dropdownColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(color: inputTextColor, fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'Pilih Bank / E-Wallet',
                          labelStyle: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          prefixIcon: Icon(Icons.account_balance, color: labelColor),
                        ),
                        items: _banks.map((bank) {
                          return DropdownMenuItem(
                            value: bank,
                            child: Text(bank),
                          );
                        }).toList(),
                        validator: (val) => val == null ? 'Bank wajib dipilih' : null,
                        onChanged: (val) {
                          setModalState(() {
                            _selectedBank = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Nomor Rekening
                      TextFormField(
                        controller: _accController,
                        style: TextStyle(color: inputTextColor, fontSize: 14, fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Nomor Rekening / No. HP',
                          labelStyle: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          prefixIcon: Icon(Icons.numbers, color: labelColor),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Nomor rekening tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Nominal Penarikan
                      TextFormField(
                        controller: _amountController,
                        style: TextStyle(color: inputTextColor, fontSize: 14, fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Nominal Penarikan (Rupiah)',
                          labelStyle: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          prefixIcon: Icon(Icons.monetization_on, color: labelColor),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Nominal tidak boleh kosong';
                          }
                          final amount = double.tryParse(val);
                          if (amount == null || amount <= 0) {
                            return 'Masukkan nominal angka yang valid';
                          }
                          if (amount > widget.driverBalance) {
                            return 'Nominal melebihi saldo saat ini';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // Konfirmasi Penarikan Button
                      ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                if (_formKey.currentState!.validate()) {
                                  setModalState(() {
                                    _isSubmitting = true;
                                  });

                                  final bank = _selectedBank!;
                                  final acc = _accController.text.trim();
                                  final amount = double.parse(_amountController.text.trim());

                                  try {
                                    final result = await widget.onWithdraw(bank, acc, amount);
                                    Navigator.pop(context); // Close bottom sheet

                                    if (result['success'] == true) {
                                      _showSuccessDialog(context, bank, acc, amount);
                                    } else {
                                      _showErrorSnackBar(context, result['message'] ?? 'Penarikan gagal');
                                    }
                                  } catch (e) {
                                    Navigator.pop(context);
                                    _showErrorSnackBar(context, 'Terjadi kesalahan koneksi server');
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCC5900),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Konfirmasi Penarikan',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context, String bank, String acc, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 72,
              ),
              const SizedBox(height: 20),
              Text(
                'Penarikan Sukses!',
                style: TextStyle(
                  color: widget.titleColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Penarikan Dana Berhasil!\nDana simulasi sebesar Rp ${formatPrice(amount.toString().split('.')[0])} sedang dikirim ke rekening $bank ($acc) Anda (Demo Mode).',
                style: TextStyle(
                  color: widget.subTitleColor,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  widget.onRefresh(); // Trigger parent refresh
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC5900),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomPullToRefresh(
      isRefreshing: widget.isRefreshing,
      onRefresh: widget.onRefresh,
      subTitleColor: widget.subTitleColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header layout with driver avatar and ID Badge
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: widget.isDarkMode ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    child: Icon(
                      Icons.person,
                      color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.driverName,
                    style: TextStyle(color: widget.titleColor, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Driver ID: ${widget.driverId}',
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.amber : Colors.amber.shade900, 
                        fontSize: 13, 
                        fontWeight: FontWeight.w800, 
                        fontFamily: 'monospace'
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Wirojek Wallet Premium Container
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF002B93),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF002B93).withOpacity(0.24),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'WIROJEK WALLET',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Saldo Dompet Saat Ini',
                    style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${formatPrice(widget.driverBalance.toString().split('.')[0])}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _showWithdrawBottomSheet(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCC5900),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payments_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Tarik Dana / Withdrawal',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Profile Details Card Form
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: widget.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INFORMASI AKUN',
                    style: TextStyle(color: widget.subTitleColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                  const SizedBox(height: 24),
                  
                  buildDetailRow(Icons.person, 'Nama Lengkap', widget.driverName, widget.titleColor, widget.subTitleColor),
                  const SizedBox(height: 16),
                  buildDetailRow(Icons.email, 'Alamat Email', widget.driverEmail, widget.titleColor, widget.subTitleColor),
                  const SizedBox(height: 16),
                  buildDetailRow(Icons.phone, 'Nomor HP', widget.driverPhone, widget.titleColor, widget.subTitleColor),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Logout Button
            ElevatedButton(
              onPressed: widget.onLogoutTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                foregroundColor: Colors.redAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Keluar dari Aplikasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDetailRow(IconData icon, String label, String value, Color titleColor, Color subTitleColor) {
    return Row(
      children: [
        Icon(icon, color: subTitleColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: subTitleColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: titleColor, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}
