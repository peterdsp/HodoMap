# KMP mobile core

This directory will contain Kotlin Multiplatform modules shared by iOS and
Android.

Expected modules:

- `common`
- `model`
- `network`
- `database`
- `domain`
- `testing`

The core owns client-side persistence and coordination. The server remains
authoritative for national timetable and source semantics.
