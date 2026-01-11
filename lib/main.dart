import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'search_delegate.dart';
import 'trash_page.dart';
import 'favorites_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NotesApp());
}

/// ---------------- APP ROOT (THEME) ----------------
class NotesApp extends StatefulWidget {
  const NotesApp({super.key});

  @override
  State<NotesApp> createState() => _NotesAppState();
}

class _NotesAppState extends State<NotesApp> {
  bool _isDarkMode = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool("isDarkMode") ?? false;

    setState(() {
      _isDarkMode = saved;
      _loaded = true;
    });
  }

  Future<void> _toggleTheme() async {
    setState(() => _isDarkMode = !_isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool("isDarkMode", _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.amber,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.amber,
        useMaterial3: true,
      ),
      home: NotesHomePage(isDarkMode: _isDarkMode, onToggleTheme: _toggleTheme),
    );
  }
}

/// ---------------- NOTE MODEL ----------------
class Note {
  String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;
  bool isFavorite;
  bool isLocked;
  int colorValue;
  List<String> tags;
  String folder; // NEW: folder/collection

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
    this.isLocked = false,
    this.colorValue = 0xFFFFFFFF,
    List<String>? tags,
    this.folder = "General",
  }) : tags = tags ?? [];

  factory Note.newNote() {
    final now = DateTime.now();
    return Note(
      id: now.millisecondsSinceEpoch.toString(),
      title: "",
      content: "",
      createdAt: now,
      updatedAt: now,
      isFavorite: false,
      isLocked: false,
      colorValue: 0xFFFFFFFF,
      tags: [],
      folder: "General",
    );
  }

  Note copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    bool? isFavorite,
    bool? isLocked,
    int? colorValue,
    List<String>? tags,
    String? folder,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      isLocked: isLocked ?? this.isLocked,
      colorValue: colorValue ?? this.colorValue,
      tags: tags ?? List<String>.from(this.tags),
      folder: folder ?? this.folder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "title": title,
      "content": content,
      "createdAt": createdAt.toIso8601String(),
      "updatedAt": updatedAt.toIso8601String(),
      "isFavorite": isFavorite,
      "isLocked": isLocked,
      "colorValue": colorValue,
      "tags": tags,
      "folder": folder,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    final rawTags = map["tags"];
    List<String> tags = [];
    if (rawTags is List) {
      tags = rawTags.map((e) => e.toString()).toList();
    }

    return Note(
      id: map["id"],
      title: map["title"] ?? "",
      content: map["content"] ?? "",
      createdAt: DateTime.parse(map["createdAt"]),
      updatedAt: DateTime.parse(map["updatedAt"]),
      isFavorite: map["isFavorite"] ?? false,
      isLocked: map["isLocked"] ?? false,
      colorValue: map["colorValue"] ?? 0xFFFFFFFF,
      tags: tags,
      folder: map["folder"] ?? "General",
    );
  }
}

/// ---------------- REPOSITORY ----------------
class NotesRepository {
  static const _notesKey = "notes";
  static const _trashKey = "trash_notes";
  static const _pinKey = "note_pin";
  static const _foldersKey = "folders"; // NEW

  Future<List<Note>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_notesKey);
    if (jsonString == null || jsonString.isEmpty) return [];

    final list = jsonDecode(jsonString) as List;
    return list.map((e) => Note.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> saveNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(
      _notesKey,
      jsonEncode(notes.map((e) => e.toMap()).toList()),
    );
  }

  Future<List<Note>> loadTrash() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_trashKey);
    if (jsonString == null || jsonString.isEmpty) return [];

    final list = jsonDecode(jsonString) as List;
    return list.map((e) => Note.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> saveTrash(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(
      _trashKey,
      jsonEncode(notes.map((e) => e.toMap()).toList()),
    );
  }

  Future<String?> loadPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey);
  }

  Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_pinKey, pin);
  }

  Future<List<String>> loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_foldersKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    final list = jsonDecode(jsonString) as List;
    return list.map((e) => e.toString()).toList();
  }

  Future<void> saveFolders(List<String> folders) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_foldersKey, jsonEncode(folders));
  }
}

