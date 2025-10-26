import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../state/bills_provider.dart';

class BillFormScreen extends ConsumerStatefulWidget {
  const BillFormScreen({super.key});

  @override
  ConsumerState<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends ConsumerState<BillFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  String _type = 'electric';
  String _status = 'unpaid';
  DateTime? _due;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d != null) {
      // ตั้งเวลา default เป็น 23:59 ของวันนั้น
      _due = DateTime(d.year, d.month, d.day, 23, 59);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(billCreateProvider);
    final dateLabel = _due == null
        ? 'เลือกวันที่ครบกำหนด'
        : DateFormat('yyyy-MM-dd 23:59').format(_due!);

    return Scaffold(
      appBar: AppBar(title: const Text('New Bill')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Type
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'electric', child: Text('electric')),
                  DropdownMenuItem(value: 'water', child: Text('water')),
                  DropdownMenuItem(value: 'internet', child: Text('internet')),
                  DropdownMenuItem(value: 'phone', child: Text('phone')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'electric'),
              ),
              const SizedBox(height: 12),

              // Title
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'กรอกชื่อบิล' : null,
              ),
              const SizedBox(height: 12),

              // Amount
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount (THB)'),
                validator: (v) {
                  final x = double.tryParse((v ?? '').trim());
                  if (x == null) return 'จำนวนเงินไม่ถูกต้อง';
                  if (x <= 0) return 'จำนวนเงินต้องมากกว่า 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Due date
              InkWell(
                onTap: _pickDueDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Due date'),
                  child: Text(
                    dateLabel,
                    style: TextStyle(
                      color: _due == null
                          ? Colors.black.withOpacity(.45)
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Status
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'unpaid', child: Text('unpaid')),
                  DropdownMenuItem(value: 'paid', child: Text('paid')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'unpaid'),
              ),
              const SizedBox(height: 12),

              // Note
              TextFormField(
                controller: _note,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 20),

              // Submit
              FilledButton.icon(
                onPressed: createState.isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        if (_due == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('กรุณาเลือก Due date'),
                            ),
                          );
                          return;
                        }
                        if (_due!.isBefore(DateTime.now())) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Due date ต้องไม่เป็นอดีต'),
                            ),
                          );
                          return;
                        }

                        await ref
                            .read(billCreateProvider.notifier)
                            .submit(
                              type: _type,
                              title: _title.text.trim(),
                              amount: double.parse(_amount.text.trim()),
                              dueDate: _due!,
                              status: _status,
                              note: _note.text.trim().isEmpty
                                  ? null
                                  : _note.text.trim(),
                            );

                        final s = ref.read(billCreateProvider);
                        if (mounted && !s.hasError) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('สร้างบิลสำเร็จ')),
                          );
                          Navigator.of(context).pop(true);
                        } else if (mounted && s.hasError) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('${s.error}')));
                        }
                      },
                icon: createState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('บันทึก'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
