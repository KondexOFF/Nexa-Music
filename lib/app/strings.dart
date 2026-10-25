/// All user-visible strings in one place (Master Plan v1.0 §1: English first,
/// stored centrally for a later Russian translation).
abstract final class S {
  static const String appTitle = 'NEXA Music';
  static const String brandNexa = 'NEXA';
  static const String brandMusic = 'MUSIC';

  // Navigation
  static const String navHome = 'Home';
  static const String navWave = 'Wave';
  static const String navDiscover = 'Discover';
  static const String navLibrary = 'Library';
  static const String navSettings = 'Settings';
  static const String navPlaylists = 'Playlists';
  static const String newPlaylist = 'New playlist';
  static const String navBack = 'Back';
  static const String navForward = 'Forward';

  // Availability notes (shown on disabled controls)
  static const String phase2 = 'Phase 2';
  static const String phase3 = 'Phase 3';
  static const String phase4 = 'Phase 4';
  static const String phase5 = 'Phase 5';
  static const String phase6 = 'Phase 6';
  static const String notInV1 = 'Not in v1.0';
  static const String nothingToPlay =
      'Choose a song in your Library to start playback';
  static const String soonLibrary =
      'Demo content - your own songs are on the Library page';
  static const String soonPlaylists =
      'Adding the playing song to a playlist arrives with playback (Phase 3)';
  static const String soonFavorites =
      'Demo song - favorites work for songs in your Library';
  static const String soonWave = 'NEXA Wave arrives in Phase 5';
  static const String soonBrowse =
      'Demo collection - NEXA collections arrive with NEXA Wave (Phase 5)';
  static const String lyricsNotInV1 = 'Lyrics are not part of NEXA Music v1.0';

  // Demo labelling
  static const String demo = 'DEMO';
  static const String demoTooltip =
      'Placeholder content. Your own music is on the Library page; playback '
      'arrives in Phase 3.';
  static const String preview = 'PREVIEW';

  // Top bar
  static const String searchHint = 'Search artists, songs, albums, or moods...';
  static const String greetingMorning = 'Good morning';
  static const String greetingAfternoon = 'Good afternoon';
  static const String greetingEvening = 'Good evening';
  static const String greetingNight = 'Good night';
  static const String greetingSubtitle = 'Personal library';

  // Wave hero
  static const String waveOverline = 'NEXA WAVE';
  static const String waveTitle = 'Your sound, in motion';
  static const String waveSubtitle =
      'A personal mix of familiar favorites and fresh discoveries, shaped by '
      'your listening.';
  static const String playWave = 'Play Wave';
  static const String shuffle = 'Shuffle';
  static const String waveTagFamiliar = 'FAMILIAR';
  static const String waveTagFresh = 'FRESH';
  static const String waveTagYours = 'ALWAYS YOURS';

  // Home sections
  static const String forYourMoment = 'For Your Moment';
  static const String forYourMomentSubtitle =
      'Playlists crafted for your mood, moments and more.';
  static const String seeAll = 'See all';
  static const String recentlyPlayed = 'Recently Played';
  static const String tabAll = 'All';
  static const String tabTracks = 'Tracks';
  static const String tabArtists = 'Artists';
  static const String tabAlbums = 'Albums';
  static const String tabPlaylists = 'Playlists';
  static const String colTitle = 'TITLE';
  static const String colArtist = 'ARTIST';
  static const String colAlbum = 'ALBUM';
  static const String colGenre = 'GENRE';
  static const String colTopTrack = 'TOP TRACK';
  static const String colYear = 'YEAR';
  static const String colPlaylist = 'PLAYLIST';
  static const String colMood = 'MOOD';
  static const String colTracks = 'TRACKS';
  static const String tracksSuffix = 'tracks';
  static const String moreActions = 'More actions';
  static const String like = 'Like';
  static const String play = 'Play';

  // Right panel
  static const String upNext = 'Up Next';
  static const String clear = 'Clear';
  static const String myTaste = 'My Taste';
  static const String myTasteNote = 'Demo values';
  static const String myTasteTooltip =
      'NEXA DNA builds your taste profile in Phase 5, only with your consent.';
  static const String discoverMore = 'Discover More';

  // Player
  static const String nowPlaying = 'NOW PLAYING';
  static const String openNowPlaying = 'Open Now Playing';
  static const String closeNowPlaying = 'Close Now Playing';
  static const String toggleQueue = 'Show or hide Up Next';
  static const String waveChip = 'NEXA Wave';
  static const String waveChipTooltip = 'Open NEXA Wave';
  static const String addToPlaylist = 'Add to playlist';
  static const String shuffleLabel = 'Shuffle';
  static const String previous = 'Previous';
  static const String playPause = 'Play / Pause';
  static const String next = 'Next';
  static const String repeat = 'Repeat';
  static const String volume = 'Volume';
  static const String queueTab = 'Queue';
  static const String lyricsTab = 'Lyrics';
  static const String mixChipTooltip = 'Open NEXA Mix Engine';

