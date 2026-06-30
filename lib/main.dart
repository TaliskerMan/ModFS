import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'ffi.dart';
import 'version.dart';
import 'logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.init();
  AppLogger.log("Application started");
  final prefs = await SharedPreferences.getInstance();
  runApp(ModFSApp(prefs: prefs));
}

/// Resolves the absolute path to the native shared library (`libmodfs_core.so` or `libmodfs_core.dylib`).
///
/// It checks bundle frameworks on macOS, fallback paths, and local development build folders.
String getLibraryPath() {
  final libraryName = Platform.isMacOS ? 'libmodfs_core.dylib' : 'libmodfs_core.so';
  
  // If running on macOS, check if the library is bundled within the App's Frameworks directory.
  if (Platform.isMacOS) {
    final executable = Platform.resolvedExecutable;
    if (executable.contains('.app/Contents/MacOS/')) {
        final frameworksDir = '${File(executable).parent.parent.path}/Frameworks';
        final bundledLib = '$frameworksDir/$libraryName';
        if (File(bundledLib).existsSync()) {
            return bundledLib;
        }
    }
  }

  // Resolve candidate locations without any developer-specific absolute paths.
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final candidates = <String>[
    // Explicit override for packagers / unusual installs.
    if (Platform.environment['MODFS_CORE_LIB'] != null)
      Platform.environment['MODFS_CORE_LIB']!,
    // Next to the executable (e.g. Linux .deb install layout).
    '$exeDir/$libraryName',
    '$exeDir/lib/$libraryName',
    // Linux packaged install prefix.
    '/opt/modfs/lib/$libraryName',
    // Local development build tree (relative to CWD).
    'src/$libraryName',
  ];

  // Search through the potential search paths to locate the native binary file.
  for (final path in candidates) {
    if (path.isNotEmpty && File(path).existsSync()) {
      return File(path).absolute.path;
    }
  }

  // Fall back to the bare name so the dynamic loader can resolve it via the
  // standard search path (rpath / LD_LIBRARY_PATH / DYLD path).
  return libraryName;
}

/// Represents the user's custom preferences including theme and font size.
class AppState {
  /// The selected color theme mode (system, light, or dark).
  final ThemeMode themeMode;

  /// The text scale/font size multiplier.
  final double fontSize;
  
  AppState({required this.themeMode, required this.fontSize});
}

/// The main entry widget for the ModFS application.
class ModFSApp extends StatefulWidget {
  /// Local key-value store for saving user preference configurations.
  final SharedPreferences prefs;
  const ModFSApp({super.key, required this.prefs});

  /// Accesses the nearest ancestor [ModFSAppState] to change app preferences.
  static ModFSAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<ModFSAppState>();

  @override
  State<ModFSApp> createState() => ModFSAppState();
}

/// State for [ModFSApp] managing dynamic updates to theme and font sizes.
class ModFSAppState extends State<ModFSApp> {
  late ThemeMode _themeMode;
  late double _fontSize;

  @override
  void initState() {
    super.initState();
    int themeIndex = widget.prefs.getInt('theme_mode') ?? 0; // 0: system, 1: light, 2: dark
    _themeMode = ThemeMode.values[themeIndex];
    _fontSize = widget.prefs.getDouble('font_size') ?? 14.0;
  }
  
  /// The current font size configuration.
  double get fontSize => _fontSize;

  /// The current theme mode configuration.
  ThemeMode get themeMode => _themeMode;

  /// The shared preference instance cached during initialization.
  SharedPreferences get prefs => widget.prefs;

  /// Updates the application-wide theme and persists the choice to disk.
  void updateTheme(ThemeMode mode) {
    widget.prefs.setInt('theme_mode', mode.index);
    setState(() => _themeMode = mode);
  }

  /// Updates the application-wide font size and persists the choice to disk.
  void updateFontSize(double size) {
    widget.prefs.setDouble('font_size', size);
    setState(() => _fontSize = size);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ModFS',
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F0F5),
        primaryColor: const Color(0xFF635BFF),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF635BFF),
          secondary: Color(0xFF00D1FF),
          surface: Colors.white,
        ),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111116),
        primaryColor: const Color(0xFF635BFF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF635BFF),
          secondary: Color(0xFF00D1FF),
          surface: Color(0xFF1C1C24),
        ),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const SearchScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Represents a file or folder record found in the search result matching the query.
