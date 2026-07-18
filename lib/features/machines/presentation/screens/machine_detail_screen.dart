// lib/features/machines/presentation/screens/machine_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../config/data/repositories/config_repository.dart';
import '../../../config/presentation/bloc/config_bloc.dart';
import '../../../engineers/presentation/bloc/engineers_bloc.dart';
import '../../../engineers/presentation/screens/engineer_form_sheet.dart';
import '../../data/models/installed_machine.dart';
import '../../data/models/engineer.dart';
import '../../data/models/machine_part.dart';
import '../../data/repositories/machines_repository.dart';
import '../bloc/machines_bloc.dart';
import 'add_machine_page.dart';
import 'invoice_viewer_screen.dart';

class MachineDetailScreen extends StatefulWidget {
  const MachineDetailScreen({
    super.key,
    required this.machineId,
    required this.clientId,
  });
  final String machineId;
  final String clientId;

  @override
  State<MachineDetailScreen> createState() => _MachineDetailScreenState();
}

class _MachineDetailScreenState extends State<MachineDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MachinesBloc>().add(MachineFetchByIdRequested(widget.machineId));
  }

  Future<void> _openEdit(InstalledMachine machine) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<MachinesBloc>()),
            BlocProvider(
              create: (_) => ConfigBloc(
                repository: context.read<ConfigRepository>(),
              )..add(ConfigLoadRequested()),
            ),
          ],
          child: AddMachinePage(
            hospitalId: widget.clientId,
            existingMachine: machine,
          ),
        ),
      ),
    );
    if (result == true && mounted) {
      context.read<MachinesBloc>().add(MachineFetchByIdRequested(widget.machineId));
      AppFeedback.success(context, 'Machine updated.');
    }
  }

  Future<void> _deleteMachine(InstalledMachine machine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('Delete machine?'),
        content: Text('Delete "${machine.brand} ${machine.model}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await context.read<MachinesRepository>().deleteMachine(machine.id);
        if (mounted) {
          context.read<MachinesBloc>().add(MachinesFetchRequested(widget.clientId));
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) AppFeedback.error(context, e.toString());
      }
    }
  }

  Future<void> _requestInvoiceUrl(String path) async {
    context.read<MachinesBloc>().add(MachineInvoiceUrlRequested(path));
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is AuthAuthenticated && authState.profile.isAdmin;

    return Scaffold(
      backgroundColor: AppColors.surface0,
      body: BlocConsumer<MachinesBloc, MachinesState>(
        listener: (context, state) {
          if (state is MachinesError) {
            AppFeedback.error(context, state.message);
          }
        },
        builder: (context, state) {
          if (state is MachinesLoading) {
            return Scaffold(
              backgroundColor: AppColors.surface0,
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (state is MachinesError) {
            return Scaffold(
              backgroundColor: AppColors.surface0,
              appBar: AppBar(
                leading: BackButton(onPressed: () => Navigator.of(context).pop()),
                title: const Text('Machine Detail'),
              ),
              body: Center(
                child: Text(state.message,
                    style: const TextStyle(color: AppColors.error)),
              ),
            );
          }
          if (state is MachineDetailLoaded) {
            return Scaffold(
              backgroundColor: AppColors.surface0,
              appBar: AppBar(
                leading: BackButton(onPressed: () => Navigator.of(context).pop()),
                title: Text('${state.machine.brand} ${state.machine.model}',
                    overflow: TextOverflow.ellipsis),
                actions: [
                  if (isAdmin) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_rounded),
                      tooltip: 'Edit machine',
                      onPressed: () => _openEdit(state.machine),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded),
                      tooltip: 'Delete machine',
                      color: AppColors.error,
                      onPressed: () => _deleteMachine(state.machine),
                    ),
                  ],
                ],
              ),
              body: _MachineDetailBody(
                machine: state.machine,
                signedInvoiceUrl: state.signedInvoiceUrl,
                isAdmin: isAdmin,
                onRequestInvoiceUrl: _requestInvoiceUrl,
                onViewInvoice: (url) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InvoiceViewerScreen(
                        signedUrl: url,
                        title: 'Invoice — ${state.machine.brand} ${state.machine.model}',
                      ),
                    ),
                  );
                },
              ),
            );
          }
          return Scaffold(
            backgroundColor: AppColors.surface0,
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────

class _MachineDetailBody extends StatelessWidget {
  const _MachineDetailBody({
    required this.machine,
    required this.isAdmin,
    required this.onRequestInvoiceUrl,
    required this.onViewInvoice,
    this.signedInvoiceUrl,
  });

  final InstalledMachine machine;
  final bool isAdmin;
  final String? signedInvoiceUrl;
  final void Function(String path) onRequestInvoiceUrl;
  final void Function(String url) onViewInvoice;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final padding = EdgeInsets.all(isDesktop ? 32.0 : 16.0);

    return SingleChildScrollView(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 860 : double.infinity),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Identity (Includes PC and Conditional Specs) ───────
              _MachineIdentityCard(machine: machine),
              const SizedBox(height: AppSpacing.md),

              // ── Warranty Lifecycle ───────────────────────
              _WarrantyLifecycle(machine: machine),
              const SizedBox(height: AppSpacing.md),

              // ── Parts ────────────────────────────────────
              if (machine.parts.isNotEmpty) ...[
                _PartsCard(parts: machine.parts),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── Engineers ────────────────────────────────
              _EngineersCard(
                machine: machine,
                isAdmin: isAdmin,
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Invoice ──────────────────────────────────
              if (machine.invoiceUrl != null)
                _InvoiceCard(
                  machine: machine,
                  signedUrl: signedInvoiceUrl,
                  onRequestUrl: () => onRequestInvoiceUrl(machine.invoiceUrl!),
                  onView: onViewInvoice,
                ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}



// ─────────────────────────────────────────────────────────────
// Machine identity card — Displays hardware parameters
// ─────────────────────────────────────────────────────────────

class _MachineIdentityCard extends StatelessWidget {
  const _MachineIdentityCard({required this.machine});
  final InstalledMachine machine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('d MMM yyyy');

    // Check if any workstation PC configuration exists
    final hasPcSpecs = machine.pcCpu != null ||
        machine.pcRam != null ||
        machine.pcStorage != null ||
        machine.pcOs != null ||
        machine.pcMobo != null || // Added check[cite: 5, 7]
        machine.pcLanPorts != null; // Added check[cite: 5, 7]

    return _SectionCard(
      header: 'MACHINE DETAILS',
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.accentSurface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.precision_manufacturing_rounded,
                  color: AppColors.accent, size: 26),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${machine.brand} ${machine.model}',
                      style: theme.textTheme.titleLarge),
                  Text(machine.machineType.label,
                      style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        _DetailRow(label: 'Machine Type', value: machine.machineType.label),
        _DetailRow(label: 'Brand', value: machine.brand),
        _DetailRow(label: 'Model', value: machine.model),
        if (machine.serialNumber != null)
          _DetailRow(label: 'Serial No.', value: machine.serialNumber!),
        if (machine.installationEngineerName != null)
          _DetailRow(
              label: 'Installed By', value: machine.installationEngineerName!),
        _DetailRow(
            label: 'Install Date', value: fmt.format(machine.installationDate)),
        _DetailRow(
            label: 'Warranty Period', value: '${machine.warrantyPeriod} months'),
        _DetailRow(
            label: 'Expiry Date', value: fmt.format(machine.warrantyExpiryDate)),
        if (machine.notes != null && machine.notes!.isNotEmpty)
          _DetailRow(label: 'Notes', value: machine.notes!),

        // ── CONDITIONAL FIELD SYSTEM SPECIFICATIONS ──────────────────
        if (machine.machineType == MachineType.printer &&
            (machine.printerAe != null || machine.printerPort != null)) ...[
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'PRINTER SPECIFICATIONS',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (machine.printerAe != null) _DetailRow(label: 'Printer AE Title', value: machine.printerAe!),
          if (machine.printerIp1 != null) _DetailRow(label: 'Printer IP 1', value: machine.printerIp1!),
          if (machine.printerIp2 != null) _DetailRow(label: 'Printer IP 2', value: machine.printerIp2!),
          if (machine.printerPort != null) _DetailRow(label: 'Printer Port', value: machine.printerPort!),
          if (machine.printerPcVersion != null) _DetailRow(label: 'PC Version', value: machine.printerPcVersion!),
          if (machine.printerMbVersion != null) _DetailRow(label: 'MB Version', value: machine.printerMbVersion!),
          if (machine.printerImagerVersion != null) _DetailRow(label: 'Imager Version', value: machine.printerImagerVersion!),
        ],

        if (machine.machineType == MachineType.xRay &&
            (machine.xrayConsoleSl != null || machine.xrayTubeSl != null || machine.xrayGeneratorSl != null)) ...[
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'X-RAY SPECIFICATIONS',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (machine.xrayConsoleSl != null) _DetailRow(label: 'Console S/N', value: machine.xrayConsoleSl!),
          if (machine.xrayTubeSl != null) _DetailRow(label: 'Tube S/N', value: machine.xrayTubeSl!),
          if (machine.xrayGeneratorSl != null) _DetailRow(label: 'Generator S/N', value: machine.xrayGeneratorSl!),
        ],

        if (machine.machineType == MachineType.fpd &&
            (machine.fpdAcqId != null || 
             machine.fpdSoftware != null || 
             machine.fpdLicenseType != null || // Added check[cite: 5, 7]
             machine.fpdDongleSerial != null)) ...[ // Added check[cite: 5, 7]
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'FPD SPECIFICATIONS',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (machine.fpdAcqId != null) _DetailRow(label: 'Acquisition ID', value: machine.fpdAcqId!),
          if (machine.fpdSoftware != null) _DetailRow(label: 'Software Name', value: machine.fpdSoftware!),
          if (machine.fpdVersion != null) _DetailRow(label: 'Software Version', value: machine.fpdVersion!),
          if (machine.fpdModule != null) _DetailRow(label: 'Module Info', value: machine.fpdModule!),
          if (machine.fpdLicense != null) _DetailRow(label: 'License Key', value: machine.fpdLicense!),
          if (machine.fpdLicenseType != null) _DetailRow(label: 'License Type', value: machine.fpdLicenseType!), // Added[cite: 5, 7]
          if (machine.fpdDongleSerial != null) _DetailRow(label: 'Dongle S/N', value: machine.fpdDongleSerial!), // Added[cite: 5, 7]
        ],

        // ── WORKSTATION PC SUB-SECTION ───────────────────────────
        if (hasPcSpecs) ...[
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'WORKSTATION HARDWARE',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (machine.pcCpu != null) _DetailRow(label: 'PC CPU', value: machine.pcCpu!),
          if (machine.pcRam != null) _DetailRow(label: 'PC RAM', value: machine.pcRam!),
          if (machine.pcStorage != null) _DetailRow(label: 'PC Storage', value: machine.pcStorage!),
          if (machine.pcOs != null) _DetailRow(label: 'Operating System', value: machine.pcOs!),
          if (machine.pcMobo != null) _DetailRow(label: 'Motherboard', value: machine.pcMobo!), // Added[cite: 5, 7]
          if (machine.pcLanPorts != null) _DetailRow(label: 'LAN Ports', value: '${machine.pcLanPorts} ports'), // Added[cite: 5, 7]
        ],

        // ── ASSIGNED IP GRID ─────────────────────────────────────
        if (machine.assignedIps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'NETWORK CONFIGURATION (IP)',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: machine.assignedIps.map((ip) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: AppRadius.chip,
                  border: Border.all(color: AppColors.surface3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lan_rounded, size: 12, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text(
                      ip,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],

        // ── SCALABLE METADATA GRID (EXTRA CUSTOM FIELDS) ───────────
        if (machine.customMetadata.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'ADDITIONAL PARAMETERS',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: machine.customMetadata.entries.map((entry) {
              return SizedBox(
                width: (MediaQuery.of(context).size.width >= 600) ? 260 : double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
// ─────────────────────────────────────────────────────────────
// Warranty lifecycle bar
// ─────────────────────────────────────────────────────────────

class _WarrantyLifecycle extends StatelessWidget {
  const _WarrantyLifecycle({required this.machine});
  final InstalledMachine machine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('MMM yyyy');

    final Color color;
    final String statusLabel;
    if (!machine.isWarrantyActive) {
      color = AppColors.error;
      statusLabel = 'EXPIRED';
    } else if (machine.isWarrantyExpiringSoon) {
      color = AppColors.warning;
      statusLabel = 'EXPIRING SOON';
    } else {
      color = AppColors.success;
      statusLabel = 'ACTIVE';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.surface2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('WARRANTY LIFECYCLE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.5,
                    color: AppColors.textTertiary,
                  )),
              _StatusPill(label: statusLabel, color: color),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                machine.warrantyLeftMonths.toString(),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text('months remaining',
                    style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: machine.warrantyProgressFraction,
              minHeight: 8,
              backgroundColor: AppColors.surface3,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(fmt.format(machine.installationDate),
                  style: theme.textTheme.labelSmall),
              Text(fmt.format(machine.warrantyExpiryDate),
                  style: theme.textTheme.labelSmall),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Install Date', style: theme.textTheme.bodySmall),
              Text('Expiry Date', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Parts card
// ─────────────────────────────────────────────────────────────

class _PartsCard extends StatelessWidget {
  const _PartsCard({required this.parts});
  final List<MachinePart> parts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionCard(
      header: 'MACHINE PARTS (${parts.length})',
      children: [
        ...parts.asMap().entries.map((entry) {
          final i = entry.key;
          final part = entry.value;
          return Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Center(
                      child: Text('${i + 1}',
                          style: theme.textTheme.labelSmall),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(part.partName, style: theme.textTheme.titleSmall),
                        Text('S/N: ${part.serialNumber}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: AppColors.textSecondary,
                            )),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: AppRadius.chip,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.build_rounded,
                            size: 10, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text('Part', style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                ],
              ),
              if (i < parts.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Divider(height: 1),
                ),
            ],
          );
        }),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────
// Engineers card — Shows list of assigned engineers
// ─────────────────────────────────────────────────────────────

class _EngineersCard extends StatelessWidget {
  const _EngineersCard({required this.machine, required this.isAdmin});
  final InstalledMachine machine;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SectionCard(
      header: 'ASSIGNED ENGINEERS (${machine.engineers.length})',
      children: [
        if (machine.engineers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text('No engineers assigned.',
                style: theme.textTheme.bodySmall),
          )
        else
          ...machine.engineers.asMap().entries.map((entry) {
            final i = entry.key;
            final eng = entry.value;

            // Resolve color and label based on the active boolean field
            final Color statusColor = eng.isAvailable 
                ? AppColors.success 
                : AppColors.warning;

            return Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.surface2,
                      child: Text(
                        eng.name.isNotEmpty ? eng.name[0].toUpperCase() : '?',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(eng.name, style: theme.textTheme.titleSmall),
                          Text(
                            eng.phone ?? 'No phone listed', // Safely fall back to phone or placeholder
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          eng.statusLabel, // Uses the model's computed helper text ('Available' / 'On Assignment')
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: statusColor),
                        ),
                      ],
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: AppSpacing.xs),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        color: AppColors.textTertiary,
                        tooltip: 'Edit engineer',
                        onPressed: () => EngineerFormSheet.show(
                          context,
                          machineId: machine.id,
                          engineer: eng,
                        ),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(AppSpacing.xs),
                      ),
                    ],
                  ],
                ),
                if (i < machine.engineers.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Divider(height: 1),
                  ),
              ],
            );
          }),
      ],
    );
  }
}
// ─────────────────────────────────────────────────────────────
// Invoice card
// ─────────────────────────────────────────────────────────────

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.machine,
    required this.onRequestUrl,
    required this.onView,
    this.signedUrl,
  });

  final InstalledMachine machine;
  final String? signedUrl;
  final VoidCallback onRequestUrl;
  final void Function(String url) onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileName =
        machine.invoiceUrl?.split('/').last ?? 'invoice.pdf';

    return _SectionCard(
      header: 'INVOICE / RECEIPT',
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded,
                  color: AppColors.error, size: 22),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis),
                  Text('PDF Document',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        if (signedUrl == null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRequestUrl,
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: const Text('Generate Secure Link'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onView(signedUrl!),
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text('View PDF'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(signedUrl!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    } else {
                      if (context.mounted) {
                        AppFeedback.error(
                            context, 'Cannot open URL.');
                      }
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.timer_rounded,
                  size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text('Link valid for 1 hour.',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.children,
    this.header,
    this.trailing,
  });

  final List<Widget> children;
  final String? header;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.surface2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  header!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.5,
                    color: AppColors.textTertiary,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: AppRadius.chip,
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      );
}