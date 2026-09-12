import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repository/attendance_repository.dart';
import '../models/attendance_model.dart';
import '../../../../core/network/supabase_client.dart';

class SupabaseAttendanceRepository implements AttendanceRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<AttendanceModel>> getAttendanceByStudent(String studentId) async {
    final response = await _client
        .from('attendance')
        .select()
        .eq('studentId', studentId)
        .order('date', ascending: false);
    return (response as List).map((e) => AttendanceModel.fromMap(e)).toList();
  }

  @override
  Future<List<AttendanceModel>> getAttendanceByDate(DateTime date) async {
    final dateString = date.toIso8601String().split('T')[0];
    final response = await _client
        .from('attendance')
        .select()
        .gte('date', '${dateString}T00:00:00')
        .lte('date', '${dateString}T23:59:59');
    return (response as List).map((e) => AttendanceModel.fromMap(e)).toList();
  }

  @override
  Future<void> markAttendance(AttendanceModel attendance) async {
    await _client.from('attendance').insert(attendance.toMap());
  }

  @override
  Future<void> updateAttendance(AttendanceModel attendance) async {
    await _client
        .from('attendance')
        .update(attendance.toMap())
        .eq('id', attendance.id);
  }
}