class SearchResult {
  /// The absolute canonical path to the file or directory.
  final String path;

  /// The size of the file in bytes. Defaults to 0 for directories.
  final int size;

  /// The last modified time in seconds (POSIX timestamp) for the file.
  final int mtime;

  /// Indicates if this record represents a directory folder.
  final bool isFolder;

  SearchResult({required this.path, required this.size, required this.mtime, required this.isFolder});

  /// Extracts the filename or directory name from the end of the [path].
  String get name => path.split('/').last;
}

/// The primary UI screen providing file searching capabilities.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

/// Helper function to build a background task closure executed inside an Isolate.
///
/// Prevents main UI thread starvation when loading or scanning the large index.
Future<void> Function() _buildIsolateTask(String libPath, int dbAddr, String dbPath, bool forceScan) {
  // Returns the async closure to execute inside a background worker.
  return () async {
    final isolateModfs = ModFSBindings(libPath);
    final ptr = Pointer<Void>.fromAddress(dbAddr);
    // Scan and write DB to disk if requested, or load cached DB from disk.
    if (forceScan) {
      isolateModfs.scanDatabase(ptr);
      isolateModfs.saveDatabase(ptr, dbPath);
    } else {
      isolateModfs.loadDatabase(ptr, dbPath);
    }
  };
}

class _SearchScreenState extends State<SearchScreen> {
  late ModFSBindings modfs;
  Pointer<Void>? dbPtr;
  final TextEditingController _searchController = TextEditingController();
  final _searchStreamController = StreamController<String>.broadcast();
  final ScrollController _scrollController = ScrollController();
  
  List<SearchResult> _results = [];
  bool _isScanning = false;
  int _totalFiles = 0;
  int _totalFolders = 0;
  String _dbPath = '';
  
  List<String> _includes = ['/'];
  List<String> _excludes = [];

  @override
  void initState() {
    super.initState();
    _initModFS();
    
    _searchController.addListener(() {
      _searchStreamController.add(_searchController.text);
    });
    
    _searchStreamController.stream.distinct().listen((query) {
      _performSearch(query);
    });
  }

