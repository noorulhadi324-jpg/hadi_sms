import '../../data/models/teacher_model.dart';

abstract class TeacherRepository {
  Future<List<TeacherModel>> getAllTeachers();
  Future<TeacherModel?> getTeacherById(String id);
  Future<void> createTeacher(TeacherModel teacher);
  Future<void> updateTeacher(TeacherModel teacher);
  Future<void> deleteTeacher(String id);
  Stream<List<TeacherModel>> streamTeachers();
}