  // Mix Engine
  static const String mixEngine = 'NEXA MIX ENGINE';
  static const String mixNote =
      'Applied to playback and saved. Smart Mix v1 uses track length and '
      'albums only; silence and level analysis come later.';
  static const String albumGaplessTitle = 'Keep albums gapless';
  static const String albumGaplessInfo =
      'The next track of the same album always follows without overlap, so '
      'live and continuous albums are never mixed.';
  static const String nextTransition = 'Next transition';
  static const String noNextTrack = 'No next track in the queue';
  // Transition reasons (Mix Engine).
  static const String planNoMixRights = 'Source does not allow mixing';
  static const String planSameAlbum = 'Same album: gapless';
  static const String planGaplessMode = 'Gapless';
  static const String planCrossfadeOff = 'Crossfade off: no overlap';
  static const String planCrossfade = 'Crossfade';
  static const String planSmartDefault = 'Smart Mix: your crossfade length';
  static const String planSmartShortTrack = 'Smart Mix: shorter for a short track';
  static const String planLimitedByLength = 'Limited by track length';
  static const String planTooShort = 'Too short to overlap: gapless';
  static const String transitions = 'Transitions';
  static const String transitionsInfo =
      'Crossfade overlaps the end of one track with the start of the next. '
      'Gapless removes extra silence without overlap. Smart Mix v1 shortens '
      'the overlap for short tracks.';
  static const String modeCrossfade = 'Crossfade';
  static const String modeSmartMix = 'Smart Mix';
  static const String modeGapless = 'Gapless';
  static const String outgoingTrack = 'A. Outgoing track';
  static const String incomingTrack = 'B. Incoming track';
  static const String crossfadeOff = 'Off - no overlap';
  static const String gaplessNote = 'No overlap in Gapless';
  static const String smartMixTitle = 'Smart Mix';
  static const String smartMixDescription =
      'Lets NEXA shorten the overlap for short tracks, based on track '
      'length. Tempo and key matching are not part of v1.';
  static const String smartMixInfo =
      'Smart Mix v1 only uses simple, explainable signals: track length and '
      'album order. It never lengthens your crossfade.';

  // Pages
  static const String waveHeading = 'Your Wave';
  static const String settingsHeading = 'Settings';
  static const String settingsAbout = 'About';
  static const String settingsAboutBody =
      'NEXA Music - personal Windows music player. Local library, playback, '
      'NEXA Mix Engine, NEXA DNA, NEXA Wave, Audius and Jamendo.';
  static const String licences = 'Open-source licences';
  static String versionLine(String version) => 'Version $version';
  static const String settingsPrivacy = 'Privacy and learning';
  static const String settingsPrivacyBody =
      'Your listening history stays on this PC and is only kept with your '
      'consent. Likes, dislikes and NEXA DNA choices always stay local too.';
  static const String settingsMix = 'Mix Engine defaults';
  static const String settingsMixBody =
      'Transition mode, crossfade length and the album rule are saved and '
      'used on every start. Change them in the NEXA Mix Engine panel.';
  static const String settingsDev = 'Developer tools';
  static const String settingsDevBody =
      'Phase 0 audio engine test (media_kit): open a local file and test '
      'play, pause, seek and volume.';
  static const String openAudioTest = 'Open audio engine test';
  static const String plannedFor = 'Planned for';
  // Library (Phase 2)
  static const String libraryTitle = 'Library';
  static const String addFolder = 'Add folder';
  static const String addFiles = 'Add files';
  static const String rescan = 'Rescan';
  static const String rescanTooltip =
      'Look for new, changed and missing files in your library folders';
  static const String tabSongs = 'Songs';
  static const String tabFavorites = 'Favorites';
  static const String tabFolders = 'Folders';
  static const String likedSongs = 'Liked Songs';
  static const String libraryEmptyTitle = 'Your library is empty';
  static const String libraryEmptyBody =
      'Add a folder with MP3, FLAC or WAV files. NEXA reads the files where '
      'they are - nothing is copied, moved or deleted.';
  static const String noResults = 'Nothing in your library matches';
  static const String favoritesEmpty =
      'No favorites yet. Click the heart next to a song.';
  static const String foldersEmpty = 'No folders added yet.';
  static const String removeFolder = 'Remove from library';
  static const String removeFolderBody =
      'The folder and its songs are removed from NEXA (also from playlists). '
      'The files on your disk are not touched.';
  static const String unlike = 'Remove from favorites';
  static const String removeFromPlaylist = 'Remove from playlist';
  static const String moveUp = 'Move up';
  static const String moveDown = 'Move down';
  static const String renamePlaylist = 'Rename';
  static const String deletePlaylist = 'Delete playlist';
  static const String deletePlaylistBody =
      'Only the playlist is deleted. The songs stay in your library.';
  static const String playlistEmpty =
      'This playlist is empty. Add songs from the library with the ... menu.';
  static const String playlistName = 'Playlist name';
  static const String create = 'Create';
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String remove = 'Remove';
  static const String songActions = 'Song actions';
  static const String playlistActions = 'Playlist actions';
  static const String colDuration = 'Time';
  static const String unavailable = 'Unavailable';
  static const String showAll = 'Show all songs';
  static const String scanning = 'Scanning';
  static const String noPlaylists = 'No playlists yet';
  static const String playOnlyPhase3 = 'Playing songs arrives in Phase 3';
  static const String searchLibraryHint = 'Search your library...';
  static const String clearSearch = 'Clear search';

