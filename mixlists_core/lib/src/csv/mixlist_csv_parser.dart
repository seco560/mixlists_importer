import 'package:csv/csv.dart' show csv;
import 'package:path/path.dart' as p;

/// One parsed, type-checked row from a mixlist CSV export. Fields absent
/// from a given file's header come back null, stored as SQL NULL.
class MixlistCsvRow {
  final String trackURI;
  final String trackName;
  final String? artistURIs; // raw comma-joined pass-through, not split
  final String artistNames; // raw comma-joined pass-through, not split
  final String? albumURI;
  final String albumName;
  final String? albumArtistURI;
  final String albumArtistName;
  final String? albumReleaseDate;
  final String? albumImageURL;
  final int? discNumber;
  final int? albumTrackNumber;
  final int durationMs;
  final String? audioPreviewURL;
  final bool isExplicit;
  final int? popularity; // no longer obtainable via the Spotify API
  final String? isrc;
  final String addedAt;
  final String? genres;
  final String? recordLabel;
  final double? danceability;
  final double? energy;
  final int? key;
  final double? loudness;
  final int? mode;
  final double? speechiness;
  final double? acousticness;
  final double? instrumentalness;
  final double? liveness;
  final double? valence;
  final double? tempo;
  final int? timeSignature;

  const MixlistCsvRow({
    required this.trackURI,
    required this.trackName,
    required this.artistURIs,
    required this.artistNames,
    required this.albumURI,
    required this.albumName,
    required this.albumArtistURI,
    required this.albumArtistName,
    required this.albumReleaseDate,
    required this.albumImageURL,
    required this.discNumber,
    required this.albumTrackNumber,
    required this.durationMs,
    required this.audioPreviewURL,
    required this.isExplicit,
    required this.popularity,
    required this.isrc,
    required this.addedAt,
    required this.genres,
    required this.recordLabel,
    required this.danceability,
    required this.energy,
    required this.key,
    required this.loudness,
    required this.mode,
    required this.speechiness,
    required this.acousticness,
    required this.instrumentalness,
    required this.liveness,
    required this.valence,
    required this.tempo,
    required this.timeSignature,
  });
}

/// Thrown by [MixlistCsvParser.parse] on a missing/misnamed required header
/// column, or a row that fails to parse. [rowNumber] is 1-based (header
/// excluded); null means a file/header-level error.
class MixlistCsvParseException implements Exception {
  final String message;
  final int? rowNumber;

  const MixlistCsvParseException(this.message, {this.rowNumber});

  @override
  String toString() => rowNumber == null
      ? 'CSV parse error: $message'
      : 'CSV parse error at row $rowNumber: $message';
}

/// Canonical field -> candidate CSV header names, checked in priority
/// order (first candidate present wins), so one parser handles multiple
/// export formats.
const Map<String, List<String>> _headerAliases = {
  'trackURI': ['Track URI'],
  'trackName': ['Track Name'],
  'artistURIs': ['Artist URI(s)'],
  'artistNames': ['Artist Name(s)'],
  'albumURI': ['Album URI'],
  'albumName': ['Album Name'],
  'albumArtistURI': ['Album Artist URI(s)', 'Artist URI(s)'],
  'albumArtistName': ['Album Artist Name(s)', 'Artist Name(s)'],
  'albumReleaseDate': ['Album Release Date', 'Release Date'],
  'albumImageURL': ['Album Image URL'],
  'discNumber': ['Disc Number'],
  'albumTrackNumber': ['Track Number'],
  'durationMs': ['Track Duration (ms)', 'Duration (ms)'],
  'audioPreviewURL': ['Track Preview URL'],
  'explicit': ['Explicit'],
  'popularity': ['Popularity'],
  'isrc': ['ISRC'],
  'addedAt': ['Added At'],
  'genres': ['Genres'],
  'recordLabel': ['Record Label'],
  'danceability': ['Danceability'],
  'energy': ['Energy'],
  'key': ['Key'],
  'loudness': ['Loudness'],
  'mode': ['Mode'],
  'speechiness': ['Speechiness'],
  'acousticness': ['Acousticness'],
  'instrumentalness': ['Instrumentalness'],
  'liveness': ['Liveness'],
  'valence': ['Valence'],
  'tempo': ['Tempo'],
  'timeSignature': ['Time Signature'],
};

/// Fields that must resolve to *some* present column (in either format) or
/// parsing fails fast with a named error. Everything else is optional and
/// defaults to null.
const _requiredCanonicalFields = [
  'trackURI',
  'trackName',
  'albumName',
  'artistNames',
  'durationMs',
  'explicit',
  'addedAt',
];

