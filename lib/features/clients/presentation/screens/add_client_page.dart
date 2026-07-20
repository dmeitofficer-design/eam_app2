// lib/features/clients/presentation/screens/add_client_page.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../config/data/repositories/config_repository.dart';
import '../../../config/presentation/bloc/config_bloc.dart';
import '../../../machines/data/models/installed_machine.dart';
import '../../../machines/data/models/machine_part.dart';
import '../../../machines/data/repositories/machines_repository.dart';
import '../../data/models/hospital_client.dart';
import '../../data/repositories/clients_repository.dart';
import '../bloc/clients_bloc.dart';
import '../../../engineers/presentation/bloc/engineers_bloc.dart';
import '../../../engineers/data/repositories/engineers_repository.dart';
import 'machine_config_page.dart';

// ─────────────────────────────────────────────────────────────
// Page entry point
// ─────────────────────────────────────────────────────────────

class AddClientPage extends StatelessWidget {
  const AddClientPage({super.key, this.existingClient});

  /// Pass existing client to enter edit mode
  final HospitalClient? existingClient;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ConfigBloc(
            repository: context.read<ConfigRepository>(),
          )..add(ConfigLoadRequested()),
        ),
        BlocProvider(
          create: (context) => EngineersBloc(
            repository: context.read<EngineersRepository>(),
          )..add(EngineersFetchAll()),
        ),
      ],
      child: _AddClientView(existingClient: existingClient),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Main form view
// ─────────────────────────────────────────────────────────────

class _AddClientView extends StatefulWidget {
  const _AddClientView({this.existingClient});
  final HospitalClient? existingClient;

  @override
  State<_AddClientView> createState() => _AddClientViewState();
}

