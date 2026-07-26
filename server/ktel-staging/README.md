# KTEL staging (transplanted from the Syrmos ops tree)

These files were built in the Syrmos working tree by mistake; they belong to
HodoMap (the intercity-coach app). They were **copied here verbatim** — no code
edits — so everything still runs as-is:

- `syrmos_admin/ktel_*.py` — the 6 self-contained KTEL modules. They import each
  other with **relative imports** (`from . import ktel_db`, `from .ktel_registry`),
  so they work as a package regardless of where it's mounted.
- `ktel_migrations/`, `data/` — `ktel_db.py` resolves these relative to the
  package parent (`__file__.parent.parent`), i.e. this `ktel-staging/` dir, and
  both `DEFAULT_KTEL_DB_PATH` / `DEFAULT_KTEL_PUBLIC_DB_PATH` are env-overridable.
- `pkg/ktel/operators.json` — operator seed data.
- `scripts/ktel_pipeline.py` — the CLI. Uses absolute `from syrmos_admin.ktel_*`,
  so run it with this dir on `PYTHONPATH`.
- `tests/test_ktel.py`, `ktel.env.example`.
- Design docs are in `../../docs/KTEL_NATIONAL_PLATFORM.md` and
  `../../docs/KTEL_NATIONAL_EXECUTION_PLAN.md`.

## Integration TODO (yours to decide)
Rename the `syrmos_admin` package to a HodoMap name and fold it into
`server/src/hodomap_pipeline/` (only `scripts/ktel_pipeline.py`'s five
`from syrmos_admin.ktel_*` lines need the prefix updated; the modules'
relative imports don't). Runtime dep: `openpyxl` (see server/pyproject.toml).

The originals were left in the Syrmos tree on purpose: Syrmos's modified
`syrmos_admin/app.py` still references `pkg/ktel/operators.json`, so deleting
them there would break that server until you unwire it.
