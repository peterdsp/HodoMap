# Roadmap

The roadmap advances by evidence gates, not by claiming arbitrary percentage
completion.

The full workstreams, R0 to R6 coverage levels, public-beta gates, national 1.0
gates, 30-day sequence and acceptance criteria are maintained in
[NATIONAL_EXECUTION_PLAN.md](NATIONAL_EXECUTION_PLAN.md).

## Phase 0: repository and contracts

- Establish repository structure and contribution rules.
- Lock toolchain versions.
- Scaffold KMP mobile core, native iOS, Android and Web applications.
- Define OpenAPI, public release and offline-pack contracts.
- Add continuous integration for tests, formatting and secret scanning.

Exit gate: each application builds against a synthetic public fixture.

## Phase 1: governed three-operator pilot

- Select three operators with different source formats.
- Establish source rights and evidence packages.
- Implement bounded adapters and fixtures.
- Normalize stops, routes, calendars and trips.
- Review road geometry.
- Build search, result, detail and operator screens.

Exit gate: all three operators work from ingestion through offline clients with
source and freshness visibility.

## Phase 2: national source registry

- Investigate all 62 federation operators.
- Classify booking providers with dated evidence.
- Acquire a stable NAP export or documented replacement.
- Record source rights, freshness and adapter ownership.

Exit gate: every operator is source-mapped or has a documented blocked state.

## Phase 3: national data build

- Normalize lawfully acquired stop records.
- Implement remaining HTML, PDF and provider adapters.
- Build service calendars and exceptions.
- Review geometry and terminal crosswalks.
- Publish coverage and freshness scorecards.

Exit gate: at least 50 operators have usable reviewed timetables for public
beta.

## Phase 4: Raspberry Pi staging

- Deploy isolated ingestion and public databases.
- Configure API, compiler, backups, nginx, systemd and monitoring.
- Prove atomic release publication and rollback.
- Complete a seven-day staging soak.

Exit gate: cold boot, backup restore, release mismatch and rollback are tested.

## Phase 5: national public beta

- Ship iOS, Android and Web.
- Add offline packs, favorites and booking handoffs.
- Complete accessibility, localization and security reviews.
- Publish source transparency and corrections workflows.

Exit gate: legal, rights, production and platform release gates pass.

## National 1.0

- All 62 operators have reviewed timetables or a dated official unavailable
  state.
- At least 90 percent of published journey patterns have reviewed geometry.
- Every supported online booking handoff is verified.
- All enabled adapters have monitoring, fixtures and an assigned owner.
