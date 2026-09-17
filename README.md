# Mixlists Importer

Companion tooling for [Mixlists](https://github.com/seco560/mixlists_project), replacing
CSV-based playlist import with a Spotify Web API-based one.

## Packages

- **`mixlists_core`** — the shared, Flutter-free schema, entity classes, CSV row parser, and
  get-or-create ingestion/dedup logic. Consumed by the Flutter app (as a git dependency) and
  by `mixlists_importer` (as a path dependency in this repo).
- **`mixlists_importer`** — a pure-Dart CLI that authenticates with a user's own Spotify
  account and produces a `mixlists.db` sqlite file matching the Mixlists app's schema. (Not
  built yet — see the Flutter app repo's planning notes.)

All data stays on-device: the importer runs locally, writes a local sqlite file, and nothing
is uploaded anywhere.