  Future<void> _initModFS() async {
    try {
      final prefs = ModFSApp.of(context)!.prefs;
      final defaultHome = Platform.environment['HOME'] ?? '/';
      _includes = prefs.getStringList('include_paths') ?? [defaultHome];
      
      List<String> defaultExcs = ['/proc', '/sys', '/dev', '/run', '/var/run', '/tmp', '/var/tmp', '$defaultHome/.gvfs', '$defaultHome/.cache', '/var/lib/docker'];
      List<String> savedExcs = prefs.getStringList('exclude_paths') ?? [];
      // If excludes have been configured, ensure required default system exclusions are also present.
      if (savedExcs.isNotEmpty) {
        bool changed = false;
        // Verify that critical runtime and system mounts are in the exclusion list.
        for (var d in defaultExcs) {
          if (!savedExcs.contains(d)) {
            savedExcs.add(d);
            changed = true;
          }
        }
        if (changed) prefs.setStringList('exclude_paths', savedExcs);
      }
      _excludes = savedExcs.isEmpty ? defaultExcs : savedExcs;
      
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        // In widget test environment, configure stub totals instead of triggering FFI initialization.
        setState(() {
          _totalFiles = 100;
          _totalFolders = 20;
        });
        return;
      }
      
      final appDir = await getApplicationSupportDirectory();
      if (!appDir.existsSync()) appDir.createSync(recursive: true);
      _dbPath = '${appDir.path}/database.fsearch';

      modfs = ModFSBindings(getLibraryPath());
      _loadOrScanDB();
    } catch (error) {
      AppLogger.log("ModFS Init Error: $error");
    }
  }

  Future<void> _loadOrScanDB({bool forceScan = false}) async {
    setState(() => _isScanning = true);
    
    // Free existing database instance in memory before creating/loading a new one.
    if (dbPtr != null) {
      modfs.freeDatabase(dbPtr!);
      dbPtr = null;
    }

    // Use Isolate.run to execute intensive FFI routines in a background thread to prevent UI freezing
    try {
      dbPtr = modfs.createDatabase(_includes, _excludes, false);
      final dbAddr = dbPtr!.address;
      final dbPathLocal = _dbPath;
      final libPathLocal = getLibraryPath();
      // Choose whether to perform a fresh disk scan or load from cached DB.
      if (forceScan) {
         await Isolate.run(_buildIsolateTask(libPathLocal, dbAddr, dbPathLocal, true));
      } else {
         if (File(_dbPath).existsSync()) {
            await Isolate.run(_buildIsolateTask(libPathLocal, dbAddr, dbPathLocal, false));
         }
      }
    } catch (error) {
      AppLogger.log("Native Error: $error");
    }
    
    // Check if widget state is still active in the widget tree before updating state.
    if (mounted) {
      // Update local state variables to reflect loading is complete and count files.
      setState(() {
        _isScanning = false;
        // Verify database ptr is valid before querying the total number of files/folders.
        if (dbPtr != null) {
           _totalFiles = modfs.getNumFiles(dbPtr!);
           _totalFolders = modfs.getNumFolders(dbPtr!);
        }
      });
      _performSearch(_searchController.text);
    }
  }

  void _rebuildDatabase() {
    _loadOrScanDB(forceScan: true);
  }

  void _performSearch(String query) {
    if (dbPtr == null || _isScanning) return;
    
    final resPtr = modfs.search(dbPtr!, query);
    // Ensure search results pointer from native engine is valid before parsing results.
    if (resPtr != nullptr) {
      final List<SearchResult> newRes = [];
      // Guarantee the native search-result handle is released even if parsing
      // throws — otherwise every failed parse leaks a result set (P2-7).
      try {
        final foldersCount = modfs.getFoldersCount(resPtr);
        final filesCount = modfs.getFilesCount(resPtr);

        final int folderLimit = foldersCount > 200 ? 200 : foldersCount;
        final int fileLimit = filesCount > 500 ? 500 : filesCount;

        // Extract each folder item path and construct the search result object.
        for (int index = 0; index < folderLimit; index++) {
          final path = modfs.getFolderPath(resPtr, index);
          // Verify folder path returned from native FFI is non-null.
          if (path != null) {
            newRes.add(SearchResult(path: path, size: 0, mtime: 0, isFolder: true));
          }
        }
        // Extract each file item path/attributes and construct the search result object.
        for (int fileIndex = 0; fileIndex < fileLimit; fileIndex++) {
          final path = modfs.getFilePath(resPtr, fileIndex);
          // Verify file path returned from native FFI is non-null.
          if (path != null) {
            final size = modfs.getFileSize(resPtr, fileIndex);
            final mtime = modfs.getFileMtime(resPtr, fileIndex);
            newRes.add(SearchResult(path: path, size: size, mtime: mtime, isFolder: false));
          }
        }
      } finally {
        modfs.freeSearchResult(resPtr);
      }
      if (mounted) setState(() => _results = newRes);
    }
  }

  void _openPath(String path) {
    // macOS opener (the supported platform); fall back to xdg-open elsewhere.
    final opener = Platform.isMacOS ? 'open' : 'xdg-open';
    Process.run(opener, [path]).catchError((error) {
      debugPrint("Could not open $path: $error");
      return ProcessResult(0, 1, '', 'Failed to launch');
    });
  }

  void _openContainingFolder(String path) {
    final parentDir = File(path).parent.path;
    _openPath(parentDir);
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen(
        includes: _includes,
        excludes: _excludes,
        onPathsUpdated: (incs, excs) async {
          final prefs = ModFSApp.of(context)!.prefs;
          await prefs.setStringList('include_paths', incs);
          await prefs.setStringList('exclude_paths', excs);
          _includes = incs;
          _excludes = excs;
          _rebuildDatabase();
        },
      )),
    ).then((_) => setState(() {}));
  }

  @override
  void dispose() {
    if (dbPtr != null) modfs.freeDatabase(dbPtr!);
    _searchStreamController.close();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatSize(int bytes) {
    if (bytes == 0) return '';
    double size = bytes.toDouble();
    List<String> suffix = ['B', 'KB', 'MB', 'GB', 'TB'];
    int unitIndex = 0;
    // Scale byte count size down by divisions of 1024 until it fits a human-readable suffix unit.
    while (size > 1024 && unitIndex < suffix.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(1)} ${suffix[unitIndex]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                    ? const [Color(0xFF14141C), Color(0xFF0A0A0F)]
                    : const [Color(0xFFFAFAFA), Color(0xFFE0E0EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(isDark),
                _buildSearchBar(isDark),
                if (_isScanning)
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         const SizedBox(
                           height: 14, width: 14, 
                           child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF635BFF))
                         ),
                         const SizedBox(width: 10),
                         Text(
                           "Indexing Database... This might take a moment", 
                           style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)
                         ),
                       ],
                     ),
                   )
                else
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text(
                           (_totalFiles == 0 && _totalFolders == 0)
                               ? "Create your Index to Search first"
                               : "Indexed: $_totalFiles Files, $_totalFolders Folders",
                           style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)
                         ),
                         TextButton.icon(
                           onPressed: _rebuildDatabase,
                           icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF00D1FF)),
                           label: const Text("Rebuild DB", style: TextStyle(color: Color(0xFF00D1FF), fontSize: 12)),
                         )
                       ],
                     ),
                   ),
                Expanded(
                  child: _buildResultsList(isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 3))
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/modfs.png', fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Text('ModFS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          InkWell(
            onTap: _openSettings,
            borderRadius: BorderRadius.circular(20),
            child: CircleAvatar(
              backgroundColor: isDark ? const Color(0xFF23232D) : Colors.black.withValues(alpha: 0.05),
              radius: 18,
              child: Icon(Icons.settings_outlined, color: isDark ? Colors.white70 : Colors.black54, size: 18),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search files and folders...',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                border: InputBorder.none,
                icon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.black54, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList(bool isDark) {
    if (_results.isEmpty) return const SizedBox.shrink();
    final double fontSize = ModFSApp.of(context)!.fontSize;

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), offset: const Offset(0, 4), blurRadius: 10),
        ],
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        trackVisibility: true,
        radius: const Radius.circular(8),
        thickness: 8,
        child: ListView.separated(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          itemCount: _results.length,
          separatorBuilder: (context, index) => Divider(
            height: 1, 
            thickness: 1, 
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)
          ),
          itemBuilder: (context, index) {
            final res = _results[index];
            return InkWell(
              onTap: () => _openPath(res.path),
              onSecondaryTap: () => _openContainingFolder(res.path),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      res.isFolder ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
                      color: res.isFolder ? const Color(0xFF635BFF) : const Color(0xFF00D1FF),
                      size: fontSize + 6,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            res.name,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: fontSize),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            res.path,
                            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: fontSize * 0.8),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!res.isFolder)
                      Expanded(
                        flex: 1,
                        child: Text(
                          _formatSize(res.size),
                          textAlign: TextAlign.right,
                          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: fontSize * 0.85, fontWeight: FontWeight.w500),
                        ),
                      )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A configuration page where user can customize application appearance preferences and directories.
