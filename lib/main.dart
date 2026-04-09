import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ModFSApp(prefs: prefs));
}

class AppState {
  final ThemeMode themeMode;
  final double fontSize;
  
  AppState({required this.themeMode, required this.fontSize});
}

class ModFSApp extends StatefulWidget {
  final SharedPreferences prefs;
  const ModFSApp({super.key, required this.prefs});

  static _ModFSAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_ModFSAppState>();

  @override
  State<ModFSApp> createState() => _ModFSAppState();
}

class _ModFSAppState extends State<ModFSApp> {
  late ThemeMode _themeMode;
  late double _fontSize;

  @override
  void initState() {
    super.initState();
    int themeIndex = widget.prefs.getInt('theme_mode') ?? 0; // 0: system, 1: light, 2: dark
    _themeMode = ThemeMode.values[themeIndex];
    _fontSize = widget.prefs.getDouble('font_size') ?? 14.0;
  }
  
  double get fontSize => _fontSize;
  ThemeMode get themeMode => _themeMode;
  SharedPreferences get prefs => widget.prefs;

  void updateTheme(ThemeMode mode) {
    widget.prefs.setInt('theme_mode', mode.index);
    setState(() => _themeMode = mode);
  }

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

class SearchResult {
  final String path;
  final int size;
  final int mtime;
  final bool isFolder;

  SearchResult({required this.path, required this.size, required this.mtime, required this.isFolder});
  String get name => path.split('/').last;
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
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
      
      List<String> defaultExcs = ['/proc', '/sys', '/dev', '/run', '/var/run', '/tmp', '/var/tmp', '\$defaultHome/.gvfs', '\$defaultHome/.cache', '/var/lib/docker'];
      List<String> savedExcs = prefs.getStringList('exclude_paths') ?? [];
      if (savedExcs.isNotEmpty) {
        bool changed = false;
        for (var d in defaultExcs) {
          if (!savedExcs.contains(d)) {
            savedExcs.add(d);
            changed = true;
          }
        }
        if (changed) prefs.setStringList('exclude_paths', savedExcs);
      }
      _excludes = savedExcs.isEmpty ? defaultExcs : savedExcs;
      
      final appDir = await getApplicationSupportDirectory();
      if (!appDir.existsSync()) appDir.createSync(recursive: true);
      _dbPath = '\${appDir.path}/database.fsearch';

      modfs = ModFSBindings('/home/freecode/antigrav/ModFS/src/libmodfs_core.so');
      _loadOrScanDB();
    } catch (e) {
      debugPrint("ModFS Init Error: \$e");
    }
  }

  Future<void> _loadOrScanDB({bool forceScan = false}) async {
    setState(() => _isScanning = true);
    
    if (dbPtr != null) {
      modfs.freeDatabase(dbPtr!);
      dbPtr = null;
    }

    // Use Isolate.run to execute intensive FFI routines in a background thread to prevent UI freezing
    try {
      dbPtr = modfs.createDatabase(_includes, _excludes, false);
      final dbAddr = dbPtr!.address;
      final dbPathLocal = _dbPath;
      if (forceScan) {
         await Isolate.run(() {
           final isolateModfs = ModFSBindings('/home/freecode/antigrav/ModFS/src/libmodfs_core.so');
           final ptr = Pointer<Void>.fromAddress(dbAddr);
           isolateModfs.scanDatabase(ptr);
           isolateModfs.saveDatabase(ptr, dbPathLocal);
         });
      } else {
         if (File(_dbPath).existsSync()) {
            await Isolate.run(() {
              final isolateModfs = ModFSBindings('/home/freecode/antigrav/ModFS/src/libmodfs_core.so');
              final ptr = Pointer<Void>.fromAddress(dbAddr);
              isolateModfs.loadDatabase(ptr, dbPathLocal);
            });
         }
      }
    } catch (e) {
      debugPrint("Native Error: \$e");
    }
    
    if (mounted) {
      setState(() {
        _isScanning = false;
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
    if (resPtr != nullptr) {
      final foldersCount = modfs.getFoldersCount(resPtr);
      final filesCount = modfs.getFilesCount(resPtr);
      
      final List<SearchResult> newRes = [];
      final int folderLimit = foldersCount > 200 ? 200 : foldersCount;
      final int fileLimit = filesCount > 500 ? 500 : filesCount;

      for (int i = 0; i < folderLimit; i++) {
        final path = modfs.getFolderPath(resPtr, i);
        if (path != null) {
           newRes.add(SearchResult(path: path, size: 0, mtime: 0, isFolder: true));
        }
      }
      for (int i = 0; i < fileLimit; i++) {
        final path = modfs.getFilePath(resPtr, i);
        if (path != null) {
           final size = modfs.getFileSize(resPtr, i);
           final mtime = modfs.getFileMtime(resPtr, i);
           newRes.add(SearchResult(path: path, size: size, mtime: mtime, isFolder: false));
        }
      }
      
      modfs.freeSearchResult(resPtr);
      if (mounted) setState(() => _results = newRes);
    }
  }

  void _openPath(String path) {
    Process.run('xdg-open', [path]).catchError((e) {
      debugPrint("Could not open \$path: \$e");
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
      MaterialPageRoute(builder: (c) => SettingsScreen(
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
    );
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
    int idx = 0;
    while (size > 1024 && idx < suffix.length - 1) {
      size /= 1024;
      idx++;
    }
    return '\${size.toStringAsFixed(1)} \${suffix[idx]}';
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
                   const Padding(
                     padding: EdgeInsets.all(16.0),
                     child: Text("Indexing / Loading Database...", style: TextStyle(color: Colors.grey)),
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
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 3))
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
              backgroundColor: isDark ? const Color(0xFF23232D) : Colors.black.withOpacity(0.05),
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
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
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
    final double fs = ModFSApp.of(context)!.fontSize;

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), offset: const Offset(0, 4), blurRadius: 10),
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
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)
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
                      size: fs + 6,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            res.name,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: fs),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            res.path,
                            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: fs * 0.8),
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
                          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: fs * 0.85, fontWeight: FontWeight.w500),
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

class SettingsScreen extends StatefulWidget {
  final List<String> includes;
  final List<String> excludes;
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

  Widget _buildPreferencesTab(_ModFSAppState appState, bool isDark) {
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
              onChanged: (ThemeMode? val) {
                if (val != null) appState.updateTheme(val);
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
            onChanged: (double? val) {
              if (val != null) appState.updateFontSize(val);
            },
            items: List.generate(11, (index) {
              double val = 8.0 + index;
              return DropdownMenuItem(value: val, child: Text(val.toInt().toString(), style: TextStyle(color: isDark ? Colors.white : Colors.black87)));
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
                    fillColor: isDark ? const Color(0xFF1C1C24) : Colors.black.withOpacity(0.05),
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
              itemBuilder: (ctx, index) {
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
          const SizedBox(height: 16),
          Text("ModFS is a modern, high-performance Flutter rebuild of FSearch, the fast file search utility.", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
          const SizedBox(height: 24),
          Text("Copyright & Licensing", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text("ModFS Copyright (C) Chuck Talk\nOriginal FSearch Copyright (C) Christian Boxdörfer", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
          const SizedBox(height: 12),
          Text("ModFS is distributed under the GNU General Public License (GPL) Version 2, maintaining full compliance with the original FSearch licensing terms.", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

// Removed _processDB completely
