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
  static const String nothingToPlay =
      'Choose a song in your Library to start playback';

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
      'NEXA Mix Engine, NEXA DNA, NEXA Wave, Audius and Jamendo; YouTube and '
      'SoundCloud in their own official players.';
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
  // Wave's slider is about what you know, not about the Discover page
  // (owner 2026-11-16: do not mix up Discover and NEXA Wave).
  static const String discovery = 'New to you';
  static const String familiarDiscovery = 'Familiar - New to you';
  static const String familiarDiscoveryInfo =
      'How many picks are new to you. Left: only songs you already know. '
      'Right: only new songs - library songs you have not played yet and, '
      'with online picks on, catalog songs. Searching the catalogs is the '
      'Discover page.';
  static const String waveNoNewLeft =
      'Nothing new left to discover - familiar songs fill the Wave. Switch '
      'on online picks or add music to hear new songs.';
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

  // NEXA Wave across catalogs (E1)
  static const String waveOnline = 'Online picks from Audius and Jamendo';
  static const String waveOnlineInfo =
      'Mixes streamed catalog songs into the new songs of your Wave (the '
      'share is yours to set below). Your liked genres and artists are sent to the '
      'catalogs as search words; your listening history and files never '
      'are. Online songs are streamed (never downloaded), crossfaded like '
      'your files, and saved only when you like them or add them to a '
      'playlist; they are not added to your history.';
  static const String waveOnlineNoSource =
      'No online catalog is switched on (Settings - Online catalogs). The '
      'Wave uses your library.';
  static String waveOnlineUnavailable(String why) =>
      'Online picks unavailable: $why The Wave continues with your library.';
  static String waveOnlinePartly(String sources, String why) =>
      'No picks from $sources right now: $why';
  static const String waveOnlineWhyOffline = 'the catalogs cannot be reached.';
  static const String waveOnlineWhyRateLimited =
      'the catalogs ask to slow down.';
  static const String waveOnlineWhyKey =
      'a catalog key is missing or was rejected.';
  static const String waveOnlineWhyError = 'the catalogs answered with an error.';
  static const String waveOnlineShare = 'Library - Online';
  static const String waveOnlineShareInfo =
      'Where the new songs come from. Without online songs (offline, no '
      'catalog) the library fills in.';
  static const String waveShareLibrary = 'Library';
  static const String waveShareOnline = 'Online';
  static String waveOnlineShareValue(double v) =>
      '${(v * 100).round()} % online';
  static String waveOnlineCount(int n) =>
      n == 1 ? '1 online song ready' : '$n online songs ready';
  static String basisPopular(String source) => 'Popular on $source right now';
  static String basisGenre(String source, String genre) =>
      'Popular on $source in $genre';
  static String basisGenres(String source) =>
      'Popular on $source in genres you like';
  static String basisArtist(String source, String artist) =>
      'By $artist, whom you like, on $source';
  static const String hideOnline = 'Not for me';
  static const String hideOnlineInfo =
      'Hidden from your Wave until NEXA closes (online songs are not saved).';
  static String skippedStream(String title) =>
      'Skipped "$title": the stream is not available';
  static const String noPlayableStream = 'No playable song in the queue';

  // E2 YouTube (official embedded player, CR-001 / D-022)
  static const String ytSection = 'YouTube';
  static const String ytPageTitle = 'YouTube video';
  static const String discoverCatalogs = 'Music catalogs';
  static const String ytLinkHint = 'Paste a YouTube link';
  static const String ytWatch = 'Watch';
  static const String ytWatchInNexa = 'Watch in NEXA';
  static const String ytBadLink =
      'This is not a link to one YouTube video (watch, youtu.be, Shorts or '
      'an 11-character video id).';
  static const String ytOpenOnYouTube = 'Open on YouTube';
  static const String ytBack = 'Back';
  static const String ytClosePlayer = 'Close YouTube player';
  static const String ytNothingPlaying =
      'No YouTube video. Paste a link below or search in Discover -> YouTube.';
  static const String ytDockExpand = 'Open the YouTube page';
  static const String ytMiniWindow = 'Mini window on top of other apps';
  static const String ytMiniRestore = 'Back to the full NEXA window';
  static const String ytLive = 'Live';
  static const String ytStarting = 'Starting the YouTube player...';
  static String ytUnavailable(String why) =>
      'The YouTube player cannot run here: $why Use "Open on YouTube".';
  static const String ytApiLoadFailed =
      'Cannot reach YouTube. Check the internet connection - your library '
      'keeps working.';
  static const String ytAutoplayBlocked =
      'Press play in the YouTube player to start the video.';
  static const String ytError2 = 'The link has an invalid video id.';
  static const String ytError5 =
      'This video cannot be played in the embedded player.';
  static const String ytError100 =
      'The video was not found - it was removed or is private.';
  static const String ytErrorNotEmbeddable =
      'This video cannot be played in other apps: its owner does not allow '
      'it, or it is no longer available.';
  static const String ytError153 =
      'YouTube did not accept NEXA\'s app identification (error 153).';
  static String ytErrorOther(int code) => 'YouTube player error $code.';
  static const String ytOverlayTitle = 'YouTube video';
  static const String ytOverlayArtist = 'YouTube';
  static const String ytLimits =
      'YouTube\'s own player with its controls and ads. It pauses when NEXA '
      'is minimised; in other sections of NEXA it stays in the compact '
      'player until you close it, and it never plays together with NEXA. '
      'Nothing you watch is saved: not in the history, NEXA Wave, NEXA DNA '
      'or playlists. YouTube Terms of Service apply.';
  static const String ytTerms = 'YouTube Terms of Service';
  static const String ytGooglePrivacy = 'Google Privacy Policy';
  static const String ytDiscoverOff =
      'YouTube is off. Turn it on in Settings to watch YouTube videos in '
      'NEXA in YouTube\'s own player.';
  static const String ytDiscoverInfo =
      'Videos play in YouTube\'s own player inside NEXA. Pasting a link '
      'needs no key; searching uses your own YouTube Data API key.';
  static const String ytNoKey =
      'To search YouTube, add your own YouTube Data API key in Settings. '
      'Pasting a link works without it.';
  static const String ytSearchHint = 'Search YouTube videos';
  static const String ytQuotaNote =
      'Each search uses 100 of your key\'s 10,000 daily quota units (about '
      '99 searches a day). NEXA searches only when you press Search.';
  static const String ytApiBadKey =
      'YouTube did not accept the API key. Check it in Settings.';
  static const String ytApiDisabled =
      'YouTube Data API v3 is not enabled for this key\'s Google Cloud '
      'project.';
  static const String ytApiQuota =
      'The key\'s daily YouTube quota is used up. Searching works again '
      'after midnight Pacific Time; pasting links still works.';
  static const String ytApiRateLimited =
      'YouTube asks to search less often. Try again in a minute.';
  static const String ytApiOffline =
      'Cannot reach YouTube. Check the internet connection.';
  static const String ytApiProvider = 'YouTube could not answer the search.';
  static const String ytSettingsTitle = 'YouTube';
  static const String ytSettingsBody =
      'Watch YouTube videos inside NEXA in YouTube\'s official player. Off '
      'until you turn it on.';
  static const String ytUse = 'Use YouTube';
  static const String ytUseInfo =
      'Shows the YouTube section in Discover. Turning it on shows what is '
      'shared with YouTube and Google first.';
  static const String ytApiKey = 'YouTube Data API key (optional)';
  static const String ytApiKeyInfo =
      'Only for searching. Create it in your own Google Cloud project and '
      'restrict it to "YouTube Data API v3". Stored only in NEXA\'s database '
      'on this PC - like any key in a desktop app it cannot be perfectly '
      'protected, so do not reuse it elsewhere.';
  static const String ytKeyCheck = 'Check key';
  static const String ytKeyDelete = 'Delete key';
  static const String ytKeyChecking = 'Checking the key...';
  static const String ytKeyOk = 'YouTube accepted the key.';
  static const String ytKeySaved = 'A key is saved.';
  static const String ytKeyNone = 'No key saved.';
  static const String ytKeyHelp = 'How to get a key';
  static const String ytConsentTitle = 'Turn on YouTube?';
  static const List<String> ytConsentPoints = [
    'Videos play in YouTube\'s own player inside NEXA, with YouTube\'s '
        'controls, branding and ads. The YouTube Terms of Service apply.',
    'YouTube (Google) receives what any YouTube player receives: the videos '
        'you open, your IP address and its own cookies in NEXA\'s built-in '
        'web view. The Google Privacy Policy applies.',
    'Searching sends your search words to Google with your own YouTube Data '
        'API key. The key stays in NEXA\'s database on this PC; you can '
        'change or delete it at any time.',
    'NEXA records nothing about what you watch: YouTube is never in your '
        'history, NEXA Wave, NEXA DNA or playlists, and NEXA has no viewing '
        'statistics or tracking - also for videos made for kids.',
    'No background play: a video pauses when NEXA is minimised and stops '
        'when you leave the YouTube page. It never plays together with NEXA.',
  ];
  static const String ytConsentAgree = 'I agree, turn on YouTube';

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

  // E2.7: saved catalog songs and YouTube videos, database safety
  static const String renameSaved = 'Rename';
  static const String deleteSaved = 'Delete saved entry';
  static const String deleteSavedBody =
      'It is removed from your favourites and from every playlist. Nothing '
      'is deleted at the source.';
  static const String ytVideoGone =
      'No longer available on YouTube (removed or private)';
  static const String dbBackupsTitle = 'Library backups';
  static const String dbBackupsBody =
      'Copies of your playlists, favourites, saved videos and history. A '
      'copy is made automatically before NEXA updates the database; the 10 '
      'newest are kept on this PC.';
  static const String dbBackupNow = 'Back up now';
  static const String dbBackupBusy = 'Backing up...';
  static String dbBackupDone(String name) => 'Backup saved: $name';
  static const String dbBackupFailed = 'The backup could not be saved.';
  static const String dbNoBackups = 'No backups yet.';
  static const String dbRestoreAction = 'Restore at next start';
  static const String dbRestoreTitle = 'Restore this backup?';
  static String dbRestoreBody(String copy) =>
      'When NEXA starts next time, the library is replaced by the backup of '
      '$copy. The current library is kept as another backup first.';
  static String dbRestorePending(String copy) =>
      'Will be restored at next start: $copy';
  static const String dbFailedTitle = 'The library could not be opened';
  static const String dbFailedNoCopy =
      'Nothing was changed. Close NEXA and try again; if it happens again, '
      'restore a copy from the backups folder.';
  static String dbFailedRestored(String copy) =>
      'The update of the library failed, so the copy made just before it was '
      'put back ($copy). Your playlists and favourites are as they were.';

  // E2.7b: Recently Played, Continue Listening, YouTube history
  static const String continueListening = 'Continue listening';
  static String continueFrom(String at) => 'Continue from $at';
  static const String recentEmpty =
      'Nothing played yet - songs you listen to show up here.';
  static const String recentOff =
      'Listening history is off, so nothing is kept here. Switch it on in '
      'Settings - Privacy and learning.';
  static String playedWhen(DateTime at, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final days = today.difference(day).inDays;
    String two(int v) => v.toString().padLeft(2, '0');
    final time = '${two(at.hour)}:${two(at.minute)}';
    if (days <= 0) {
      return 'Today $time';
    }
    if (days == 1) {
      return 'Yesterday $time';
    }
    return '${at.year}-${two(at.month)}-${two(at.day)}';
  }

  static const String ytHistory = 'Local YouTube history';
  static const String ytHistoryInfo =
      'Off by default. Keeps videos you watch in NEXA in Recently Played and '
      'Continue listening, on this PC only. Videos made for kids are never '
      'kept: NEXA asks YouTube for this (1 unit of your API quota per '
      'video).';
  static const String ytHistoryNoKey =
      'Without a YouTube API key (Settings - YouTube) NEXA cannot check '
      'this, so no video is kept.';
  static const String ytHistoryClear = 'Delete YouTube history';
  static const String ytHistoryClearBody =
      'Removes the watched YouTube videos from the history. Your songs, '
      'favourites and playlists stay.';

  // E2.8: one queue for all sources
  static String skippedEntry(String title, String why) =>
      'Skipped "$title": $why';
  static const String queueNoExternalPlayer =
      'its player (YouTube / SoundCloud) is not available here';
  static const String queueContinue = 'Continue';
  static const String skipped = 'Skipped';
  static const String queueWaiting =
      'The YouTube / SoundCloud player did not start by itself. Press '
      'Continue.';
  static String queueInExternal(String source) =>
      'Playing in the $source player';
  static const String addedToQueue = 'Added to the queue';

  // E3: SoundCloud (official widget, CR-002)
  static const String scUnnamed = 'SoundCloud track';
  static String scUnavailable(String why) =>
      'SoundCloud cannot be shown here: $why';
  static const String scTrackError =
      'SoundCloud cannot play this track (removed, private or not '
      'available in your region)';
  static const String scApiLoadFailed =
      "SoundCloud's player could not be loaded (offline?)";
  static const String scIntro =
      'Paste a link to a SoundCloud track, playlist or profile. It plays in '
      'SoundCloud\'s own player in NEXA - with the uploader, SoundCloud\'s '
      'branding and its controls; a playlist or profile plays through as one '
      'entry. Like it or add it to a playlist or the queue like any other '
      'song.';
  static const String scLinkHint =
      'https://soundcloud.com/artist/track (or a playlist / profile)';
  static const String scKindTrack = 'SoundCloud';
  static const String scKindSet = 'SoundCloud playlist';
  static const String scKindProfile = 'SoundCloud profile';
  static const String scOpenLink = 'Open link';
  static const String scResolving = 'Looking up the link...';
  // Optional ad blocking in the web players (D-026, Settings - Privacy)
  static const String adBlockTitle =
      'Ad blocking in the YouTube and SoundCloud players';
  static const String adBlockInfo =
      'Optional, off by default: a local uBlock Origin Lite (unpacked '
      'Chromium build, chosen by you - NEXA does not bundle or download it) '
      'in the web players only. Your library, Audius and Jamendo never use '
      'it. Blocking YouTube ads breaks the YouTube API rules (Developer '
      'Policies III.I.05-06); not every ad is blocked, and YouTube may '
      'detect it or stop playing videos. Remove takes it out completely.';
  static const String adBlockWarningTitle = 'Switch on ad blocking?';
  static const String adBlockWarningBody =
      'This is not an officially permitted use of the YouTube player: '
      'blocking ads breaks the YouTube API Services Developer Policies '
      '(III.I.05-06). Your API key or access can be revoked, YouTube may '
      'detect the blocker, and videos may stop playing. NEXA does not '
      'promise that any ad is blocked. Use it only for yourself and switch '
      'it off if YouTube misbehaves.';
  static const String adBlockSwitchOn = 'Switch on';
  static const String adBlockChoose = 'Choose folder';
  static const String adBlockChooseTitle =
      'Folder of the unpacked uBlock Origin Lite (Chromium)';
  static const String adBlockRemove = 'Remove from the players';
  static const String adBlockNoFolder = 'No extension folder chosen.';
  static String adBlockFolder(String path) => 'Extension folder: $path';
  static String adBlockBadFolder(String path) =>
      'Not an unpacked extension (no manifest.json): $path';
  static const String adBlockNextPlayer =
      'Takes effect when the YouTube or SoundCloud player opens next time.';
  static const String adBlockRemoveNext =
      'Removed from the players when one opens next time.';
  static const String adBlockRestart =
      'Restart NEXA to apply: the web players of this run were started '
      'without extension support.';
  static String adBlockRefused(String why) => 'WebView2 refused: $why';
  static const String adBlockRemoved =
      'Removed: the web players run without extensions again.';
  static const String adBlockLoaded =
      'On in the web players. Whether an ad is blocked depends on YouTube.';
  static const String adBlockOff = 'Switched off in the web players.';
  static const String scShortLink =
      'This short link could not be opened (offline, or SoundCloud did not '
      'send the full address). Open it in the browser and paste the full '
      'soundcloud.com address.';
  static const String scNotALink = 'This is not a SoundCloud link.';
  static const String scLimits =
      'No SoundCloud search in this version: the SoundCloud API needs '
      'permitted access. NEXA never downloads, caches or mixes SoundCloud '
      'audio - no crossfade, not in NEXA Wave.';
  static const String scOpenOnSoundCloud = 'Open on SoundCloud';
  static const String scClose = 'Close SoundCloud player';

  // E5: real Home sections instead of DEMO
  static const String yourPlaylists = 'Your playlists';
  static const String yourPlaylistsSubtitle =
      'Liked Songs and the playlists you made - songs, catalog tracks, '
      'YouTube videos and SoundCloud tracks together.';
  static const String openLibrary = 'Open Library';
  static String openOnSource(String source) => 'Open on $source';
  static const String sourcesTitle = 'Sources';
  static const String sourcesBody =
      'Where your music comes from besides your own files.';
  static const String discoverYouTubeTitle = 'YouTube in NEXA';
  static const String discoverSoundCloudTitle = 'SoundCloud in NEXA';
}
