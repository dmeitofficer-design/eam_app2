// lib/features/dashboard/data/repositories/dashboard_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dashboard_analytics.dart';

class DashboardRepository {
  DashboardRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<DashboardAnalytics> getAnalytics() async {
    final data = await _client
        .from('dashboard_analytics')
        .select()
        .single();
    return DashboardAnalytics.fromJson(data);
  }
}
