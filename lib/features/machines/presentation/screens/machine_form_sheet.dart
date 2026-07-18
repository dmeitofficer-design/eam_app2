// lib/features/machines/presentation/screens/machine_form_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/installed_machine.dart';
import '../../data/repositories/machines_repository.dart';

class MachineFormSheet extends StatefulWidget {
  const MachineFormSheet({
    super.key,
    required this.hospitalId,
    this.machine,
  });

  final String hospitalId;
  final InstalledMachine? machine;

  static Future<InstalledMachine?> show(
    BuildContext context, {
    required String hospitalId,
    InstalledMachine? machine,
  }) {
    return showModalBottomSheet<InstalledMachine>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RepositoryProvider.value(
        value: context.read<MachinesRepository>(),
        child: MachineFormSheet(hospitalId: hospitalId, machine: machine),
      ),
    );
  }

  @override
  State<MachineFormSheet> createState() => _MachineFormSheetState();
}

class _MachineFormSheetState extends State<MachineFormSheet> {
  final _formKey   = GlobalKey<FormState>();
  bool _saving     = false;

  late final _brandCtrl    = TextEditingController(text: widget.machine?.brand);
  late final _modelCtrl    = TextEditingController(text: widget.machine?.model);
  late final _serialCtrl   = TextEditingController(text: widget.machine?.serialNumber);
  late final _notesCtrl    = TextEditingController(text: widget.machine?.notes);

  // PC Hardware Controllers
  late final _pcCpuCtrl     = TextEditingController(text: widget.machine?.pcCpu);
  late final _pcRamCtrl     = TextEditingController(text: widget.machine?.pcRam);
  late final _pcStorageCtrl = TextEditingController(text: widget.machine?.pcStorage);
  late final _pcOsCtrl      = TextEditingController(text: widget.machine?.pcOs);

  // Dynamic IP Controller List
  final List<TextEditingController> _ipCtrls = [];

  // ─── TYPE SPECIFIC CONTROLLERS ───────────────────────────────────────
  // Printer Type
  late final _printerAeCtrl         = TextEditingController(text: widget.machine?.printerAe);
  late final _printerIp1Ctrl        = TextEditingController(text: widget.machine?.printerIp1);
  late final _printerIp2Ctrl        = TextEditingController(text: widget.machine?.printerIp2);
  late final _printerPortCtrl       = TextEditingController(text: widget.machine?.printerPort);
  late final _printerPcVerCtrl      = TextEditingController(text: widget.machine?.printerPcVersion);
  late final _printerMbVerCtrl      = TextEditingController(text: widget.machine?.printerMbVersion);
  late final _printerImagerVerCtrl  = TextEditingController(text: widget.machine?.printerImagerVersion);

  // X-ray Type
  late final _xrayConsoleCtrl       = TextEditingController(text: widget.machine?.xrayConsoleSl);
  late final _xrayTubeCtrl          = TextEditingController(text: widget.machine?.xrayTubeSl);
  late final _xrayGeneratorCtrl     = TextEditingController(text: widget.machine?.xrayGeneratorSl);

  // FPD Type
  late final _fpdAcqIdCtrl          = TextEditingController(text: widget.machine?.fpdAcqId);
  late final _fpdSoftwareCtrl       = TextEditingController(text: widget.machine?.fpdSoftware);
  late final _fpdVersionCtrl        = TextEditingController(text: widget.machine?.fpdVersion);
  late final _fpdModuleCtrl         = TextEditingController(text: widget.machine?.fpdModule);
  late final _fpdLicenseCtrl        = TextEditingController(text: widget.machine?.fpdLicense);

  // Dynamic Scalable Attributes
  final List<MapEntry<TextEditingController, TextEditingController>> _customFields = [];

  MachineType _machineType    = MachineType.xRay;
  int _warrantyPeriod         = 12; // months
  DateTime _installationDate  = DateTime.now();

  final _fmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    if (widget.machine != null) {
      _machineType       = widget.machine!.machineType;
      _warrantyPeriod    = widget.machine!.warrantyPeriod;
      _installationDate  = widget.machine!.installationDate;

      for (var ip in widget.machine!.assignedIps) {
        _ipCtrls.add(TextEditingController(text: ip));
      }

      // Populate custom scalable parameters if present
      widget.machine!.customMetadata.forEach((key, value) {
        _customFields.add(MapEntry(
          TextEditingController(text: key),
          TextEditingController(text: value),
        ));
      });
    }

