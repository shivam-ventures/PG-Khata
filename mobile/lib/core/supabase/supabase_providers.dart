import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The single Supabase client instance, initialized in `main.dart` before
/// `runApp`. Every feature's Supabase-backed repository reads this instead
/// of calling `Supabase.instance.client` directly, so tests can override it.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
