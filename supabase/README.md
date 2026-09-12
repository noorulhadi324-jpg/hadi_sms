Apply migrations in numeric order.

Before production:
- review every RLS policy
- add insert/update policies for each role
- move school registration to a server-side transaction/RPC
- hash invitation codes
- configure email templates and password reset redirect URLs
- configure storage policies for school logos/documents
