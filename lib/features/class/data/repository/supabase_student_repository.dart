import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repository/student_repository.dart';
import '../models/student_model.dart';
import '../../../../core/network/supabase_client.dart';

class SupabaseStudentRepository implements StudentRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<StudentModel>> getAllStudents(int schoolId) async {
    final response = await _client
        .from('students')
        .select()
        .eq('school_id', schoolId)
        .order('full_name');
    return (response as List).map((e) => StudentModel.fromMap(e)).toList();
  }

  @override
  Future<StudentModel?> getStudentById(String id) async {
    final response = await _client
        .from('students')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return StudentModel.fromMap(response);
  }

  @override
  Future<void> createStudent(StudentModel student) async {
    await _client.from('students').insert(student.toMap());
  }

  @override
  Future<void> updateStudent(StudentModel student) async {
    await _client
        .from('students')
        .update(student.toMap())
        .eq('id', student.id);
  }

  @override
  Future<void> deleteStudent(String id) async {
    await _client.from('students').delete().eq('id', id);
  }

  @override
  Stream<List<StudentModel>> streamStudents(int schoolId) {
    return _client
        .from('students')
        .stream(primaryKey: ['id'])
        .eq('school_id', schoolId)
        .map((data) => data.map((e) => StudentModel.fromMap(e)).toList());
  }
}