  // Player (Phase 3)
  static const String pause = 'Pause';
  static const String nothingPlaying = 'Nothing playing';
  static const String pickASong = 'Choose a song to play';
  static const String shuffleOn = 'Shuffle: on';
  static const String shuffleOff = 'Shuffle: off';
  static const String repeatOff = 'Repeat: off';
  static const String repeatAll = 'Repeat: all';
  static const String repeatOne = 'Repeat: this song';
  static const String mute = 'Mute';
  static const String unmute = 'Unmute';
  static const String seek = 'Position';
  static const String playAll = 'Play';
  static const String playNext = 'Play next';
  static const String addToQueue = 'Add to queue';
  static const String removeFromQueue = 'Remove from queue';
  static const String queueEmpty =
      'The queue is empty. Play a song or playlist from your Library.';
  static const String goToLibrary = 'Go to Library';
  static const String goToAlbum = 'Go to album';
  static const String goToArtist = 'Go to artist';
  static const String outputDevice = 'Output device';
  static const String outputDeviceBody =
      'Where NEXA plays sound. "System default" follows the Windows setting.';
  static const String mediaKeysBody =
      'Media keys and the Windows media overlay control NEXA, also in the '
      'background. Windows sends the keys to the app that is playing, so '
      'other players keep their media keys.';
  static const String keyboardTitle = 'Keyboard shortcuts';
  static const String keyboardBody =
      'Space: play / pause  -  Ctrl + Right / Left: next / previous  -  '
      'Ctrl + Up / Down: volume  -  Ctrl + M: mute. Tab moves between '
      'controls; Enter or Space activates the focused control.';

  // NEXA DNA and NEXA Wave (Phase 5)
  static const String dislike = 'Dislike';
  static const String undislike = 'Remove dislike';
  static const String dislikeInfo =
      'NEXA Wave will never suggest this song. The file stays in your library.';
  static const String waveOverlineFull = 'NEXA WAVE';
  static const String waveSubtitleLive =
      'A continuous queue from your own playable songs - shaped by your '
      'NEXA DNA, likes and dislikes and, if you allow it, your listening.';
  static const String startWave = 'Start Wave';
  static const String refreshWave = 'New picks';
  static const String waveNextUp = 'Coming up in your Wave';
  static const String waveEmptyLibrary =
      'Add music to your Library first - NEXA Wave only uses songs you can '
      'play.';
  static const String waveNothingLeft =
      'Nothing to suggest: every song is disliked, excluded or unavailable. '
      'Change your NEXA DNA or remove a dislike.';
  static const String wavePlaying = 'Wave is playing';
  static const String familiar = 'Familiar';
  static const String discovery = 'Discovery';
  static const String familiarDiscovery = 'Familiar - Discovery';
  static const String familiarDiscoveryInfo =
      'Left: songs you already know and finish. Right: songs you have not '
      'played yet.';
  static const String fresh = 'NEW';
  static const String privateSession = 'Private session';
  static const String privateSessionInfo =
      'Nothing from this session is added to your listening history. Ends '
      'when NEXA closes.';
  static const String privateSessionOn = 'Private session - not recorded';
  static const String editDna = 'Edit NEXA DNA';
  static const String setUpDna = 'Set up NEXA DNA';
  static const String dnaTitle = 'Your NEXA DNA';
  static const String dnaIntro =
      'Pick a few genres and artists you like. Click again to exclude one '
      '(never suggested), a third time to clear. You can skip this.';
  static const String dnaGenres = 'Genres';
  static const String dnaArtists = 'Artists';
  static const String dnaNoTags =
      'Your library has no genre or artist tags yet.';
  static const String dnaLiked = 'Liked';
  static const String dnaExcluded = 'Excluded';
  static const String skip = 'Skip';
  static const String done = 'Done';
  static const String historyQuestion = 'Remember what I listen to';
  static const String historyQuestionInfo =
      'Keeps a local history (song, time, finished or skipped) on this PC so '
      'the Wave can learn. Nothing is sent anywhere. You can pause or delete '
      'it at any time in Settings.';
  static const String myTasteEmpty =
      'No NEXA DNA yet. Pick genres and artists you like to shape your Wave.';
  static const String myTasteLiked = 'You like';
  static const String myTasteExcluded = 'Never suggest';
  static const String whyThisTrack = 'Why this song';

