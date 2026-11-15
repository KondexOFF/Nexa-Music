// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LibraryFoldersTable extends LibraryFolders
    with TableInfo<$LibraryFoldersTable, FolderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathKeyMeta = const VerificationMeta(
    'pathKey',
  );
  @override
  late final GeneratedColumn<String> pathKey = GeneratedColumn<String>(
    'path_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastScanAtMeta = const VerificationMeta(
    'lastScanAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastScanAt = GeneratedColumn<DateTime>(
    'last_scan_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    pathKey,
    addedAt,
    lastScanAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<FolderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('path_key')) {
      context.handle(
        _pathKeyMeta,
        pathKey.isAcceptableOrUnknown(data['path_key']!, _pathKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_pathKeyMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('last_scan_at')) {
      context.handle(
        _lastScanAtMeta,
        lastScanAt.isAcceptableOrUnknown(
          data['last_scan_at']!,
          _lastScanAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FolderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FolderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      pathKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path_key'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      lastScanAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_scan_at'],
      ),
    );
  }

  @override
  $LibraryFoldersTable createAlias(String alias) {
    return $LibraryFoldersTable(attachedDatabase, alias);
  }
}

class FolderRow extends DataClass implements Insertable<FolderRow> {
  final int id;
  final String path;

  /// Normalised path (lower case on Windows) used to avoid duplicates.
  final String pathKey;
  final DateTime addedAt;
  final DateTime? lastScanAt;
  const FolderRow({
    required this.id,
    required this.path,
    required this.pathKey,
    required this.addedAt,
    this.lastScanAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['path_key'] = Variable<String>(pathKey);
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || lastScanAt != null) {
      map['last_scan_at'] = Variable<DateTime>(lastScanAt);
    }
    return map;
  }

  LibraryFoldersCompanion toCompanion(bool nullToAbsent) {
    return LibraryFoldersCompanion(
      id: Value(id),
      path: Value(path),
      pathKey: Value(pathKey),
      addedAt: Value(addedAt),
      lastScanAt: lastScanAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastScanAt),
    );
  }

  factory FolderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FolderRow(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      pathKey: serializer.fromJson<String>(json['pathKey']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      lastScanAt: serializer.fromJson<DateTime?>(json['lastScanAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'pathKey': serializer.toJson<String>(pathKey),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'lastScanAt': serializer.toJson<DateTime?>(lastScanAt),
    };
  }

  FolderRow copyWith({
    int? id,
    String? path,
    String? pathKey,
    DateTime? addedAt,
    Value<DateTime?> lastScanAt = const Value.absent(),
  }) => FolderRow(
    id: id ?? this.id,
    path: path ?? this.path,
    pathKey: pathKey ?? this.pathKey,
    addedAt: addedAt ?? this.addedAt,
    lastScanAt: lastScanAt.present ? lastScanAt.value : this.lastScanAt,
  );
  FolderRow copyWithCompanion(LibraryFoldersCompanion data) {
    return FolderRow(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      pathKey: data.pathKey.present ? data.pathKey.value : this.pathKey,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      lastScanAt: data.lastScanAt.present
          ? data.lastScanAt.value
          : this.lastScanAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FolderRow(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('pathKey: $pathKey, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastScanAt: $lastScanAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path, pathKey, addedAt, lastScanAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FolderRow &&
          other.id == this.id &&
          other.path == this.path &&
          other.pathKey == this.pathKey &&
          other.addedAt == this.addedAt &&
          other.lastScanAt == this.lastScanAt);
}

class LibraryFoldersCompanion extends UpdateCompanion<FolderRow> {
  final Value<int> id;
  final Value<String> path;
  final Value<String> pathKey;
  final Value<DateTime> addedAt;
  final Value<DateTime?> lastScanAt;
  const LibraryFoldersCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.pathKey = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastScanAt = const Value.absent(),
  });
  LibraryFoldersCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required String pathKey,
    required DateTime addedAt,
    this.lastScanAt = const Value.absent(),
  }) : path = Value(path),
       pathKey = Value(pathKey),
       addedAt = Value(addedAt);
  static Insertable<FolderRow> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<String>? pathKey,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? lastScanAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (pathKey != null) 'path_key': pathKey,
      if (addedAt != null) 'added_at': addedAt,
      if (lastScanAt != null) 'last_scan_at': lastScanAt,
    });
  }

  LibraryFoldersCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<String>? pathKey,
    Value<DateTime>? addedAt,
    Value<DateTime?>? lastScanAt,
  }) {
    return LibraryFoldersCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      pathKey: pathKey ?? this.pathKey,
      addedAt: addedAt ?? this.addedAt,
      lastScanAt: lastScanAt ?? this.lastScanAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (pathKey.present) {
      map['path_key'] = Variable<String>(pathKey.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (lastScanAt.present) {
      map['last_scan_at'] = Variable<DateTime>(lastScanAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryFoldersCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('pathKey: $pathKey, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastScanAt: $lastScanAt')
          ..write(')'))
        .toString();
  }
}

class $TracksTable extends Tracks with TableInfo<$TracksTable, TrackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _pathKeyMeta = const VerificationMeta(
    'pathKey',
  );
  @override
  late final GeneratedColumn<String> pathKey = GeneratedColumn<String>(
    'path_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_folders (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumArtistMeta = const VerificationMeta(
    'albumArtist',
  );
  @override
  late final GeneratedColumn<String> albumArtist = GeneratedColumn<String>(
    'album_artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackNumberMeta = const VerificationMeta(
    'trackNumber',
  );
  @override
  late final GeneratedColumn<int> trackNumber = GeneratedColumn<int>(
    'track_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discNumberMeta = const VerificationMeta(
    'discNumber',
  );
  @override
  late final GeneratedColumn<int> discNumber = GeneratedColumn<int>(
    'disc_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileModifiedMeta = const VerificationMeta(
    'fileModified',
  );
  @override
  late final GeneratedColumn<DateTime> fileModified = GeneratedColumn<DateTime>(
    'file_modified',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artworkPathMeta = const VerificationMeta(
    'artworkPath',
  );
  @override
  late final GeneratedColumn<String> artworkPath = GeneratedColumn<String>(
    'artwork_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  @override
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'search_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _favoriteMeta = const VerificationMeta(
    'favorite',
  );
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
    'favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _favoritedAtMeta = const VerificationMeta(
    'favoritedAt',
  );
  @override
  late final GeneratedColumn<DateTime> favoritedAt = GeneratedColumn<DateTime>(
    'favorited_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _availableMeta = const VerificationMeta(
    'available',
  );
  @override
  late final GeneratedColumn<bool> available = GeneratedColumn<bool>(
    'available',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("available" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _problemMeta = const VerificationMeta(
    'problem',
  );
  @override
  late final GeneratedColumn<String> problem = GeneratedColumn<String>(
    'problem',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dislikedMeta = const VerificationMeta(
    'disliked',
  );
  @override
  late final GeneratedColumn<bool> disliked = GeneratedColumn<bool>(
    'disliked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("disliked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dislikedAtMeta = const VerificationMeta(
    'dislikedAt',
  );
  @override
  late final GeneratedColumn<DateTime> dislikedAt = GeneratedColumn<DateTime>(
    'disliked_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userTitleMeta = const VerificationMeta(
    'userTitle',
  );
  @override
  late final GeneratedColumn<String> userTitle = GeneratedColumn<String>(
    'user_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageUrlMeta = const VerificationMeta(
    'pageUrl',
  );
  @override
  late final GeneratedColumn<String> pageUrl = GeneratedColumn<String>(
    'page_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _licenseMeta = const VerificationMeta(
    'license',
  );
  @override
  late final GeneratedColumn<String> license = GeneratedColumn<String>(
    'license',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _licenseUrlMeta = const VerificationMeta(
    'licenseUrl',
  );
  @override
  late final GeneratedColumn<String> licenseUrl = GeneratedColumn<String>(
    'license_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metaFetchedAtMeta = const VerificationMeta(
    'metaFetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> metaFetchedAt =
      GeneratedColumn<DateTime>(
        'meta_fetched_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    source,
    pathKey,
    path,
    folderId,
    title,
    artist,
    album,
    albumArtist,
    genre,
    year,
    trackNumber,
    discNumber,
    durationMs,
    fileSize,
    fileModified,
    artworkPath,
    searchText,
    favorite,
    favoritedAt,
    available,
    problem,
    addedAt,
    disliked,
    dislikedAt,
    userTitle,
    pageUrl,
    license,
    licenseUrl,
    metaFetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('path_key')) {
      context.handle(
        _pathKeyMeta,
        pathKey.isAcceptableOrUnknown(data['path_key']!, _pathKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_pathKeyMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    } else if (isInserting) {
      context.missing(_albumMeta);
    }
    if (data.containsKey('album_artist')) {
      context.handle(
        _albumArtistMeta,
        albumArtist.isAcceptableOrUnknown(
          data['album_artist']!,
          _albumArtistMeta,
        ),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('track_number')) {
      context.handle(
        _trackNumberMeta,
        trackNumber.isAcceptableOrUnknown(
          data['track_number']!,
          _trackNumberMeta,
        ),
      );
    }
    if (data.containsKey('disc_number')) {
      context.handle(
        _discNumberMeta,
        discNumber.isAcceptableOrUnknown(data['disc_number']!, _discNumberMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_fileSizeMeta);
    }
    if (data.containsKey('file_modified')) {
      context.handle(
        _fileModifiedMeta,
        fileModified.isAcceptableOrUnknown(
          data['file_modified']!,
          _fileModifiedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fileModifiedMeta);
    }
    if (data.containsKey('artwork_path')) {
      context.handle(
        _artworkPathMeta,
        artworkPath.isAcceptableOrUnknown(
          data['artwork_path']!,
          _artworkPathMeta,
        ),
      );
    }
    if (data.containsKey('search_text')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['search_text']!, _searchTextMeta),
      );
    } else if (isInserting) {
      context.missing(_searchTextMeta);
    }
    if (data.containsKey('favorite')) {
      context.handle(
        _favoriteMeta,
        favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta),
      );
    }
    if (data.containsKey('favorited_at')) {
      context.handle(
        _favoritedAtMeta,
        favoritedAt.isAcceptableOrUnknown(
          data['favorited_at']!,
          _favoritedAtMeta,
        ),
      );
    }
    if (data.containsKey('available')) {
      context.handle(
        _availableMeta,
        available.isAcceptableOrUnknown(data['available']!, _availableMeta),
      );
    }
    if (data.containsKey('problem')) {
      context.handle(
        _problemMeta,
        problem.isAcceptableOrUnknown(data['problem']!, _problemMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('disliked')) {
      context.handle(
        _dislikedMeta,
        disliked.isAcceptableOrUnknown(data['disliked']!, _dislikedMeta),
      );
    }
    if (data.containsKey('disliked_at')) {
      context.handle(
        _dislikedAtMeta,
        dislikedAt.isAcceptableOrUnknown(data['disliked_at']!, _dislikedAtMeta),
      );
    }
    if (data.containsKey('user_title')) {
      context.handle(
        _userTitleMeta,
        userTitle.isAcceptableOrUnknown(data['user_title']!, _userTitleMeta),
      );
    }
    if (data.containsKey('page_url')) {
      context.handle(
        _pageUrlMeta,
        pageUrl.isAcceptableOrUnknown(data['page_url']!, _pageUrlMeta),
      );
    }
    if (data.containsKey('license')) {
      context.handle(
        _licenseMeta,
        license.isAcceptableOrUnknown(data['license']!, _licenseMeta),
      );
    }
    if (data.containsKey('license_url')) {
      context.handle(
        _licenseUrlMeta,
        licenseUrl.isAcceptableOrUnknown(data['license_url']!, _licenseUrlMeta),
      );
    }
    if (data.containsKey('meta_fetched_at')) {
      context.handle(
        _metaFetchedAtMeta,
        metaFetchedAt.isAcceptableOrUnknown(
          data['meta_fetched_at']!,
          _metaFetchedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      pathKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path_key'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      )!,
      albumArtist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_artist'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      trackNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_number'],
      ),
      discNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}disc_number'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      fileModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}file_modified'],
      )!,
      artworkPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_path'],
      ),
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_text'],
      )!,
      favorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}favorite'],
      )!,
      favoritedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}favorited_at'],
      ),
      available: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}available'],
      )!,
      problem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}problem'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      disliked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}disliked'],
      )!,
      dislikedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}disliked_at'],
      ),
      userTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_title'],
      ),
      pageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}page_url'],
      ),
      license: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license'],
      ),
      licenseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license_url'],
      ),
      metaFetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}meta_fetched_at'],
      ),
    );
  }

  @override
  $TracksTable createAlias(String alias) {
    return $TracksTable(attachedDatabase, alias);
  }
}

