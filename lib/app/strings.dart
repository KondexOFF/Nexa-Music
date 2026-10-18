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
  static const String waveChipTooltip =
      'Open NEXA Wave. Personal learning starts in Phase 5.';
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
  static const String mixPreviewNote =
      'Preview of the controls. Not applied to audio until Phase 4.';
  static const String transitions = 'Transitions';
  static const String transitionsInfo =
      'Crossfade overlaps the end of one track with the start of the next. '
      'Gapless removes extra silence without overlap. Smart Mix v1 picks the '
      'transition moment from track length, silence and signal level.';
  static const String modeCrossfade = 'Crossfade';
  static const String modeSmartMix = 'Smart Mix';
  static const String modeGapless = 'Gapless';
  static const String outgoingTrack = 'A. Outgoing track';
  static const String incomingTrack = 'B. Incoming track';
  static const String crossfadeOff = 'Off - no overlap';
  static const String gaplessNote = 'No overlap in Gapless';
  static const String smartMixTitle = 'Smart Mix';
  static const String smartMixDescription =
      'Lets NEXA adjust transition timing using track length, silence and '
      'signal level. Tempo and key matching are not part of v1.';
  static const String smartMixInfo =
      'Smart Mix v1 is planned for Phase 4. It will only use simple, '
      'explainable signals.';

  // Pages
  static const String waveHeading = 'Your Wave starts here';
  static const String waveBody =
      'NEXA Wave will build a continuous personal queue from the tracks you '
      'can play, your likes and dislikes and - only with your consent - your '
      'listening history. It arrives in Phase 5 together with NEXA DNA.';
  static const String discoverHeading = 'Discover online catalogs';
  static const String discoverBody =
      'Audius and Jamendo will be searchable through their official APIs, '
      "respecting each provider's rules. Planned for Phase 6.";
  static const String settingsHeading = 'Settings';
  static const String settingsAbout = 'About';
  static const String settingsAboutBody =
      'NEXA Music - personal Windows music player. Development phase 1: '
      'design system and screen layout.';
  static const String settingsPrivacy = 'Privacy and learning';
  static const String settingsPrivacyBody =
      'Learning pause, history removal and private sessions arrive with '
      'NEXA DNA in Phase 5.';
  static const String settingsMix = 'Mix Engine defaults';
  static const String settingsMixBody =
      'Saved crossfade and gapless defaults arrive in Phase 4.';
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
      'Keyboard media keys (play/pause, next, previous, stop) control NEXA '
      'while it is open, also in the background.';
}
