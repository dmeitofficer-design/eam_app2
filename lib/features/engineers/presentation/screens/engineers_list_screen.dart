// lib/features/engineers/presentation/screens/engineers_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../machines/data/models/engineer.dart'; 
import '../bloc/engineers_bloc.dart'; 

class EngineersListScreen extends StatefulWidget {
  const EngineersListScreen({super.key});

  @override
  State<EngineersListScreen> createState() => _EngineersListScreenState();
}

class _EngineersListScreenState extends State<EngineersListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<EngineersBloc>().add(EngineersFetchAll());
  }

  void _showAddEngineerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final machineIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Register New Engineer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number (Optional)'),
            ),
            TextField(
              controller: machineIdController,
              decoration: const InputDecoration(labelText: 'Machine ID (Optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final String machineIdText = machineIdController.text.trim();
                
                final newEngineer = Engineer(
                  id: '', 
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                  isAvailable: true, // Default to available
                  machineId: machineIdText.isEmpty ? null : machineIdText,
                  createdAt: DateTime.now(),
                );

                context.read<EngineersBloc>().add(EngineersCreateRequested(newEngineer));
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Engineer engineer) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Engineer Profile'),
          content: Text(
            'Are you sure you want to remove ${engineer.name}? This will clear them from any active field records.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<EngineersBloc>().add(EngineersDeleteRequested(engineer.id));
                Navigator.of(dialogContext).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${engineer.name} removed successfully.')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Engineers Directory')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEngineerDialog,
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
      body: BlocConsumer<EngineersBloc, EngineersState>(
        listener: (context, state) {
          if (state is EngineersError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${state.message}'), backgroundColor: Colors.red),
            );
          } else if (state is EngineersActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.green),
            );
          }
        },
        builder: (context, state) {
          if (state is EngineersLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          List<Engineer> engineersList = [];
          if (state is EngineersLoaded) {
            engineersList = state.engineers;
          } else if (state is EngineersActionSuccess) {
            engineersList = state.engineers;
          }

          if (engineersList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No engineers found.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: engineersList.length,
            itemBuilder: (context, index) {
              final eng = engineersList[index];
              final isAvailable = eng.isAvailable;
              
              final Color statusColor = isAvailable ? Colors.green : Colors.orange;
              final Color backgroundColor = isAvailable ? Colors.green.shade100 : Colors.orange.shade100;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: backgroundColor,
                  child: Icon(
                    isAvailable ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                    color: statusColor,
                  ),
                ),
                title: Text(eng.name),
                subtitle: Text(eng.phone ?? 'No phone listed'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        eng.statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      tooltip: 'Delete Engineer',
                      onPressed: () => _confirmDelete(context, eng),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}