class TrackRow extends DataClass implements Insertable<TrackRow> {
  final int id;
  final String source;

  /// Normalised path; one row per file however often it is scanned.
  final String pathKey;
  final String path;
  final int? folderId;
  final String title;
  final String artist;
  final String album;
  final String? albumArtist;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final int? durationMs;
  final int fileSize;
  final DateTime fileModified;
  final String? artworkPath;

  /// Lower-cased title, artist, album, genre and file name for search
  /// (SQLite LIKE is case-insensitive only for ASCII).
  final String searchText;
  final bool favorite;
  final DateTime? favoritedAt;
  final bool available;
  final String? problem;
  final DateTime addedAt;

  /// Explicit dislike (NEXA DNA, schema v3): never suggested by NEXA Wave.
  final bool disliked;
  final DateTime? dislikedAt;

  /// The user's own name for a saved entry (rename); null = [title].
  final String? userTitle;

  /// Page of the entry at its source (backlink / "Open on YouTube").
  final String? pageUrl;

  /// Catalog licence name and link (attribution).
  final String? license;
  final String? licenseUrl;

  /// When title / artist / artwork were last received from the source's
  /// API. YouTube data is refreshed or removed within 30 days (YouTube API
  /// Services Developer Policies III.E.4.c); the video id and the user's
  /// own name are kept.
  final DateTime? metaFetchedAt;
  const TrackRow({
    required this.id,
    required this.source,
    required this.pathKey,
    required this.path,
    this.folderId,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtist,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.durationMs,
    required this.fileSize,
    required this.fileModified,
    this.artworkPath,
    required this.searchText,
    required this.favorite,
    this.favoritedAt,
    required this.available,
    this.problem,
    required this.addedAt,
    required this.disliked,
    this.dislikedAt,
    this.userTitle,
    this.pageUrl,
    this.license,
    this.licenseUrl,
    this.metaFetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source'] = Variable<String>(source);
    map['path_key'] = Variable<String>(pathKey);
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<int>(folderId);
    }
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['album'] = Variable<String>(album);
    if (!nullToAbsent || albumArtist != null) {
      map['album_artist'] = Variable<String>(albumArtist);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || trackNumber != null) {
      map['track_number'] = Variable<int>(trackNumber);
    }
    if (!nullToAbsent || discNumber != null) {
      map['disc_number'] = Variable<int>(discNumber);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['file_size'] = Variable<int>(fileSize);
    map['file_modified'] = Variable<DateTime>(fileModified);
    if (!nullToAbsent || artworkPath != null) {
      map['artwork_path'] = Variable<String>(artworkPath);
    }
    map['search_text'] = Variable<String>(searchText);
    map['favorite'] = Variable<bool>(favorite);
    if (!nullToAbsent || favoritedAt != null) {
      map['favorited_at'] = Variable<DateTime>(favoritedAt);
    }
    map['available'] = Variable<bool>(available);
    if (!nullToAbsent || problem != null) {
      map['problem'] = Variable<String>(problem);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    map['disliked'] = Variable<bool>(disliked);
    if (!nullToAbsent || dislikedAt != null) {
      map['disliked_at'] = Variable<DateTime>(dislikedAt);
    }
    if (!nullToAbsent || userTitle != null) {
      map['user_title'] = Variable<String>(userTitle);
    }
    if (!nullToAbsent || pageUrl != null) {
      map['page_url'] = Variable<String>(pageUrl);
    }
    if (!nullToAbsent || license != null) {
      map['license'] = Variable<String>(license);
    }
    if (!nullToAbsent || licenseUrl != null) {
      map['license_url'] = Variable<String>(licenseUrl);
    }
    if (!nullToAbsent || metaFetchedAt != null) {
      map['meta_fetched_at'] = Variable<DateTime>(metaFetchedAt);
    }
    return map;
  }

  TracksCompanion toCompanion(bool nullToAbsent) {
    return TracksCompanion(
      id: Value(id),
      source: Value(source),
      pathKey: Value(pathKey),
      path: Value(path),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      albumArtist: albumArtist == null && nullToAbsent
          ? const Value.absent()
          : Value(albumArtist),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      trackNumber: trackNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(trackNumber),
      discNumber: discNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(discNumber),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      fileSize: Value(fileSize),
      fileModified: Value(fileModified),
      artworkPath: artworkPath == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkPath),
      searchText: Value(searchText),
      favorite: Value(favorite),
      favoritedAt: favoritedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(favoritedAt),
      available: Value(available),
      problem: problem == null && nullToAbsent
          ? const Value.absent()
          : Value(problem),
      addedAt: Value(addedAt),
      disliked: Value(disliked),
      dislikedAt: dislikedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dislikedAt),
      userTitle: userTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(userTitle),
      pageUrl: pageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(pageUrl),
      license: license == null && nullToAbsent
          ? const Value.absent()
          : Value(license),
      licenseUrl: licenseUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(licenseUrl),
      metaFetchedAt: metaFetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(metaFetchedAt),
    );
  }