class SettingsScreen extends StatefulWidget {
  /// The list of target folders currently configured for search scans.
  final List<String> includes;

  /// The list of directories to exclude from search scans.
  final List<String> excludes;

  /// Callback function triggered when directories are added or removed.
  final Function(List<String>, List<String>) onPathsUpdated;
  
  const SettingsScreen({super.key, required this.includes, required this.excludes, required this.onPathsUpdated});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late List<String> _localIncludes;
  late List<String> _localExcludes;
  final _includeController = TextEditingController();
  final _excludeController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _localIncludes = List.from(widget.includes);
    _localExcludes = List.from(widget.excludes);
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _includeController.dispose();
    _excludeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _addInclude() {
    final txt = _includeController.text.trim();
    if (txt.isNotEmpty && !_localIncludes.contains(txt)) {
      setState(() => _localIncludes.add(txt));
      _includeController.clear();
      widget.onPathsUpdated(_localIncludes, _localExcludes);
    }
  }

  void _addExclude() {
    final txt = _excludeController.text.trim();
    if (txt.isNotEmpty && !_localExcludes.contains(txt)) {
      setState(() => _localExcludes.add(txt));
      _excludeController.clear();
      widget.onPathsUpdated(_localIncludes, _localExcludes);
    }
  }

  void _removeInclude(String path) {
    setState(() => _localIncludes.remove(path));
    widget.onPathsUpdated(_localIncludes, _localExcludes);
  }