/// ---------------- HOME PAGE ----------------
class NotesHomePage extends StatefulWidget {
  final bool isDarkMode;
  final Future<void> Function() onToggleTheme;

  const NotesHomePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<NotesHomePage> createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> {
  final NotesRepository repo = NotesRepository();

  List<Note> notes = [];
  List<Note> trash = [];
  bool loading = true;

  // sorting & filtering
  String _sortBy = "newest";
  String _filterBy = "none";
  int? _filterColor;
  String? _filterTag;

  // folders
  List<String> _folders = [];
  String? _currentFolder; // null = All Notes

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    notes = await repo.loadNotes();
    trash = await repo.loadTrash();
    _folders = await repo.loadFolders();

    // Ensure folders list includes all folder names used by notes
    for (final n in notes) {
      if (n.folder.isNotEmpty && !_folders.contains(n.folder)) {
        _folders.add(n.folder);
      }
    }
    if (_folders.isEmpty && notes.isNotEmpty) {
      _folders = notes.map((n) => n.folder).toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }

    if (_folders.isEmpty) {
      _folders.add("General");
    }

    await repo.saveFolders(_folders);

    _applySorting();
    setState(() => loading = false);
  }

  /// ---------- TAG HELPERS ----------
  List<String> _allTags() {
    final set = <String>{};
    for (final n in notes) {
      set.addAll(n.tags);
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// ---------- FOLDER HELPERS ----------
  Future<void> _createFolder() async {
    String input = "";

    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("New Folder"),
        content: TextField(
          decoration: const InputDecoration(
            hintText: "e.g. School, Work, Ideas",
          ),
          onChanged: (v) => input = v,
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            child: const Text("Create"),
            onPressed: () {
              final trimmed = input.trim();
              if (trimmed.isNotEmpty) {
                Navigator.pop(context, trimmed);
              }
            },
          ),
        ],
      ),
    );