  factory TrackRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackRow(
      id: serializer.fromJson<int>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      pathKey: serializer.fromJson<String>(json['pathKey']),
      path: serializer.fromJson<String>(json['path']),
      folderId: serializer.fromJson<int?>(json['folderId']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      album: serializer.fromJson<String>(json['album']),
      albumArtist: serializer.fromJson<String?>(json['albumArtist']),
      genre: serializer.fromJson<String?>(json['genre']),
      year: serializer.fromJson<int?>(json['year']),
      trackNumber: serializer.fromJson<int?>(json['trackNumber']),
      discNumber: serializer.fromJson<int?>(json['discNumber']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      fileModified: serializer.fromJson<DateTime>(json['fileModified']),
      artworkPath: serializer.fromJson<String?>(json['artworkPath']),
      searchText: serializer.fromJson<String>(json['searchText']),
      favorite: serializer.fromJson<bool>(json['favorite']),
      favoritedAt: serializer.fromJson<DateTime?>(json['favoritedAt']),
      available: serializer.fromJson<bool>(json['available']),
      problem: serializer.fromJson<String?>(json['problem']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      disliked: serializer.fromJson<bool>(json['disliked']),
      dislikedAt: serializer.fromJson<DateTime?>(json['dislikedAt']),
      userTitle: serializer.fromJson<String?>(json['userTitle']),
      pageUrl: serializer.fromJson<String?>(json['pageUrl']),
      license: serializer.fromJson<String?>(json['license']),
      licenseUrl: serializer.fromJson<String?>(json['licenseUrl']),
      metaFetchedAt: serializer.fromJson<DateTime?>(json['metaFetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(source),
      'pathKey': serializer.toJson<String>(pathKey),
      'path': serializer.toJson<String>(path),
      'folderId': serializer.toJson<int?>(folderId),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'album': serializer.toJson<String>(album),
      'albumArtist': serializer.toJson<String?>(albumArtist),
      'genre': serializer.toJson<String?>(genre),
      'year': serializer.toJson<int?>(year),
      'trackNumber': serializer.toJson<int?>(trackNumber),
      'discNumber': serializer.toJson<int?>(discNumber),
      'durationMs': serializer.toJson<int?>(durationMs),
      'fileSize': serializer.toJson<int>(fileSize),
      'fileModified': serializer.toJson<DateTime>(fileModified),
      'artworkPath': serializer.toJson<String?>(artworkPath),
      'searchText': serializer.toJson<String>(searchText),
      'favorite': serializer.toJson<bool>(favorite),
      'favoritedAt': serializer.toJson<DateTime?>(favoritedAt),
      'available': serializer.toJson<bool>(available),
      'problem': serializer.toJson<String?>(problem),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'disliked': serializer.toJson<bool>(disliked),
      'dislikedAt': serializer.toJson<DateTime?>(dislikedAt),
      'userTitle': serializer.toJson<String?>(userTitle),
      'pageUrl': serializer.toJson<String?>(pageUrl),
      'license': serializer.toJson<String?>(license),
      'licenseUrl': serializer.toJson<String?>(licenseUrl),
      'metaFetchedAt': serializer.toJson<DateTime?>(metaFetchedAt),
    };
  }

  TrackRow copyWith({
    int? id,
    String? source,
    String? pathKey,
    String? path,
    Value<int?> folderId = const Value.absent(),
    String? title,
    String? artist,
    String? album,
    Value<String?> albumArtist = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<int?> trackNumber = const Value.absent(),
    Value<int?> discNumber = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    int? fileSize,
    DateTime? fileModified,
    Value<String?> artworkPath = const Value.absent(),
    String? searchText,
    bool? favorite,
    Value<DateTime?> favoritedAt = const Value.absent(),
    bool? available,
    Value<String?> problem = const Value.absent(),
    DateTime? addedAt,
    bool? disliked,
    Value<DateTime?> dislikedAt = const Value.absent(),
    Value<String?> userTitle = const Value.absent(),
    Value<String?> pageUrl = const Value.absent(),
    Value<String?> license = const Value.absent(),
    Value<String?> licenseUrl = const Value.absent(),
    Value<DateTime?> metaFetchedAt = const Value.absent(),
  }) => TrackRow(
    id: id ?? this.id,
    source: source ?? this.source,
    pathKey: pathKey ?? this.pathKey,
    path: path ?? this.path,
    folderId: folderId.present ? folderId.value : this.folderId,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    albumArtist: albumArtist.present ? albumArtist.value : this.albumArtist,
    genre: genre.present ? genre.value : this.genre,
    year: year.present ? year.value : this.year,
    trackNumber: trackNumber.present ? trackNumber.value : this.trackNumber,
    discNumber: discNumber.present ? discNumber.value : this.discNumber,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    fileSize: fileSize ?? this.fileSize,
    fileModified: fileModified ?? this.fileModified,
    artworkPath: artworkPath.present ? artworkPath.value : this.artworkPath,
    searchText: searchText ?? this.searchText,
    favorite: favorite ?? this.favorite,
    favoritedAt: favoritedAt.present ? favoritedAt.value : this.favoritedAt,
    available: available ?? this.available,
    problem: problem.present ? problem.value : this.problem,
    addedAt: addedAt ?? this.addedAt,
    disliked: disliked ?? this.disliked,
    dislikedAt: dislikedAt.present ? dislikedAt.value : this.dislikedAt,
    userTitle: userTitle.present ? userTitle.value : this.userTitle,
    pageUrl: pageUrl.present ? pageUrl.value : this.pageUrl,
    license: license.present ? license.value : this.license,
    licenseUrl: licenseUrl.present ? licenseUrl.value : this.licenseUrl,
    metaFetchedAt: metaFetchedAt.present
        ? metaFetchedAt.value
        : this.metaFetchedAt,
  );
  TrackRow copyWithCompanion(TracksCompanion data) {
    return TrackRow(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      pathKey: data.pathKey.present ? data.pathKey.value : this.pathKey,
      path: data.path.present ? data.path.value : this.path,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      albumArtist: data.albumArtist.present
          ? data.albumArtist.value
          : this.albumArtist,
      genre: data.genre.present ? data.genre.value : this.genre,
      year: data.year.present ? data.year.value : this.year,
      trackNumber: data.trackNumber.present
          ? data.trackNumber.value
          : this.trackNumber,
      discNumber: data.discNumber.present
          ? data.discNumber.value
          : this.discNumber,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      fileModified: data.fileModified.present
          ? data.fileModified.value
          : this.fileModified,
      artworkPath: data.artworkPath.present
          ? data.artworkPath.value
          : this.artworkPath,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
      favoritedAt: data.favoritedAt.present
          ? data.favoritedAt.value
          : this.favoritedAt,
      available: data.available.present ? data.available.value : this.available,
      problem: data.problem.present ? data.problem.value : this.problem,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      disliked: data.disliked.present ? data.disliked.value : this.disliked,
      dislikedAt: data.dislikedAt.present
          ? data.dislikedAt.value
          : this.dislikedAt,
      userTitle: data.userTitle.present ? data.userTitle.value : this.userTitle,
      pageUrl: data.pageUrl.present ? data.pageUrl.value : this.pageUrl,
      license: data.license.present ? data.license.value : this.license,
      licenseUrl: data.licenseUrl.present
          ? data.licenseUrl.value
          : this.licenseUrl,
      metaFetchedAt: data.metaFetchedAt.present
          ? data.metaFetchedAt.value
          : this.metaFetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackRow(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('pathKey: $pathKey, ')
          ..write('path: $path, ')
          ..write('folderId: $folderId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('genre: $genre, ')
          ..write('year: $year, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('discNumber: $discNumber, ')
          ..write('durationMs: $durationMs, ')
          ..write('fileSize: $fileSize, ')
          ..write('fileModified: $fileModified, ')
          ..write('artworkPath: $artworkPath, ')
          ..write('searchText: $searchText, ')
          ..write('favorite: $favorite, ')
          ..write('favoritedAt: $favoritedAt, ')
          ..write('available: $available, ')
          ..write('problem: $problem, ')
          ..write('addedAt: $addedAt, ')
          ..write('disliked: $disliked, ')
          ..write('dislikedAt: $dislikedAt, ')
          ..write('userTitle: $userTitle, ')
          ..write('pageUrl: $pageUrl, ')
          ..write('license: $license, ')
          ..write('licenseUrl: $licenseUrl, ')
          ..write('metaFetchedAt: $metaFetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    source,
    pathKey,
    path,
    folderId,
    title,
    artist,
    album,
    albumArtist,
    genre,
    year,
    trackNumber,
    discNumber,
    durationMs,
    fileSize,
    fileModified,
    artworkPath,
    searchText,
    favorite,
    favoritedAt,
    available,
    problem,
    addedAt,
    disliked,
    dislikedAt,
    userTitle,
    pageUrl,
    license,
    licenseUrl,
    metaFetchedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackRow &&
          other.id == this.id &&
          other.source == this.source &&
          other.pathKey == this.pathKey &&
          other.path == this.path &&
          other.folderId == this.folderId &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.albumArtist == this.albumArtist &&
          other.genre == this.genre &&
          other.year == this.year &&
          other.trackNumber == this.trackNumber &&
          other.discNumber == this.discNumber &&
          other.durationMs == this.durationMs &&
          other.fileSize == this.fileSize &&
          other.fileModified == this.fileModified &&
          other.artworkPath == this.artworkPath &&
          other.searchText == this.searchText &&
          other.favorite == this.favorite &&
          other.favoritedAt == this.favoritedAt &&
          other.available == this.available &&
          other.problem == this.problem &&
          other.addedAt == this.addedAt &&
          other.disliked == this.disliked &&
          other.dislikedAt == this.dislikedAt &&
          other.userTitle == this.userTitle &&
          other.pageUrl == this.pageUrl &&
          other.license == this.license &&
          other.licenseUrl == this.licenseUrl &&
          other.metaFetchedAt == this.metaFetchedAt);
}

class TracksCompanion extends UpdateCompanion<TrackRow> {
  final Value<int> id;
  final Value<String> source;
  final Value<String> pathKey;
  final Value<String> path;
  final Value<int?> folderId;
  final Value<String> title;
  final Value<String> artist;
  final Value<String> album;
  final Value<String?> albumArtist;
  final Value<String?> genre;
  final Value<int?> year;
  final Value<int?> trackNumber;
  final Value<int?> discNumber;
  final Value<int?> durationMs;
  final Value<int> fileSize;
  final Value<DateTime> fileModified;
  final Value<String?> artworkPath;
  final Value<String> searchText;
  final Value<bool> favorite;
  final Value<DateTime?> favoritedAt;
  final Value<bool> available;
  final Value<String?> problem;
  final Value<DateTime> addedAt;
  final Value<bool> disliked;
  final Value<DateTime?> dislikedAt;
  final Value<String?> userTitle;
  final Value<String?> pageUrl;
  final Value<String?> license;
  final Value<String?> licenseUrl;
  final Value<DateTime?> metaFetchedAt;
  const TracksCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.pathKey = const Value.absent(),
    this.path = const Value.absent(),
    this.folderId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.genre = const Value.absent(),
    this.year = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.fileModified = const Value.absent(),
    this.artworkPath = const Value.absent(),
    this.searchText = const Value.absent(),
    this.favorite = const Value.absent(),
    this.favoritedAt = const Value.absent(),
    this.available = const Value.absent(),
    this.problem = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.disliked = const Value.absent(),
    this.dislikedAt = const Value.absent(),
    this.userTitle = const Value.absent(),
    this.pageUrl = const Value.absent(),
    this.license = const Value.absent(),
    this.licenseUrl = const Value.absent(),
    this.metaFetchedAt = const Value.absent(),
  });
  TracksCompanion.insert({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    required String pathKey,
    required String path,
    this.folderId = const Value.absent(),
    required String title,
    required String artist,
    required String album,
    this.albumArtist = const Value.absent(),
    this.genre = const Value.absent(),
    this.year = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.durationMs = const Value.absent(),
    required int fileSize,
    required DateTime fileModified,
    this.artworkPath = const Value.absent(),
    required String searchText,
    this.favorite = const Value.absent(),
    this.favoritedAt = const Value.absent(),
    this.available = const Value.absent(),
    this.problem = const Value.absent(),
    required DateTime addedAt,
    this.disliked = const Value.absent(),
    this.dislikedAt = const Value.absent(),
    this.userTitle = const Value.absent(),
    this.pageUrl = const Value.absent(),
    this.license = const Value.absent(),
    this.licenseUrl = const Value.absent(),
    this.metaFetchedAt = const Value.absent(),
  }) : pathKey = Value(pathKey),
       path = Value(path),
       title = Value(title),
       artist = Value(artist),
       album = Value(album),
       fileSize = Value(fileSize),
       fileModified = Value(fileModified),
       searchText = Value(searchText),
       addedAt = Value(addedAt);
  static Insertable<TrackRow> custom({
    Expression<int>? id,
    Expression<String>? source,
    Expression<String>? pathKey,
    Expression<String>? path,
    Expression<int>? folderId,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? albumArtist,
    Expression<String>? genre,
    Expression<int>? year,
    Expression<int>? trackNumber,
    Expression<int>? discNumber,
    Expression<int>? durationMs,
    Expression<int>? fileSize,
    Expression<DateTime>? fileModified,
    Expression<String>? artworkPath,
    Expression<String>? searchText,
    Expression<bool>? favorite,
    Expression<DateTime>? favoritedAt,
    Expression<bool>? available,
    Expression<String>? problem,
    Expression<DateTime>? addedAt,
    Expression<bool>? disliked,
    Expression<DateTime>? dislikedAt,
    Expression<String>? userTitle,
    Expression<String>? pageUrl,
    Expression<String>? license,
    Expression<String>? licenseUrl,
    Expression<DateTime>? metaFetchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (pathKey != null) 'path_key': pathKey,
      if (path != null) 'path': path,
      if (folderId != null) 'folder_id': folderId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (albumArtist != null) 'album_artist': albumArtist,
      if (genre != null) 'genre': genre,
      if (year != null) 'year': year,
      if (trackNumber != null) 'track_number': trackNumber,
      if (discNumber != null) 'disc_number': discNumber,
      if (durationMs != null) 'duration_ms': durationMs,
      if (fileSize != null) 'file_size': fileSize,
      if (fileModified != null) 'file_modified': fileModified,
      if (artworkPath != null) 'artwork_path': artworkPath,
      if (searchText != null) 'search_text': searchText,
      if (favorite != null) 'favorite': favorite,
      if (favoritedAt != null) 'favorited_at': favoritedAt,
      if (available != null) 'available': available,
      if (problem != null) 'problem': problem,
      if (addedAt != null) 'added_at': addedAt,
      if (disliked != null) 'disliked': disliked,
      if (dislikedAt != null) 'disliked_at': dislikedAt,
      if (userTitle != null) 'user_title': userTitle,
      if (pageUrl != null) 'page_url': pageUrl,
      if (license != null) 'license': license,
      if (licenseUrl != null) 'license_url': licenseUrl,
      if (metaFetchedAt != null) 'meta_fetched_at': metaFetchedAt,
    });
  }

  TracksCompanion copyWith({
    Value<int>? id,
    Value<String>? source,
    Value<String>? pathKey,
    Value<String>? path,
    Value<int?>? folderId,
    Value<String>? title,
    Value<String>? artist,
    Value<String>? album,
    Value<String?>? albumArtist,
    Value<String?>? genre,
    Value<int?>? year,
    Value<int?>? trackNumber,
    Value<int?>? discNumber,
    Value<int?>? durationMs,
    Value<int>? fileSize,
    Value<DateTime>? fileModified,
    Value<String?>? artworkPath,
    Value<String>? searchText,
    Value<bool>? favorite,
    Value<DateTime?>? favoritedAt,
    Value<bool>? available,
    Value<String?>? problem,
    Value<DateTime>? addedAt,
    Value<bool>? disliked,
    Value<DateTime?>? dislikedAt,
    Value<String?>? userTitle,
    Value<String?>? pageUrl,
    Value<String?>? license,
    Value<String?>? licenseUrl,
    Value<DateTime?>? metaFetchedAt,
  }) {
    return TracksCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      pathKey: pathKey ?? this.pathKey,
      path: path ?? this.path,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      durationMs: durationMs ?? this.durationMs,
      fileSize: fileSize ?? this.fileSize,
      fileModified: fileModified ?? this.fileModified,
      artworkPath: artworkPath ?? this.artworkPath,
      searchText: searchText ?? this.searchText,
      favorite: favorite ?? this.favorite,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      available: available ?? this.available,
      problem: problem ?? this.problem,
      addedAt: addedAt ?? this.addedAt,
      disliked: disliked ?? this.disliked,
      dislikedAt: dislikedAt ?? this.dislikedAt,
      userTitle: userTitle ?? this.userTitle,
      pageUrl: pageUrl ?? this.pageUrl,
      license: license ?? this.license,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      metaFetchedAt: metaFetchedAt ?? this.metaFetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (pathKey.present) {
      map['path_key'] = Variable<String>(pathKey.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (albumArtist.present) {
      map['album_artist'] = Variable<String>(albumArtist.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (trackNumber.present) {
      map['track_number'] = Variable<int>(trackNumber.value);
    }
    if (discNumber.present) {
      map['disc_number'] = Variable<int>(discNumber.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (fileModified.present) {
      map['file_modified'] = Variable<DateTime>(fileModified.value);
    }
    if (artworkPath.present) {
      map['artwork_path'] = Variable<String>(artworkPath.value);
    }
    if (searchText.present) {
      map['search_text'] = Variable<String>(searchText.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
    }
    if (favoritedAt.present) {
      map['favorited_at'] = Variable<DateTime>(favoritedAt.value);
    }
    if (available.present) {
      map['available'] = Variable<bool>(available.value);
    }
    if (problem.present) {
      map['problem'] = Variable<String>(problem.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (disliked.present) {
      map['disliked'] = Variable<bool>(disliked.value);
    }
    if (dislikedAt.present) {
      map['disliked_at'] = Variable<DateTime>(dislikedAt.value);
    }
    if (userTitle.present) {
      map['user_title'] = Variable<String>(userTitle.value);
    }
    if (pageUrl.present) {
      map['page_url'] = Variable<String>(pageUrl.value);
    }
    if (license.present) {
      map['license'] = Variable<String>(license.value);
    }
    if (licenseUrl.present) {
      map['license_url'] = Variable<String>(licenseUrl.value);
    }
    if (metaFetchedAt.present) {
      map['meta_fetched_at'] = Variable<DateTime>(metaFetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('pathKey: $pathKey, ')
          ..write('path: $path, ')
          ..write('folderId: $folderId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('genre: $genre, ')
          ..write('year: $year, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('discNumber: $discNumber, ')
          ..write('durationMs: $durationMs, ')
          ..write('fileSize: $fileSize, ')
          ..write('fileModified: $fileModified, ')
          ..write('artworkPath: $artworkPath, ')
          ..write('searchText: $searchText, ')
          ..write('favorite: $favorite, ')
          ..write('favoritedAt: $favoritedAt, ')
          ..write('available: $available, ')
          ..write('problem: $problem, ')
          ..write('addedAt: $addedAt, ')
          ..write('disliked: $disliked, ')
          ..write('dislikedAt: $dislikedAt, ')
          ..write('userTitle: $userTitle, ')
          ..write('pageUrl: $pageUrl, ')
          ..write('license: $license, ')
          ..write('licenseUrl: $licenseUrl, ')
          ..write('metaFetchedAt: $metaFetchedAt')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, PlaylistRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class PlaylistRow extends DataClass implements Insertable<PlaylistRow> {
  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PlaylistRow({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaylistRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlaylistRow copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PlaylistRow(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaylistRow copyWithCompanion(PlaylistsCompanion data) {
    return PlaylistRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PlaylistsCompanion extends UpdateCompanion<PlaylistRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PlaylistRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PlaylistEntriesTable extends PlaylistEntries
    with TableInfo<$PlaylistEntriesTable, PlaylistEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    trackId,
    position,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $PlaylistEntriesTable createAlias(String alias) {
    return $PlaylistEntriesTable(attachedDatabase, alias);
  }
}

class PlaylistEntryRow extends DataClass
    implements Insertable<PlaylistEntryRow> {
  final int id;
  final int playlistId;
  final int trackId;
  final int position;
  final DateTime addedAt;
  const PlaylistEntryRow({
    required this.id,
    required this.playlistId,
    required this.trackId,
    required this.position,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['track_id'] = Variable<int>(trackId);
    map['position'] = Variable<int>(position);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  PlaylistEntriesCompanion toCompanion(bool nullToAbsent) {
    return PlaylistEntriesCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      trackId: Value(trackId),
      position: Value(position),
      addedAt: Value(addedAt),
    );
  }

  factory PlaylistEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistEntryRow(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      trackId: serializer.fromJson<int>(json['trackId']),
      position: serializer.fromJson<int>(json['position']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'trackId': serializer.toJson<int>(trackId),
      'position': serializer.toJson<int>(position),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  PlaylistEntryRow copyWith({
    int? id,
    int? playlistId,
    int? trackId,
    int? position,
    DateTime? addedAt,
  }) => PlaylistEntryRow(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    trackId: trackId ?? this.trackId,
    position: position ?? this.position,
    addedAt: addedAt ?? this.addedAt,
  );
  PlaylistEntryRow copyWithCompanion(PlaylistEntriesCompanion data) {
    return PlaylistEntryRow(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      position: data.position.present ? data.position.value : this.position,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistEntryRow(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, playlistId, trackId, position, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistEntryRow &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.trackId == this.trackId &&
          other.position == this.position &&
          other.addedAt == this.addedAt);
}

class PlaylistEntriesCompanion extends UpdateCompanion<PlaylistEntryRow> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<int> trackId;
  final Value<int> position;
  final Value<DateTime> addedAt;
  const PlaylistEntriesCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.position = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  PlaylistEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required int trackId,
    required int position,
    required DateTime addedAt,
  }) : playlistId = Value(playlistId),
       trackId = Value(trackId),
       position = Value(position),
       addedAt = Value(addedAt);
  static Insertable<PlaylistEntryRow> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<int>? trackId,
    Expression<int>? position,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (trackId != null) 'track_id': trackId,
      if (position != null) 'position': position,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  PlaylistEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<int>? trackId,
    Value<int>? position,
    Value<DateTime>? addedAt,
  }) {
    return PlaylistEntriesCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      trackId: trackId ?? this.trackId,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistEntriesCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(AppSettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ListeningEventsTable extends ListeningEvents
    with TableInfo<$ListeningEventsTable, ListeningEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListeningEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listenedMsMeta = const VerificationMeta(
    'listenedMs',
  );
  @override
  late final GeneratedColumn<int> listenedMs = GeneratedColumn<int>(
    'listened_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endReasonMeta = const VerificationMeta(
    'endReason',
  );
  @override
  late final GeneratedColumn<String> endReason = GeneratedColumn<String>(
    'end_reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackId,
    startedAt,
    listenedMs,
    durationMs,
    endReason,
    mode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'listening_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ListeningEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('listened_ms')) {
      context.handle(
        _listenedMsMeta,
        listenedMs.isAcceptableOrUnknown(data['listened_ms']!, _listenedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_listenedMsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('end_reason')) {
      context.handle(
        _endReasonMeta,
        endReason.isAcceptableOrUnknown(data['end_reason']!, _endReasonMeta),
      );
    } else if (isInserting) {
      context.missing(_endReasonMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ListeningEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListeningEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      listenedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}listened_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      endReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_reason'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
    );
  }

  @override
  $ListeningEventsTable createAlias(String alias) {
    return $ListeningEventsTable(attachedDatabase, alias);
  }
}

class ListeningEventRow extends DataClass
    implements Insertable<ListeningEventRow> {
  final int id;
  final int trackId;
  final DateTime startedAt;

  /// How far the track was played (position when it ended).
  final int listenedMs;
  final int? durationMs;

  /// completed / skipped / stopped ([EndReason] name).
  final String endReason;

  /// library / wave ([PlayContext] name).
  final String mode;
  const ListeningEventRow({
    required this.id,
    required this.trackId,
    required this.startedAt,
    required this.listenedMs,
    this.durationMs,
    required this.endReason,
    required this.mode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['track_id'] = Variable<int>(trackId);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['listened_ms'] = Variable<int>(listenedMs);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['end_reason'] = Variable<String>(endReason);
    map['mode'] = Variable<String>(mode);
    return map;
  }

  ListeningEventsCompanion toCompanion(bool nullToAbsent) {
    return ListeningEventsCompanion(
      id: Value(id),
      trackId: Value(trackId),
      startedAt: Value(startedAt),
      listenedMs: Value(listenedMs),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      endReason: Value(endReason),
      mode: Value(mode),
    );
  }

  factory ListeningEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListeningEventRow(
      id: serializer.fromJson<int>(json['id']),
      trackId: serializer.fromJson<int>(json['trackId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      listenedMs: serializer.fromJson<int>(json['listenedMs']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      endReason: serializer.fromJson<String>(json['endReason']),
      mode: serializer.fromJson<String>(json['mode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackId': serializer.toJson<int>(trackId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'listenedMs': serializer.toJson<int>(listenedMs),
      'durationMs': serializer.toJson<int?>(durationMs),
      'endReason': serializer.toJson<String>(endReason),
      'mode': serializer.toJson<String>(mode),
    };
  }

  ListeningEventRow copyWith({
    int? id,
    int? trackId,
    DateTime? startedAt,
    int? listenedMs,
    Value<int?> durationMs = const Value.absent(),
    String? endReason,
    String? mode,
  }) => ListeningEventRow(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    startedAt: startedAt ?? this.startedAt,
    listenedMs: listenedMs ?? this.listenedMs,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    endReason: endReason ?? this.endReason,
    mode: mode ?? this.mode,
  );
  ListeningEventRow copyWithCompanion(ListeningEventsCompanion data) {
    return ListeningEventRow(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      listenedMs: data.listenedMs.present
          ? data.listenedMs.value
          : this.listenedMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      endReason: data.endReason.present ? data.endReason.value : this.endReason,
      mode: data.mode.present ? data.mode.value : this.mode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListeningEventRow(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('startedAt: $startedAt, ')
          ..write('listenedMs: $listenedMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('endReason: $endReason, ')
          ..write('mode: $mode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    trackId,
    startedAt,
    listenedMs,
    durationMs,
    endReason,
    mode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListeningEventRow &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.startedAt == this.startedAt &&
          other.listenedMs == this.listenedMs &&
          other.durationMs == this.durationMs &&
          other.endReason == this.endReason &&
          other.mode == this.mode);
}

class ListeningEventsCompanion extends UpdateCompanion<ListeningEventRow> {
  final Value<int> id;
  final Value<int> trackId;
  final Value<DateTime> startedAt;
  final Value<int> listenedMs;
  final Value<int?> durationMs;
  final Value<String> endReason;
  final Value<String> mode;
  const ListeningEventsCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.listenedMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.endReason = const Value.absent(),
    this.mode = const Value.absent(),
  });
  ListeningEventsCompanion.insert({
    this.id = const Value.absent(),
    required int trackId,
    required DateTime startedAt,
    required int listenedMs,
    this.durationMs = const Value.absent(),
    required String endReason,
    required String mode,
  }) : trackId = Value(trackId),
       startedAt = Value(startedAt),
       listenedMs = Value(listenedMs),
       endReason = Value(endReason),
       mode = Value(mode);
  static Insertable<ListeningEventRow> custom({
    Expression<int>? id,
    Expression<int>? trackId,
    Expression<DateTime>? startedAt,
    Expression<int>? listenedMs,
    Expression<int>? durationMs,
    Expression<String>? endReason,
    Expression<String>? mode,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (startedAt != null) 'started_at': startedAt,
      if (listenedMs != null) 'listened_ms': listenedMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (endReason != null) 'end_reason': endReason,
      if (mode != null) 'mode': mode,
    });
  }

  ListeningEventsCompanion copyWith({
    Value<int>? id,
    Value<int>? trackId,
    Value<DateTime>? startedAt,
    Value<int>? listenedMs,
    Value<int?>? durationMs,
    Value<String>? endReason,
    Value<String>? mode,
  }) {
    return ListeningEventsCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      startedAt: startedAt ?? this.startedAt,
      listenedMs: listenedMs ?? this.listenedMs,
      durationMs: durationMs ?? this.durationMs,
      endReason: endReason ?? this.endReason,
      mode: mode ?? this.mode,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (listenedMs.present) {
      map['listened_ms'] = Variable<int>(listenedMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (endReason.present) {
      map['end_reason'] = Variable<String>(endReason.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListeningEventsCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('startedAt: $startedAt, ')
          ..write('listenedMs: $listenedMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('endReason: $endReason, ')
          ..write('mode: $mode')
          ..write(')'))
        .toString();
  }
}

class $TasteItemsTable extends TasteItems
    with TableInfo<$TasteItemsTable, TasteItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasteItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueKeyMeta = const VerificationMeta(
    'valueKey',
  );
  @override
  late final GeneratedColumn<String> valueKey = GeneratedColumn<String>(
    'value_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _excludedMeta = const VerificationMeta(
    'excluded',
  );
  @override
  late final GeneratedColumn<bool> excluded = GeneratedColumn<bool>(
    'excluded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("excluded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    value,
    valueKey,
    weight,
    excluded,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'taste_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<TasteItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('value_key')) {
      context.handle(
        _valueKeyMeta,
        valueKey.isAcceptableOrUnknown(data['value_key']!, _valueKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_valueKeyMeta);
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('excluded')) {
      context.handle(
        _excludedMeta,
        excluded.isAcceptableOrUnknown(data['excluded']!, _excludedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {kind, valueKey},
  ];
  @override
  TasteItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TasteItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      valueKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_key'],
      )!,
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      )!,
      excluded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}excluded'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TasteItemsTable createAlias(String alias) {
    return $TasteItemsTable(attachedDatabase, alias);
  }
}

class TasteItemRow extends DataClass implements Insertable<TasteItemRow> {
  final int id;

  /// genre / artist ([TasteKind] name).
  final String kind;
  final String value;

  /// Lower-cased [value] (one row per kind and value).
  final String valueKey;
  final double weight;

  /// True: never suggest tracks with this genre / artist.
  final bool excluded;
  final DateTime updatedAt;
  const TasteItemRow({
    required this.id,
    required this.kind,
    required this.value,
    required this.valueKey,
    required this.weight,
    required this.excluded,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['value'] = Variable<String>(value);
    map['value_key'] = Variable<String>(valueKey);
    map['weight'] = Variable<double>(weight);
    map['excluded'] = Variable<bool>(excluded);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TasteItemsCompanion toCompanion(bool nullToAbsent) {
    return TasteItemsCompanion(
      id: Value(id),
      kind: Value(kind),
      value: Value(value),
      valueKey: Value(valueKey),
      weight: Value(weight),
      excluded: Value(excluded),
      updatedAt: Value(updatedAt),
    );
  }

  factory TasteItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TasteItemRow(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      value: serializer.fromJson<String>(json['value']),
      valueKey: serializer.fromJson<String>(json['valueKey']),
      weight: serializer.fromJson<double>(json['weight']),
      excluded: serializer.fromJson<bool>(json['excluded']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'value': serializer.toJson<String>(value),
      'valueKey': serializer.toJson<String>(valueKey),
      'weight': serializer.toJson<double>(weight),
      'excluded': serializer.toJson<bool>(excluded),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TasteItemRow copyWith({
    int? id,
    String? kind,
    String? value,
    String? valueKey,
    double? weight,
    bool? excluded,
    DateTime? updatedAt,
  }) => TasteItemRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    value: value ?? this.value,
    valueKey: valueKey ?? this.valueKey,
    weight: weight ?? this.weight,
    excluded: excluded ?? this.excluded,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TasteItemRow copyWithCompanion(TasteItemsCompanion data) {
    return TasteItemRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      value: data.value.present ? data.value.value : this.value,
      valueKey: data.valueKey.present ? data.valueKey.value : this.valueKey,
      weight: data.weight.present ? data.weight.value : this.weight,
      excluded: data.excluded.present ? data.excluded.value : this.excluded,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TasteItemRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('value: $value, ')
          ..write('valueKey: $valueKey, ')
          ..write('weight: $weight, ')
          ..write('excluded: $excluded, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, value, valueKey, weight, excluded, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TasteItemRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.value == this.value &&
          other.valueKey == this.valueKey &&
          other.weight == this.weight &&
          other.excluded == this.excluded &&
          other.updatedAt == this.updatedAt);
}

class TasteItemsCompanion extends UpdateCompanion<TasteItemRow> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> value;
  final Value<String> valueKey;
  final Value<double> weight;
  final Value<bool> excluded;
  final Value<DateTime> updatedAt;
  const TasteItemsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.value = const Value.absent(),
    this.valueKey = const Value.absent(),
    this.weight = const Value.absent(),
    this.excluded = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TasteItemsCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String value,
    required String valueKey,
    this.weight = const Value.absent(),
    this.excluded = const Value.absent(),
    required DateTime updatedAt,
  }) : kind = Value(kind),
       value = Value(value),
       valueKey = Value(valueKey),
       updatedAt = Value(updatedAt);
  static Insertable<TasteItemRow> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? value,
    Expression<String>? valueKey,
    Expression<double>? weight,
    Expression<bool>? excluded,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (value != null) 'value': value,
      if (valueKey != null) 'value_key': valueKey,
      if (weight != null) 'weight': weight,
      if (excluded != null) 'excluded': excluded,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TasteItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String>? value,
    Value<String>? valueKey,
    Value<double>? weight,
    Value<bool>? excluded,
    Value<DateTime>? updatedAt,
  }) {
    return TasteItemsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      value: value ?? this.value,
      valueKey: valueKey ?? this.valueKey,
      weight: weight ?? this.weight,
      excluded: excluded ?? this.excluded,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (valueKey.present) {
      map['value_key'] = Variable<String>(valueKey.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (excluded.present) {
      map['excluded'] = Variable<bool>(excluded.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasteItemsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('value: $value, ')
          ..write('valueKey: $valueKey, ')
          ..write('weight: $weight, ')
          ..write('excluded: $excluded, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LibraryFoldersTable libraryFolders = $LibraryFoldersTable(this);
  late final $TracksTable tracks = $TracksTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistEntriesTable playlistEntries = $PlaylistEntriesTable(
    this,
  );
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $ListeningEventsTable listeningEvents = $ListeningEventsTable(
    this,
  );
  late final $TasteItemsTable tasteItems = $TasteItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    libraryFolders,
    tracks,
    playlists,
    playlistEntries,
    appSettings,
    listeningEvents,
    tasteItems,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tracks', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('listening_events', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$LibraryFoldersTableCreateCompanionBuilder =
    LibraryFoldersCompanion Function({
      Value<int> id,
      required String path,
      required String pathKey,
      required DateTime addedAt,
      Value<DateTime?> lastScanAt,
    });
typedef $$LibraryFoldersTableUpdateCompanionBuilder =
    LibraryFoldersCompanion Function({
      Value<int> id,
      Value<String> path,
      Value<String> pathKey,
      Value<DateTime> addedAt,
      Value<DateTime?> lastScanAt,
    });

final class $$LibraryFoldersTableReferences
    extends BaseReferences<_$AppDatabase, $LibraryFoldersTable, FolderRow> {
  $$LibraryFoldersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$TracksTable, List<TrackRow>> _tracksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tracks,
    aliasName: 'library_folders__id__tracks__folder_id',
  );

  $$TracksTableProcessedTableManager get tracksRefs {
    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibraryFoldersTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pathKey => $composableBuilder(
    column: $table.pathKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tracksRefs(
    Expression<bool> Function($$TracksTableFilterComposer f) f,
  ) {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryFoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pathKey => $composableBuilder(
    column: $table.pathKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryFoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get pathKey =>
      $composableBuilder(column: $table.pathKey, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => column,
  );

  Expression<T> tracksRefs<T extends Object>(
    Expression<T> Function($$TracksTableAnnotationComposer a) f,
  ) {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryFoldersTable,
          FolderRow,
          $$LibraryFoldersTableFilterComposer,
          $$LibraryFoldersTableOrderingComposer,
          $$LibraryFoldersTableAnnotationComposer,
          $$LibraryFoldersTableCreateCompanionBuilder,
          $$LibraryFoldersTableUpdateCompanionBuilder,
          (FolderRow, $$LibraryFoldersTableReferences),
          FolderRow,
          PrefetchHooks Function({bool tracksRefs})
        > {
  $$LibraryFoldersTableTableManager(
    _$AppDatabase db,
    $LibraryFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> pathKey = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> lastScanAt = const Value.absent(),
              }) => LibraryFoldersCompanion(
                id: id,
                path: path,
                pathKey: pathKey,
                addedAt: addedAt,
                lastScanAt: lastScanAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                required String pathKey,
                required DateTime addedAt,
                Value<DateTime?> lastScanAt = const Value.absent(),
              }) => LibraryFoldersCompanion.insert(
                id: id,
                path: path,
                pathKey: pathKey,
                addedAt: addedAt,
                lastScanAt: lastScanAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryFoldersTable, FolderRow>(table),
                  $$LibraryFoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tracksRefs) db.tracks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tracksRefs)
                    await $_getPrefetchedData<
                      FolderRow,
                      $LibraryFoldersTable,
                      TrackRow
                    >(
                      currentTable: table,
                      referencedTable: $$LibraryFoldersTableReferences
                          ._tracksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LibraryFoldersTableReferences(
                            db,
                            table,
                            p0,
                          ).tracksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LibraryFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryFoldersTable,
      FolderRow,
      $$LibraryFoldersTableFilterComposer,
      $$LibraryFoldersTableOrderingComposer,
      $$LibraryFoldersTableAnnotationComposer,
      $$LibraryFoldersTableCreateCompanionBuilder,
      $$LibraryFoldersTableUpdateCompanionBuilder,
      (FolderRow, $$LibraryFoldersTableReferences),
      FolderRow,
      PrefetchHooks Function({bool tracksRefs})
    >;
typedef $$TracksTableCreateCompanionBuilder = TracksCompanion Function({
  Value<int> id,
  Value<String> source,
  required String pathKey,
  required String path,
  Value<int?> folderId,
  required String title,
  required String artist,
  required String album,
  Value<String?> albumArtist,
  Value<String?> genre,
  Value<int?> year,
  Value<int?> trackNumber,
  Value<int?> discNumber,
  Value<int?> durationMs,
  required int fileSize,
  required DateTime fileModified,
  Value<String?> artworkPath,
  required String searchText,
  Value<bool> favorite,
  Value<DateTime?> favoritedAt,
  Value<bool> available,
  Value<String?> problem,
  required DateTime addedAt,
  Value<bool> disliked,
  Value<DateTime?> dislikedAt,
  Value<String?> userTitle,
  Value<String?> pageUrl,
  Value<String?> license,
  Value<String?> licenseUrl,
  Value<DateTime?> metaFetchedAt,
});
typedef $$TracksTableUpdateCompanionBuilder = TracksCompanion Function({
  Value<int> id,
  Value<String> source,
  Value<String> pathKey,
  Value<String> path,
  Value<int?> folderId,
  Value<String> title,
  Value<String> artist,
  Value<String> album,
  Value<String?> albumArtist,
  Value<String?> genre,
  Value<int?> year,
  Value<int?> trackNumber,
  Value<int?> discNumber,
  Value<int?> durationMs,
  Value<int> fileSize,
  Value<DateTime> fileModified,
  Value<String?> artworkPath,
  Value<String> searchText,
  Value<bool> favorite,
  Value<DateTime?> favoritedAt,
  Value<bool> available,
  Value<String?> problem,
  Value<DateTime> addedAt,
  Value<bool> disliked,
  Value<DateTime?> dislikedAt,
  Value<String?> userTitle,
  Value<String?> pageUrl,
  Value<String?> license,
  Value<String?> licenseUrl,
  Value<DateTime?> metaFetchedAt,
});

final class $$TracksTableReferences
    extends BaseReferences<_$AppDatabase, $TracksTable, TrackRow> {
  $$TracksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LibraryFoldersTable _folderIdTable(_$AppDatabase db) =>
      db.libraryFolders.createAlias('tracks__folder_id__library_folders__id');

  $$LibraryFoldersTableProcessedTableManager? get folderId {
    final $_column = $_itemColumn<int>('folder_id');
    if ($_column == null) return null;
    final manager = $$LibraryFoldersTableTableManager(
      $_db,
      $_db.libraryFolders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PlaylistEntriesTable, List<PlaylistEntryRow>>
  _playlistEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistEntries,
    aliasName: 'tracks__id__playlist_entries__track_id',
  );

  $$PlaylistEntriesTableProcessedTableManager get playlistEntriesRefs {
    final manager = $$PlaylistEntriesTableTableManager(
      $_db,
      $_db.playlistEntries,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playlistEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ListeningEventsTable, List<ListeningEventRow>>
  _listeningEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.listeningEvents,
    aliasName: 'tracks__id__listening_events__track_id',
  );

  $$ListeningEventsTableProcessedTableManager get listeningEventsRefs {
    final manager = $$ListeningEventsTableTableManager(
      $_db,
      $_db.listeningEvents,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _listeningEventsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TracksTableFilterComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pathKey => $composableBuilder(
    column: $table.pathKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fileModified => $composableBuilder(
    column: $table.fileModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkPath => $composableBuilder(
    column: $table.artworkPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get available => $composableBuilder(
    column: $table.available,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get problem => $composableBuilder(
    column: $table.problem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get disliked => $composableBuilder(
    column: $table.disliked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dislikedAt => $composableBuilder(
    column: $table.dislikedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userTitle => $composableBuilder(
    column: $table.userTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pageUrl => $composableBuilder(
    column: $table.pageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get license => $composableBuilder(
    column: $table.license,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get licenseUrl => $composableBuilder(
    column: $table.licenseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get metaFetchedAt => $composableBuilder(
    column: $table.metaFetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryFoldersTableFilterComposer get folderId {
    final $$LibraryFoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableFilterComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> playlistEntriesRefs(
    Expression<bool> Function($$PlaylistEntriesTableFilterComposer f) f,
  ) {
    final $$PlaylistEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistEntries,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistEntriesTableFilterComposer(
            $db: $db,
            $table: $db.playlistEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> listeningEventsRefs(
    Expression<bool> Function($$ListeningEventsTableFilterComposer f) f,
  ) {
    final $$ListeningEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.listeningEvents,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ListeningEventsTableFilterComposer(
            $db: $db,
            $table: $db.listeningEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TracksTableOrderingComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pathKey => $composableBuilder(
    column: $table.pathKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fileModified => $composableBuilder(
    column: $table.fileModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkPath => $composableBuilder(
    column: $table.artworkPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get available => $composableBuilder(
    column: $table.available,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get problem => $composableBuilder(
    column: $table.problem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get disliked => $composableBuilder(
    column: $table.disliked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dislikedAt => $composableBuilder(
    column: $table.dislikedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userTitle => $composableBuilder(
    column: $table.userTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pageUrl => $composableBuilder(
    column: $table.pageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get license => $composableBuilder(
    column: $table.license,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get licenseUrl => $composableBuilder(
    column: $table.licenseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get metaFetchedAt => $composableBuilder(
    column: $table.metaFetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryFoldersTableOrderingComposer get folderId {
    final $$LibraryFoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableOrderingComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get pathKey =>
      $composableBuilder(column: $table.pathKey, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<DateTime> get fileModified => $composableBuilder(
    column: $table.fileModified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artworkPath => $composableBuilder(
    column: $table.artworkPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);

  GeneratedColumn<DateTime> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get available =>
      $composableBuilder(column: $table.available, builder: (column) => column);

  GeneratedColumn<String> get problem =>
      $composableBuilder(column: $table.problem, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<bool> get disliked =>
      $composableBuilder(column: $table.disliked, builder: (column) => column);

  GeneratedColumn<DateTime> get dislikedAt => $composableBuilder(
    column: $table.dislikedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userTitle =>
      $composableBuilder(column: $table.userTitle, builder: (column) => column);

  GeneratedColumn<String> get pageUrl =>
      $composableBuilder(column: $table.pageUrl, builder: (column) => column);

  GeneratedColumn<String> get license =>
      $composableBuilder(column: $table.license, builder: (column) => column);

  GeneratedColumn<String> get licenseUrl => $composableBuilder(
    column: $table.licenseUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get metaFetchedAt => $composableBuilder(
    column: $table.metaFetchedAt,
    builder: (column) => column,
  );

  $$LibraryFoldersTableAnnotationComposer get folderId {
    final $$LibraryFoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> playlistEntriesRefs<T extends Object>(
    Expression<T> Function($$PlaylistEntriesTableAnnotationComposer a) f,
  ) {
    final $$PlaylistEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistEntries,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> listeningEventsRefs<T extends Object>(
    Expression<T> Function($$ListeningEventsTableAnnotationComposer a) f,
  ) {
    final $$ListeningEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.listeningEvents,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ListeningEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.listeningEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TracksTable,
          TrackRow,
          $$TracksTableFilterComposer,
          $$TracksTableOrderingComposer,
          $$TracksTableAnnotationComposer,
          $$TracksTableCreateCompanionBuilder,
          $$TracksTableUpdateCompanionBuilder,
          (TrackRow, $$TracksTableReferences),
          TrackRow,
          PrefetchHooks Function({
            bool folderId,
            bool playlistEntriesRefs,
            bool listeningEventsRefs,
          })
        > {
  $$TracksTableTableManager(_$AppDatabase db, $TracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> pathKey = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int?> folderId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<String> album = const Value.absent(),
                Value<String?> albumArtist = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<DateTime> fileModified = const Value.absent(),
                Value<String?> artworkPath = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<DateTime?> favoritedAt = const Value.absent(),
                Value<bool> available = const Value.absent(),
                Value<String?> problem = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<bool> disliked = const Value.absent(),
                Value<DateTime?> dislikedAt = const Value.absent(),
                Value<String?> userTitle = const Value.absent(),
                Value<String?> pageUrl = const Value.absent(),
                Value<String?> license = const Value.absent(),
                Value<String?> licenseUrl = const Value.absent(),
                Value<DateTime?> metaFetchedAt = const Value.absent(),
              }) => TracksCompanion(
                id: id,
                source: source,
                pathKey: pathKey,
                path: path,
                folderId: folderId,
                title: title,
                artist: artist,
                album: album,
                albumArtist: albumArtist,
                genre: genre,
                year: year,
                trackNumber: trackNumber,
                discNumber: discNumber,
                durationMs: durationMs,
                fileSize: fileSize,
                fileModified: fileModified,
                artworkPath: artworkPath,
                searchText: searchText,
                favorite: favorite,
                favoritedAt: favoritedAt,
                available: available,
                problem: problem,
                addedAt: addedAt,
                disliked: disliked,
                dislikedAt: dislikedAt,
                userTitle: userTitle,
                pageUrl: pageUrl,
                license: license,
                licenseUrl: licenseUrl,
                metaFetchedAt: metaFetchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                required String pathKey,
                required String path,
                Value<int?> folderId = const Value.absent(),
                required String title,
                required String artist,
                required String album,
                Value<String?> albumArtist = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                required int fileSize,
                required DateTime fileModified,
                Value<String?> artworkPath = const Value.absent(),
                required String searchText,
                Value<bool> favorite = const Value.absent(),
                Value<DateTime?> favoritedAt = const Value.absent(),
                Value<bool> available = const Value.absent(),
                Value<String?> problem = const Value.absent(),
                required DateTime addedAt,
                Value<bool> disliked = const Value.absent(),
                Value<DateTime?> dislikedAt = const Value.absent(),
                Value<String?> userTitle = const Value.absent(),
                Value<String?> pageUrl = const Value.absent(),
                Value<String?> license = const Value.absent(),
                Value<String?> licenseUrl = const Value.absent(),
                Value<DateTime?> metaFetchedAt = const Value.absent(),
              }) => TracksCompanion.insert(
                id: id,
                source: source,
                pathKey: pathKey,
                path: path,
                folderId: folderId,
                title: title,
                artist: artist,
                album: album,
                albumArtist: albumArtist,
                genre: genre,
                year: year,
                trackNumber: trackNumber,
                discNumber: discNumber,
                durationMs: durationMs,
                fileSize: fileSize,
                fileModified: fileModified,
                artworkPath: artworkPath,
                searchText: searchText,
                favorite: favorite,
                favoritedAt: favoritedAt,
                available: available,
                problem: problem,
                addedAt: addedAt,
                disliked: disliked,
                dislikedAt: dislikedAt,
                userTitle: userTitle,
                pageUrl: pageUrl,
                license: license,
                licenseUrl: licenseUrl,
                metaFetchedAt: metaFetchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TracksTable, TrackRow>(table),
                  $$TracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                folderId = false,
                playlistEntriesRefs = false,
                listeningEventsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playlistEntriesRefs) db.playlistEntries,
                    if (listeningEventsRefs) db.listeningEvents,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (folderId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.folderId,
                            referencedTable: $$TracksTableReferences
                                ._folderIdTable(db),
                            referencedColumn: $$TracksTableReferences
                                ._folderIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playlistEntriesRefs)
                        await $_getPrefetchedData<
                          TrackRow,
                          $TracksTable,
                          PlaylistEntryRow
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._playlistEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (listeningEventsRefs)
                        await $_getPrefetchedData<
                          TrackRow,
                          $TracksTable,
                          ListeningEventRow
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._listeningEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).listeningEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TracksTable,
      TrackRow,
      $$TracksTableFilterComposer,
      $$TracksTableOrderingComposer,
      $$TracksTableAnnotationComposer,
      $$TracksTableCreateCompanionBuilder,
      $$TracksTableUpdateCompanionBuilder,
      (TrackRow, $$TracksTableReferences),
      TrackRow,
      PrefetchHooks Function({
        bool folderId,
        bool playlistEntriesRefs,
        bool listeningEventsRefs,
      })
    >;
typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  required String name,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$PlaylistsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistsTable, PlaylistRow> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistEntriesTable, List<PlaylistEntryRow>>
  _playlistEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistEntries,
    aliasName: 'playlists__id__playlist_entries__playlist_id',
  );

  $$PlaylistEntriesTableProcessedTableManager get playlistEntriesRefs {
    final manager = $$PlaylistEntriesTableTableManager(
      $_db,
      $_db.playlistEntries,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playlistEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistEntriesRefs(
    Expression<bool> Function($$PlaylistEntriesTableFilterComposer f) f,
  ) {
    final $$PlaylistEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistEntries,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistEntriesTableFilterComposer(
            $db: $db,
            $table: $db.playlistEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> playlistEntriesRefs<T extends Object>(
    Expression<T> Function($$PlaylistEntriesTableAnnotationComposer a) f,
  ) {
    final $$PlaylistEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistEntries,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistsTable,
          PlaylistRow,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (PlaylistRow, $$PlaylistsTableReferences),
          PlaylistRow,
          PrefetchHooks Function({bool playlistEntriesRefs})
        > {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistsTable, PlaylistRow>(table),
                  $$PlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistEntriesRefs) db.playlistEntries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistEntriesRefs)
                    await $_getPrefetchedData<
                      PlaylistRow,
                      $PlaylistsTable,
                      PlaylistEntryRow
                    >(
                      currentTable: table,
                      referencedTable: $$PlaylistsTableReferences
                          ._playlistEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlaylistsTableReferences(
                            db,
                            table,
                            p0,
                          ).playlistEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.playlistId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistsTable,
      PlaylistRow,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (PlaylistRow, $$PlaylistsTableReferences),
      PlaylistRow,
      PrefetchHooks Function({bool playlistEntriesRefs})
    >;
typedef $$PlaylistEntriesTableCreateCompanionBuilder =
    PlaylistEntriesCompanion Function({
      Value<int> id,
      required int playlistId,
      required int trackId,
      required int position,
      required DateTime addedAt,
    });
typedef $$PlaylistEntriesTableUpdateCompanionBuilder =
    PlaylistEntriesCompanion Function({
      Value<int> id,
      Value<int> playlistId,
      Value<int> trackId,
      Value<int> position,
      Value<DateTime> addedAt,
    });

final class $$PlaylistEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $PlaylistEntriesTable, PlaylistEntryRow> {
  $$PlaylistEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('playlist_entries__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('playlist_entries__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistEntriesTable,
          PlaylistEntryRow,
          $$PlaylistEntriesTableFilterComposer,
          $$PlaylistEntriesTableOrderingComposer,
          $$PlaylistEntriesTableAnnotationComposer,
          $$PlaylistEntriesTableCreateCompanionBuilder,
          $$PlaylistEntriesTableUpdateCompanionBuilder,
          (PlaylistEntryRow, $$PlaylistEntriesTableReferences),
          PlaylistEntryRow,
          PrefetchHooks Function({bool playlistId, bool trackId})
        > {
  $$PlaylistEntriesTableTableManager(
    _$AppDatabase db,
    $PlaylistEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<int> trackId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => PlaylistEntriesCompanion(
                id: id,
                playlistId: playlistId,
                trackId: trackId,
                position: position,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required int trackId,
                required int position,
                required DateTime addedAt,
              }) => PlaylistEntriesCompanion.insert(
                id: id,
                playlistId: playlistId,
                trackId: trackId,
                position: position,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistEntriesTable, PlaylistEntryRow>(table),
                  $$PlaylistEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false, trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$PlaylistEntriesTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$PlaylistEntriesTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$PlaylistEntriesTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$PlaylistEntriesTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistEntriesTable,
      PlaylistEntryRow,
      $$PlaylistEntriesTableFilterComposer,
      $$PlaylistEntriesTableOrderingComposer,
      $$PlaylistEntriesTableAnnotationComposer,
      $$PlaylistEntriesTableCreateCompanionBuilder,
      $$PlaylistEntriesTableUpdateCompanionBuilder,
      (PlaylistEntryRow, $$PlaylistEntriesTableReferences),
      PlaylistEntryRow,
      PrefetchHooks Function({bool playlistId, bool trackId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          SettingRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      SettingRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        SettingRow,
        BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>,
      ),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$ListeningEventsTableCreateCompanionBuilder =
    ListeningEventsCompanion Function({
      Value<int> id,
      required int trackId,
      required DateTime startedAt,
      required int listenedMs,
      Value<int?> durationMs,
      required String endReason,
      required String mode,
    });
typedef $$ListeningEventsTableUpdateCompanionBuilder =
    ListeningEventsCompanion Function({
      Value<int> id,
      Value<int> trackId,
      Value<DateTime> startedAt,
      Value<int> listenedMs,
      Value<int?> durationMs,
      Value<String> endReason,
      Value<String> mode,
    });

final class $$ListeningEventsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ListeningEventsTable,
          ListeningEventRow
        > {
  $$ListeningEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('listening_events__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ListeningEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ListeningEventsTable> {
  $$ListeningEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endReason => $composableBuilder(
    column: $table.endReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ListeningEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ListeningEventsTable> {
  $$ListeningEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endReason => $composableBuilder(
    column: $table.endReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ListeningEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ListeningEventsTable> {
  $$ListeningEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endReason =>
      $composableBuilder(column: $table.endReason, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ListeningEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ListeningEventsTable,
          ListeningEventRow,
          $$ListeningEventsTableFilterComposer,
          $$ListeningEventsTableOrderingComposer,
          $$ListeningEventsTableAnnotationComposer,
          $$ListeningEventsTableCreateCompanionBuilder,
          $$ListeningEventsTableUpdateCompanionBuilder,
          (ListeningEventRow, $$ListeningEventsTableReferences),
          ListeningEventRow,
          PrefetchHooks Function({bool trackId})
        > {
  $$ListeningEventsTableTableManager(
    _$AppDatabase db,
    $ListeningEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListeningEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListeningEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListeningEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> trackId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> listenedMs = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String> endReason = const Value.absent(),
                Value<String> mode = const Value.absent(),
              }) => ListeningEventsCompanion(
                id: id,
                trackId: trackId,
                startedAt: startedAt,
                listenedMs: listenedMs,
                durationMs: durationMs,
                endReason: endReason,
                mode: mode,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int trackId,
                required DateTime startedAt,
                required int listenedMs,
                Value<int?> durationMs = const Value.absent(),
                required String endReason,
                required String mode,
              }) => ListeningEventsCompanion.insert(
                id: id,
                trackId: trackId,
                startedAt: startedAt,
                listenedMs: listenedMs,
                durationMs: durationMs,
                endReason: endReason,
                mode: mode,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ListeningEventsTable, ListeningEventRow>(table),
                  $$ListeningEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$ListeningEventsTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$ListeningEventsTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ListeningEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ListeningEventsTable,
      ListeningEventRow,
      $$ListeningEventsTableFilterComposer,
      $$ListeningEventsTableOrderingComposer,
      $$ListeningEventsTableAnnotationComposer,
      $$ListeningEventsTableCreateCompanionBuilder,
      $$ListeningEventsTableUpdateCompanionBuilder,
      (ListeningEventRow, $$ListeningEventsTableReferences),
      ListeningEventRow,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$TasteItemsTableCreateCompanionBuilder = TasteItemsCompanion Function({
  Value<int> id,
  required String kind,
  required String value,
  required String valueKey,
  Value<double> weight,
  Value<bool> excluded,
  required DateTime updatedAt,
});
typedef $$TasteItemsTableUpdateCompanionBuilder = TasteItemsCompanion Function({
  Value<int> id,
  Value<String> kind,
  Value<String> value,
  Value<String> valueKey,
  Value<double> weight,
  Value<bool> excluded,
  Value<DateTime> updatedAt,
});

class $$TasteItemsTableFilterComposer
    extends Composer<_$AppDatabase, $TasteItemsTable> {
  $$TasteItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueKey => $composableBuilder(
    column: $table.valueKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get excluded => $composableBuilder(
    column: $table.excluded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TasteItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $TasteItemsTable> {
  $$TasteItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueKey => $composableBuilder(
    column: $table.valueKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get excluded => $composableBuilder(
    column: $table.excluded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TasteItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasteItemsTable> {
  $$TasteItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get valueKey =>
      $composableBuilder(column: $table.valueKey, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<bool> get excluded =>
      $composableBuilder(column: $table.excluded, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TasteItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasteItemsTable,
          TasteItemRow,
          $$TasteItemsTableFilterComposer,
          $$TasteItemsTableOrderingComposer,
          $$TasteItemsTableAnnotationComposer,
          $$TasteItemsTableCreateCompanionBuilder,
          $$TasteItemsTableUpdateCompanionBuilder,
          (
            TasteItemRow,
            BaseReferences<_$AppDatabase, $TasteItemsTable, TasteItemRow>,
          ),
          TasteItemRow,
          PrefetchHooks Function()
        > {
  $$TasteItemsTableTableManager(_$AppDatabase db, $TasteItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasteItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasteItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasteItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> valueKey = const Value.absent(),
                Value<double> weight = const Value.absent(),
                Value<bool> excluded = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TasteItemsCompanion(
                id: id,
                kind: kind,
                value: value,
                valueKey: valueKey,
                weight: weight,
                excluded: excluded,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                required String value,
                required String valueKey,
                Value<double> weight = const Value.absent(),
                Value<bool> excluded = const Value.absent(),
                required DateTime updatedAt,
              }) => TasteItemsCompanion.insert(
                id: id,
                kind: kind,
                value: value,
                valueKey: valueKey,
                weight: weight,
                excluded: excluded,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TasteItemsTable, TasteItemRow>(table),
                  BaseReferences<_$AppDatabase, $TasteItemsTable, TasteItemRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TasteItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasteItemsTable,
      TasteItemRow,
      $$TasteItemsTableFilterComposer,
      $$TasteItemsTableOrderingComposer,
      $$TasteItemsTableAnnotationComposer,
      $$TasteItemsTableCreateCompanionBuilder,
      $$TasteItemsTableUpdateCompanionBuilder,
      (
        TasteItemRow,
        BaseReferences<_$AppDatabase, $TasteItemsTable, TasteItemRow>,
      ),
      TasteItemRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LibraryFoldersTableTableManager get libraryFolders =>
      $$LibraryFoldersTableTableManager(_db, _db.libraryFolders);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistEntriesTableTableManager get playlistEntries =>
      $$PlaylistEntriesTableTableManager(_db, _db.playlistEntries);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$ListeningEventsTableTableManager get listeningEvents =>
      $$ListeningEventsTableTableManager(_db, _db.listeningEvents);
  $$TasteItemsTableTableManager get tasteItems =>
      $$TasteItemsTableTableManager(_db, _db.tasteItems);
}
