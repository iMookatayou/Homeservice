import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/medicine_provider.dart';

import '../services/medicine_api.dart'; // ใช้ CreateMedicinePayload จาก service

class MedicineFormScreen extends ConsumerStatefulWidget {
  const MedicineFormScreen({super.key});

  @override
  ConsumerState<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends ConsumerState<MedicineFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _form = TextEditingController();
  final _unit = TextEditingController();
  final _category = TextEditingController();

  String? _locationId;

  @override
  void dispose() {
    _name.dispose();
    _form.dispose();
    _unit.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final payload = CreateMedicinePayload(
      name: _name.text.trim(),
      form: _form.text.trim().isEmpty ? null : _form.text.trim(),
      unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      category: _category.text.trim().isEmpty ? null : _category.text.trim(),
      locationId: _locationId,
    );

    await ref.read(createMedicineProvider(payload).future);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เพิ่มยาเรียบร้อย')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(medicineLocationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('เพิ่มยาใหม่')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อยา',
                    hintText: 'เช่น Paracetamol 500mg',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'กรุณากรอกชื่อยา'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _form,
                  decoration: const InputDecoration(
                    labelText: 'รูปแบบยา (เช่น tablet, syrup)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _unit,
                  decoration: const InputDecoration(
                    labelText: 'หน่วย (เช่น tab, ml)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _category,
                  decoration: const InputDecoration(
                    labelText: 'หมวดหมู่ (เช่น painkiller)',
                  ),
                ),
                const SizedBox(height: 12),

                // Location dropdown
                locationsAsync.when(
                  data: (list) => DropdownButtonFormField<String?>(
                    value: _locationId,
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          '— ไม่ระบุที่เก็บ —',
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                      ),
                      ...list.map(
                        (e) => DropdownMenuItem<String?>(
                          value: e.id,
                          child: Text(e.name ?? e.id),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _locationId = v),
                    decoration: const InputDecoration(labelText: 'ที่เก็บยา'),
                  ),
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (e, st) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('โหลดรายการที่เก็บยาไม่สำเร็จ'),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(medicineLocationsProvider),
                        child: const Text('ลองใหม่'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('บันทึก'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
