import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repository/teacher_repository.dart';
import '../models/teacher_model.dart';
import '../../../../core/network/supabase_client.dart';

class SupabaseTeacherRepository implements TeacherRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<TeacherModel>> getAllTeachers() async {
    final response = await _client.from('teachers').select().order('firstName');
    return (response as List).map((e) => TeacherModel.fromMap(e)).toList();
  }

  @override
  Future<TeacherModel?> getTeacherById(String id) async {
    final response = await _client.from('teachers').select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return TeacherModel.fromMap(response);
  }

  @override
  Future<void> createTeacher(TeacherModel teacher) async {
    await _client.from('teachers').insert(teacher.toMap());
  }

  @override
  Future<void> updateTeacher(TeacherModel teacher) async {
    await _client.from('teachers').update(teacher.toMap()).eq('id', teacher.id);
  }

  @override
  Future<void> deleteTeacher(String id) async {
    await _client.from('teachers').delete().eq('id', id);
  }

  @override
  Stream<List<TeacherModel>> streamTeachers() {
    return _client
        .from('teachers')
        .stream(primaryKey: ['id'])
        .map((data) => data.map((e) => TeacherModel.fromMap(e)).toList());
  }
}
