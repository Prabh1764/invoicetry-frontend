import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/job_template.dart';
import '../../data/repositories/job_template_repo.dart';
import '../../data/services/api_client.dart';
import '../home/home_screen.dart';

final jobTemplateForEditProvider = FutureProvider.family<JobTemplate?, String>((ref, id) async {
  if (id == 'new') return null;
  final repo = ref.watch(jobTemplateRepoProvider);
  return repo.getById(id);
});

class EditJobTemplateScreen extends ConsumerStatefulWidget {
  final String? templateId;

  const EditJobTemplateScreen({super.key, this.templateId});

  @override
  ConsumerState<EditJobTemplateScreen> createState() => _EditJobTemplateScreenState();
}

class _EditJobTemplateScreenState extends ConsumerState<EditJobTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _taxPctController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    _taxPctController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final repo = ref.read(jobTemplateRepoProvider);
      final template = JobTemplate(
        id: widget.templateId ?? '',
        description: _descriptionController.text,
        defaultPrice: double.tryParse(_priceController.text) ?? 0,
        defaultTaxPct: double.tryParse(_taxPctController.text) ?? 0,
        defaultNotes: _notesController.text.isEmpty ? null : _notesController.text,
      );
      if (widget.templateId == null || widget.templateId == 'new') {
        await repo.create(template);
      } else {
        await repo.update(widget.templateId!, template);
      }
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.templateId != null ? ref.watch(jobTemplateForEditProvider(widget.templateId!)) : null;

    template?.when(
      data: (t) {
        if (t != null && _descriptionController.text.isEmpty) {
          _descriptionController.text = t.description;
          _priceController.text = t.defaultPrice.toString();
          _taxPctController.text = t.defaultTaxPct.toString();
          _notesController.text = t.defaultNotes ?? '';
        }
      },
      loading: () {},
      error: (_, __) {},
    );

    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.templateId == null ? 'New Template' : 'Edit Template'),
        automaticallyImplyLeading: canPop,
        leading: canPop ? const BackButton() : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description *'),
              validator: (value) => value?.isEmpty ?? true ? 'Description is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Default Price'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _taxPctController,
              decoration: const InputDecoration(labelText: 'Default Tax %'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Default Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

