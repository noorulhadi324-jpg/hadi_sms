import '../../data/models/attendance_model.dart';

abstract class AttendanceRepository {
  Future<List<AttendanceModel>> getAttendanceByStudent(String studentId);
  Future<List<AttendanceModel>> getAttendanceByDate(DateTime date);
  Future<void> markAttendance(AttendanceModel attendance);
  Future<void> updateAttendance(AttendanceModel attendance);
}
