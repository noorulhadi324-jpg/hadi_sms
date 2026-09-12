# Architecture

The application follows **Clean Architecture** principles to ensure scalability and maintainability:

- **core**: Platform-level and global services (Network, Router, Theme, Constants).
- **shared**: Reusable models, validators, repositories, and UI components.
- **features**: Isolated business modules (Student, Attendance, Finance, etc.).

Each feature is organized into three layers:
1. **Data**: Models and Repository implementations (Supabase).
2. **Domain**: Abstract Repository interfaces and Business Logic entities.
3. **Presentation**: UI Screens, Widgets, and State Management (Bloc/Cubit).

### Security
Data security and multi-tenancy are enforced at the database level using **Supabase Row Level Security (RLS)**. This ensures that users from one school can never access or modify data belonging to another school.
