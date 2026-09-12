import '../../data/models/student_model.dart';

abstract class StudentRepository {
  Future<List<StudentModel>> getAllStudents(int schoolId);
  Future<StudentModel?> getStudentById(String id);
  Future<void> createStudent(StudentModel student);
  Future<void> updateStudent(StudentModel student);
  Future<void> deleteStudent(String id);
  Stream<List<StudentModel>> streamStudents(int schoolId);
}
