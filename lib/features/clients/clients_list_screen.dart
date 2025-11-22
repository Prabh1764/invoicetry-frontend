import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_card.dart';
import '../../data/models/client.dart';
import '../../data/repositories/client_repo.dart';
import '../../data/services/api_client.dart';
import '../home/home_screen.dart';
import 'edit_client_screen.dart';

final clientsListProvider = FutureProvider<List<Client>>((ref) async {
  final repo = ref.watch(clientRepoProvider);
  return repo.getAll();
});

class ClientsListScreen extends ConsumerStatefulWidget {
  const ClientsListScreen({super.key});

  @override
  ConsumerState<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends ConsumerState<ClientsListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsListProvider);

    final navigator = Navigator.of(context);
    final canPop = navigator.canPop();

    void handleBack() {
      if (canPop) {
        navigator.pop();
      } else {
        context.go('/home');
      }
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: handleBack,
        ),
        title: const Text('Clients'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                ref.invalidate(clientsListProvider);
              },
            ),
          ),
          Expanded(
            child: clients.when(
              data: (clientsList) {
                final filtered = _searchController.text.isEmpty
                    ? clientsList
                    : clientsList.where((c) => c.name.toLowerCase().contains(_searchController.text.toLowerCase())).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No clients found'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(clientsListProvider),
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final client = filtered[index];
                      return AppCard(
                        child: ListTile(
                          title: Text(client.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (client.email != null) Text(client.email!),
                              if (client.phone != null) Text(client.phone!),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => context.push('/clients/${client.id}/edit'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Client'),
                                      content: Text('Are you sure you want to delete ${client.name}?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    try {
                                      final repo = ref.read(clientRepoProvider);
                                      await repo.delete(client.id);
                                      ref.invalidate(clientsListProvider);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client deleted')));
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                      }
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/clients/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