    if (_ipCtrls.isEmpty) {
      _ipCtrls.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    _notesCtrl.dispose();
    _pcCpuCtrl.dispose();
    _pcRamCtrl.dispose();
    _pcStorageCtrl.dispose();
    _pcOsCtrl.dispose();
    for (var ctrl in _ipCtrls) {
      ctrl.dispose();
    }
    
    // Dispose dynamic block
    _printerAeCtrl.dispose();
    _printerIp1Ctrl.dispose();
    _printerIp2Ctrl.dispose();
    _printerPortCtrl.dispose();
    _printerPcVerCtrl.dispose();
    _printerMbVerCtrl.dispose();
    _printerImagerVerCtrl.dispose();
    _xrayConsoleCtrl.dispose();
    _xrayTubeCtrl.dispose();
    _xrayGeneratorCtrl.dispose();
    _fpdAcqIdCtrl.dispose();
    _fpdSoftwareCtrl.dispose();
    _fpdVersionCtrl.dispose();
    _fpdModuleCtrl.dispose();
    _fpdLicenseCtrl.dispose();
    for (var field in _customFields) {
      field.key.dispose();
      field.value.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _installationDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _installationDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final repo = context.read<MachinesRepository>();

      // Parse custom scalable fields array down to plain map structure
      final Map<String, String> metaMap = {};
      for (var entry in _customFields) {
        final k = entry.key.text.trim();
        final v = entry.value.text.trim();
        if (k.isNotEmpty && v.isNotEmpty) {
          metaMap[k] = v;
        }
      }

      final draft = InstalledMachine(
        id: widget.machine?.id ?? '',
        hospitalId: widget.hospitalId,
        machineType: _machineType,
        brand: _brandCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        serialNumber: _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
        installationDate: _installationDate,
        warrantyPeriod: _warrantyPeriod,
        invoiceUrl: widget.machine?.invoiceUrl,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: widget.machine?.createdAt ?? DateTime.now(),
        
        pcCpu: _pcCpuCtrl.text.trim().isEmpty ? null : _pcCpuCtrl.text.trim(),
        pcRam: _pcRamCtrl.text.trim().isEmpty ? null : _pcRamCtrl.text.trim(),
        pcStorage: _pcStorageCtrl.text.trim().isEmpty ? null : _pcStorageCtrl.text.trim(),
        pcOs: _pcOsCtrl.text.trim().isEmpty ? null : _pcOsCtrl.text.trim(),
        assignedIps: _ipCtrls.map((c) => c.text.trim()).where((ip) => ip.isNotEmpty).toList(),

        // Conditional field persistence mappings
        printerAe: _printerAeCtrl.text.trim().isEmpty ? null : _printerAeCtrl.text.trim(),
        printerIp1: _printerIp1Ctrl.text.trim().isEmpty ? null : _printerIp1Ctrl.text.trim(),
        printerIp2: _printerIp2Ctrl.text.trim().isEmpty ? null : _printerIp2Ctrl.text.trim(),
        printerPort: _printerPortCtrl.text.trim().isEmpty ? null : _printerPortCtrl.text.trim(),
        printerPcVersion: _printerPcVerCtrl.text.trim().isEmpty ? null : _printerPcVerCtrl.text.trim(),
        printerMbVersion: _printerMbVerCtrl.text.trim().isEmpty ? null : _printerMbVerCtrl.text.trim(),
        printerImagerVersion: _printerImagerVerCtrl.text.trim().isEmpty ? null : _printerImagerVerCtrl.text.trim(),

        xrayConsoleSl: _xrayConsoleCtrl.text.trim().isEmpty ? null : _xrayConsoleCtrl.text.trim(),
        xrayTubeSl: _xrayTubeCtrl.text.trim().isEmpty ? null : _xrayTubeCtrl.text.trim(),
        xrayGeneratorSl: _xrayGeneratorCtrl.text.trim().isEmpty ? null : _xrayGeneratorCtrl.text.trim(),

        fpdAcqId: _fpdAcqIdCtrl.text.trim().isEmpty ? null : _fpdAcqIdCtrl.text.trim(),
        fpdSoftware: _fpdSoftwareCtrl.text.trim().isEmpty ? null : _fpdSoftwareCtrl.text.trim(),
        fpdVersion: _fpdVersionCtrl.text.trim().isEmpty ? null : _fpdVersionCtrl.text.trim(),
        fpdModule: _fpdModuleCtrl.text.trim().isEmpty ? null : _fpdModuleCtrl.text.trim(),
        fpdLicense: _fpdLicenseCtrl.text.trim().isEmpty ? null : _fpdLicenseCtrl.text.trim(),

        customMetadata: metaMap,
      );

      final result = widget.machine == null
          ? await repo.createMachine(draft)
          : await repo.updateMachine(draft);

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
    final theme  = Theme.of(context);
    final isEdit = widget.machine != null;

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
                isEdit ? 'Edit Machine' : 'Add Machine',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Machine Type
              const _Label('Machine Type'),
              DropdownButtonFormField<MachineType>(
                value: _machineType,
                dropdownColor: AppColors.surface1,
                decoration: const InputDecoration(),
                items: MachineType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.label),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _machineType = v!),
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Brand'),
                        TextFormField(
                          controller: _brandCtrl,
                          decoration: const InputDecoration(hintText: 'e.g. GE Healthcare'),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Model'),
                        TextFormField(
                          controller: _modelCtrl,
                          decoration: const InputDecoration(hintText: 'e.g. Optima XR240amx'),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              const _Label('Serial Number (optional)'),
              TextFormField(
                controller: _serialCtrl,
                decoration: const InputDecoration(hintText: 'e.g. SN-20240001'),
              ),
              const SizedBox(height: AppSpacing.md),

              // ─── CONDITIONAL FIELD INJECTION BLOCK ─────────────────
              _buildConditionalFields(),

              // Installation date picker
              const _Label('Installation Date'),
              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: TextEditingController(
                      text: _fmt.format(_installationDate),
                    ),
                    decoration: const InputDecoration(
                      suffixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Warranty period stepper
              const _Label('Warranty Period'),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: AppRadius.inputField,
                  border: Border.all(color: AppColors.surface3),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded),
                      onPressed: _warrantyPeriod > 1
                          ? () => setState(() => _warrantyPeriod--)
                          : null,
                      color: AppColors.textSecondary,
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '$_warrantyPeriod months',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => setState(() => _warrantyPeriod++),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              const _Label('Notes (optional)'),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Installation notes, configuration info…',
                ),
              ),
              
              // PC Configuration Info
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(),
              ),
              const _Label('PC Configuration (Optional)'),
              const SizedBox(height: AppSpacing.xs),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pcCpuCtrl,
                      decoration: const InputDecoration(hintText: 'CPU (e.g. Core i5)'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _pcRamCtrl,
                      decoration: const InputDecoration(hintText: 'RAM (e.g. 16GB)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pcStorageCtrl,
                      decoration: const InputDecoration(hintText: 'Storage (e.g. 512GB SSD)'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _pcOsCtrl,
                      decoration: const InputDecoration(hintText: 'OS (e.g. Windows 11 Pro)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Network Configurations
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _Label('Assigned IP Addresses'),
                  TextButton.icon(
                    onPressed: () => setState(() => _ipCtrls.add(TextEditingController())),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add IP'),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
              
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ipCtrls.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ipCtrls[index],
                            decoration: InputDecoration(
                              hintText: 'e.g. 192.168.1.${10 + index}',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          onPressed: () => setState(() {
                            if (_ipCtrls.length > 1) {
                              _ipCtrls[index].dispose();
                              _ipCtrls.removeAt(index);
                            } else {
                              _ipCtrls[0].clear();
                            }
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // ─── SCALABLE EXTRA ATTRIBUTES BLOCK ───────────────────
              _buildScalableFieldsSection(),
              const SizedBox(height: AppSpacing.xl),

              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEdit ? 'Save Changes' : 'Add Machine'),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  // Helper template for switching conditional field blocks
  Widget _buildConditionalFields() {
    switch (_machineType) {
      case MachineType.printer:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('Printer Details'),
            TextFormField(controller: _printerAeCtrl, decoration: const InputDecoration(hintText: 'AE Title')),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _printerIp1Ctrl, decoration: const InputDecoration(hintText: 'IP 1'))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: TextFormField(controller: _printerIp2Ctrl, decoration: const InputDecoration(hintText: 'IP 2'))),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _printerPortCtrl, decoration: const InputDecoration(hintText: 'Port'))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: TextFormField(controller: _printerPcVerCtrl, decoration: const InputDecoration(hintText: 'PC Version'))),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _printerMbVerCtrl, decoration: const InputDecoration(hintText: 'MB Version'))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: TextFormField(controller: _printerImagerVerCtrl, decoration: const InputDecoration(hintText: 'Imager Version'))),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.md), child: Divider()),
          ],
        );

      case MachineType.xRay:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('X-Ray Components'),
            TextFormField(controller: _xrayConsoleCtrl, decoration: const InputDecoration(hintText: 'Console S/L')),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(controller: _xrayTubeCtrl, decoration: const InputDecoration(hintText: 'Tube S/L')),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(controller: _xrayGeneratorCtrl, decoration: const InputDecoration(hintText: 'Generator S/L')),
            const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.md), child: Divider()),
          ],
        );

      case MachineType.fpd:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('FPD Parameters'),
            TextFormField(controller: _fpdAcqIdCtrl, decoration: const InputDecoration(hintText: 'Acq ID Number')),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _fpdSoftwareCtrl, decoration: const InputDecoration(hintText: 'Software'))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: TextFormField(controller: _fpdVersionCtrl, decoration: const InputDecoration(hintText: 'Version'))),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _fpdModuleCtrl, decoration: const InputDecoration(hintText: 'Module'))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: TextFormField(controller: _fpdLicenseCtrl, decoration: const InputDecoration(hintText: 'License'))),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.md), child: Divider()),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // Dynamic parameter mapping component
  Widget _buildScalableFieldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _Label('Scalable Fields'),
            TextButton.icon(
              onPressed: () => setState(() => _customFields.add(MapEntry(TextEditingController(), TextEditingController()))),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: const Text('Add Field Option'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        if (_customFields.isNotEmpty) const SizedBox(height: AppSpacing.xs),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _customFields.length,
          itemBuilder: (context, idx) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _customFields[idx].key,
                      decoration: const InputDecoration(hintText: 'Field Title'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _customFields[idx].value,
                      decoration: const InputDecoration(hintText: 'Value'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent),
                    onPressed: () => setState(() {
                      _customFields[idx].key.dispose();
                      _customFields[idx].value.dispose();
                      _customFields.removeAt(idx);
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            color: AppColors.textTertiary,
          ),
        ),
      );
}