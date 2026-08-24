// lib/widgets/alert_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/medicine_alert.dart'; // 👈 ใช้ model ที่ถูกต้อง
import '../state/medicine_actions.dart';

class AlertSheet extends ConsumerStatefulWidget {
  final String id;
  const AlertSheet({super.key, required this.id});

  @override
  ConsumerState<AlertSheet> createState() => _AlertSheetState();
}

class _AlertSheetState extends ConsumerState<AlertSheet> {
  final _form = GlobalKey<FormState>();
  bool _enabled = true;
  final _minQty = TextEditingController();
  final _expWin = TextEditingController();

  @override
  void dispose() {
    _minQty.dispose();
    _expWin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final a = MedicineAlert(
      enabled: _enabled,
      minQty: _minQty.text.trim().isEmpty
          ? null
          : int.parse(_minQty.text.trim()),
      expiryWindowDays: _expWin.text.trim().isEmpty
          ? null
          : int.parse(_expWin.text.trim()),
    );
    await ref.read(alertUpdateProvider((widget.id, a)).future);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('อัปเดตการเตือนแล้ว')));
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
                Text(
                  'ตั้งเตือน',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  title: const Text('เปิดการเตือน'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _minQty,
                  decoration: const InputDecoration(
                    labelText: 'แจ้งเตือนเมื่อคงเหลือ ≤ (ชิ้น)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if ((v ?? '').isEmpty) return null;
                    final t = int.tryParse(v!);
                    if (t == null || t < 0) return 'ตัวเลขไม่ถูกต้อง';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _expWin,
                  decoration: const InputDecoration(
                    labelText: 'แจ้งเตือนเมื่อเหลือวันหมดอายุ ≤ (วัน)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if ((v ?? '').isEmpty) return null;
                    final t = int.tryParse(v!);
                    if (t == null || t < 0) return 'ตัวเลขไม่ถูกต้อง';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check),
                    label: const Text('บันทึก'),
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
