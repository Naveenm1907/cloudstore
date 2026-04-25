// main.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloudStore',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const FileManagerPage(),
    );
  }
}

class FileManagerPage extends StatefulWidget {
  const FileManagerPage({super.key});

  @override
  State<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage> {
  List<Map<String, dynamic>> _items = [];
  String _currentPath = '';
  bool _loading = false;
  String? _error;
  final Set<String> _unlockedFolders = {};

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  List<String> get _pathSegments {
    if (_currentPath.isEmpty) return [];
    return _currentPath.split('/');
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ApiService.listFiles(_currentPath);
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _navigateTo(String path) {
    setState(() => _currentPath = path);
    _loadFiles();
  }

  Future<bool> _ensureFolderUnlocked(String folderPath) async {
    try {
      if (_unlockedFolders.contains(folderPath)) return true;

      final hasPassword = await ApiService.hasFolderPassword(folderPath);
      if (!hasPassword) return true;

      final password = await _showInputDialog(
        'Folder locked',
        'Enter password to open',
        obscure: true,
      );
      if (password == null || password.trim().isEmpty) return false;

      await ApiService.verifyFolderPassword(folderPath, password.trim());
      _unlockedFolders.add(folderPath);
      return true;
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
      return false;
    }
  }

  Future<void> _openFolder(String folderName) async {
    final newPath =
        _currentPath.isEmpty ? folderName : '$_currentPath/$folderName';
    final ok = await _ensureFolderUnlocked(newPath);
    if (!ok) return;
    _navigateTo(newPath);
  }

  void _goBack() {
    if (_currentPath.isEmpty) return;
    final segments = _pathSegments;
    segments.removeLast();
    _navigateTo(segments.join('/'));
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'mp4', 'zip'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    _showLoading('Uploading...');
    try {
      await ApiService.uploadFile(file, _currentPath);
      if (mounted) Navigator.pop(context);
      _showSnack('File uploaded');
      _loadFiles();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _createFolder() async {
    final name = await _showInputDialog('New Folder', 'Folder name');
    if (name == null || name.trim().isEmpty) return;

    _showLoading('Creating folder...');
    try {
      await ApiService.createFolder(name.trim(), _currentPath);
      if (mounted) Navigator.pop(context);
      _showSnack('Folder created');
      _loadFiles();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _renameItem(Map<String, dynamic> item) async {
    final newName =
        await _showInputDialog('Rename', 'New name', initial: item['name']);
    if (newName == null || newName.trim().isEmpty) return;

    final itemPath = _currentPath.isEmpty
        ? item['name'] as String
        : '$_currentPath/${item['name']}';

    _showLoading('Renaming...');
    try {
      await ApiService.renameItem(itemPath, newName.trim());
      if (mounted) Navigator.pop(context);
      _showSnack('Renamed');
      _loadFiles();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _moveItem(Map<String, dynamic> item) async {
    final dest = await _showInputDialog(
        'Move', 'Destination folder path (empty = root)');
    if (dest == null) return;

    final sourcePath = _currentPath.isEmpty
        ? item['name'] as String
        : '$_currentPath/${item['name']}';

    _showLoading('Moving...');
    try {
      await ApiService.moveItem(sourcePath, dest.trim());
      if (mounted) Navigator.pop(context);
      _showSnack('Moved');
      _loadFiles();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${item['name']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    final itemPath = _currentPath.isEmpty
        ? item['name'] as String
        : '$_currentPath/${item['name']}';

    _showLoading('Deleting...');
    try {
      await ApiService.deleteItem(itemPath);
      if (mounted) Navigator.pop(context);
      _showSnack('Deleted');
      _loadFiles();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _downloadItem(Map<String, dynamic> item) async {
    final filePath = _currentPath.isEmpty
        ? item['name'] as String
        : '$_currentPath/${item['name']}';

    _showLoading('Downloading...');
    try {
      final filename = item['name'] as String;

      if (Platform.isAndroid || Platform.isIOS) {
        final bytes = await ApiService.downloadBytes(filePath);
        final saved = await FilePicker.platform.saveFile(
          dialogTitle: 'Save file',
          fileName: filename,
          bytes: bytes,
        );
        if (mounted) Navigator.pop(context);
        if (saved == null) return;
        _showSnack('Downloaded');
        return;
      }

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save file',
        fileName: filename,
      );
      if (savePath == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      await ApiService.downloadFile(filePath, savePath);
      if (mounted) Navigator.pop(context);
      _showSnack('Downloaded to $savePath');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _viewFile(Map<String, dynamic> item) async {
    final url = item['url']?.toString();
    if (url == null || url.isEmpty) {
      _showSnack('No URL for this file', isError: true);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnack('Invalid file URL', isError: true);
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppFileViewerPage(
          fileName: item['name']?.toString() ?? 'File',
          fileUrl: uri.toString(),
        ),
      ),
    );
  }

  Future<void> _setFolderPassword() async {
    if (_currentPath.isEmpty) {
      _showSnack('Navigate into a folder first', isError: true);
      return;
    }
    final password = await _showInputDialog(
        'Set Password', 'Enter password for this folder',
        obscure: true);
    if (password == null || password.trim().isEmpty) return;

    _showLoading('Setting password...');
    try {
      await ApiService.setFolderPassword(_currentPath, password.trim());
      if (mounted) Navigator.pop(context);
      _showSnack('Password set');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _verifyFolderPassword() async {
    if (_currentPath.isEmpty) {
      _showSnack('Navigate into a folder first', isError: true);
      return;
    }
    final password = await _showInputDialog(
        'Verify Password', 'Enter folder password',
        obscure: true);
    if (password == null || password.trim().isEmpty) return;

    _showLoading('Verifying...');
    try {
      final result =
          await ApiService.verifyFolderPassword(_currentPath, password.trim());
      if (mounted) Navigator.pop(context);
      _unlockedFolders.add(_currentPath);
      final token = result['token']?.toString() ?? '';
      final preview = token.length >= 8 ? token.substring(0, 8) : token;
      _showSnack('Verified${preview.isEmpty ? '' : ' — token: $preview...'}');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _showItemActions(Map<String, dynamic> item) {
    final isFolder = item['type'] == 'folder';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _renameItem(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move),
              title: const Text('Move'),
              onTap: () {
                Navigator.pop(ctx);
                _moveItem(item);
              },
            ),
            if (!isFolder)
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('View in app'),
                onTap: () {
                  Navigator.pop(ctx);
                  _viewFile(item);
                },
              ),
            if (!isFolder)
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Download'),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadItem(item);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title:
                  const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteItem(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showInputDialog(String title, String hint,
      {String? initial, bool obscure = false}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: obscure,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('OK')),
        ],
      ),
    );
  }

  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  IconData _iconForFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' || 'png' => Icons.image,
      'pdf' => Icons.picture_as_pdf,
      'mp4' => Icons.videocam,
      'zip' => Icons.archive,
      _ => Icons.insert_drive_file,
    };
  }

  String _formatSize(dynamic bytes) {
    final b = (bytes is int) ? bytes : int.tryParse(bytes.toString()) ?? 0;
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: _currentPath.isNotEmpty
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack)
            : null,
        title: Text(_currentPath.isEmpty ? 'CloudStore' : _pathSegments.last),
        actions: [
          if (_currentPath.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'set_pw') _setFolderPassword();
                if (v == 'verify_pw') _verifyFolderPassword();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'set_pw', child: Text('Set Password')),
                const PopupMenuItem(
                    value: 'verify_pw', child: Text('Verify Password')),
              ],
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFiles),
        ],
      ),
      body: _buildBody(colors),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'folder',
            onPressed: _createFolder,
            child: const Icon(Icons.create_new_folder),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'upload',
            onPressed: _pickAndUpload,
            child: const Icon(Icons.upload_file),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme colors) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: colors.error)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadFiles,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 64, color: colors.outline),
            const SizedBox(height: 12),
            Text('Empty folder',
                style: TextStyle(color: colors.outline, fontSize: 16)),
          ],
        ),
      );
    }

