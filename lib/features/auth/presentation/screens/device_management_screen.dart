// lib/features/auth/presentation/screens/device_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/error_formatter.dart';
import '../bloc/device_management_bloc.dart';
import '../bloc/device_management_event.dart';
import '../bloc/device_management_state.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  void _fetchSessions() {
    context.read<DeviceManagementBloc>().add(FetchSessionsRequested());
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Unknown';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      return DateFormat('yyyy-MM-dd hh:mm a').format(dateTime);
    } catch (_) {
      return isoString;
    }
  }

  Map<String, dynamic> _getDeviceDetails(String? userAgentOrPlatform) {
    final platform = (userAgentOrPlatform ?? '').toLowerCase();
    
    if (platform.contains('android')) {
      return {'name': 'Android Device', 'icon': Icons.phone_android};
    } else if (platform.contains('iphone') || platform.contains('ipad') || platform.contains('ios')) {
      return {'name': 'iPhone / iPad', 'icon': Icons.phone_iphone};
    } else if (platform.contains('windows')) {
      return {'name': 'Windows PC', 'icon': Icons.desktop_windows};
    } else if (platform.contains('macintosh') || platform.contains('macos')) {
      return {'name': 'Mac Computer', 'icon': Icons.desktop_mac};
    } else if (platform.contains('linux')) {
      return {'name': 'Linux Desktop', 'icon': Icons.computer};
    }
    
    return {
      'name': platform.isNotEmpty ? userAgentOrPlatform! : 'Hardware Terminal', 
      'icon': Icons.devices_other
    };
  }

  void _showErrorSnackBar(String rawError) {
    final formattedMessage = ErrorFormatter.format(rawError);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          formattedMessage,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'RETRY',
          textColor: Colors.amberAccent,
          onPressed: _fetchSessions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Device Security Settings')),
      body: BlocListener<DeviceManagementBloc, DeviceManagementState>(
        listener: (context, state) {
          if (state is SessionActionSuccess) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            _fetchSessions();
          }
          if (state is DeviceManagementFailure) {
            _showErrorSnackBar(state.error);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emergency Terminate Card
              Card(
                color: Colors.red.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Log out of all other devices',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Instantly evict your account configurations from any other mobile or desktop hardware terminals.',
                              style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      IntrinsicWidth(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onPressed: () {
                            context.read<DeviceManagementBloc>().add(LogOutOtherDevicesRequested());
                          },
                          child: const Text('Sign Out Others', maxLines: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Active Device Sessions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              // Device Sessions List View Panel
              Expanded(
                child: BlocBuilder<DeviceManagementBloc, DeviceManagementState>(
                  builder: (context, state) {
                    if (state is DeviceManagementLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is DeviceManagementFailure) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              ErrorFormatter.format(state.error),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _fetchSessions,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    if (state is SessionsLoaded) {
                      if (state.sessions.isEmpty) {
                        return const Center(child: Text('No active connected hardware tracked.'));
                      }

                      return ListView.builder(
                        itemCount: state.sessions.length,
                        shrinkWrap: true,
                        itemBuilder: (context, index) {
                          final session = state.sessions[index];
                          final id = session['session_id']?.toString() ?? '';
                          
                          // Dynamic Client-Side Platform Sniffer
                          String deviceRaw = 'Hardware Terminal';
                          
                          if (index == 0) {
                            switch (Theme.of(context).platform) {
                              case TargetPlatform.android:
                                deviceRaw = 'Android Device';
                                break;
                              case TargetPlatform.iOS:
                                deviceRaw = 'iPhone / iPad';
                                break;
                              case TargetPlatform.windows:
                                deviceRaw = 'Windows PC';
                                break;
                              case TargetPlatform.macOS:
                                deviceRaw = 'Mac Computer';
                                break;
                              case TargetPlatform.linux:
                                deviceRaw = 'Linux Desktop';
                                break;
                              default:
                                deviceRaw = 'Web Browser Portal';
                            }
                            deviceRaw += ' (Current Device)';
                          } else {
                            deviceRaw = 'Authorized Secure Session';
                          }
                          
                          final device = _getDeviceDetails(deviceRaw);
                          final truncatedId = id.length > 8 ? id.substring(0, 8) : (id.isEmpty ? 'N/A' : id);
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    index == 0 ? device['icon'] as IconData : Icons.devices_other, 
                                    color: index == 0 ? Colors.blue : Colors.blueGrey, 
                                    size: 28,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          deviceRaw,
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: index == 0 ? Colors.blue.shade900 : null,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'ID: $truncatedId...',
                                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600, fontSize: 10),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Logged In: ${_formatDateTime(session['login_time'])}\nLast Sync: ${_formatDateTime(session['last_active'])}',
                                          style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (index != 0 && id.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () {
                                        context.read<DeviceManagementBloc>().add(TerminateSessionRequested(id));
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }

                    return const Center(child: Text('Awaiting device setup sync...'));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}