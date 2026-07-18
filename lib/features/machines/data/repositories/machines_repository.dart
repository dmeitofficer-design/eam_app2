// lib/features/machines/data/repositories/machines_repository.dart

import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/installed_machine.dart';
import '../models/machine_part.dart';
import '../../../../core/constants/app_constants.dart';

class MachinesRepository {
  MachinesRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Fetches machines and joins the engineers via the junction table.
  Future<List<InstalledMachine>> getMachinesByHospital(String hospitalId) async {
    final data = await _client
        .from(AppConstants.tableInstalledMachines)
        .select('*, machine_engineers(engineers(*)), machine_parts(*)')
        .eq('hospital_id', hospitalId)
        .order('installation_date', ascending: false);
    return (data as List<dynamic>)
        .map((e) => InstalledMachine.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches a single machine and joins the engineers via the junction table.
  Future<InstalledMachine> getMachineById(String machineId) async {
    final data = await _client
        .from(AppConstants.tableInstalledMachines)
        .select('*, machine_engineers(engineers(*)), machine_parts(*)')
        .eq('id', machineId)
        .single();
    return InstalledMachine.fromJson(data);
  }

  /// Manages the many-to-many relationship for engineers.
  Future<void> updateMachineEngineers(String machineId, List<String> engineerIds) async {
    await _client.from('machine_engineers').delete().eq('machine_id', machineId);
    if (engineerIds.isNotEmpty) {
      final payload = engineerIds.map((eId) => {
        'machine_id': machineId,
        'engineer_id': eId
      }).toList();
      await _client.from('machine_engineers').insert(payload);
    }
  }

  Future<InstalledMachine> createMachineWithParts(
    InstalledMachine machine,
    List<MachinePart> parts,
    List<String> engineerIds,
  ) async {
    final machineData = await _client
        .from(AppConstants.tableInstalledMachines)
        .insert(machine.toJson())
        .select('*, machine_engineers(engineers(*)), machine_parts(*)')
        .single();
        
    final created = InstalledMachine.fromJson(machineData);

    if (parts.isNotEmpty) {
      final partsPayload = parts.map((p) => {
                'machine_id': created.id,
                'part_name': p.partName,
                'serial_number': p.serialNumber,
              }).toList();
      await _client.from('machine_parts').insert(partsPayload);
    }

    await updateMachineEngineers(created.id, engineerIds);
    return getMachineById(created.id);
  }

  Future<InstalledMachine> updateMachineWithParts(
    InstalledMachine machine,
    List<MachinePart> parts,
    List<String> engineerIds,
  ) async {
    await _client
        .from(AppConstants.tableInstalledMachines)
        .update(machine.toJson())
        .eq('id', machine.id);

    await _client.from('machine_parts').delete().eq('machine_id', machine.id);

    if (parts.isNotEmpty) {
      final partsPayload = parts.map((p) => {
                'machine_id': machine.id,
                'part_name': p.partName,
                'serial_number': p.serialNumber,
              }).toList();
      await _client.from('machine_parts').insert(partsPayload);
    }

    await updateMachineEngineers(machine.id, engineerIds);
    return getMachineById(machine.id);
  }

  // --- Standardized CRUD ---

  Future<InstalledMachine> createMachine(InstalledMachine machine) async {
    final machineData = await _client
        .from(AppConstants.tableInstalledMachines)
        .insert(machine.toJson())
        .select('*, machine_engineers(engineers(*)), machine_parts(*)')
        .single();
        
    return InstalledMachine.fromJson(machineData);
  }

  Future<InstalledMachine> updateMachine(InstalledMachine machine) async {
    await _client
        .from(AppConstants.tableInstalledMachines)
        .update(machine.toJson())
        .eq('id', machine.id);

    return getMachineById(machine.id);
  }

  Future<void> deleteMachine(String id) async {
    await _client
        .from(AppConstants.tableInstalledMachines)
        .delete()
        .eq('id', id);
  }

  // --- Storage ---

  Future<String> uploadInvoice({
    required String machineId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final storagePath = 'machines/$machineId/$fileName';
    await _client.storage.from(AppConstants.invoiceBucket).uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
    return storagePath;
  }

  Future<String> getInvoiceSignedUrl(String storagePath) async {
    return _client.storage
        .from(AppConstants.invoiceBucket)
        .createSignedUrl(storagePath, 3600);
  }

  Future<Uint8List> downloadInvoice(String storagePath) async {
    return _client.storage
        .from(AppConstants.invoiceBucket)
        .download(storagePath);
  }
}