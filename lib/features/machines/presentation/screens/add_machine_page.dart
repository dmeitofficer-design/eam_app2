// lib/features/machines/presentation/screens/add_machine_page.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../config/presentation/bloc/config_bloc.dart';
// IMPORT: Ensure your Engineers Bloc path is added here
import '../../../engineers/presentation/bloc/engineers_bloc.dart'; 
import '../../data/models/installed_machine.dart';
import '../../data/models/machine_part.dart';
import '../../data/repositories/machines_repository.dart';
import '../bloc/machines_bloc.dart';
import '../screens/machine_config_page.dart';
import '../../data/models/engineer.dart';

/// Safely resolves an engineer's identifier regardless of which field name
/// the model actually exposes (id / engineerId / uuid).
String _engineerIdOf(dynamic engineer) {
  try {
    return (engineer?.id ?? engineer?.engineerId ?? engineer?.uuid ?? '')
        .toString();
  } catch (_) {
    return '';
  }
}

class AddMachinePage extends StatefulWidget {
  const AddMachinePage({
    super.key,
    required this.hospitalId,
    this.existingMachine,
  });

  final String hospitalId;
  final InstalledMachine? existingMachine;

  @override
  State<AddMachinePage> createState() => _AddMachinePageState();
}

class _AddMachinePageState extends State<AddMachinePage> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool get _isEdit => widget.existingMachine != null;

  String _machineType = '';
  String _brand = '';
  late final _modelCtrl = TextEditingController(text: widget.existingMachine?.model ?? '');
  late final _serialCtrl = TextEditingController(text: widget.existingMachine?.serialNumber ?? '');
  
  // Array tracking active assigned engineer primary database keys
  List<String> selectedEngineerIds = [];

  // Toggle state to conditionally reveal PC hardware fields
  bool _showPcConfig = false;

  // Workstation Configuration Controllers
  late final _pcCpuCtrl = TextEditingController(text: widget.existingMachine?.pcCpu ?? '');
  late final _pcRamCtrl = TextEditingController(text: widget.existingMachine?.pcRam ?? '');
  late final _pcStorageCtrl = TextEditingController(text: widget.existingMachine?.pcStorage ?? '');
  late final _pcOsCtrl = TextEditingController(text: widget.existingMachine?.pcOs ?? '');
  late final _pcMoboCtrl = TextEditingController(text: widget.existingMachine?.pcMobo ?? ''); 
  String? _pcLanPorts = '1';

  // Dynamic Network IP Layout List
  final List<TextEditingController> _ipCtrls = [];

  // ─── CONDITIONAL MACHINE TYPE CONTROLLERS ───────────────────────────
  // Printer Type
  late final _printerAeCtrl         = TextEditingController(text: widget.existingMachine?.printerAe ?? '');
  late final _printerIp1Ctrl        = TextEditingController(text: widget.existingMachine?.printerIp1 ?? '');
  late final _printerIp2Ctrl        = TextEditingController(text: widget.existingMachine?.printerIp2 ?? '');
  late final _printerPortCtrl       = TextEditingController(text: widget.existingMachine?.printerPort ?? '');
  late final _printerPcVerCtrl      = TextEditingController(text: widget.existingMachine?.printerPcVersion ?? '');
  late final _printerMbVerCtrl      = TextEditingController(text: widget.existingMachine?.printerMbVersion ?? '');
  late final _printerImagerVerCtrl  = TextEditingController(text: widget.existingMachine?.printerImagerVersion ?? '');

  // X-ray Type
  late final _xrayConsoleCtrl       = TextEditingController(text: widget.existingMachine?.xrayConsoleSl ?? '');
  late final _xrayTubeCtrl          = TextEditingController(text: widget.existingMachine?.xrayTubeSl ?? '');
  late final _xrayGeneratorCtrl     = TextEditingController(text: widget.existingMachine?.xrayGeneratorSl ?? '');

  // FPD Type
  late final _fpdAcqIdCtrl          = TextEditingController(text: widget.existingMachine?.fpdAcqId ?? '');
  late final _fpdSoftwareCtrl       = TextEditingController(text: widget.existingMachine?.fpdSoftware ?? '');
  late final _fpdVersionCtrl        = TextEditingController(text: widget.existingMachine?.fpdVersion ?? '');
  late final _fpdModuleCtrl         = TextEditingController(text: widget.existingMachine?.fpdModule ?? '');
  late final _fpdLicenseCtrl        = TextEditingController(text: widget.existingMachine?.fpdLicense ?? '');
  String? _fpdLicenseType           = 'Hardware/Dongle Key';
  late final _fpdDongleSerialCtrl   = TextEditingController(text: widget.existingMachine?.fpdDongleSerial ?? '');

  final List<MapEntry<TextEditingController, TextEditingController>> _customFields = [];

  late DateTime _installDate = widget.existingMachine?.installationDate ?? DateTime.now();
  late int _warrantyMonths = widget.existingMachine?.warrantyPeriod ?? 24;

  final List<_PartRow> _parts = [];
  String? _pdfFileName;
  Uint8List? _pdfBytes;

  final _dateFmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    context.read<EngineersBloc>().add(EngineersFetchAll());
    if (widget.existingMachine != null) {
      _machineType = widget.existingMachine!.machineType.label;
      _brand = widget.existingMachine!.brand;
      
      selectedEngineerIds = widget.existingMachine!.engineers
          .map(_engineerIdOf)
          .where((id) => id.isNotEmpty)
          .toList();
      
      _pcLanPorts = widget.existingMachine!.pcLanPorts?.toString() ?? '1';
      _fpdLicenseType = widget.existingMachine!.fpdLicenseType ?? 'Hardware/Dongle Key';

      // Auto-enable PC configuration layout if data already exists during an edit view
      if (widget.existingMachine!.pcCpu != null ||
          widget.existingMachine!.pcRam != null ||
          widget.existingMachine!.pcStorage != null ||
          widget.existingMachine!.pcOs != null ||
          widget.existingMachine!.pcMobo != null) {
        _showPcConfig = true;
      }

      for (final p in widget.existingMachine!.parts) {
        _parts.add(_PartRow(name: p.partName, serial: p.serialNumber));
      }
      
      for (final ip in widget.existingMachine!.assignedIps) {
        _ipCtrls.add(TextEditingController(text: ip));
      }

      widget.existingMachine!.customMetadata.forEach((key, value) {
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
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    _pcCpuCtrl.dispose();
    _pcRamCtrl.dispose();
    _pcStorageCtrl.dispose();
    _pcOsCtrl.dispose();
    _pcMoboCtrl.dispose();
    
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
    _fpdDongleSerialCtrl.dispose();

    for (final p in _parts) p.dispose();
    for (final ctrl in _ipCtrls) ctrl.dispose();
    for (final pair in _customFields) {
      pair.key.dispose();
      pair.value.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _installDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _installDate = picked);
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _pdfFileName = result.files.single.name;
        _pdfBytes = result.files.single.bytes;
      });
    }
  }

  void _addPart() => setState(() => _parts.add(_PartRow()));
  void _removePart(int i) {
    _parts[i].dispose();
    setState(() => _parts.removeAt(i));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_machineType.isEmpty) {
      AppFeedback.error(context, 'Please select a machine type.');
      return;
    }
    if (_brand.isEmpty) {
      AppFeedback.error(context, 'Please select a brand.');
      return;
    }

    final chosenEngineerId = selectedEngineerIds.isNotEmpty ? selectedEngineerIds.first : null;

    setState(() => _saving = true);

    try {
      final repo = context.read<MachinesRepository>();

      final partsList = _parts
          .where((p) => p.nameCtrl.text.trim().isNotEmpty)
          .map((p) => MachinePart.draft(
                partName: p.nameCtrl.text.trim(),
                serialNumber: p.serialCtrl.text.trim(),
              ))
          .toList();

      final Map<String, String> metaMap = {};
      for (var entry in _customFields) {
        final k = entry.key.text.trim();
        final v = entry.value.text.trim();
        if (k.isNotEmpty && v.isNotEmpty) {
          metaMap[k] = v;
        }
      }

      final List<String> assignedIpsList = _ipCtrls
          .map((ctrl) => ctrl.text.trim())
          .where((ip) => ip.isNotEmpty)
          .toList();

      final typeEnum = MachineType.fromString(_machineType);

      final draft = InstalledMachine(
        id: widget.existingMachine?.id ?? '',
        hospitalId: widget.hospitalId,
        machineType: typeEnum,
        brand: _brand,
        model: _modelCtrl.text.trim(),
        serialNumber: _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
        
        installationEngineerId: chosenEngineerId,
        installationEngineerName: null, 
        
        installationDate: _installDate,
        warrantyPeriod: _warrantyMonths,
        invoiceUrl: widget.existingMachine?.invoiceUrl,
        createdAt: widget.existingMachine?.createdAt ?? DateTime.now(),
        assignedIps: assignedIpsList,

        // Clean field values if the configuration container was explicitly toggled off
        pcCpu: _showPcConfig && _pcCpuCtrl.text.trim().isNotEmpty ? _pcCpuCtrl.text.trim() : null,
        pcRam: _showPcConfig && _pcRamCtrl.text.trim().isNotEmpty ? _pcRamCtrl.text.trim() : null,
        pcStorage: _showPcConfig && _pcStorageCtrl.text.trim().isNotEmpty ? _pcStorageCtrl.text.trim() : null,
        pcOs: _showPcConfig && _pcOsCtrl.text.trim().isNotEmpty ? _pcOsCtrl.text.trim() : null,
        pcMobo: _showPcConfig && _pcMoboCtrl.text.trim().isNotEmpty ? _pcMoboCtrl.text.trim() : null,
        pcLanPorts: _showPcConfig && _pcLanPorts != null ? int.tryParse(_pcLanPorts!) : null,

        printerAe: typeEnum == MachineType.printer && _printerAeCtrl.text.trim().isNotEmpty ? _printerAeCtrl.text.trim() : null,
        printerIp1: typeEnum == MachineType.printer && _printerIp1Ctrl.text.trim().isNotEmpty ? _printerIp1Ctrl.text.trim() : null,
        printerIp2: typeEnum == MachineType.printer && _printerIp2Ctrl.text.trim().isNotEmpty ? _printerIp2Ctrl.text.trim() : null,
        printerPort: typeEnum == MachineType.printer && _printerPortCtrl.text.trim().isNotEmpty ? _printerPortCtrl.text.trim() : null,
        printerPcVersion: typeEnum == MachineType.printer && _printerPcVerCtrl.text.trim().isNotEmpty ? _printerPcVerCtrl.text.trim() : null,
        printerMbVersion: typeEnum == MachineType.printer && _printerMbVerCtrl.text.trim().isNotEmpty ? _printerMbVerCtrl.text.trim() : null,
        printerImagerVersion: typeEnum == MachineType.printer && _printerImagerVerCtrl.text.trim().isNotEmpty ? _printerImagerVerCtrl.text.trim() : null,

        xrayConsoleSl: typeEnum == MachineType.xRay && _xrayConsoleCtrl.text.trim().isNotEmpty ? _xrayConsoleCtrl.text.trim() : null,
        xrayTubeSl: typeEnum == MachineType.xRay && _xrayTubeCtrl.text.trim().isNotEmpty ? _xrayTubeCtrl.text.trim() : null,
        xrayGeneratorSl: typeEnum == MachineType.xRay && _xrayGeneratorCtrl.text.trim().isNotEmpty ? _xrayGeneratorCtrl.text.trim() : null,

        fpdAcqId: typeEnum == MachineType.fpd && _fpdAcqIdCtrl.text.trim().isNotEmpty ? _fpdAcqIdCtrl.text.trim() : null,
        fpdSoftware: typeEnum == MachineType.fpd && _fpdSoftwareCtrl.text.trim().isNotEmpty ? _fpdSoftwareCtrl.text.trim() : null,
        fpdVersion: typeEnum == MachineType.fpd && _fpdVersionCtrl.text.trim().isNotEmpty ? _fpdVersionCtrl.text.trim() : null,
        fpdModule: typeEnum == MachineType.fpd && _fpdModuleCtrl.text.trim().isNotEmpty ? _fpdModuleCtrl.text.trim() : null,
        fpdLicense: typeEnum == MachineType.fpd && _fpdLicenseCtrl.text.trim().isNotEmpty ? _fpdLicenseCtrl.text.trim() : null,
        fpdLicenseType: typeEnum == MachineType.fpd ? _fpdLicenseType : null,
        fpdDongleSerial: typeEnum == MachineType.fpd && _fpdDongleSerialCtrl.text.trim().isNotEmpty ? _fpdDongleSerialCtrl.text.trim() : null,

        customMetadata: metaMap,
      );

      InstalledMachine saved;
      if (_isEdit) {
        saved = await repo.updateMachineWithParts(draft, partsList, selectedEngineerIds);
      } else {
        saved = await repo.createMachineWithParts(draft, partsList, selectedEngineerIds);
      }

      if (_pdfBytes != null && _pdfFileName != null) {
        final path = await repo.uploadInvoice(
          machineId: saved.id,
          fileBytes: _pdfBytes!,
          fileName: _pdfFileName!,
        );
        await repo.updateMachineWithParts(
          saved.copyWith(invoiceUrl: path),
          saved.parts,
          selectedEngineerIds,
        );
      }

      if (mounted) {
        context.read<MachinesBloc>().add(MachinesFetchRequested(widget.hospitalId));
        Navigator.of(context).pop(true);
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
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final isMobile = width < 600;

    Widget buildMachineTypeField(ConfigState cfg) => _Field(
          label: 'Machine Type',
          child: DropdownButtonFormField<String>(
            value: _machineType.isEmpty ? null : _machineType,
            isExpanded: true,
            dropdownColor: AppColors.surface2,
            hint: const Text('Select type', overflow: TextOverflow.ellipsis),
            decoration: const InputDecoration(),
            items: cfg.machineTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _machineType = v ?? ''),
          ),
        );

    Widget buildBrandField(ConfigState cfg) => _Field(
          label: 'Brand',
          child: DropdownButtonFormField<String>(
            value: _brand.isEmpty ? null : _brand,
            isExpanded: true,
            dropdownColor: AppColors.surface2,
            hint: const Text('Select brand', overflow: TextOverflow.ellipsis),
            decoration: const InputDecoration(),
            items: cfg.brands.map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _brand = v ?? ''),
          ),
        );

    Widget buildModelField() => _Field(
          label: 'Model',
          child: TextFormField(controller: _modelCtrl, decoration: const InputDecoration(hintText: 'e.g. GXR-S')),
        );

    Widget buildSerialField() => _Field(
          label: 'Serial Number (optional)',
          child: TextFormField(controller: _serialCtrl, decoration: const InputDecoration(hintText: 'e.g. SN-2024-001')),
        );

    Widget buildDateField() => _Field(
          label: 'Installation Date',
          child: GestureDetector(
            onTap: _pickDate,
            child: AbsorbPointer(
              child: TextFormField(
                controller: TextEditingController(text: _dateFmt.format(_installDate)),
                decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_rounded, size: 18)),
              ),
            ),
          ),
        );

    Widget buildWarrantyField() => _Field(
          label: 'Warranty Period',
          child: _WarrantyStepper(value: _warrantyMonths, onChanged: (v) => setState(() => _warrantyMonths = v)),
        );

    return Scaffold(
      backgroundColor: AppColors.surface0,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEdit ? 'Edit Machine' : 'Add Machine'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 700 : double.infinity),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('Machine Details'),
                  const SizedBox(height: AppSpacing.md),

                  BlocBuilder<ConfigBloc, ConfigState>(
                    builder: (context, cfg) => _FormCard(
                      children: [
                        if (isMobile) ...[
                          buildMachineTypeField(cfg),
                          buildBrandField(cfg),
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: buildMachineTypeField(cfg)),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: buildBrandField(cfg)),
                            ],
                          ),
                        ],

                        if (isMobile) ...[
                          buildModelField(),
                          buildSerialField(),
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: buildModelField()),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: buildSerialField()),
                            ],
                          ),
                        ],

                        _Field(
                          label: 'Assigned Installation Engineers',
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: AppRadius.inputField,
                              border: Border.all(color: AppColors.surface3),
                            ),
                            child: BlocBuilder<EngineersBloc, EngineersState>(
                              builder: (context, state) {
                                List<Engineer> engineersList = [];
                                bool isLoadedState = false;

                                if (state is EngineersLoaded) {
                                  engineersList = state.engineers;
                                  isLoadedState = true;
                                } else if (state is EngineersActionSuccess) {
                                  engineersList = state.engineers;
                                  isLoadedState = true;
                                }

                                if (isLoadedState) {
                                  if (engineersList.isEmpty) {
                                    return Text(
                                      'No engineers found', 
                                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary)
                                    );
                                  }

                                  return Wrap(
                                    spacing: 8.0,
                                    runSpacing: 4.0,
                                    children: engineersList.map((dynamic engineer) {
                                      final String engId = _engineerIdOf(engineer);
                                      final String engName = (engineer?.name ?? 'Unknown').toString();
                                      final bool isAvailable = engineer?.isAvailable ?? true;
                                      
                                      if (engId.isEmpty) return const SizedBox.shrink();

                                      final isSelected = selectedEngineerIds.contains(engId);
                                      return FilterChip(
                                        label: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(engName),
                                            if (!isAvailable) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade800,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'ASSIGNED',
                                                  style: TextStyle(
                                                    fontSize: 8, 
                                                    fontWeight: FontWeight.bold, 
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        selected: isSelected,
                                        selectedColor: AppColors.accent.withOpacity(0.15),
                                        checkmarkColor: AppColors.accent,
                                        disabledColor: Colors.orange.withOpacity(0.08),
                                        side: BorderSide(
                                          color: isAvailable 
                                              ? (isSelected ? AppColors.accent : AppColors.surface3) 
                                              : Colors.orange.shade400,
                                          width: 1,
                                        ),
                                        labelStyle: theme.textTheme.bodyMedium?.copyWith(
                                          color: isAvailable 
                                              ? (isSelected ? AppColors.accent : AppColors.textPrimary)
                                              : Colors.orange.shade300,
                                          fontWeight: isAvailable ? FontWeight.normal : FontWeight.w500,
                                        ),
                                        onSelected: isAvailable
                                            ? (bool checked) {
                                                setState(() {
                                                  if (checked) {
                                                    selectedEngineerIds.add(engId);
                                                  } else {
                                                    selectedEngineerIds.remove(engId);
                                                  }
                                                });
                                              }
                                            : null,
                                      );
                                    }).toList(),
                                  );
                                }

                                if (state is EngineersError) {
                                  return Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Failed to load engineers: ${state.message}', 
                                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                
                                return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              },
                            ),
                          ),
                        ),

                        if (isMobile) ...[
                          buildDateField(),
                          buildWarrantyField(),
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: buildDateField()),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: buildWarrantyField()),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  _buildConditionalTechnicalFields(isMobile),

                  // PC Configuration Header and Toggle
                  _SectionTitle('PC Configuration (Optional)'),
                  const SizedBox(height: AppSpacing.xs),
                  
                  // NEW: Toggle visibility configuration setting switch
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Include Workstation Details',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'Turn on to append internal PC specs and hardware details',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                    ),
                    activeColor: AppColors.accent,
                    value: _showPcConfig,
                    onChanged: (bool value) => setState(() => _showPcConfig = value),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  
                  // Animated container conditionally rendering hardware card layout
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: !_showPcConfig 
                        ? const SizedBox.shrink() 
                        : Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: _FormCard(
                              children: [
                                if (isMobile) ...[
                                  _Field(label: 'CPU', child: TextFormField(controller: _pcCpuCtrl, decoration: const InputDecoration(hintText: 'e.g. Core i7'))),
                                  _Field(label: 'RAM', child: TextFormField(controller: _pcRamCtrl, decoration: const InputDecoration(hintText: 'e.g. 16GB'))),
                                  _Field(label: 'Storage', child: TextFormField(controller: _pcStorageCtrl, decoration: const InputDecoration(hintText: 'e.g. 512GB SSD'))),
                                  _Field(label: 'Operating System', child: TextFormField(controller: _pcOsCtrl, decoration: const InputDecoration(hintText: 'e.g. Windows 11 Pro'))),
                                  _Field(label: 'Motherboard', child: TextFormField(controller: _pcMoboCtrl, decoration: const InputDecoration(hintText: 'e.g. Asus Prime H610'))),
                                  _Field(
                                    label: 'Number of LAN ports',
                                    child: DropdownButtonFormField<String>(
                                      value: _pcLanPorts,
                                      isExpanded: true,
                                      dropdownColor: AppColors.surface2,
                                      items: ['1', '2', '3', '4'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                      onChanged: (v) => setState(() => _pcLanPorts = v),
                                    ),
                                  ),
                                ] else ...[
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _Field(label: 'CPU', child: TextFormField(controller: _pcCpuCtrl, decoration: const InputDecoration(hintText: 'e.g. Core i7')))),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(child: _Field(label: 'RAM', child: TextFormField(controller: _pcRamCtrl, decoration: const InputDecoration(hintText: 'e.g. 16GB')))),
                                    ],
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _Field(label: 'Storage', child: TextFormField(controller: _pcStorageCtrl, decoration: const InputDecoration(hintText: 'e.g. 512GB SSD')))),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(child: _Field(label: 'Operating System', child: TextFormField(controller: _pcOsCtrl, decoration: const InputDecoration(hintText: 'e.g. Windows 11 Pro')))),
                                    ],
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _Field(label: 'Motherboard', child: TextFormField(controller: _pcMoboCtrl, decoration: const InputDecoration(hintText: 'e.g. Asus Prime H610')))),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: _Field(
                                          label: 'Number of LAN ports',
                                          child: DropdownButtonFormField<String>(
                                            value: _pcLanPorts,
                                            isExpanded: true,
                                            dropdownColor: AppColors.surface2,
                                            items: ['1', '2', '3', '4'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                            onChanged: (v) => setState(() => _pcLanPorts = v),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'ASSIGNED IP ADDRESSES',
                          style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.4, color: AppColors.textTertiary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => _ipCtrls.add(TextEditingController())),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add IP'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.accent, visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),
                  _FormCard(
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _ipCtrls.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _Field(
                                    label: 'IP Address #${index + 1}',
                                    child: TextFormField(decoration: InputDecoration(hintText: 'e.g. 192.168.1.${50 + index}'), controller: _ipCtrls[index]),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: IconButton(
                                    onPressed: () => setState(() {
                                      if (_ipCtrls.length > 1) {
                                        _ipCtrls[index].dispose();
                                        _ipCtrls.removeAt(index);
                                      } else {
                                        _ipCtrls[0].clear();
                                      }
                                    }),
                                    icon: const Icon(Icons.remove_circle_rounded),
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  _buildScalableFieldsSection(theme),

                  const SizedBox(height: AppSpacing.lg),
                  _SectionTitle('Machine Parts'),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Individual components with serial numbers.', style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.md),

                  if (_parts.isNotEmpty)
                    _FormCard(
                      children: List.generate(
                        _parts.length,
                        (i) => Column(
                          children: [
                            if (isMobile) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('PART #${i + 1}', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1, color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
                                  IconButton(onPressed: () => _removePart(i), icon: const Icon(Icons.remove_circle_rounded), color: AppColors.error),
                                ],
                              ),
                              _Field(label: 'Part Name', child: TextFormField(controller: _parts[i].nameCtrl, decoration: const InputDecoration(hintText: 'e.g. X-ray Tube'))),
                              _Field(label: 'Serial Number', child: TextFormField(controller: _parts[i].serialCtrl, decoration: const InputDecoration(hintText: 'e.g. XT-20240012'))),
                            ] else ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _Field(label: 'Part Name', child: TextFormField(controller: _parts[i].nameCtrl, decoration: const InputDecoration(hintText: 'e.g. X-ray Tube')))),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(child: _Field(label: 'Serial Number', child: TextFormField(controller: _parts[i].serialCtrl, decoration: const InputDecoration(hintText: 'e.g. XT-20240012')))),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 24),
                                    child: IconButton(onPressed: () => _removePart(i), icon: const Icon(Icons.remove_circle_rounded), color: AppColors.error),
                                  ),
                                ],
                              ),
                            ],
                            if (i < _parts.length - 1) const Divider(height: AppSpacing.md),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addPart,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Part'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  _SectionTitle('PDF Receipt / Invoice'),
                  const SizedBox(height: AppSpacing.md),

                  GestureDetector(
                    onTap: _pdfFileName == null ? _pickPdf : null,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface1,
                        borderRadius: AppRadius.card,
                        border: Border.all(color: _pdfFileName != null ? AppColors.accent : AppColors.surface3),
                      ),
                      child: _pdfFileName != null
                          ? Row(
                              children: [
                                const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error, size: 28),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: Text(_pdfFileName!, style: theme.textTheme.bodyMedium)),
                                IconButton(
                                  onPressed: () => setState(() {
                                    _pdfFileName = null;
                                    _pdfBytes = null;
                                  }),
                                  icon: const Icon(Icons.close_rounded),
                                  color: AppColors.textTertiary,
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment:  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.upload_file_rounded, color: AppColors.textTertiary),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    widget.existingMachine?.invoiceUrl != null ? 'Replace existing invoice PDF' : 'Tap to select PDF receipt',
                                    style: theme.textTheme.bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Text(_isEdit ? 'Save Changes' : 'Add Machine', style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionalTechnicalFields(bool isMobile) {
    if (_machineType.isEmpty) return const SizedBox.shrink();
    final type = MachineType.fromString(_machineType);

    switch (type) {
      case MachineType.printer:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Printer Specifications'),
            const SizedBox(height: AppSpacing.md),
            _FormCard(
              children: [
                _Field(label: 'AE Title', child: TextFormField(controller: _printerAeCtrl, decoration: const InputDecoration(hintText: 'e.g. DRYPIX_PRINTER'))),
                if (isMobile) ...[
                  _Field(label: 'IP Address 1', child: TextFormField(controller: _printerIp1Ctrl, decoration: const InputDecoration(hintText: '192.168.1.10'))),
                  _Field(label: 'IP Address 2', child: TextFormField(controller: _printerIp2Ctrl, decoration: const InputDecoration(hintText: '192.168.1.11'))),
                  _Field(label: 'Port', child: TextFormField(controller: _printerPortCtrl, decoration: const InputDecoration(hintText: 'e.g. 5040'))),
                  _Field(label: 'PC Version', child: TextFormField(controller: _printerPcVerCtrl, decoration: const InputDecoration(hintText: 'v2.1.0'))),
                  _Field(label: 'MB Version', child: TextFormField(controller: _printerMbVerCtrl, decoration: const InputDecoration(hintText: 'v1.04'))),
                  _Field(label: 'Imager Version', child: TextFormField(controller: _printerImagerVerCtrl, decoration: const InputDecoration(hintText: 'v3.5.2'))),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: _Field(label: 'IP Address 1', child: TextFormField(controller: _printerIp1Ctrl, decoration: const InputDecoration(hintText: '192.168.1.10')))),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _Field(label: 'IP Address 2', child: TextFormField(controller: _printerIp2Ctrl, decoration: const InputDecoration(hintText: '192.168.1.11')))),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _Field(label: 'Port', child: TextFormField(controller: _printerPortCtrl, decoration: const InputDecoration(hintText: 'e.g. 5040')))),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _Field(label: 'PC Version', child: TextFormField(controller: _printerPcVerCtrl, decoration: const InputDecoration(hintText: 'v2.1.0')))),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _Field(label: 'MB Version', child: TextFormField(controller: _printerMbVerCtrl, decoration: const InputDecoration(hintText: 'v1.04')))),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _Field(label: 'Imager Version', child: TextFormField(controller: _printerImagerVerCtrl, decoration: const InputDecoration(hintText: 'v3.5.2')))),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );

      case MachineType.xRay:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('X-Ray Structural Components'),
            const SizedBox(height: AppSpacing.md),
            _FormCard(
              children: [
                _Field(label: 'Console S/L', child: TextFormField(controller: _xrayConsoleCtrl, decoration: const InputDecoration(hintText: 'Enter console serial number'))),
                _Field(label: 'Tube S/L', child: TextFormField(controller: _xrayTubeCtrl, decoration: const InputDecoration(hintText: 'Enter tube serial number'))),
                _Field(label: 'Generator S/L', child: TextFormField(controller: _xrayGeneratorCtrl, decoration: const InputDecoration(hintText: 'Enter generator serial number'))),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );

      case MachineType.fpd:
        Widget buildSoftwareName() => _Field(label: 'Software Name', child: TextFormField(controller: _fpdSoftwareCtrl, decoration: const InputDecoration(hintText: 'e.g. Radrex')));
        Widget buildSoftwareVersion() => _Field(label: 'Software Version', child: TextFormField(controller: _fpdVersionCtrl, decoration: const InputDecoration(hintText: 'v4.2')));
        Widget buildModuleInfo() => _Field(label: 'Module Info', child: TextFormField(controller: _fpdModuleCtrl, decoration: const InputDecoration(hintText: 'e.g. Pixium 3543')));
        Widget buildLicenseKey() => _Field(label: 'License String / Key', child: TextFormField(controller: _fpdLicenseCtrl, decoration: const InputDecoration(hintText: 'License status')));
        
        Widget buildLicenseType() => _Field(
              label: 'License Type',
              child: DropdownButtonFormField<String>(
                value: _fpdLicenseType,
                isExpanded: true,
                dropdownColor: AppColors.surface2,
                items: ['Hardware/Dongle Key', 'Software Key', 'Demo']
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (v) => setState(() => _fpdLicenseType = v),
              ),
            );

        Widget buildDongleSerial() => _Field(
              label: 'Dongle Serial',
              child: TextFormField(
                controller: _fpdDongleSerialCtrl,
                decoration: const InputDecoration(hintText: 'e.g. DG-7710X'),
              ),
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Flat Panel Detector Parameters'),
            const SizedBox(height: AppSpacing.md),
            _FormCard(
              children: [
                _Field(label: 'Acquisition ID Number', child: TextFormField(controller: _fpdAcqIdCtrl, decoration: const InputDecoration(hintText: 'e.g. ACQ-99012'))),
                if (isMobile) ...[
                  buildSoftwareName(),
                  buildSoftwareVersion(),
                  buildModuleInfo(),
                  buildLicenseKey(),
                  buildLicenseType(),
                  buildDongleSerial(),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: buildSoftwareName()),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: buildSoftwareVersion()),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: buildModuleInfo()),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: buildLicenseKey()),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: buildLicenseType()),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: buildDongleSerial()),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildScalableFieldsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'SCALABLE CUSTOM EXTRA FIELDS',
                style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.4, color: AppColors.textTertiary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _customFields.add(MapEntry(TextEditingController(), TextEditingController()))),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: const Text('Add Scalable Row'),
              style: TextButton.styleFrom(foregroundColor: AppColors.accent, visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        if (_customFields.isNotEmpty)
          _FormCard(
            children: [
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
                          child: _Field(
                            label: 'Field Key',
                            child: TextFormField(controller: _customFields[idx].key, decoration: const InputDecoration(hintText: 'e.g. KV Max')),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          flex: 3,
                          child: _Field(
                            label: 'Value',
                            child: TextFormField(controller: _customFields[idx].value, decoration: const InputDecoration(hintText: 'e.g. 150')),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent),
                            onPressed: () => setState(() {
                              _customFields[idx].key.dispose();
                              _customFields[idx].value.dispose();
                              _customFields.removeAt(idx);
                            }),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
      ],
    );
  }
}

class _PartRow {
  _PartRow({String? name, String? serial})
      : nameCtrl = TextEditingController(text: name ?? ''),
        serialCtrl = TextEditingController(text: serial ?? '');

  final TextEditingController nameCtrl;
  final TextEditingController serialCtrl;

  void dispose() {
    nameCtrl.dispose();
    serialCtrl.dispose();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.4, color: AppColors.textTertiary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(flex: 2, child: Divider()),
        ],
      );
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.surface2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.1, color: AppColors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.xs),
            child,
          ],
        ),
      );
}

class _WarrantyStepper extends StatelessWidget {
  const _WarrantyStepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: AppRadius.inputField,
          border: Border.all(color: AppColors.surface3),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_rounded, size: 18),
              onPressed: value > 1 ? () => onChanged(value - 1) : null,
              color: AppColors.textSecondary,
              padding: const EdgeInsets.all(AppSpacing.xs),
            ),
            Expanded(
              child: Text(
                '$value mo',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 18),
              onPressed: () => onChanged(value + 1),
              color: AppColors.textSecondary,
              padding: const EdgeInsets.all(AppSpacing.xs),
            ),
          ],
        ),
      );
}