# Database migrations

Store immutable, ordered migrations for ingestion and public schemas here.

Migrations must:

- Be repeatable from an empty database.
- Preserve source lineage.
- Avoid editing already-released migration files.
- Run foreign-key and integrity checks.
- Keep ingestion and compiled public databases separate.
