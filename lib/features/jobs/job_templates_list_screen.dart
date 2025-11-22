import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_card.dart';
import '../../data/models/job_template.dart';
import '../../data/repositories/job_template_repo.dart';
import '../../data/services/api_client.dart';
import '../home/home_screen.dart';
import 'edit_job_template_screen.dart';

final jobTemplatesListProvider = FutureProvider<List<JobTemplate>>((ref) async {
  final repo = ref.watch(jobTemplateRepoProvider);
  return repo.getAll();
});

class JobTemplatesListScreen extends ConsumerWidget {
  const JobTemplatesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(jobTemplatesListProvider);

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
        title: const Text('Job Templates'),
      ),
      body: templates.when(
        data: (templatesList) {
          if (templatesList.isEmpty) {
            return const Center(child: Text('No templates found'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(jobTemplatesListProvider),
            child: ListView.builder(
              itemCount: templatesList.length,
              itemBuilder: (context, index) {
                final template = templatesList[index];
                return AppCard(
                  child: ListTile(
                    title: Text(template.description),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Price: \$${template.defaultPrice.toStringAsFixed(2)}'),
                        Text('Tax: ${template.defaultTaxPct}%'),
                        if (template.defaultNotes != null) Text(template.defaultNotes!),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => context.push('/jobs/${template.id}/edit'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Template'),
                                content: Text('Are you sure you want to delete ${template.description}?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              try {
                                final repo = ref.read(jobTemplateRepoProvider);
                                await repo.delete(template.id);
                                ref.invalidate(jobTemplatesListProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template deleted')));
                                }
                              } catch (e) {
                                if (context.mounted) {
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/jobs/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

