# Database Module Map

The supplied project structure describes these major tables/modules:

users
roles
permissions
schools
branches
academic_sessions
classes
sections
subjects
students
parents
teachers
staff
attendance
homework
assignments
exams
results
grades
fee_categories
fee_payments
fee_receipts
library_books
issued_books
vehicles
routes
inventory
stock
payroll
leave_requests
notifications
events
audit_logs
settings

This build adds the foundational school/profile/student/parent-link/invitation/audit/notification/settings migrations. Remaining module tables should be added in the same tenant-isolated pattern before production use.