class MixlistCsvParser {
  static List<MixlistCsvRow> parse(String csvContent) {
    // Defensive: File.readAsString() already strips a leading UTF-8 BOM,
    // but strip it here too in case content ever arrives via a different
    // path (e.g. bytes decoded manually).
    if (csvContent.startsWith('﻿')) {
      csvContent = csvContent.substring(1);
    }

    final table = csv.decode(csvContent);
    if (table.isEmpty) {
      throw const MixlistCsvParseException('File is empty');
    }

    final header = table.first.map((h) => h.toString().trim()).toList();
    final cols = _resolveColumns(header);

    for (final field in _requiredCanonicalFields) {
      if (!cols.containsKey(field)) {
        throw MixlistCsvParseException(
          "Missing required column for '$field' "
          '(looked for: ${_headerAliases[field]!.join(" or ")})',
        );
      }
    }

    final dataRows = table.skip(1).toList();
    if (dataRows.isEmpty) {
      throw const MixlistCsvParseException(
        'File has a header but no data rows',
      );
    }

    return [
      for (var i = 0; i < dataRows.length; i++)
        _parseRow(dataRows[i], cols, rowNumber: i + 1),
    ];
  }

  /// Derives the pre-filled mixlist title from a file path: basename,
  /// strip `.csv` (case-insensitive), `_` -> ` `.
  /// E.g. `/x/y/minor_mix_1.csv` -> `minor mix 1`.
  static String titleFromFilePath(String path) {
    var base = p.basenameWithoutExtension(path);
    return base.replaceAll('_', ' ');
  }

  static Map<String, int> _resolveColumns(List<String> header) {
    final resolved = <String, int>{};
    for (final entry in _headerAliases.entries) {
      for (final candidate in entry.value) {
        final idx = header.indexOf(candidate);
        if (idx != -1) {
          resolved[entry.key] = idx;
          break;
        }
      }
    }
    return resolved;
  }

  static MixlistCsvRow _parseRow(
    List<dynamic> row,
    Map<String, int> cols, {
    required int rowNumber,
  }) {
    String? str(String field) {
      final idx = cols[field];
      if (idx == null || idx >= row.length) return null;
      final value = row[idx].toString();
      return value.isEmpty ? null : value;
    }

    int? intVal(String field) {
      final raw = str(field);
      if (raw == null) return null;
      final parsed = int.tryParse(raw);
      if (parsed == null) {
        throw MixlistCsvParseException(
          "Column for '$field' has non-numeric value '$raw'",
          rowNumber: rowNumber,
        );
      }
      return parsed;
    }

    double? doubleVal(String field) {
      final raw = str(field);
      if (raw == null) return null;
      final parsed = double.tryParse(raw);
      if (parsed == null) {
        throw MixlistCsvParseException(
          "Column for '$field' has non-numeric value '$raw'",
          rowNumber: rowNumber,
        );
      }
      return parsed;
    }

    String required(String field) {
      final value = str(field);
      if (value == null) {
        throw MixlistCsvParseException(
          "Column for '$field' is required but blank",
          rowNumber: rowNumber,
        );
      }
      return value;
    }

    int requiredInt(String field) {
      final value = intVal(field);
      if (value == null) {
        throw MixlistCsvParseException(
          "Column for '$field' is required but blank",
          rowNumber: rowNumber,
        );
      }
      return value;
    }

    return MixlistCsvRow(
      trackURI: required('trackURI'),
      trackName: required('trackName'),
      artistURIs: str('artistURIs'),
      artistNames: required('artistNames'),
      albumURI: str('albumURI'),
      albumName: required('albumName'),
      albumArtistURI: str('albumArtistURI'),
      // Falls back to the track-level artist name when this file's format
      // doesn't distinguish album artist from track artist -- since
      // artistNames is required, this is always non-null in practice.
      albumArtistName: str('albumArtistName') ?? required('artistNames'),
      albumReleaseDate: str('albumReleaseDate'),
      albumImageURL: str('albumImageURL'),
      discNumber: intVal('discNumber'),
      albumTrackNumber: intVal('albumTrackNumber'),
      durationMs: requiredInt('durationMs'),
      audioPreviewURL: str('audioPreviewURL'),
      isExplicit: (str('explicit') ?? '').trim().toLowerCase() == 'true',
      popularity: intVal('popularity'),
      isrc: str('isrc'),
      addedAt: required('addedAt'),
      genres: str('genres'),
      recordLabel: str('recordLabel'),
      danceability: doubleVal('danceability'),
      energy: doubleVal('energy'),
      key: intVal('key'),
      loudness: doubleVal('loudness'),
      mode: intVal('mode'),
      speechiness: doubleVal('speechiness'),
      acousticness: doubleVal('acousticness'),
      instrumentalness: doubleVal('instrumentalness'),
      liveness: doubleVal('liveness'),
      valence: doubleVal('valence'),
      tempo: doubleVal('tempo'),
      timeSignature: intVal('timeSignature'),
    );
  }
}
