// lib/features/clients/presentation/screens/client_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../machines/data/models/installed_machine.dart';
import '../../../machines/presentation/bloc/machines_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../config/data/repositories/config_repository.dart';
import '../../../config/presentation/bloc/config_bloc.dart';
import '../../data/repositories/clients_repository.dart';
import '../../data/models/hospital_client.dart';
import '../bloc/clients_bloc.dart';
import 'add_client_page.dart';
import '../../../machines/presentation/screens/add_machine_page.dart';

class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({super.key, required this.clientId});
  final String clientId;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  HospitalClient? _client;
  bool _loadingClient = true;
  String? _clientError;

  @override
  void initState() {
    super.initState();
    _loadClient();
    _fetchMachines();
  }

  void _fetchMachines() {
    context.read<MachinesBloc>().add(MachinesFetchRequested(widget.clientId));
  }

  Future<void> _loadClient() async {
    setState(() {
      _loadingClient = true;
      _clientError = null;
    });
    try {
      final repo = context.read<ClientsRepository>();
      final client = await repo.getClientById(widget.clientId);
      if (mounted) {
        setState(() {
          _client = client;
          _loadingClient = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _clientError = e.toString();
          _loadingClient = false;
        });
      }
    }
  }

  Future<void> _openEdit() async {
    if (_client == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<ClientsBloc>()),
            BlocProvider(
              create: (_) => ConfigBloc(
                repository: context.read<ConfigRepository>(),
              )..add(ConfigLoadRequested()),
            ),
          ],
          child: AddClientPage(existingClient: _client),
        ),
      ),
    );
    _loadClient();
  }

  Future<void> _openAddMachine() async {
    if (_client == null) return;
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
          child: AddMachinePage(hospitalId: widget.clientId),
        ),
      ),
    );
    if (result == true && mounted) {
      _fetchMachines();
      AppFeedback.success(context, 'Machine added.');
    }
  }

  Future<void> _deleteClient() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('Delete client?'),
        content: Text(
          'This will permanently delete "${_client?.name}" and all their machines.',
        ),
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
        await context.read<ClientsRepository>().deleteClient(widget.clientId);
        context.read<ClientsBloc>().add(const ClientsFetchRequested());
        if (mounted) context.go('/clients');
      } catch (e) {
        if (mounted) AppFeedback.error(context, e.toString());
      }
    }
  }

  void _showErrorSnackBar(String errorMessage) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'RETRY',
          textColor: Colors.amberAccent,
          onPressed: _fetchMachines,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppConstants.tabletBreakpoint;
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is AuthAuthenticated && authState.profile.isAdmin;

    return Scaffold(
      backgroundColor: AppColors.surface0,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/clients'),
        ),
        title: Text(
          _client?.name ?? 'Client Detail',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (isAdmin && _client != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Edit client',
              onPressed: _openEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded),
              tooltip: 'Delete client',
              color: AppColors.error,
              onPressed: _deleteClient,
            ),
          ],
        ],
      ),
      body: _loadingClient
          ? const Center(child: CircularProgressIndicator())
          : _clientError != null
              ? ErrorStateWidget(
                  rawError: _clientError!,
                  onRetry: () {
                    _loadClient();
                    _fetchMachines();
                  },
                )
              : _client == null
                  ? const Center(child: Text('Client not found.'))
                  : BlocListener<MachinesBloc, MachinesState>(
                      listener: (context, state) {
                        if (state is MachinesError) {
                          _showErrorSnackBar(state.message);
                        }
                      },
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(
                          isDesktop ? AppSpacing.xl : AppSpacing.md,
                        ),
                        child: isDesktop
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 320,
                                    child: _ClientProfileCard(client: _client!),
                                  ),
                                  const SizedBox(width: AppSpacing.lg),
                                  Expanded(
                                    child: _MachinesList(
                                      isAdmin: isAdmin,
                                      clientId: widget.clientId,
                                      onAddMachine: _openAddMachine,
                                      onRetry: _fetchMachines,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _ClientProfileCard(client: _client!),
                                  const SizedBox(height: AppSpacing.lg),
                                  _MachinesList(
                                    isAdmin: isAdmin,
                                    clientId: widget.clientId,
                                    onAddMachine: _openAddMachine,
                                    onRetry: _fetchMachines,
                                  ),
                                ],
                              ),
                      ),
                    ),
    );
  }
}

// ── Client Profile Card ──────────────────────────────────────

class _ClientProfileCard extends StatelessWidget {
  const _ClientProfileCard({required this.client});
  final HospitalClient client;

