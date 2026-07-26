-- National KTEL coach domain.
--
-- This schema is intentionally separate from the existing rail-shaped lines
-- tables. KTEL data is multi-operator, source-fragmented, date-sensitive, and
-- must preserve provenance for every published fact.

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS schema_version (
    version     INTEGER NOT NULL PRIMARY KEY,
    applied_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS ktel_operators (
    id                    TEXT PRIMARY KEY,
    federation_number     INTEGER UNIQUE,
    slug                  TEXT NOT NULL UNIQUE,
    name_en               TEXT NOT NULL,
    name_el               TEXT NOT NULL,
    operator_kind         TEXT NOT NULL DEFAULT 'intercity',
    federation_status     TEXT NOT NULL DEFAULT 'listed',
    directory_url         TEXT,
    official_site_url     TEXT,
    registry_verified_at  TEXT,
    created_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    CHECK (operator_kind IN ('intercity', 'urban', 'private', 'other')),
    CHECK (federation_status IN ('listed', 'not_listed', 'unverified', 'inactive'))
);

CREATE TABLE IF NOT EXISTS ktel_sources (
    id                TEXT PRIMARY KEY,
    label             TEXT NOT NULL,
    source_kind       TEXT NOT NULL,
    base_url          TEXT NOT NULL,
    authority_level   TEXT NOT NULL,
    access_mode       TEXT NOT NULL,
    license_id        TEXT,
    terms_status      TEXT NOT NULL DEFAULT 'unreviewed',
    terms_url         TEXT,
    rights_status     TEXT NOT NULL DEFAULT 'unknown',
    retention_mode    TEXT NOT NULL DEFAULT 'metadata_only',
    allowed_data_classes TEXT NOT NULL DEFAULT '[]',
    contains_personal_data TEXT NOT NULL DEFAULT 'possible',
    contains_commercial_state INTEGER NOT NULL DEFAULT 0,
    retention_days    INTEGER,
    legal_reviewed_at TEXT,
    refresh_policy    TEXT NOT NULL,
    enabled           INTEGER NOT NULL DEFAULT 1,
    notes             TEXT,
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    CHECK (source_kind IN (
        'federation_directory', 'national_access_point', 'ticketing',
        'operator_site', 'openstreetmap', 'manual_review'
    )),
    CHECK (authority_level IN ('official', 'first_party', 'community', 'manual')),
    CHECK (access_mode IN ('public', 'public_client', 'file_import', 'contract_required')),
    CHECK (terms_status IN ('reviewed', 'unreviewed', 'restricted', 'unknown')),
    CHECK (rights_status IN ('allowed', 'permission_pending', 'prohibited', 'unknown')),
    CHECK (retention_mode IN (
        'metadata_only', 'redacted', 'raw_timeboxed', 'raw_persistent'
    )),
    CHECK (contains_personal_data IN ('yes', 'no', 'possible'))
);

CREATE TABLE IF NOT EXISTS ktel_operator_sources (
    operator_id          TEXT NOT NULL REFERENCES ktel_operators(id) ON DELETE CASCADE,
    source_id            TEXT NOT NULL REFERENCES ktel_sources(id) ON DELETE CASCADE,
    external_operator_id TEXT,
    tenant_code          TEXT,
    tenant_url           TEXT,
    coverage_status      TEXT NOT NULL DEFAULT 'unverified',
    stop_group_count     INTEGER,
    stop_count           INTEGER,
    web_active_count     INTEGER,
    verified_at          TEXT,
    last_success_at      TEXT,
    notes                TEXT,
    PRIMARY KEY (operator_id, source_id),
    UNIQUE (source_id, tenant_code),
    CHECK (coverage_status IN (
        'verified_live', 'verified_absent', 'unverified', 'blocked', 'retired'
    ))
);

CREATE TABLE IF NOT EXISTS ktel_import_runs (
    id                 TEXT PRIMARY KEY,
    source_id          TEXT NOT NULL REFERENCES ktel_sources(id),
    operator_id        TEXT REFERENCES ktel_operators(id),
    run_kind           TEXT NOT NULL,
    status             TEXT NOT NULL,
    started_at         TEXT NOT NULL,
    finished_at        TEXT,
    request_count      INTEGER NOT NULL DEFAULT 0,
    cache_hit_count    INTEGER NOT NULL DEFAULT 0,
    records_seen       INTEGER NOT NULL DEFAULT 0,
    records_written    INTEGER NOT NULL DEFAULT 0,
    records_quarantined INTEGER NOT NULL DEFAULT 0,
    error              TEXT,
    CHECK (run_kind IN (
        'registry', 'identity', 'stops', 'reachable', 'executions',
        'nap_file', 'geometry', 'manual'
    )),
    CHECK (status IN ('running', 'succeeded', 'partial', 'failed', 'skipped'))
);

CREATE TABLE IF NOT EXISTS ktel_source_artifacts (
    digest             TEXT PRIMARY KEY,
    source_id          TEXT NOT NULL REFERENCES ktel_sources(id),
    operator_id        TEXT REFERENCES ktel_operators(id),
    import_run_id      TEXT REFERENCES ktel_import_runs(id) ON DELETE SET NULL,
    media_type         TEXT NOT NULL,
    storage_path       TEXT,
    source_url         TEXT,
    retrieved_at       TEXT NOT NULL,
    effective_from     TEXT,
    effective_until    TEXT,
    rights_status      TEXT NOT NULL DEFAULT 'unreviewed',
    byte_size          INTEGER,
    redacted           INTEGER NOT NULL DEFAULT 1,
    CHECK (rights_status IN (
        'permitted', 'unreviewed', 'restricted', 'unknown'
    ))
);

CREATE TABLE IF NOT EXISTS ktel_source_records (
    id                 TEXT PRIMARY KEY,
    source_id          TEXT NOT NULL REFERENCES ktel_sources(id),
    operator_id        TEXT REFERENCES ktel_operators(id),
    artifact_digest    TEXT REFERENCES ktel_source_artifacts(digest),
    import_run_id      TEXT REFERENCES ktel_import_runs(id) ON DELETE SET NULL,
    record_kind        TEXT NOT NULL,
    external_id        TEXT,
    normalized_json    TEXT NOT NULL,
    content_hash       TEXT NOT NULL,
    retrieved_at       TEXT NOT NULL,
    UNIQUE (source_id, record_kind, external_id, content_hash)
);

CREATE TABLE IF NOT EXISTS ktel_stop_places (
    id                 TEXT PRIMARY KEY,
    operator_id        TEXT NOT NULL REFERENCES ktel_operators(id) ON DELETE CASCADE,
    name               TEXT NOT NULL,
    name_el            TEXT,
    source_id          TEXT NOT NULL REFERENCES ktel_sources(id),
    external_id        TEXT NOT NULL,
    default_stop_id    TEXT,
    web_active         INTEGER NOT NULL DEFAULT 0,
    publication_state  TEXT NOT NULL DEFAULT 'candidate',
    content_hash       TEXT,
    first_seen_at      TEXT NOT NULL,
    last_seen_at       TEXT NOT NULL,
    UNIQUE (operator_id, source_id, external_id),
    CHECK (publication_state IN (
        'candidate', 'verified', 'published', 'stale', 'withdrawn', 'quarantined'
    ))
);

CREATE TABLE IF NOT EXISTS ktel_stops (
    id                 TEXT PRIMARY KEY,
    operator_id        TEXT NOT NULL REFERENCES ktel_operators(id) ON DELETE CASCADE,
    stop_place_id      TEXT REFERENCES ktel_stop_places(id) ON DELETE SET NULL,
    name               TEXT NOT NULL,
    name_el            TEXT,
    address            TEXT,
    phone              TEXT,
    latitude           REAL,
    longitude          REAL,
    coordinate_status  TEXT NOT NULL DEFAULT 'missing',
    web_active         INTEGER NOT NULL DEFAULT 0,
    publication_state  TEXT NOT NULL DEFAULT 'candidate',
    source_id          TEXT NOT NULL REFERENCES ktel_sources(id),
    external_id        TEXT NOT NULL,
    content_hash       TEXT,
    first_seen_at      TEXT NOT NULL,
    last_seen_at       TEXT NOT NULL,
    UNIQUE (operator_id, source_id, external_id),
    CHECK (coordinate_status IN (
        'valid', 'missing', 'out_of_range', 'outside_greece',
        'placeholder', 'duplicate', 'manual_review'
    )),
    CHECK (publication_state IN (
        'candidate', 'verified', 'published', 'stale', 'withdrawn', 'quarantined'
    ))
);

CREATE TABLE IF NOT EXISTS ktel_lines (
    id                 TEXT PRIMARY KEY,
    operator_id        TEXT NOT NULL REFERENCES ktel_operators(id) ON DELETE CASCADE,
    public_code        TEXT,
    name               TEXT NOT NULL,
    name_el            TEXT,
    source_id          TEXT NOT NULL REFERENCES ktel_sources(id),
    external_id        TEXT,
    data_status        TEXT NOT NULL DEFAULT 'observed',
    publication_state  TEXT NOT NULL DEFAULT 'candidate',
    first_seen_at      TEXT NOT NULL,
    last_seen_at       TEXT NOT NULL,
    UNIQUE (operator_id, source_id, external_id),
    CHECK (data_status IN ('observed', 'candidate', 'verified', 'stale', 'withdrawn')),
    CHECK (publication_state IN (
        'candidate', 'verified', 'published', 'stale', 'withdrawn', 'quarantined'
    ))
);

CREATE TABLE IF NOT EXISTS ktel_journey_patterns (
    id                 TEXT PRIMARY KEY,
    line_id            TEXT REFERENCES ktel_lines(id) ON DELETE CASCADE,
    operator_id        TEXT NOT NULL REFERENCES ktel_operators(id) ON DELETE CASCADE,
    name               TEXT NOT NULL,
    direction          TEXT,
    source_id          TEXT NOT NULL REFERENCES ktel_sources(id),
    external_id        TEXT,
    geometry_status    TEXT NOT NULL DEFAULT 'unverified',
    geometry_geojson   TEXT,
    publication_state  TEXT NOT NULL DEFAULT 'candidate',
    first_seen_at      TEXT NOT NULL,
    last_seen_at       TEXT NOT NULL,
    UNIQUE (operator_id, source_id, external_id),
    CHECK (geometry_status IN (
        'unverified', 'ordered_stops_only', 'osm_candidate',
        'reviewed', 'rejected'
    )),
    CHECK (publication_state IN (
        'candidate', 'verified', 'published', 'stale', 'withdrawn', 'quarantined'
    ))
);

CREATE TABLE IF NOT EXISTS ktel_pattern_stops (
    pattern_id       TEXT NOT NULL REFERENCES ktel_journey_patterns(id) ON DELETE CASCADE,
    stop_id          TEXT NOT NULL REFERENCES ktel_stops(id) ON DELETE CASCADE,
    stop_sequence    INTEGER NOT NULL,
    pickup_type      TEXT NOT NULL DEFAULT 'unknown',
    dropoff_type     TEXT NOT NULL DEFAULT 'unknown',
    PRIMARY KEY (pattern_id, stop_sequence),
    UNIQUE (pattern_id, stop_id, stop_sequence),
    CHECK (pickup_type IN ('allowed', 'not_allowed', 'request', 'unknown')),
    CHECK (dropoff_type IN ('allowed', 'not_allowed', 'request', 'unknown'))
);

CREATE TABLE IF NOT EXISTS ktel_service_calendars (
    id                 TEXT PRIMARY KEY,
    operator_id        TEXT NOT NULL REFERENCES ktel_operators(id) ON DELETE CASCADE,
    name               TEXT NOT NULL,
    valid_from         TEXT,
    valid_until        TEXT,
    monday             INTEGER NOT NULL DEFAULT 0,
    tuesday            INTEGER NOT NULL DEFAULT 0,
    wednesday          INTEGER NOT NULL DEFAULT 0,
    thursday           INTEGER NOT NULL DEFAULT 0,
    friday             INTEGER NOT NULL DEFAULT 0,
    saturday           INTEGER NOT NULL DEFAULT 0,
    sunday             INTEGER NOT NULL DEFAULT 0,
    source_id          TEXT NOT NULL REFERENCES ktel_sources(id),
    verification_state TEXT NOT NULL DEFAULT 'candidate',
    publication_state  TEXT NOT NULL DEFAULT 'candidate',
    CHECK (verification_state IN ('candidate', 'operator_verified', 'expired', 'rejected')),
    CHECK (publication_state IN (
        'candidate', 'verified', 'published', 'stale', 'withdrawn', 'quarantined'
    ))
);

CREATE TABLE IF NOT EXISTS ktel_calendar_exceptions (
    calendar_id      TEXT NOT NULL REFERENCES ktel_service_calendars(id) ON DELETE CASCADE,
    service_date     TEXT NOT NULL,
    exception_type   TEXT NOT NULL,
    source_id        TEXT NOT NULL REFERENCES ktel_sources(id),
    note             TEXT,
    PRIMARY KEY (calendar_id, service_date),
    CHECK (exception_type IN ('added', 'removed'))
);

CREATE TABLE IF NOT EXISTS ktel_trips (
    id                  TEXT PRIMARY KEY,
    operator_id         TEXT NOT NULL REFERENCES ktel_operators(id) ON DELETE CASCADE,
    line_id             TEXT REFERENCES ktel_lines(id) ON DELETE SET NULL,
    pattern_id          TEXT REFERENCES ktel_journey_patterns(id) ON DELETE SET NULL,
    calendar_id         TEXT REFERENCES ktel_service_calendars(id) ON DELETE SET NULL,
    service_date        TEXT,
    departure_at        TEXT NOT NULL,
    approximate_arrival_at TEXT,
    source_id           TEXT NOT NULL REFERENCES ktel_sources(id),
    external_id         TEXT,
    commercial_state    TEXT NOT NULL DEFAULT 'unknown',
    schedule_scope      TEXT NOT NULL DEFAULT 'date_specific_bookable',
    publication_state   TEXT NOT NULL DEFAULT 'candidate',
    fare_amount         REAL,
    fare_currency       TEXT,
    booking_url         TEXT,
    observed_at         TEXT NOT NULL,
    expires_at          TEXT,
    content_hash        TEXT,
    UNIQUE (operator_id, source_id, external_id, service_date),
    CHECK (commercial_state IN (
        'bookable', 'closed', 'sold_out', 'unknown', 'withdrawn'
    )),
    CHECK (schedule_scope IN (
        'date_specific_bookable', 'operator_published',
        'nap_published', 'candidate_recurrence'
    )),
    CHECK (publication_state IN (
        'candidate', 'verified', 'published', 'stale', 'withdrawn', 'quarantined'
    ))
);

CREATE TABLE IF NOT EXISTS ktel_stop_times (
    trip_id          TEXT NOT NULL REFERENCES ktel_trips(id) ON DELETE CASCADE,
    stop_id          TEXT NOT NULL REFERENCES ktel_stops(id) ON DELETE CASCADE,
    stop_sequence    INTEGER NOT NULL,
    arrival_at       TEXT,
    departure_at     TEXT,
    time_status      TEXT NOT NULL DEFAULT 'unknown',
    PRIMARY KEY (trip_id, stop_sequence),
    CHECK (time_status IN ('scheduled', 'approximate', 'unknown'))
);

CREATE TABLE IF NOT EXISTS ktel_import_issues (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    import_run_id  TEXT REFERENCES ktel_import_runs(id) ON DELETE CASCADE,
    operator_id    TEXT REFERENCES ktel_operators(id),
    entity_kind    TEXT NOT NULL,
    external_id    TEXT,
    issue_code     TEXT NOT NULL,
    severity       TEXT NOT NULL,
    details_json   TEXT,
    created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    CHECK (severity IN ('info', 'warning', 'error'))
);

CREATE TABLE IF NOT EXISTS ktel_review_events (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_kind      TEXT NOT NULL,
    entity_id        TEXT NOT NULL,
    action           TEXT NOT NULL,
    reviewer         TEXT NOT NULL,
    reason           TEXT,
    before_hash      TEXT,
    after_hash       TEXT,
    reviewed_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    CHECK (action IN (
        'verify', 'publish', 'quarantine', 'reject', 'withdraw', 'restore'
    ))
);

CREATE TABLE IF NOT EXISTS ktel_publication_releases (
    id               TEXT PRIMARY KEY,
    status           TEXT NOT NULL,
    created_at       TEXT NOT NULL,
    published_at     TEXT,
    manifest_hash    TEXT,
    previous_id      TEXT REFERENCES ktel_publication_releases(id),
    notes            TEXT,
    CHECK (status IN ('building', 'validated', 'published', 'failed', 'retired'))
);

CREATE INDEX IF NOT EXISTS idx_ktel_operator_sources_coverage
    ON ktel_operator_sources(coverage_status, operator_id);
CREATE INDEX IF NOT EXISTS idx_ktel_stops_operator_name
    ON ktel_stops(operator_id, name);
CREATE INDEX IF NOT EXISTS idx_ktel_stops_coordinates
    ON ktel_stops(coordinate_status, latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_ktel_lines_operator
    ON ktel_lines(operator_id, name);
CREATE INDEX IF NOT EXISTS idx_ktel_patterns_line
    ON ktel_journey_patterns(line_id, name);
CREATE INDEX IF NOT EXISTS idx_ktel_trips_search
    ON ktel_trips(service_date, departure_at, operator_id);
CREATE INDEX IF NOT EXISTS idx_ktel_stop_times_stop
    ON ktel_stop_times(stop_id, departure_at);
CREATE INDEX IF NOT EXISTS idx_ktel_import_runs_source
    ON ktel_import_runs(source_id, started_at);
CREATE INDEX IF NOT EXISTS idx_ktel_source_records_lookup
    ON ktel_source_records(source_id, record_kind, external_id);
CREATE INDEX IF NOT EXISTS idx_ktel_review_events_entity
    ON ktel_review_events(entity_kind, entity_id, reviewed_at);

INSERT OR IGNORE INTO schema_version(version) VALUES (1);
