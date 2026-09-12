import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repository/academic_repository.dart';
import '../models/class_model.dart';
import '../models/section_model.dart';
import '../models/subject_model.dart';
import '../../../../core/network/supabase_client.dart';

class SupabaseAcademicRepository implements AcademicRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<ClassModel>> getClasses(int schoolId) async {
    final response = await _client
        .from('classes')
        .select()
        .eq('school_id', schoolId)
        .order('numeric_level');
    return (response as List).map((e) => ClassModel.fromMap(e)).toList();
  }

  @override
  Future<List<SectionModel>> getSections(String classId) async {
    final response = await _client
        .from('sections')
        .select()
        .eq('class_id', classId)
        .order('section_name');
    return (response as List).map((e) => SectionModel.fromMap(e)).toList();
  }

  @override
  Future<List<SubjectModel>> getSubjects(int schoolId) async {
    final response = await _client
        .from('subjects')
        .select()
        .eq('school_id', schoolId)
        .order('subject_name');
    return (response as List).map((e) => SubjectModel.fromMap(e)).toList();
  }

  @override
  Future<void> createClass(ClassModel classModel) async {
    await _client.from('classes').insert(classModel.toMap());
  }

  @override
  Future<void> createSection(SectionModel sectionModel) async {
    await _client.from('sections').insert(sectionModel.toMap());
  }

  @override
  Future<void> createSubject(SubjectModel subjectModel) async {
    await _client.from('subjects').insert(subjectModel.toMap());
  }
}
