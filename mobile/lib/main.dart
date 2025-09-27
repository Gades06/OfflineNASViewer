import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class FileInfo {
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final String? modified;
  final String? mimeType;

  FileInfo({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modified,
    this.mimeType,
  });

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    return FileInfo(
      name: json['name'],
      path: json['path'],
      isDirectory: json['is_directory'],
      size: json['size'],
      modified: json['modified'],
      mimeType: json['mime_type'],
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline NAS Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const FileBrowserPage(),
    );
  }
}

class FileBrowserPage extends StatefulWidget {
  const FileBrowserPage({super.key});

  @override
  State<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends State<FileBrowserPage> {
  List<FileInfo> files = [];
  String currentPath = '';
  bool loading = false;
  String? error;
  String baseUrl = 'http://192.168.1.100:3000'; // Default server IP

  @override
  void initState() {
    super.initState();
    fetchFiles();
  }

  Future<void> fetchFiles([String path = '']) async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/browse?path=${Uri.encodeComponent(path)}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        setState(() {
          files = jsonData.map((json) => FileInfo.fromJson(json)).toList();
          currentPath = path;
          loading = false;
        });
      } else {
        throw Exception('Failed to load files');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  void navigateToPath(String path) {
    fetchFiles(path);
  }

  void goBack() {
    if (currentPath.isNotEmpty) {
      final pathParts = currentPath.split('/').where((part) => part.isNotEmpty).toList();
      if (pathParts.isNotEmpty) {
        pathParts.removeLast();
        final newPath = pathParts.join('/');
        fetchFiles(newPath);
      }
    }
  }

  String formatSize(int? bytes) {
    if (bytes == null) return '-';
    const sizes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size > 1024 && i < sizes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${sizes[i]}';
  }

  void showServerSettingsDialog() {
    String tempUrl = baseUrl;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Server Settings'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Server URL',
            hintText: 'http://192.168.1.100:3000',
          ),
          onChanged: (value) => tempUrl = value,
          controller: TextEditingController(text: baseUrl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                baseUrl = tempUrl;
              });
              Navigator.pop(context);
              fetchFiles(currentPath);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📁 NAS Viewer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: showServerSettingsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                if (currentPath.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: loading ? null : goBack,
                  ),
                Expanded(
                  child: Text(
                    '/$currentPath',
                    style: const TextStyle(fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: $error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => fetchFiles(currentPath),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : files.isEmpty
                        ? const Center(
                            child: Text(
                              'No files or directories found',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: files.length,
                            itemBuilder: (context, index) {
                              final file = files[index];
                              return ListTile(
                                leading: Icon(
                                  file.isDirectory ? Icons.folder : Icons.description,
                                  color: file.isDirectory ? Colors.blue : Colors.grey,
                                  size: 32,
                                ),
                                title: Text(file.name),
                                subtitle: file.isDirectory
                                    ? Text(file.modified ?? '')
                                    : Text(
                                        '${formatSize(file.size)} • ${file.modified ?? ''}',
                                      ),
                                onTap: file.isDirectory
                                    ? () => navigateToPath(file.path)
                                    : null,
                                trailing: file.isDirectory
                                    ? const Icon(Icons.chevron_right)
                                    : null,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
