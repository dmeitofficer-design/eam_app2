// lib/features/clients/presentation/screens/client_form_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/hospital_client.dart';
import '../../data/repositories/clients_repository.dart';

class ClientFormSheet extends StatefulWidget {
  const ClientFormSheet({super.key, this.client});
  final HospitalClient? client;

  static Future<HospitalClient?> show(
    BuildContext context, {
    HospitalClient? client,
  }) {
    return showModalBottomSheet<HospitalClient>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RepositoryProvider.value(
        value: context.read<ClientsRepository>(), // Fixed: Changed to RepositoryProvider
        child: ClientFormSheet(client: client),
      ),
    );
  }

  @override
  State<ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends State<ClientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final _nameCtrl         = TextEditingController(text: widget.client?.name);
  late final _addressCtrl      = TextEditingController(text: widget.client?.address);
  late final _districtCtrl     = TextEditingController(text: widget.client?.district); // Added
  late final _contactNameCtrl  = TextEditingController(text: widget.client?.contactPersonName);
  late final _contactDesigCtrl = TextEditingController(text: widget.client?.contactPersonDesignation);
  late final _contactPhoneCtrl = TextEditingController(text: widget.client?.contactPersonPhone);

  DivisionType _division     = DivisionType.dhaka;
  FacilityType _facilityType = FacilityType.hospital;

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _division     = widget.client!.division;
      _facilityType = widget.client!.facilityType;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _districtCtrl.dispose(); // Added
    _contactNameCtrl.dispose();
    _contactDesigCtrl.dispose();
    _contactPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final repo = context.read<ClientsRepository>();
      final draft = HospitalClient(
        id: widget.client?.id ?? '',
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        division: _division,
        district: _districtCtrl.text.trim(),
        genre: widget.client?.genre ?? 'General',
        facilityType: _facilityType,
        contactPersonName: _contactNameCtrl.text.trim(),
        contactPersonDesignation: _contactDesigCtrl.text.trim(),
        contactPersonPhone: _contactPhoneCtrl.text.trim(),
        createdAt: widget.client?.createdAt ?? DateTime.now(),
      );

      final result = widget.client == null
          ? await repo.createClient(draft)
          : await repo.updateClient(draft);

      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.client != null;

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
                isEdit ? 'Edit Client' : 'New Client',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xl),

              const _FieldLabel('Facility Name'),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'e.g. Dhaka Medical College Hospital'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              const _FieldLabel('Address'),
              TextFormField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Full address'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
Row(
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Division'),
          DropdownButtonFormField<DivisionType>(
            value: _division,
            isExpanded: true, // 1. FIX: Forces the dropdown row content to stay inside its layout bounds
            decoration: const InputDecoration(),
            dropdownColor: AppColors.surface1,
            items: DivisionType.values
                .map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(
                        d.label,
                        overflow: TextOverflow.ellipsis, // 2. FIX: Safely truncates text with '...' if it's too long
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _division = v!),
          ),
        ],
      ),
    ),
    const SizedBox(width: AppSpacing.sm),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Facility Type'),
          DropdownButtonFormField<FacilityType>(
            value: _facilityType,
            isExpanded: true, // Apply here too to safeguard against long facility names
            decoration: const InputDecoration(),
            dropdownColor: AppColors.surface1,
            items: FacilityType.values
                .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(
                        f.label,
                        overflow: TextOverflow.ellipsis, // Safeguard text truncation
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _facilityType = v!),
          ),
        ],
      ),
    ),
  ],
),
              const SizedBox(height: AppSpacing.md),

              // Added District Field
              const _FieldLabel('District'),
              TextFormField(
                controller: _districtCtrl,
                decoration: const InputDecoration(hintText: 'e.g. Gazipur'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              const Divider(),
              const SizedBox(height: AppSpacing.md),

              Text('Contact Person', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),

              const _FieldLabel('Full Name'),
              TextFormField(
                controller: _contactNameCtrl,
                decoration: const InputDecoration(hintText: 'e.g. Dr. Kamal Hossain'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              const _FieldLabel('Designation'),
              TextFormField(
                controller: _contactDesigCtrl,
                decoration: const InputDecoration(hintText: 'e.g. Head of Radiology'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              const _FieldLabel('Phone Number'),
              TextFormField(
                controller: _contactPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: 'e.g. 017XXXXXXXX'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.xl),

  SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: _saving ? null : _submit,
    // BULLETPROOF FIX: Forces the StadiumBorder across all button interaction states
    style: ElevatedButton.styleFrom(
      shape: const StadiumBorder(),
    ).copyWith(
      shape: WidgetStateProperty.all(const StadiumBorder()),
    ),
    child: _saving 
        ? const SizedBox(
            height: 20, 
            width: 20, 
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Text(isEdit ? 'Save Changes' : 'Create Client'),
  ),
),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}