  void _removeExclude(String path) {
    setState(() => _localExcludes.remove(path));
    widget.onPathsUpdated(_localIncludes, _localExcludes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final modFsApp = ModFSApp.of(context)!;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF14141C) : const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF635BFF),
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          indicatorColor: const Color(0xFF635BFF),
          tabs: const [
            Tab(text: "Preferences"),
            Tab(text: "Include Paths"),
            Tab(text: "Exclude Paths"),
            Tab(text: "About"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPreferencesTab(modFsApp, isDark),
          _buildPathsTab('Included Paths', 'Search targets. Triggers rebuild.', _includeController, _addInclude, _localIncludes, _removeInclude, isDark),
          _buildPathsTab('Excluded Paths', 'Omitted paths. Triggers rebuild. Recommended to keep defaults.', _excludeController, _addExclude, _localExcludes, _removeExclude, isDark, isExcluded: true),
          _buildAboutTab(isDark),
        ],
      ),
    );
  }

  Widget _buildPreferencesTab(ModFSAppState appState, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Appearance", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            title: Text("Theme Mode", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            trailing: DropdownButton<ThemeMode>(
              value: appState.themeMode,
              dropdownColor: isDark ? const Color(0xFF1C1C24) : Colors.white,
              onChanged: (ThemeMode? value) {
                // Ensure dropdown selection value is not null.
                if (value != null) {
                  appState.updateTheme(value);
                  // Refresh UI immediately to reflect selection.
                  setState(() {});
                }
              },
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text("Choose a font size", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButton<double>(
            value: appState.fontSize,
            dropdownColor: isDark ? const Color(0xFF1C1C24) : Colors.white,
            onChanged: (double? value) {
              // Ensure font size dropdown selection value is not null.
              if (value != null) {
                appState.updateFontSize(value);
                // Refresh local UI to render custom fonts using updated size.
                setState(() {});
              }
            },
            items: List.generate(11, (loopIndex) {
              double value = 8.0 + loopIndex;
              return DropdownMenuItem(value: value, child: Text(value.toInt().toString(), style: TextStyle(color: isDark ? Colors.white : Colors.black87)));
            }),
          )
        ],
      ),
    );
  }
  String? _getExclusionReason(String path) {
    if (path == '/proc') return 'Virtual system processes (Prevents crashing/OOM)';
    if (path == '/sys') return 'Hardware configuration states (Prevents loops)';
    if (path == '/dev') return 'Raw device and stream data';
    if (path == '/run' || path == '/var/run') return 'Temporary runtime data';
    if (path == '/tmp' || path == '/var/tmp') return 'Volatile system cache';
    if (path.endsWith('.gvfs')) return 'Network FUSE mounts (Prevents hanging)';
    if (path.endsWith('.cache')) return 'Application cache files (High churn)';
    if (path == '/var/lib/docker') return 'Container overlay snapshots (High churn)';
    return null;
  }

  Widget _buildPathsTab(String title, String sub, TextEditingController ctrl, VoidCallback onAdd, List<String> list, Function(String) onRemove, bool isDark, {bool isExcluded = false}) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(sub, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                 controller: ctrl,
                 style: TextStyle(color: isDark ? Colors.white : Colors.black),
                 decoration: InputDecoration(
                    hintText: "Add absolute path (e.g., /home/user)",
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1C1C24) : Colors.black.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                 ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF635BFF), borderRadius: BorderRadius.circular(12)),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: onAdd,
                )
              )
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(list[index], style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: (isExcluded && _getExclusionReason(list[index]) != null)
                      ? Text(_getExclusionReason(list[index])!, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12))
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    onPressed: () => onRemove(list[index])
                  ),
                );
              }
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAboutTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("About ModFS", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Version: $appVersion", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
          const SizedBox(height: 16),
          Text("ModFS is a modern, high-performance Flutter rebuild of FSearch, the fast file search utility.", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
          const SizedBox(height: 24),
          Text("Copyright & Licensing", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text("ModFS Copyright (C) Chuck Talk\nOriginal FSearch Copyright (C) Christian Boxdörfer", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
          const SizedBox(height: 12),
          Text("ModFS is distributed under the GNU General Public License (GPL) Version 2, maintaining full compliance with the original FSearch licensing terms.", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, height: 1.5)),
          const SizedBox(height: 16),
          SelectableText("Source code is available at: https://github.com/TaliskerMan/ModFS", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
        ],
      ),
    );
  }
}

// Removed _processDB completely