  Future<void> _makeCall(BuildContext context, String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri url = Uri.parse('tel:$cleanNumber');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (context.mounted) {
          AppFeedback.error(context, 'Could not initiate connection to $phoneNumber');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppFeedback.error(context, 'Error launching system phone service.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.surface2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FACILITY PROFILE',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.5,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(client.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _Badge(label: client.division.label),
              _Badge(label: client.facilityType.label, accent: true),
              if (client.genre.isNotEmpty)
                _Badge(label: client.genre, color: AppColors.surface3),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.location_on_rounded,
            label: 'Address',
            value: client.address,
          ),
          if (client.district.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(
              icon: Icons.map_rounded,
              label: 'District',
              value: client.district,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'CONTACT PERSON',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.5,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            icon: Icons.person_rounded,
            label: 'Name',
            value: client.contactPersonName,
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            icon: Icons.badge_rounded,
            label: 'Designation',
            value: client.contactPersonDesignation,
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            icon: Icons.phone_rounded,
            label: 'Phone',
            value: client.contactPersonPhone.isNotEmpty
                ? client.contactPersonPhone
                : 'Not Provided',
            trailing: client.contactPersonPhone.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.call_rounded,
                        color: AppColors.success, size: 20),
                    tooltip: 'Call individual contact',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.success.withOpacity(0.12),
                      padding: const EdgeInsets.all(AppSpacing.xs),
                    ),
                    onPressed: () => _makeCall(context, client.contactPersonPhone),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              Text(
                value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.xs),
          trailing!,
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.accent = false, this.color});
  final String label;
  final bool accent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? (accent ? AppColors.accentSurface : AppColors.surface2);
    final fg = accent ? AppColors.accent : AppColors.textSecondary;
    final border = accent ? AppColors.accent : AppColors.surface3;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.chip,
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}

// ── Machines List ────────────────────────────────────────────

class _MachinesList extends StatelessWidget {
  const _MachinesList({
    required this.isAdmin,
    required this.clientId,
    required this.onAddMachine,
    required this.onRetry,
  });
  final bool isAdmin;
  final String clientId;
  final VoidCallback onAddMachine;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Installed Machines',
                style: theme.textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (isAdmin)
              OutlinedButton.icon(
                onPressed: onAddMachine,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Machine'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        BlocBuilder<MachinesBloc, MachinesState>(
          builder: (context, state) {
            if (state is MachinesLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is MachinesError) {
              return ErrorStateWidget(
                rawError: state.message,
                onRetry: onRetry,
              );
            }
            if (state is MachinesLoaded) {
              if (state.machines.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: AppRadius.card,
                    border: Border.all(color: AppColors.surface2),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.precision_manufacturing_rounded,
                            size: 40, color: AppColors.surface3),
                        const SizedBox(height: AppSpacing.sm),
                        Text('No machines installed yet.',
                            style: theme.textTheme.bodyMedium),
                        if (isAdmin) ...[
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton(
                            onPressed: onAddMachine,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                            ),
                            child: const Text('Add first machine'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: state.machines
                    .map((m) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _MachineCard(
                            machine: m,
                            clientId: clientId,
                          ),
                        ))
                    .toList(),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

class _MachineCard extends StatelessWidget {
  const _MachineCard({required this.machine, required this.clientId});
  final InstalledMachine machine;
  final String clientId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('d MMM yyyy');

    final Color warrantyColor;
    final String warrantyLabel;
    if (!machine.isWarrantyActive) {
      warrantyColor = AppColors.error;
      warrantyLabel = 'Expired';
    } else if (machine.isWarrantyExpiringSoon) {
      warrantyColor = AppColors.warning;
      warrantyLabel = '${machine.warrantyLeftMonths}m left';
    } else {
      warrantyColor = AppColors.success;
      warrantyLabel = '${machine.warrantyLeftMonths}m left';
    }

    return Material(
      color: AppColors.surface1,
      borderRadius: AppRadius.card,
      child: InkWell(
        onTap: () => context.push('/clients/$clientId/machine/${machine.id}'),
        borderRadius: AppRadius.card,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.surface2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${machine.brand} ${machine.model}',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          machine.machineType.label,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _WarrantyBadge(
                    color: warrantyColor,
                    label: warrantyLabel,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: machine.warrantyProgressFraction,
                  minHeight: 4,
                  backgroundColor: AppColors.surface3,
                  valueColor: AlwaysStoppedAnimation<Color>(warrantyColor),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 12, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              'Installed ${fmt.format(machine.installationDate)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        if (machine.parts.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.build_rounded,
                                  size: 12, color: AppColors.textTertiary),
                              const SizedBox(width: 4),
                              Text(
                                '${machine.parts.length} part(s)',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        if (machine.engineers.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.engineering_rounded,
                                  size: 12, color: AppColors.textTertiary),
                              const SizedBox(width: 4),
                              Text(
                                '${machine.engineers.length} engineer(s)',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.textTertiary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarrantyBadge extends StatelessWidget {
  const _WarrantyBadge({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: AppRadius.chip,
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}