    final folders =
        _items.where((i) => i['type'] == 'folder').toList();
    final files =
        _items.where((i) => i['type'] == 'file').toList();

    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          if (_currentPath.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '/$_currentPath',
                style: TextStyle(color: colors.outline, fontSize: 13),
              ),
            ),
          ...folders.map((f) => _buildFolderTile(f, colors)),
          if (folders.isNotEmpty && files.isNotEmpty)
            const Divider(height: 1),
          ...files.map((f) => _buildFileTile(f, colors)),
        ],
      ),
    );
  }

  Widget _buildFolderTile(Map<String, dynamic> item, ColorScheme colors) {
    return ListTile(
      leading: Icon(Icons.folder, color: colors.primary, size: 36),
      title: Text(item['name'] as String),
      subtitle: Text(item['created_at'] as String? ?? '',
          style: const TextStyle(fontSize: 12)),
      onTap: () => _openFolder(item['name'] as String),
      onLongPress: () => _showItemActions(item),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showItemActions(item),
      ),
    );
  }

  Widget _buildFileTile(Map<String, dynamic> item, ColorScheme colors) {
    final name = item['name'] as String;
    return ListTile(
      leading: Icon(_iconForFile(name), color: colors.secondary, size: 32),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_formatSize(item['size'])}  •  ${item['created_at'] ?? ''}',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () => _viewFile(item),
      onLongPress: () => _showItemActions(item),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showItemActions(item),
      ),
    );
  }
}

class InAppFileViewerPage extends StatelessWidget {
  const InAppFileViewerPage({
    super.key,
    required this.fileName,
    required this.fileUrl,
  });

  final String fileName;
  final String fileUrl;

  static const Set<String> _imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
  static const Set<String> _videoExts = {'mp4', 'mov', 'mkv', 'webm'};

  String get _ext {
    final parts = fileName.toLowerCase().split('.');
    return parts.length > 1 ? parts.last : '';
  }

  bool get _isImage => _imageExts.contains(_ext);
  bool get _isVideo => _videoExts.contains(_ext);

  String get _viewerUrl {
    // Google Docs Viewer renders PDF/DOC/DOCX/PPT/XLS and many others inline.
    final encoded = Uri.encodeComponent(fileUrl);
    return 'https://docs.google.com/gview?embedded=1&url=$encoded';
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isImage) {
      body = Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.network(
            fileUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Failed to load image',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      );
    } else if (_isVideo) {
      body = _NetworkVideoPlayer(url: fileUrl);
    } else {
      body = _InAppWebViewer(url: _viewerUrl);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: body,
    );
  }
}

class _InAppWebViewer extends StatefulWidget {
  const _InAppWebViewer({required this.url});
  final String url;

  @override
  State<_InAppWebViewer> createState() => _InAppWebViewerState();
}

class _InAppWebViewerState extends State<_InAppWebViewer> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _NetworkVideoPlayer extends StatefulWidget {
  const _NetworkVideoPlayer({required this.url});
  final String url;

  @override
  State<_NetworkVideoPlayer> createState() => _NetworkVideoPlayerState();
}

class _NetworkVideoPlayerState extends State<_NetworkVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                      }
                    });
                  },
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
