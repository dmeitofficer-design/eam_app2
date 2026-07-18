// lib/features/engineers/presentation/screens/engineer_form_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../machines/data/models/engineer.dart';
import '../../../machines/data/repositories/machines_repository.dart';
import '../../../machines/presentation/bloc/machines_bloc.dart';
import '../bloc/engineers_bloc.dart';

class EngineerFormSheet extends StatefulWidget {
  const EngineerFormSheet({
    super.key,
    this.machineId, 
    this.engineer,
  });

  final String? machineId; 
  final Engineer? engineer;

  /// Shows the bottom sheet. After save, refreshes the machine detail
  /// via [MachinesBloc.MachineFetchByIdRequested].
  static Future<void> show(
    BuildContext context, {
    String? machineId, 
    Engineer? engineer,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<MachinesBloc>()),
          BlocProvider.value(value: context.read<EngineersBloc>()),
        ],
        child: EngineerFormSheet(machineId: machineId, engineer: engineer), 
      ),
    );
  }

  @override
  State<EngineerFormSheet> createState() => _EngineerFormSheetState();
}

class _EngineerFormSheetState extends State<EngineerFormSheet> {
  final _formKey   = GlobalKey<FormState>();
  bool _saving     = false;
  late final _nameCtrl  = TextEditingController(text: widget.engineer?.name ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.engineer?.phone ?? '');
  late bool _isAvailable = widget.engineer?.isAvailable ?? true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final engineersBloc = context.read<EngineersBloc>();
      final machinesBloc  = context.read<MachinesBloc>();

      final engineer = Engineer(
        id: widget.engineer?.id ?? '',
        machineId: widget.machineId,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        isAvailable: _isAvailable,
        createdAt: widget.engineer?.createdAt ?? DateTime.now(),
      );

      if (widget.engineer == null) {
        engineersBloc.add(EngineersCreateRequested(engineer));
      } else {
        engineersBloc.add(EngineersUpdateRequested(engineer));
      }

      // Wait a tick, then refresh the machine detail if it exists
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        if (widget.machineId != null) {
          machinesBloc.add(MachineFetchByIdRequested(widget.machineId!));
        }
        
        Navigator.of(context).pop();
        AppFeedback.success(
          context,
          widget.engineer == null
              ? 'Engineer added.'
              : 'Engineer updated.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, e.toString());
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isEdit = widget.engineer != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surface3,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                isEdit ? 'Edit Engineer' : 'Add Engineer',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Full name
              Text('FULL NAME',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    color: AppColors.textTertiary,
                  )),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration:
                    const InputDecoration(hintText: 'e.g. Rakib Hasan'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Contact Number
              Text('CONTACT NUMBER',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    color: AppColors.textTertiary,
                  )),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'e.g. +880 1XXXXXXXXX',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Status Toggle (Available / On Assignment)
              Text('AVAILABILITY',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    color: AppColors.textTertiary,
                  )),
              const SizedBox(height: AppSpacing.xs),
              
              SwitchListTile(
                title: Text(
                  _isAvailable ? 'Available for assignment' : 'Currently on duty',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                ),
                subtitle: Text(
                  _isAvailable ? 'Can be immediately assigned' : 'Occupied with setup/support',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                ),
                value: _isAvailable,
                activeColor: Colors.blue,
                activeTrackColor: Colors.blue.withOpacity(0.3),
                inactiveThumbColor: Colors.orange,
                inactiveTrackColor: Colors.orange.withOpacity(0.3),
                contentPadding: EdgeInsets.zero,
                onChanged: (bool value) {
                  setState(() {
                    _isAvailable = value;
                  });
                },
              ),

              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEdit ? 'Save Changes' : 'Add Engineer'),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}