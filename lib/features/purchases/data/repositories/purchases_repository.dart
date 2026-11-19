// lib/features/purchases/data/repositories/purchases_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchase_bill.dart';

/// Purchase bills (migration 010). RLS limits every call to admins.
class PurchasesRepository {
  PurchasesRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _machine = 'installed_machines(brand, model, hospital_id, hospital_clients(name))';
  static const _billSelect = '*, purchase_vendors(name), '
      'purchase_bill_items(*, purchase_item_serials(*, $_machine))';

  /// All bills with items and serials, newest first.
  // shortcut: loads everything (~70 bills, 1k serials) for local search; page it past a few thousand bills.
  Future<List<PurchaseBill>> getBills() async {
    final data = await _client
        .from('purchase_bills')
        .select(_billSelect)
        .order('bill_date', ascending: false);
    return (data as List)
        .map((e) => PurchaseBill.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PurchaseBill> getBill(String id) async {
    final data = await _client.from('purchase_bills').select(_billSelect).eq('id', id).single();
    return PurchaseBill.fromJson(data);
  }

  /// Purchased parts linked to one machine.
  Future<List<MachinePurchasedPart>> getPartsForMachine(String machineId) async {
    final data = await _client
        .from('purchase_item_serials')
        .select('*, purchase_bill_items(*, purchase_bills(id, bill_no, bill_date))')
        .eq('machine_id', machineId)
        .order('serial_no');
    return (data as List)
        .map((e) => MachinePurchasedPart.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Links serials to a machine, or unlinks them when [machineId] is null.
  Future<void> assignSerials(List<String> serialIds, String? machineId) async {
    if (serialIds.isEmpty) return;
    await _client
        .from('purchase_item_serials')
        .update({'machine_id': machineId})
        .inFilter('id', serialIds);
  }
}
