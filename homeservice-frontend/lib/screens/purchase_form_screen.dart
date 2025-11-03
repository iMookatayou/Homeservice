import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/purchase_actions.dart'; 

enum PurchaseFormMode { create, edit }

class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({
    super.key,
    this.mode = PurchaseFormMode.create,
    this.id,
  });

  final PurchaseFormMode mode;
  final String? id;

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _amount = TextEditingController();

  final _fnTitle = FocusNode();
  final _fnNote = FocusNode();
  final _fnAmount = FocusNode();

  String _currency = 'THB';
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _amount.dispose();
    _fnTitle.dispose();
    _fnNote.dispose();
    _fnAmount.dispose();
    super.dispose();
  }

  String? _validateTitle(String? v) {
    if (v == null || v.trim().isEmpty) return 'กรอกหัวข้อรายการ';
    if (v.trim().length < 3) return 'อย่างน้อย 3 ตัวอักษร';
    return null;
  }

  String? _validateAmount(String? v) {
    if (v == null || v.trim().isEmpty) return null; 
    final parsed = double.tryParse(v.trim());
    if (parsed == null) return 'ตัวเลขไม่ถูกต้อง';
    if (parsed < 0) return 'ต้องมากกว่า 0';
    return null;
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      await Future.delayed(const Duration(milliseconds: 80));
      _scrollToFirstError();
      return;
    }

    final amountEstimated = _amount.text.trim().isEmpty
        ? null
        : double.tryParse(_amount.text.trim());

    final payload = CreatePurchasePayload(
      title: _title.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      amountEstimated: amountEstimated,
      currency: _currency,
    );

    setState(() => _submitting = true);
    try {
      final created = await ref.read(createPurchaseProvider(payload).future);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('สร้างรายการสำเร็จ')));

      context.go('/purchases/${created.id}');
    } catch (e) {
      var message = 'เกิดข้อผิดพลาด';
      final t = e.runtimeType.toString();
      if (t == 'AuthRequired') {
        message = 'กรุณาเข้าสู่ระบบ';
      } else if (t == 'ApiError') {
        message = e.toString();
      } else {
        message = e.toString();
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _scrollToFirstError() {
    if (_validateTitle(_title.text) != null) {
      _fnTitle.requestFocus();
    } else if (_validateAmount(_amount.text) != null) {
      _fnAmount.requestFocus();
    }
  }

  // จำกัดตัวเลข + จุดเดียว
  final _amountFormatter = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
  ];

  @override
  Widget build(BuildContext context) {
    const spacing = 16.0;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == PurchaseFormMode.create
              ? 'Create Purchase'
              : 'Edit Purchase',
        ),
        actions: [
          TextButton(
            onPressed: _submitting
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    context.pop();
                  },
            child: const Text('ยกเลิก'),
          ),
        ],
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _submitting, 
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(spacing),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                // หัวข้อส่วน
                Text(
                  'รายละเอียดรายการ',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _title,
                          focusNode: _fnTitle,
                          decoration: const InputDecoration(
                            labelText: 'Title *',
                            hintText: 'เช่น “ซื้ออุปกรณ์ทำความสะอาด”',
                            prefixIcon: Icon(Icons.assignment_outlined),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: _validateTitle,
                          onFieldSubmitted: (_) =>
                              _fnNote.requestFocus(), // next ไป Note
                        ),
                        const SizedBox(height: spacing),
                        TextFormField(
                          controller: _note,
                          focusNode: _fnNote,
                          decoration: const InputDecoration(
                            labelText: 'Note',
                            hintText: 'รายละเอียดเพิ่มเติม (ไม่บังคับ)',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                          minLines: 3,
                          maxLines: 6,
                          keyboardType: TextInputType.multiline,
                          maxLength: 500,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: spacing),

                Text(
                  'งบประมาณคร่าว ๆ',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _amount,
                          focusNode: _fnAmount,
                          decoration: InputDecoration(
                            labelText: 'Estimated Amount',
                            hintText: 'เช่น 1,500 หรือ 1500',
                            prefixIcon: const Icon(Icons.payments_outlined),
                            suffixText: _currency,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: _amountFormatter,
                          validator: _validateAmount,
                          onFieldSubmitted: (_) => _handleSubmit(),
                        ),
                        const SizedBox(height: 12),
                        // เลือกสกุลเงินแบบ SegmentedButton ใช้ง่าย เร็ว
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Currency',
                                style: theme.textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'THB',
                                    label: Text('THB'),
                                  ),
                                  ButtonSegment(
                                    value: 'USD',
                                    label: Text('USD'),
                                  ),
                                  ButtonSegment(
                                    value: 'EUR',
                                    label: Text('EUR'),
                                  ),
                                ],
                                selected: {_currency},
                                onSelectionChanged: (s) {
                                  setState(() => _currency = s.first);
                                },
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'ใส่ได้หรือเว้นว่างถ้ายังไม่แน่ใจ',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 120), // เผื่อพื้นที่เหนือปุ่มล่าง
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(_submitting ? 'กำลังบันทึก…' : 'บันทึก'),
            ),
            onPressed: _submitting ? null : _handleSubmit,
          ),
        ),
      ),
    );
  }
}
