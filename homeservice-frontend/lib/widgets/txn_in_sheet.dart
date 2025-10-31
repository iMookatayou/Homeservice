import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/medicine_api.dart';
import '../../state/medicine_actions.dart';

class TxnInSheet extends ConsumerStatefulWidget {
  final String id;
  const TxnInSheet({super.key, required this.id});

  @override
  ConsumerState<TxnInSheet> createState() => _TxnInSheetState();
}

class _TxnInSheetState extends ConsumerState<TxnInSheet> {
  final _form = GlobalKey<FormState>();
  final _lot = TextEditingController();
  final _exp = TextEditingController(); // YYYY-MM-DD
  final _qty = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _lot.dispose();
    _exp.dispose();
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final qty = int.parse(_qty.text.trim());
    final p = TxnInPayload(
      lotNo: _lot.text.trim().isEmpty ? null : _lot.text.trim(),
      expiryDate: _exp.text.trim().isEmpty ? null : _exp.text.trim(),
      qty: qty,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    await ref.read(txnInProvider((widget.id, p)).future);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('รับเข้าสต็อกแล้ว')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text('รับเข้า', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lot,
                  decoration: const InputDecoration(
                    labelText: 'เลขล็อต (ถ้ามี)',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _exp,
                  decoration: const InputDecoration(
                    labelText: 'วันหมดอายุ (YYYY-MM-DD)',
                  ),
                  keyboardType: TextInputType.datetime,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'จำนวน (ชิ้น)'),
                  validator: (v) {
                    final t = int.tryParse(v ?? '');
                    if (t == null || t <= 0) return 'ใส่จำนวนให้ถูกต้อง';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: 'บันทึก (ถ้ามี)',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check),
                    label: const Text('ยืนยัน'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
