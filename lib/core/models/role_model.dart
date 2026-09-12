enum AppRole {
  principal,
  teacher,
  parent,
  staff,
  student; // student is usually handled via students table, but added for completeness

  String get name {
    switch (this) {
      case AppRole.principal: return 'principal';
      case AppRole.teacher: return 'teacher';
      case AppRole.parent: return 'parent';
      case AppRole.staff: return 'staff';
      case AppRole.student: return 'student';
    }
  }

  static AppRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'principal': return AppRole.principal;
      case 'teacher': return AppRole.teacher;
      case 'parent': return AppRole.parent;
      case 'staff': return AppRole.staff;
      case 'student': return AppRole.student;
      default: return AppRole.staff;
    }
  }
}