    if (name != null) {
      setState(() {
        if (!_folders.contains(name)) {
          _folders.add(name);
          _folders.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        }
      });
      await repo.saveFolders(_folders);
    }
  }

  Future<void> _createFolderAndMove(Note note) async {
    String input = "";

    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Move to New Folder"),
        content: TextField(
          decoration: const InputDecoration(hintText: "Folder name"),
          onChanged: (v) => input = v,
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            child: const Text("Move"),
            onPressed: () {
              final trimmed = input.trim();
              if (trimmed.isNotEmpty) {
                Navigator.pop(context, trimmed);
              }
            },
          ),
        ],
      ),
    );

    if (name != null) {
      setState(() {
        if (!_folders.contains(name)) {
          _folders.add(name);
          _folders.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        }
        note.folder = name;
      });
      await repo.saveFolders(_folders);
      await repo.saveNotes(notes);
    }
  }

  void _openMoveToFolder(Note note) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  "Move to folder",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ..._folders.map((folder) {
                return ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(folder),
                  onTap: () async {
                    setState(() {
                      note.folder = folder;
                    });
                    await repo.saveNotes(notes);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
              ListTile(
                leading: const Icon(Icons.create_new_folder),
                title: const Text("New folder"),
                onTap: () {
                  Navigator.pop(context);
                  _createFolderAndMove(note);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// ---------- SORTING & FILTERING ----------
  void _applySorting() {
    switch (_sortBy) {
      case "newest":
        notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case "oldest":
        notes.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case "a-z":
        notes.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case "z-a":
        notes.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
        break;
      case "favorites":
        notes.sort((a, b) {
          if (a.isFavorite == b.isFavorite) {
            return b.updatedAt.compareTo(a.updatedAt);
          }
          return b.isFavorite ? 1 : -1;
        });
        break;
      case "color":
        notes.sort((a, b) => a.colorValue.compareTo(b.colorValue));
        break;
    }
  }

  List<Note> _filteredNotes() {
    List<Note> list = [...notes];

    if (_filterBy == "favorites") {
      list = list.where((n) => n.isFavorite).toList();
    } else if (_filterBy == "locked") {
      list = list.where((n) => n.isLocked).toList();
    } else if (_filterBy == "today") {
      final now = DateTime.now();
      list = list
          .where(
            (n) =>
                n.createdAt.year == now.year &&
                n.createdAt.month == now.month &&
                n.createdAt.day == now.day,
          )
          .toList();
    }

    if (_filterColor != null) {
      list = list.where((n) => n.colorValue == _filterColor).toList();
    }

    if (_filterTag != null && _filterTag!.isNotEmpty) {
      list = list.where((n) => n.tags.contains(_filterTag)).toList();
    }

    if (_currentFolder != null) {
      list = list.where((n) => n.folder == _currentFolder).toList();
    }

    return list;
  }

  void _openSortFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final allTags = _allTags();
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Sort By",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    RadioListTile(
                      title: const Text("Newest"),
                      value: "newest",
                      groupValue: _sortBy,
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() => _sortBy = v);
                        setState(() {
                          _sortBy = v;
                          _applySorting();
                        });
                      },
                    ),
                    RadioListTile(
                      title: const Text("Oldest"),
                      value: "oldest",
                      groupValue: _sortBy,
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() => _sortBy = v);
                        setState(() {
                          _sortBy = v;
                          _applySorting();
                        });
                      },
                    ),
                    RadioListTile(
                      title: const Text("Title A–Z"),
                      value: "a-z",
                      groupValue: _sortBy,
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() => _sortBy = v);
                        setState(() {
                          _sortBy = v;
                          _applySorting();
                        });
                      },
                    ),
                    RadioListTile(
                      title: const Text("Title Z–A"),
                      value: "z-a",
                      groupValue: _sortBy,
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() => _sortBy = v);
                        setState(() {
                          _sortBy = v;
                          _applySorting();
                        });
                      },
                    ),
                    RadioListTile(
                      title: const Text("Favorites first"),
                      value: "favorites",
                      groupValue: _sortBy,
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() => _sortBy = v);
                        setState(() {
                          _sortBy = v;
                          _applySorting();
                        });
                      },
                    ),
                    RadioListTile(
                      title: const Text("Color"),
                      value: "color",
                      groupValue: _sortBy,
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() => _sortBy = v);
                        setState(() {
                          _sortBy = v;
                          _applySorting();
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Filter By",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    RadioListTile(
                      title: const Text("None"),
                      value: "none",
                      groupValue: _filterBy,
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() => _filterBy = v);
                        setState(() {
                          _filterBy = v;
                          _filterColor = null;
                          _filterTag = null;
                        });
                      },
                    ),
                    RadioListTile(
                      title: const Text("Favorites"),
                      value: "favorites",
                      groupValue: _filterBy,
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() => _filterBy = v);
                        setState(() => _filterBy = v);
                      },
                    ),
                    RadioListTile(
                      title: const Text("Locked"),
                      value: "locked",
                      groupValue: _filterBy,
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() => _filterBy = v);
                        setState(() => _filterBy = v);
                      },
                    ),
                    RadioListTile(
                      title: const Text("Today"),
                      value: "today",
                      groupValue: _filterBy,
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() => _filterBy = v);
                        setState(() => _filterBy = v);
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Filter by Color",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [
                        _colorFilterCircle(Colors.white),
                        _colorFilterCircle(Colors.yellow),
                        _colorFilterCircle(Colors.orange),
                        _colorFilterCircle(Colors.pink),
                        _colorFilterCircle(Colors.green),
                        _colorFilterCircle(Colors.blue),
                        _colorFilterCircle(Colors.purple),
                        _colorFilterCircle(Colors.teal),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (allTags.isNotEmpty) ...[
                      const Text(
                        "Filter by Tag",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: allTags.map((tag) {
                          final selected = _filterTag == tag;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _filterTag = selected ? null : tag;
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.amber.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(tag),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _colorFilterCircle(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterBy = "color";
          _filterColor = color.value;
        });
        Navigator.pop(context);
      },
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 1),
        ),
      ),
    );
  }

  /// ---------- PIN & LOCK ----------
  Future<String?> _createPin() async {
    String input = "";

    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create 4-digit PIN"),
        content: TextField(
          maxLength: 4,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(hintText: "Enter PIN"),
          onChanged: (v) => input = v,
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            child: const Text("Save"),
            onPressed: () {
              if (input.length == 4) {
                Navigator.pop(context, input);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _askPin() async {
    final saved = await repo.loadPin();
    if (saved == null) return false;

    String input = "";

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Enter PIN"),
        content: TextField(
          maxLength: 4,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(hintText: "Enter PIN"),
          onChanged: (v) => input = v,
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
          ),
          FilledButton(
            child: const Text("Unlock"),
            onPressed: () => Navigator.pop(context, input == saved),
          ),
        ],
      ),
    );

    return ok ?? false;
  }

  Future<void> _toggleLock(Note note) async {
    final currentPin = await repo.loadPin();

    if (currentPin == null) {
      final newPin = await _createPin();
      if (newPin == null) return;
      await repo.savePin(newPin);
    }

    setState(() => note.isLocked = !note.isLocked);
    repo.saveNotes(notes);
  }

  // ---------- CRUD ----------
  Future<void> _addNote() async {
    final newNote = Note.newNote();
    newNote.folder = _currentFolder ?? "General";

    final result = await Navigator.push<Note>(
      context,
      MaterialPageRoute(
        builder: (_) => EditNotePage(note: newNote, isNew: true),
      ),
    );

    if (result != null) {
      notes.insert(0, result);
      _applySorting();
      repo.saveNotes(notes);

      if (!_folders.contains(result.folder)) {
        _folders.add(result.folder);
        _folders.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        await repo.saveFolders(_folders);
      }

      setState(() {});
    }
  }

  Future<void> _edit(Note note) async {
    final result = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (_) => EditNotePage(note: note, isNew: false)),
    );

    if (result != null) {
      final index = notes.indexWhere((n) => n.id == result.id);
      notes[index] = result;
      _applySorting();
      repo.saveNotes(notes);

      if (!_folders.contains(result.folder)) {
        _folders.add(result.folder);
        _folders.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        await repo.saveFolders(_folders);
      }

      setState(() {});
    }
  }

  Future<void> _moveToTrash(Note note) async {
    notes.removeWhere((n) => n.id == note.id);
    trash.insert(0, note);

    await repo.saveNotes(notes);
    await repo.saveTrash(trash);

    setState(() {});
  }

  Future<void> _restore(Note note) async {
    trash.removeWhere((n) => n.id == note.id);
    notes.insert(0, note);

    await repo.saveTrash(trash);
    await repo.saveNotes(notes);

    setState(() {});
  }

  Future<void> _deleteForever(Note note) async {
    trash.removeWhere((n) => n.id == note.id);
    await repo.saveTrash(trash);
    setState(() {});
  }

  // ---------- NAV HELPERS ----------
  void _openFavoritesPage() {
    final favs = notes.where((n) => n.isFavorite).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FavoritesPage(favorites: favs, onOpen: _edit),
      ),
    );
  }

  void _openTrashPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrashPage(
          trash: trash,
          onRestore: _restore,
          onDeleteForever: _deleteForever,
        ),
      ),
    );
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: ListTile(
          leading: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode),
          title: const Text("Dark Mode"),
          trailing: Switch(
            value: widget.isDarkMode,
            onChanged: (_) {
              Navigator.pop(context);
              widget.onToggleTheme();
            },
          ),
          onTap: () {
            Navigator.pop(context);
            widget.onToggleTheme();
          },
        ),
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final shownNotes = _filteredNotes();
    final allTags = _allTags();

    return Scaffold(
      // LEFT DRAWER
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DrawerHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "My Notes",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text("Quick navigation"),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.notes),
                title: const Text("All Notes"),
                selected: _currentFolder == null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentFolder = null;
                    _filterBy = "none";
                    _filterColor = null;
                    _filterTag = null;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text("Favorites"),
                onTap: () {
                  Navigator.pop(context);
                  _openFavoritesPage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text("Recycle Bin"),
                onTap: () {
                  Navigator.pop(context);
                  _openTrashPage();
                },
              ),
              const Divider(),
              // FOLDERS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Text(
                      "Folders",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.create_new_folder, size: 20),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _createFolder();
                      },
                    ),
                  ],
                ),
              ),
              ..._folders.map((folder) {
                final selected = _currentFolder == folder;
                return ListTile(
                  leading: Icon(
                    Icons.folder,
                    color: selected ? Colors.amber : null,
                  ),
                  title: Text(folder),
                  selected: selected,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentFolder = folder;
                      _filterBy = "none";
                      _filterColor = null;
                      _filterTag = null;
                    });
                  },
                );
              }).toList(),
              const Divider(),
              // LABELS (tags)
              if (allTags.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "Labels",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                ...allTags.map((tag) {
                  final selected = _filterTag == tag;
                  return ListTile(
                    leading: Icon(
                      Icons.label,
                      color: selected ? Colors.amber : null,
                    ),
                    title: Text(tag),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _filterTag = selected ? null : tag;
                        _filterBy = "none";
                      });
                    },
                  );
                }).toList(),
                const Divider(),
              ],
              SwitchListTile(
                secondary: Icon(
                  widget.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                ),
                title: const Text("Dark Mode"),
                value: widget.isDarkMode,
                onChanged: (_) {
                  Navigator.pop(context);
                  widget.onToggleTheme();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text("Settings"),
                onTap: () {
                  Navigator.pop(context);
                  _openSettingsSheet();
                },
              ),
            ],
          ),
        ),
      ),

      appBar: AppBar(
        title: Text(
          _currentFolder == null ? "My Notes" : "My Notes • ${_currentFolder!}",
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: _openFavoritesPage,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: NotesSearchDelegate(notes: notes, onOpen: _edit),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openSortFilterSheet,
          ),
          IconButton(icon: const Icon(Icons.delete), onPressed: _openTrashPage),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettingsSheet,
          ),
        ],
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : shownNotes.isEmpty
          ? const Center(child: Text("No notes yet"))
          : ListView.builder(
              itemCount: shownNotes.length,
              itemBuilder: (_, i) {
                final note = shownNotes[i];

                return Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(note.colorValue),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      note.isLocked
                          ? "🔒 Locked Note"
                          : (note.title.isEmpty ? "(No title)" : note.title),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.isLocked ? "This note is locked" : note.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.folder,
                              size: 14,
                              color: Colors.black.withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              note.folder,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                        if (note.tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 2,
                            children: note.tags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "#$tag",
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            note.isFavorite ? Icons.star : Icons.star_border,
                            color: note.isFavorite ? Colors.amber : null,
                          ),
                          onPressed: () {
                            setState(() {
                              note.isFavorite = !note.isFavorite;
                              _applySorting();
                            });
                            repo.saveNotes(notes);
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            note.isLocked ? Icons.lock : Icons.lock_open,
                            color: note.isLocked ? Colors.red : null,
                          ),
                          onPressed: () => _toggleLock(note),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _moveToTrash(note),
                        ),
                      ],
                    ),
                    onTap: () async {
                      if (note.isLocked) {
                        final ok = await _askPin();
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Incorrect PIN")),
                          );
                          return;
                        }
                      }
                      _edit(note);
                    },
                    onLongPress: () => _openMoveToFolder(note),
                  ),
                );
              },
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// ---------------- EDIT NOTE PAGE ----------------
class EditNotePage extends StatefulWidget {
  final Note note;
  final bool isNew;

