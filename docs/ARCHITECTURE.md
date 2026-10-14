# Architecture

HADI SMS is a Flutter application backed by Supabase Auth, PostgreSQL, Row Level Security (RLS), and Edge Functions.

## Current implementation

- **Core** (`lib/core`): Supabase client initialization, router/guards, theme, constants, and shared UI wrappers.
- **Features** (`lib/features`): feature-oriented modules for academics, attendance, finance, communication, students/classes, staff, parents, reporting, and operations.
- **State management is mixed today**: Riverpod is used by app startup, the dashboard, and some newer flows; several older screens still use StatefulWidget and call Supabase directly. Some BLoC/repository files are placeholders and must not be treated as implemented architecture.
- **Data access is not yet fully centralized**: repository implementations exist for selected modules, but some screens issue PostgREST queries directly. Move business/data access behind repositories incrementally, with tests for each migrated feature.
- **Routing**: GoRouter is configured centrally in `lib/core/router/app_router.dart`, with authentication/role checks in router guards and session routing.

## Target architecture

New or refactored features should follow:

1. **Presentation** — screens, reusable widgets, and Riverpod providers/controllers.
2. **Domain** — entities, repository contracts, and use cases for non-trivial business rules.
3. **Data** — Supabase data sources, DTO/models, and repository implementations.

Use one state-management approach (Riverpod) for new work. Do not add new BLoC/Cubit implementations unless the project explicitly adopts BLoC after a separate migration decision. Remove unused placeholder files only after confirming no imports or external references.

## Security and tenant isolation

- Client apps must use only the Supabase publishable key; never embed a service-role/secret key.
- PostgreSQL RLS is the primary row-level tenant boundary. Every exposed table must have deliberate policies and cross-school access tests.
- Privileged account operations must be performed by Edge Functions that verify the caller’s authenticated identity, active status, role, and school context on the server.
- SECURITY DEFINER RPCs must have explicit execute grants, fixed search paths where appropriate, and authorization checks inside the function.
- Client-side school IDs are filters for query clarity, not security boundaries; RLS must independently enforce tenant isolation.

## Current technical debt

- Migrate direct screen-level Supabase calls into repositories feature by feature.
- Replace silent exception swallowing with typed failures and visible loading/error/empty states.
- Add unit, repository, widget, Edge Function, and RLS integration tests.
- Keep every production schema change as a committed migration and verify that a fresh database can be built from repository migration history.
- Align finance and attendance summaries with server-side aggregates for larger schools.
- Keep this document updated when architecture decisions change.
