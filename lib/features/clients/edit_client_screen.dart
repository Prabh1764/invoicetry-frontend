import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/client.dart';
import '../../data/repositories/client_repo.dart';
import '../../data/services/api_client.dart';
import '../home/home_screen.dart';

final clientForEditProvider = FutureProvider.family<Client?, String>((ref, id) async {
  if (id == 'new') return null;
  final repo = ref.watch(clientRepoProvider);
  return repo.getById(id);
});

class EditClientScreen extends ConsumerStatefulWidget {
  final String? clientId;

  const EditClientScreen({super.key, this.clientId});

  @override
  ConsumerState<EditClientScreen> createState() => _EditClientScreenState();
}

class _EditClientScreenState extends ConsumerState<EditClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _companyController = TextEditingController();
  final _logoUrlController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _companyController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final repo = ref.read(clientRepoProvider);
      final client = Client(
        id: widget.clientId ?? '',
        name: _nameController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        address: _addressController.text.isEmpty ? null : _addressController.text,
        company: _companyController.text.isEmpty ? null : _companyController.text,
        logoUrl: _logoUrlController.text.isEmpty ? null : _logoUrlController.text,
        createdAt: DateTime.now(),
      );
      if (widget.clientId == null || widget.clientId == 'new') {
        await repo.create(client);
      } else {
        await repo.update(widget.clientId!, client);
      }
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.clientId != null ? ref.watch(clientForEditProvider(widget.clientId!)) : null;

    client?.when(
      data: (c) {
        if (c != null && _nameController.text.isEmpty) {
          _nameController.text = c.name;
          _emailController.text = c.email ?? '';
          _phoneController.text = c.phone ?? '';
          _addressController.text = c.address ?? '';
          _companyController.text = c.company ?? '';
          _logoUrlController.text = c.logoUrl ?? '';
        }
      },
      loading: () {},
      error: (_, __) {},
    );

    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.clientId == null ? 'New Client' : 'Edit Client'),
        automaticallyImplyLeading: canPop,
        leading: canPop ? const BackButton() : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: (value) => value?.isEmpty ?? true ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(labelText: 'Company'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _logoUrlController,
              decoration: const InputDecoration(labelText: 'Logo URL'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

