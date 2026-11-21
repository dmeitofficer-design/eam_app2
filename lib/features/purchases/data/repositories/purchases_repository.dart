// lib/features/purchases/data/repositories/purchases_repository.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/error_formatter.dart';
import '../models/bill_draft.dart';
import '../models/purchase_bill.dart';

/// Purchase bills (migration 010). RLS limits every call to admins and
/// accountants (014).
class PurchasesRepository {
  PurchasesRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // The view, not the table: accountants can't read installed_machines directly.
  static const _machine = 'installed_machines_view(brand, model, hospital_id, hospital_clients(name))';
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
        .select('*, purchase_bill_items(*, purchase_bills(id, bill_no, dme_no, bill_date))')
        .eq('machine_id', machineId)
        .order('serial_no');
    return (data as List)
        .map((e) => MachinePurchasedPart.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> getVendorNames() async {
    final data = await _client.from('purchase_vendors').select('name').order('name');
    return [for (final r in data as List) (r as Map)['name'] as String];
  }

  /// Saves a whole bill in one transaction (migration 012); returns its id.
  Future<String> createBill(BillDraft draft) async {
    final id = await _client.rpc('create_purchase_bill', params: {'bill': draft.toJson()});
    return id as String;
  }

  /// AI-fill: sends the image/PDF to the scan-bill Edge Function (Gemini).
  /// The API key stays on the server; the function checks the caller is an admin.
  Future<BillDraft> scanWithAi(Uint8List bytes, String mimeType) async {
    try {
      final response = await _client.functions.invoke(
        'scan-bill',
        body: {'mime_type': mimeType, 'data': base64Encode(bytes)},
      );
      final data = response.data;
      if (data is Map && data['error'] != null) throw AppException(data['error'].toString());
      if (data is! Map<String, dynamic>) throw const AppException('The AI reply could not be read.');
      return BillDraft.fromAiJson(data);
    } on FunctionException catch (e) {
      final details = e.details;
      throw AppException(details is Map && details['error'] != null
          ? details['error'].toString()
          : (e.reasonPhrase ?? 'AI-fill failed (${e.status}).'),);
    }
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