  // Reasons (why a song is in the Wave)
  static String reasonLikedArtist(String artist) => 'Because you like $artist';
  static String reasonLikedGenre(String genre) => 'Matches your taste: $genre';
  static const String reasonFavorite = 'One of your favorites';
  static const String reasonOftenFinished = 'You usually play this to the end';
  static const String reasonFamiliar = 'A familiar song';
  static const String reasonNew = 'New to you - not played yet';
  static const String reasonFromLibrary = 'From your library';
  static const String reasonRepeat =
      'Played recently - your library has no other match right now';

  // Privacy settings (Phase 5)
  static const String historyConsent = 'Keep listening history';
  static const String historyConsentInfo =
      'Song, time and whether it was finished or skipped - used only by '
      'NEXA Wave on this PC.';
  static const String pauseLearning = 'Pause learning';
  static const String pauseLearningInfo =
      'Stop adding to the history until you switch this off again.';
  static String historyCount(int n) =>
      n == 1 ? '1 listening saved' : '$n listenings saved';
  static const String clearHistory = 'Delete history';
  static const String clearHistoryBody =
      'All saved listenings are deleted from this PC. Likes, dislikes and '
      'NEXA DNA stay.';
  static const String resetDna = 'Reset NEXA DNA';
  static const String resetDnaBody =
      'Removes your genre and artist choices, all dislikes and the '
      'Familiar - Discovery setting. Favorites and history stay.';
  static const String reset = 'Reset';

  // Online catalogs (Phase 6)
  static const String onlineNotSaved =
      'Online catalog songs are not saved in your library in this version';
  static const String onlineNotInLibrary = 'Not part of your library';
  static const String discoverOverline = 'DISCOVER';
  static const String discoverTitle = 'Free music from open catalogs';
  static const String discoverIntro =
      'Search Audius and Jamendo through their official APIs. Every result '
      'shows where it comes from and whether it can be played here. Your '
      'search text is sent to these catalogs; your library and history are '
      'not.';
  static const String discoverSearchHint = 'Search artists, songs or genres';
  static const String search = 'Search';
  static const String allSources = 'All';
  static const String discoverEmpty = 'Search to see results from the catalogs.';
  static const String noCatalogResults = 'No results';
  static const String searching = 'Searching...';
  static const String streamHere = 'Stream in NEXA';
  static const String notPlayableHere = 'Not playable here';
  static const String openPage = 'Open page';
  static String onSource(String source) => 'on $source';
  static String sourceLicense(String license) => 'Licence: $license';
  static const String noMixOnline =
      'Streams only - no crossfade (no right to process the audio)';
  static const String catalogOffline =
      'Cannot reach the catalog. Check the internet connection - your '
      'library keeps working.';
  static const String catalogRateLimited =
      'The catalog asks to slow down. Try again in a minute.';
  static const String catalogProviderError = 'The catalog answered with an error';
  static const String audiusNotConfigured =
      'Audius refused the request (it may now require an API key).';
  static const String jamendoNotConfigured =
      'Jamendo needs your own free client id: create one at '
      'devportal.jamendo.com and enter it in Settings - Online catalogs.';
  static const String jamendoBadKey =
      'Jamendo rejected the client id. Check it in Settings - Online catalogs.';
  static const String openSettings = 'Open Settings';
  static const String catalogDisabled = 'Switched off in Settings';

  // Settings: online catalogs
  static const String settingsCatalogs = 'Online catalogs';
  static const String settingsCatalogsBody =
      'Audius and Jamendo are searched through their official APIs. Songs '
      'are streamed, never downloaded. Keys are stored only on this PC.';
  static const String useAudius = 'Use Audius';
  static const String useAudiusInfo = 'Free, no account or key needed.';
  static const String jamendoClientId = 'Jamendo client id';
  static const String jamendoClientIdInfo =
      'Free for personal, non-commercial use. Create it at '
      'devportal.jamendo.com; it stays on this PC.';
  static const String jamendoTerms = 'Jamendo API terms';
}
