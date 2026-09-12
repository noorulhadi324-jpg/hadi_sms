import '../../data/models/class_model.dart';
import '../../data/models/section_model.dart';
import '../../data/models/subject_model.dart';

abstract class AcademicRepository {
  Future<List<ClassModel>> getClasses(int schoolId);
  Future<List<SectionModel>> getSections(String classId);
  Future<List<SubjectModel>> getSubjects(int schoolId);
  
  Future<void> createClass(ClassModel classModel);
  Future<void> createSection(SectionModel sectionModel);
  Future<void> createSubject(SubjectModel subjectModel);
}