class _AddClientViewState extends State<_AddClientView> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool get _isEdit => widget.existingClient != null;

  // ── Hospital fields ──────────────────────────────────────
  late final _nameCtrl =
      TextEditingController(text: widget.existingClient?.name ?? '');
  late final _addressCtrl =
      TextEditingController(text: widget.existingClient?.address ?? '');
  late final _districtCtrl =
      TextEditingController(text: widget.existingClient?.district ?? '');
  late String _genre = widget.existingClient?.genre ?? '';
  late DivisionType _division =
      widget.existingClient?.division ?? DivisionType.dhaka;
  late FacilityType _facilityType =
      widget.existingClient?.facilityType ?? FacilityType.hospital;

  // ── Contact fields ───────────────────────────────────────
  late final _contactNameCtrl = TextEditingController(
      text: widget.existingClient?.contactPersonName ?? '');
  late final _contactDesigCtrl = TextEditingController(
      text: widget.existingClient?.contactPersonDesignation ?? '');
  late final _contactPhoneCtrl = TextEditingController(
      text: widget.existingClient?.contactPersonPhone ?? '');

  // ── Machine fields (only shown for new client) ───────────
  bool _addMachine = false;
  String _machineType = '';
  String _brand = '';
  late final _machineModelCtrl = TextEditingController();
  late final _machineSerialCtrl = TextEditingController();

  // Installation engineers (multi-select).
  List<String> _selectedEngineers = [];

  DateTime _installDate = DateTime.now();
  int _warrantyMonths = 24;

  // Toggle state to conditionally reveal PC hardware fields
  bool _showPcConfig = false;

  // PC Config Fields
  late final _pcCpuCtrl = TextEditingController();
  late final _pcRamCtrl = TextEditingController();
  late final _pcStorageCtrl = TextEditingController();
  late final _pcOsCtrl = TextEditingController();
  late final _pcMoboCtrl = TextEditingController();
  String? _pcLanPorts = '1';

  // FPD Conditional Fields
  late final _fpdAcqIdCtrl = TextEditingController();
  late final _fpdSoftwareCtrl = TextEditingController();
  late final _fpdVersionCtrl = TextEditingController();
  late final _fpdModuleCtrl = TextEditingController();
  late final _fpdLicenseCtrl = TextEditingController();
  String? _fpdLicenseType = 'Hardware/Dongle Key';
  late final _fpdDongleSerialCtrl = TextEditingController();

  // Printer Conditional Fields
  late final _printerAeCtrl = TextEditingController();
  late final _printerIp1Ctrl = TextEditingController();
  late final _printerIp2Ctrl = TextEditingController();
  late final _printerPortCtrl = TextEditingController();
  late final _printerPcVerCtrl = TextEditingController();
  late final _printerMbVerCtrl = TextEditingController();
  late final _printerImagerVerCtrl = TextEditingController();

  // X-Ray Conditional Fields
  late final _xrayConsoleCtrl = TextEditingController();
  late final _xrayTubeCtrl = TextEditingController();
  late final _xrayGeneratorCtrl = TextEditingController();

  // ── Parts list ──────────────────────────────────────────
  final List<_PartRow> _parts = [];

  // ── PDF receipt ─────────────────────────────────────────
  String? _pdfFileName;
  Uint8List? _pdfBytes;

  final _dateFmt = DateFormat('d MMM yyyy');

  Widget _buildTwoColumnFields({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              const SizedBox(height: AppSpacing.sm),
              right,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  void _openModelEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ConfigBloc>(),
          child: const MachineConfigPage(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _districtCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactDesigCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _machineModelCtrl.dispose();
    _machineSerialCtrl.dispose();

    _pcCpuCtrl.dispose();
    _pcRamCtrl.dispose();
    _pcStorageCtrl.dispose();
    _pcOsCtrl.dispose();
    _pcMoboCtrl.dispose();

    _fpdAcqIdCtrl.dispose();
    _fpdSoftwareCtrl.dispose();
    _fpdVersionCtrl.dispose();
    _fpdModuleCtrl.dispose();
    _fpdLicenseCtrl.dispose();
    _fpdDongleSerialCtrl.dispose();

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

    for (final p in _parts) {
      p.dispose();
    }
    super.dispose();
  }

  // ── Date picker ─────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _installDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _installDate = picked);
  }

  // ── PDF picker ──────────────────────────────────────────
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

  // ── Add a part row ──────────────────────────────────────
  void _addPart() {
    setState(() => _parts.add(_PartRow()));
  }

  void _removePart(int index) {
    _parts[index].dispose();
    setState(() => _parts.removeAt(index));
  }

  // ── Submit ───────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_addMachine && !_isEdit) {
      if (_machineType.isEmpty) {
        AppFeedback.error(context, 'Please select a machine type.');
        return;
      }
      if (_brand.isEmpty) {
        AppFeedback.error(context, 'Please select a brand.');
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final clientsRepo = context.read<ClientsRepository>();
      final machinesRepo = context.read<MachinesRepository>();

      final draft = HospitalClient(
        id: widget.existingClient?.id ?? '',
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        district: _districtCtrl.text.trim(),
        genre: _genre,
        division: _division,
        facilityType: _facilityType,
        contactPersonName: _contactNameCtrl.text.trim(),
        contactPersonDesignation: _contactDesigCtrl.text.trim(),
        contactPersonPhone: _contactPhoneCtrl.text.trim(),
        createdAt: widget.existingClient?.createdAt ?? DateTime.now(),
      );

      final HospitalClient saved;
      if (_isEdit) {
        saved = await clientsRepo.updateClient(draft);
      } else {
        saved = await clientsRepo.createClient(draft);
      }

      if (_addMachine && !_isEdit) {
        final partsList = _parts
            .where((p) => p.nameCtrl.text.trim().isNotEmpty)
            .map((p) => MachinePart.draft(
                  partName: p.nameCtrl.text.trim(),
                  serialNumber: p.serialCtrl.text.trim(),
                ))
            .toList();

        final typeEnum = MachineType.fromString(_machineType);

        final machineDraft = InstalledMachine(
          id: '',
          hospitalId: saved.id,
          machineType: typeEnum,
          brand: _brand,
          model: _machineModelCtrl.text.trim(),
          serialNumber: _machineSerialCtrl.text.trim().isEmpty
              ? null
              : _machineSerialCtrl.text.trim(),
          installationEngineerName: null,
          installationDate: _installDate,
          warrantyPeriod: _warrantyMonths,
          createdAt: DateTime.now(),

          // Conditionally submit configurations based on _showPcConfig layout gate state
          pcCpu: _showPcConfig && _pcCpuCtrl.text.trim().isNotEmpty ? _pcCpuCtrl.text.trim() : null,
          pcRam: _showPcConfig && _pcRamCtrl.text.trim().isNotEmpty ? _pcRamCtrl.text.trim() : null,
          pcStorage: _showPcConfig && _pcStorageCtrl.text.trim().isNotEmpty ? _pcStorageCtrl.text.trim() : null,
          pcOs: _showPcConfig && _pcOsCtrl.text.trim().isNotEmpty ? _pcOsCtrl.text.trim() : null,
          
          customMetadata: {
            if (_showPcConfig && _pcMoboCtrl.text.trim().isNotEmpty)
              'pc_motherboard': _pcMoboCtrl.text.trim(),
            if (_showPcConfig && _pcLanPorts != null && _pcLanPorts!.trim().isNotEmpty)
              'pc_lan_ports': _pcLanPorts!.trim(),
            if (typeEnum == MachineType.fpd && _fpdLicenseType != null && _fpdLicenseType!.trim().isNotEmpty)
              'fpd_license_type': _fpdLicenseType!.trim(),
            if (typeEnum == MachineType.fpd && _fpdDongleSerialCtrl.text.trim().isNotEmpty)
              'fpd_dongle_serial': _fpdDongleSerialCtrl.text.trim(),
          },

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
        );

        final createdMachine = await machinesRepo.createMachineWithParts(
          machineDraft,
          partsList,
          _selectedEngineers,
        );

        if (_pdfBytes != null && _pdfFileName != null) {
          final storagePath = await machinesRepo.uploadInvoice(
            machineId: createdMachine.id,
            fileBytes: _pdfBytes!,
            fileName: _pdfFileName!,
          );
          await machinesRepo.updateMachineWithParts(
            createdMachine.copyWith(invoiceUrl: storagePath),
            createdMachine.parts,
            _selectedEngineers,
          );
        }
      }

      if (mounted) {
        context.read<ClientsBloc>().add(ClientsFetchRequested());
        AppFeedback.success(
          context,
          _isEdit ? 'Client updated.' : 'Client created successfully.',
        );
        context.go('/clients/${saved.id}');
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
    final isCompact = width < 600;

    return Scaffold(
      backgroundColor: AppColors.surface0,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(_isEdit ? 'Edit Client' : 'Add New Client'),
        actions: [
          if (!_isEdit)
            isCompact
                ? IconButton(
                    onPressed: _openModelEditor,
                    icon: const Icon(Icons.tune_rounded),
                    tooltip: 'Model Editor',
                  )
                : TextButton.icon(
                    onPressed: _openModelEditor,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Model Editor'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                    ),
                  ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.md),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 800 : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Facility Information'),
                    const SizedBox(height: AppSpacing.md),
                    _FormCard(
                      children: [
                        _Field(
                          label: 'Hospital / Facility Name',
                          child: TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Dhaka Medical College Hospital',
                            ),
                            validator: _required,
                          ),
                        ),
                        _Field(
                          label: 'Address',
                          child: TextFormField(
                            controller: _addressCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'Full street address',
                            ),
                            validator: _required,
                          ),
                        ),
                        _buildTwoColumnFields(
                          left: _Field(
                            label: 'District',
                            child: TextFormField(
                              controller: _districtCtrl,
                              decoration: const InputDecoration(
                                hintText: 'e.g. Dhaka',
                              ),
                              validator: _required,
                            ),
                          ),
                          right: _Field(
                            label: 'Division',
                            child: DropdownButtonFormField<DivisionType>(
                              value: _division,
                              dropdownColor: AppColors.surface2,
                              decoration: const InputDecoration(),
                              items: DivisionType.values
                                  .map((d) => DropdownMenuItem(
                                        value: d,
                                        child: Text(d.label),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _division = v!),
                            ),
                          ),
                        ),
                        _buildTwoColumnFields(
                          left: _Field(
                            label: 'Facility Type',
                            child: DropdownButtonFormField<FacilityType>(
                              value: _facilityType,
                              dropdownColor: AppColors.surface2,
                              decoration: const InputDecoration(),
                              items: FacilityType.values
                                  .map((f) => DropdownMenuItem(
                                        value: f,
                                        child: Text(f.label),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _facilityType = v!),
                            ),
                          ),
                          right: BlocBuilder<ConfigBloc, ConfigState>(
                            builder: (context, cfg) => _Field(
                              label: 'Genre / Specialty',
                              child: DropdownButtonFormField<String>(
                                value: (cfg.genres.contains(_genre) &&
                                        _genre.isNotEmpty)
                                    ? _genre
                                    : null,
                                dropdownColor: AppColors.surface2,
                                hint: const Text('Select genre'),
                                decoration: const InputDecoration(),
                                items: [
                                  ...cfg.genres.map(
                                    (g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(g),
                                    ),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _genre = v ?? ''),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionTitle('Contact Person'),
                    const SizedBox(height: AppSpacing.md),
                    _FormCard(
                      children: [
                        _buildTwoColumnFields(
                          left: _Field(
                            label: 'Full Name',
                            child: TextFormField(
                              controller: _contactNameCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Dr. Kamal Hossain',
                              ),
                              validator: _required,
                            ),
                          ),
                          right: _Field(
                            label: 'Designation',
                            child: TextFormField(
                              controller: _contactDesigCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Director, Medical',
                              ),
                              validator: _required,
                            ),
                          ),
                        ),
                        _Field(
                          label: 'Phone Number',
                          child: TextFormField(
                            controller: _contactPhoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: '+880 1X XX XXX XXX',
                            ),
                            validator: _required,
                          ),
                        ),
                      ],
                    ),
                    if (!_isEdit) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: _SectionTitle('Installed Machine'),
                          ),
                          Switch(
                            value: _addMachine,
                            onChanged: (v) => setState(() => _addMachine = v),
                            activeColor: AppColors.accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _addMachine
                            ? 'Fill in the machine details below.'
                            : 'Toggle to add a machine to this client now.',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (_addMachine) ...[
                        const SizedBox(height: AppSpacing.md),
                        _MachineSection(
                          brand: _brand,
                          machineType: _machineType,
                          machineModelCtrl: _machineModelCtrl,
                          machineSerialCtrl: _machineSerialCtrl,
                          selectedEngineers: _selectedEngineers,
                          onEngineersChanged: (v) =>
                              setState(() => _selectedEngineers = v),
                          installDate: _installDate,
                          warrantyMonths: _warrantyMonths,
                          dateFmt: _dateFmt,
                          showPcConfig: _showPcConfig,
                          onShowPcConfigChanged: (v) =>
                              setState(() => _showPcConfig = v),
                          pcCpuCtrl: _pcCpuCtrl,
                          pcRamCtrl: _pcRamCtrl,
                          pcStorageCtrl: _pcStorageCtrl,
                          pcOsCtrl: _pcOsCtrl,
                          pcMoboCtrl: _pcMoboCtrl,
                          pcLanPorts: _pcLanPorts,
                          fpdAcqIdCtrl: _fpdAcqIdCtrl,
                          fpdSoftwareCtrl: _fpdSoftwareCtrl,
                          fpdVersionCtrl: _fpdVersionCtrl,
                          fpdModuleCtrl: _fpdModuleCtrl,
                          fpdLicenseCtrl: _fpdLicenseCtrl,
                          fpdLicenseType: _fpdLicenseType,
                          fpdDongleSerialCtrl: _fpdDongleSerialCtrl,
                          printerAeCtrl: _printerAeCtrl,
                          printerIp1Ctrl: _printerIp1Ctrl,
                          printerIp2Ctrl: _printerIp2Ctrl,
                          printerPortCtrl: _printerPortCtrl,
                          printerPcVerCtrl: _printerPcVerCtrl,
                          printerMbVerCtrl: _printerMbVerCtrl,
                          printerImagerVerCtrl: _printerImagerVerCtrl,
                          xrayConsoleCtrl: _xrayConsoleCtrl,
                          xrayTubeCtrl: _xrayTubeCtrl,
                          xrayGeneratorCtrl: _xrayGeneratorCtrl,
                          onBrandChanged: (v) => setState(() => _brand = v),
                          onTypeChanged: (v) =>
                              setState(() => _machineType = v),
                          onDateTap: _pickDate,
                          onWarrantyChanged: (v) =>
                              setState(() => _warrantyMonths = v),
                          onLanPortsChanged: (v) =>
                              setState(() => _pcLanPorts = v),
                          onFpdLicenseTypeChanged: (v) =>
                              setState(() => _fpdLicenseType = v),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const _SectionTitle('Machine Parts'),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Add individual component parts with serial numbers.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _PartsSection(
                          parts: _parts,
                          onAdd: _addPart,
                          onRemove: _removePart,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const _SectionTitle('PDF Receipt / Invoice'),
                        const SizedBox(height: AppSpacing.md),
                        _PdfPickerCard(
                          fileName: _pdfFileName,
                          onPick: _pickPdf,
                          onClear: () => setState(() {
                            _pdfFileName = null;
                            _pdfBytes = null;
                          }),
                        ),
                      ],
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          shape: const StadiumBorder(),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEdit ? 'Save Changes' : 'Create Client',
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required' : null;
}

// ─────────────────────────────────────────────────────────────
// Machine section widget
// ─────────────────────────────────────────────────────────────

class _MachineSection extends StatelessWidget {
  const _MachineSection({
    required this.brand,
    required this.machineType,
    required this.machineModelCtrl,
    required this.machineSerialCtrl,
    required this.selectedEngineers,
    required this.onEngineersChanged,
    required this.installDate,
    required this.warrantyMonths,
    required this.dateFmt,
    required this.showPcConfig,
    required this.onShowPcConfigChanged,
    required this.pcCpuCtrl,
    required this.pcRamCtrl,
    required this.pcStorageCtrl,
    required this.pcOsCtrl,
    required this.pcMoboCtrl,
    required this.pcLanPorts,
    required this.fpdAcqIdCtrl,
    required this.fpdSoftwareCtrl,
    required this.fpdVersionCtrl,
    required this.fpdModuleCtrl,
    required this.fpdLicenseCtrl,
    required this.fpdLicenseType,
    required this.fpdDongleSerialCtrl,
    required this.printerAeCtrl,
    required this.printerIp1Ctrl,
    required this.printerIp2Ctrl,
    required this.printerPortCtrl,
    required this.printerPcVerCtrl,
    required this.printerMbVerCtrl,
    required this.printerImagerVerCtrl,
    required this.xrayConsoleCtrl,
    required this.xrayTubeCtrl,
    required this.xrayGeneratorCtrl,
    required this.onBrandChanged,
    required this.onTypeChanged,
    required this.onDateTap,
    required this.onWarrantyChanged,
    required this.onLanPortsChanged,
    required this.onFpdLicenseTypeChanged,
  });

  final String brand;
  final String machineType;
  final TextEditingController machineModelCtrl;
  final TextEditingController machineSerialCtrl;
  final List<String> selectedEngineers;
  final ValueChanged<List<String>> onEngineersChanged;
  final DateTime installDate;
  final int warrantyMonths;
  final DateFormat dateFmt;

  final bool showPcConfig;
  final ValueChanged<bool> onShowPcConfigChanged;

  final TextEditingController pcCpuCtrl;
  final TextEditingController pcRamCtrl;
  final TextEditingController pcStorageCtrl;
  final TextEditingController pcOsCtrl;
  final TextEditingController pcMoboCtrl;
  final String? pcLanPorts;

  final TextEditingController fpdAcqIdCtrl;
  final TextEditingController fpdSoftwareCtrl;
  final TextEditingController fpdVersionCtrl;
  final TextEditingController fpdModuleCtrl;
  final TextEditingController fpdLicenseCtrl;
  final String? fpdLicenseType;
  final TextEditingController fpdDongleSerialCtrl;

  final TextEditingController printerAeCtrl;
  final TextEditingController printerIp1Ctrl;
  final TextEditingController printerIp2Ctrl;
  final TextEditingController printerPortCtrl;
  final TextEditingController printerPcVerCtrl;
  final TextEditingController printerMbVerCtrl;
  final TextEditingController printerImagerVerCtrl;

  final TextEditingController xrayConsoleCtrl;
  final TextEditingController xrayTubeCtrl;
  final TextEditingController xrayGeneratorCtrl;

  final ValueChanged<String> onBrandChanged;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onDateTap;
  final ValueChanged<int> onWarrantyChanged;
  final ValueChanged<String?> onLanPortsChanged;
  final ValueChanged<String?> onFpdLicenseTypeChanged;

  Widget _buildTwoColumnFields({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              const SizedBox(height: AppSpacing.sm),
              right,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<ConfigBloc, ConfigState>(
      builder: (context, cfg) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FormCard(
              children: [
                _buildTwoColumnFields(
                  left: _Field(
                    label: 'Machine Type',
                    child: DropdownButtonFormField<String>(
                      value: (cfg.machineTypes.contains(machineType) &&
                              machineType.isNotEmpty)
                          ? machineType
                          : null,
                      dropdownColor: AppColors.surface2,
                      hint: const Text('Select type'),
                      decoration: const InputDecoration(),
                      items: cfg.machineTypes
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t),
                              ))
                          .toList(),
                      onChanged: (v) => onTypeChanged(v ?? ''),
                    ),
                  ),
                  right: _Field(
                    label: 'Brand',
                    child: DropdownButtonFormField<String>(
                      value: (cfg.brands.contains(brand) && brand.isNotEmpty)
                          ? brand
                          : null,
                      dropdownColor: AppColors.surface2,
                      hint: const Text('Select brand'),
                      decoration: const InputDecoration(),
                      items: cfg.brands
                          .map((b) => DropdownMenuItem(
                                value: b,
                                child: Text(b),
                              ))
                          .toList(),
                      onChanged: (v) => onBrandChanged(v ?? ''),
                    ),
                  ),
                ),
                _buildTwoColumnFields(
                  left: _Field(
                    label: 'Model',
                    child: TextFormField(
                      controller: machineModelCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. GXR-S'),
                    ),
                  ),
                  right: _Field(
                    label: 'Serial Number (optional)',
                    child: TextFormField(
                      controller: machineSerialCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. SN-2024-001'),
                    ),
                  ),
                ),
                _Field(
                  label: 'Installation Engineers',
                  child: BlocBuilder<EngineersBloc, EngineersState>(
                    builder: (context, state) {
                      if (state is EngineersLoading) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }

                      if (state is EngineersLoaded) {
                        final engineers = state.engineers;

                        if (engineers.isEmpty) {
                          return const Text('No engineers registered in the system.');
                        }

                        return Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: engineers.map((engineer) {
                            final isSelected = selectedEngineers.contains(engineer.id);
                            final isAvailable = engineer.isAvailable;

                            return FilterChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(engineer.name),
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
                              onSelected: isAvailable
                                  ? (selected) {
                                      final updated = List<String>.from(selectedEngineers);
                                      if (selected) {
                                        updated.add(engineer.id);
                                      } else {
                                        updated.remove(engineer.id);
                                      }
                                      onEngineersChanged(updated);
                                    }
                                  : null,
                              
                              selectedColor: AppColors.accent.withOpacity(0.2),
                              checkmarkColor: AppColors.accent,
                              disabledColor: Colors.orange.withOpacity(0.12),
                              side: BorderSide(
                                color: isAvailable 
                                    ? (isSelected ? AppColors.accent : AppColors.surface3) 
                                    : Colors.orange.shade400,
                                width: 1,
                              ),
                              labelStyle: TextStyle(
                                color: isAvailable 
                                    ? AppColors.textPrimary 
                                    : Colors.orange.shade300,
                                fontWeight: isAvailable ? FontWeight.normal : FontWeight.w500,
                              ),
                            );
                          }).toList(),
                        );
                      }

                      if (state is EngineersError) {
                        return Text(
                          'Error loading engineers: ${state.message}', 
                          style: const TextStyle(color: Colors.red),
                        );
                      }

                      return const Text('Initializing directory...');
                    },
                  ),
                ),
                _buildTwoColumnFields(
                  left: _Field(
                    label: 'Installation Date',
                    child: GestureDetector(
                      onTap: onDateTap,
                      child: AbsorbPointer(
                        child: TextFormField(
                          key: ValueKey(installDate),
                          initialValue: dateFmt.format(installDate),
                          decoration: const InputDecoration(
                            suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                  right: _Field(
                    label: 'Warranty Period',
                    child: _WarrantyStepper(
                      value: warrantyMonths,
                      onChanged: onWarrantyChanged,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            
            // ── Conditional Block for Machine Parameters ────
            if (machineType.isNotEmpty) ...[
              _buildConditionalTechnicalFields(),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── PC Configuration Block with Animated View Gating ───
            _SectionTitle('PC Configuration (Optional)'),
            const SizedBox(height: AppSpacing.xs),
            
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
              value: showPcConfig,
              onChanged: onShowPcConfigChanged,
            ),
            const SizedBox(height: AppSpacing.sm),
            
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: !showPcConfig
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: _FormCard(
                        children: [
                          _buildTwoColumnFields(
                            left: _Field(
                              label: 'CPU',
                              child: TextFormField(
                                controller: pcCpuCtrl,
                                decoration: const InputDecoration(hintText: 'e.g. Core i7'),
                              ),
                            ),
                            right: _Field(
                              label: 'RAM',
                              child: TextFormField(
                                controller: pcRamCtrl,
                                decoration: const InputDecoration(hintText: 'e.g. 16GB'),
                              ),
                            ),
                          ),
                          _buildTwoColumnFields(
                            left: _Field(
                              label: 'Storage',
                              child: TextFormField(
                                controller: pcStorageCtrl,
                                decoration: const InputDecoration(hintText: 'e.g. 512GB SSD'),
                              ),
                            ),
                            right: _Field(
                              label: 'Operating System',
                              child: TextFormField(
                                controller: pcOsCtrl,
                                decoration: const InputDecoration(hintText: 'e.g. Windows 11 Pro'),
                              ),
                            ),
                          ),
                          _buildTwoColumnFields(
                            left: _Field(
                              label: 'Motherboard',
                              child: TextFormField(
                                controller: pcMoboCtrl,
                                decoration: const InputDecoration(hintText: 'e.g. Asus Prime H610'),
                              ),
                            ),
                            right: _Field(
                              label: 'Number of LAN ports',
                              child: DropdownButtonFormField<String>(
                                value: pcLanPorts,
                                isExpanded: true,
                                dropdownColor: AppColors.surface2,
                                items: ['1', '2', '3', '4']
                                    .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                                    .toList(),
                                onChanged: onLanPortsChanged,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConditionalTechnicalFields() {
    final type = MachineType.fromString(machineType);

    switch (type) {
      case MachineType.printer:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Printer Specifications'),
            const SizedBox(height: AppSpacing.md),
            _FormCard(
              children: [
                _Field(
                  label: 'AE Title',
                  child: TextFormField(
                    controller: printerAeCtrl,
                    decoration: const InputDecoration(hintText: 'e.g. DRYPIX_PRINTER'),
                  ),
                ),
                _buildTwoColumnFields(
                  left: _Field(
                    label: 'IP Address 1',
                    child: TextFormField(
                      controller: printerIp1Ctrl,
                      decoration: const InputDecoration(hintText: '192.168.1.10'),
                    ),
                  ),
                  right: _Field(
                    label: 'IP Address 2',
                    child: TextFormField(
                      controller: printerIp2Ctrl,
                      decoration: const InputDecoration(hintText: '192.168.1.11'),
                    ),
                  ),
                ),
                _buildTwoColumnFields(
                  left: _Field(
                    label: 'Port',
                    child: TextFormField(
                      controller: printerPortCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. 5040'),
                    ),
                  ),
                  right: _Field(
                    label: 'PC Version',
                    child: TextFormField(
                      controller: printerPcVerCtrl,
                      decoration: const InputDecoration(hintText: 'v2.1.0'),
                    ),
                  ),
                ),
                _buildTwoColumnFields(
                  left: _Field(
                    label: 'MB Version',
                    child: TextFormField(
                      controller: printerMbVerCtrl,
                      decoration: const InputDecoration(hintText: 'v1.04'),
                    ),
                  ),
                  right: _Field(
                    label: 'Imager Version',
                    child: TextFormField(
                      controller: printerImagerVerCtrl,
                      decoration: const InputDecoration(hintText: 'v3.5.2'),
                    ),
                  ),
                ),
              ],
            ),
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
                _Field(
                  label: 'Console S/L',
                  child: TextFormField(
                    controller: xrayConsoleCtrl,
                    decoration: const InputDecoration(hintText: 'Enter console serial number'),
                  ),
                ),
                _Field(
                  label: 'Tube S/L',
                  child: TextFormField(
                    controller: xrayTubeCtrl,
                    decoration: const InputDecoration(hintText: 'Enter tube serial number'),
                  ),
                ),
                _Field(
                  label: 'Generator S/L',
                  child: TextFormField(
                    controller: xrayGeneratorCtrl,
                    decoration: const InputDecoration(hintText: 'Enter generator serial number'),
                  ),
                ),
              ],
            ),
          ],
        );

      case MachineType.fpd:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Flat Panel Detector Parameters'),
            const SizedBox(height: AppSpacing.md),
            _FormCard(
              children: [
                _Field(
                  label: 'Acquisition ID Number',
                  child: TextFormField(
                    controller: fpdAcqIdCtrl,
                    decoration: const InputDecoration(hintText: 'e.g. ACQ-99012'),
                  ),
                ),
                _buildTwoColumnFields(
                  left: _Field(
                    label: 'Software Name',
                    child: TextFormField(
                      controller: fpdSoftwareCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. Radrex'),
                    ),
                  ),
                  right: _Field(
                    label: 'Software Version',
                    child: TextFormField(
                      controller: fpdVersionCtrl,
                      decoration: const InputDecoration(hintText: 'v4.2'),
                    ),
                  ),
                ),
                _buildTwoColumnFields(
                  left: _Field(
                    label: 'Module Info',
                    child: TextFormField(
                      controller: fpdModuleCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. Pixium 3543'),
                    ),
                  ),
                  right: _Field(
                    label: 'License String / Key',
                    child: TextFormField(
                      controller: fpdLicenseCtrl,
                      decoration: const InputDecoration(hintText: 'License status'),
                    ),
                  ),
                ),
                _buildTwoColumnFields(
                  left: _Field(
                    label: 'License Type',
                    child: DropdownButtonFormField<String>(
                      value: fpdLicenseType,
                      isExpanded: true,
                      dropdownColor: AppColors.surface2,
                      items: ['Hardware/Dongle Key', 'Software Key', 'Demo']
                          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: onFpdLicenseTypeChanged,
                    ),
                  ),
                  right: _Field(
                    label: 'Dongle Serial',
                    child: TextFormField(
                      controller: fpdDongleSerialCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. DG-7710X'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Parts section
// ─────────────────────────────────────────────────────────────

class _PartsSection extends StatelessWidget {
  const _PartsSection({
    required this.parts,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_PartRow> parts;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (parts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: AppRadius.card,
              border: Border.all(
                color: AppColors.surface3,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.build_circle_rounded,
                  size: 36,
                  color: AppColors.surface3,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'No parts added yet',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          )
        else
          _FormCard(
            children: List.generate(
              parts.length,
              (i) => _PartRowWidget(
                index: i,
                row: parts[i],
                onRemove: () => onRemove(i),
                showDivider: i < parts.length - 1,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Part'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
      ],
    );
  }
}

class _PartRowWidget extends StatelessWidget {
  const _PartRowWidget({
    required this.index,
    required this.row,
    required this.onRemove,
    required this.showDivider,
  });

  final int index;
  final _PartRow row;
  final VoidCallback onRemove;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Field(
                label: 'Part Name',
                child: TextFormField(
                  controller: row.nameCtrl,
                  decoration:
                      const InputDecoration(hintText: 'e.g. X-ray Tube'),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Field(
                label: 'Serial Number',
                child: TextFormField(
                  controller: row.serialCtrl,
                  decoration:
                      const InputDecoration(hintText: 'e.g. XT-20240012'),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.remove_circle_rounded),
                color: AppColors.error,
                tooltip: 'Remove part',
              ),
            ),
          ],
        ),
        if (showDivider) const Divider(height: AppSpacing.md),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PDF picker card
// ─────────────────────────────────────────────────────────────

class _PdfPickerCard extends StatelessWidget {
  const _PdfPickerCard({
    required this.fileName,
    required this.onPick,
    required this.onClear,
  });

  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFile = fileName != null;

    return GestureDetector(
      onTap: hasFile ? null : onPick,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: AppRadius.card,
          border: Border.all(
            color: hasFile ? AppColors.accent : AppColors.surface3,
          ),
        ),
        child: hasFile
            ? Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded,
                      color: AppColors.error, size: 28),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fileName!, style: theme.textTheme.titleSmall),
                        Text('PDF selected — ready to upload',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.success,
                            )),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textTertiary,
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_file_rounded,
                      color: AppColors.textTertiary),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tap to select PDF receipt',
                          style: theme.textTheme.bodyMedium),
                      Text('Max 50 MB · PDF only',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Small helper widgets
// ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.4,
                  color: AppColors.textTertiary,
                ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Divider()),
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
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.1,
                    color: AppColors.textTertiary,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            child,
          ],
        ),
      );
}

class _WarrantyStepper extends StatelessWidget {
  const _WarrantyStepper({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
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
}

// ─────────────────────────────────────────────────────────────
// Internal data class for a part form row
// ─────────────────────────────────────────────────────────────

class _PartRow {
  _PartRow()
      : nameCtrl = TextEditingController(),
        serialCtrl = TextEditingController();

  final TextEditingController nameCtrl;
  final TextEditingController serialCtrl;

  void dispose() {
    nameCtrl.dispose();
    serialCtrl.dispose();
  }
}