  const EditNotePage({super.key, required this.note, required this.isNew});

  @override
  State<EditNotePage> createState() => _EditNotePageState();
}

class _EditNotePageState extends State<EditNotePage> {
  late TextEditingController _title;
  late TextEditingController _content;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note.title);
    _content = TextEditingController(text: widget.note.content);
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.note.copyWith(
      title: _title.text.trim(),
      content: _content.text.trim(),
      updatedAt: DateTime.now(),
      colorValue: widget.note.colorValue,
      tags: List<String>.from(widget.note.tags),
      folder: widget.note.folder,
    );

    Navigator.pop(context, updated);
  }

  // --------- EXPORT AS TEXT ---------
  void _exportAsTxt() {
    final title = _title.text.trim().isEmpty
        ? 'Untitled Note'
        : _title.text.trim();
    final content = _content.text.trim();

    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln()
      ..writeln(content);

    Share.share(buffer.toString(), subject: title);
  }

  // --------- EXPORT AS PDF ---------
  Future<void> _exportAsPdf() async {
    final title = _title.text.trim().isEmpty
        ? 'Untitled Note'
        : _title.text.trim();
    final content = _content.text.trim();

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            pw.Text(content),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${title.replaceAll(" ", "_").toLowerCase()}.pdf',
    );
  }

  Future<void> _addTag() async {
    String input = "";

    final tag = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Tag"),
        content: TextField(
          decoration: const InputDecoration(hintText: "e.g. work, anime, web3"),
          onChanged: (v) => input = v,
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            child: const Text("Add"),
            onPressed: () {
              final trimmed = input.trim();
              if (trimmed.isNotEmpty) {
                Navigator.pop(context, trimmed);
              }
            },
          ),
        ],
      ),
    );

    if (tag != null) {
      setState(() {
        if (!widget.note.tags.contains(tag)) {
          widget.note.tags.add(tag);
        }
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      widget.note.tags.remove(tag);
    });
  }

  Widget _colorCircle(Color color) {
    final selected = widget.note.colorValue == color.value;

    return GestureDetector(
      onTap: () {
        setState(() => widget.note.colorValue = color.value);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Colors.black, width: 2) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tags = widget.note.tags;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? "New Note" : "Edit Note"),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export as text',
            onPressed: _exportAsTxt,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export as PDF',
            onPressed: _exportAsPdf,
          ),
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                hintText: "Title",
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            // COLORS
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _colorCircle(Colors.white),
                  _colorCircle(Colors.yellow),
                  _colorCircle(Colors.orange),
                  _colorCircle(Colors.pink),
                  _colorCircle(Colors.green),
                  _colorCircle(Colors.blue),
                  _colorCircle(Colors.purple),
                  _colorCircle(Colors.teal),
                  _colorCircle(Colors.grey.shade300),
                ],
              ),
            ),

            // FOLDER INFO (read-only hint)
            Row(
              children: [
                const Icon(Icons.folder, size: 16),
                const SizedBox(width: 6),
                Text(
                  "Folder: ${widget.note.folder}",
                  style: const TextStyle(fontSize: 12),
                ),
                const Spacer(),
                const Text(
                  "(Long-press note on home screen to move)",
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // TAGS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Tags",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                TextButton.icon(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add),
                  label: const Text("Add tag"),
                ),
              ],
            ),
            if (tags.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _removeTag(tag),
                  );
                }).toList(),
              ),
            if (tags.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "No tags yet. Tap 'Add tag' to create one.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),

            const Divider(),

            Expanded(
              child: TextField(
                controller: _content,
                decoration: const InputDecoration(
                  hintText: "Start typing...",
                  border: InputBorder.none,
                ),
                keyboardType: TextInputType.multiline,
                maxLines: null,
                expands: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
