import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({Key? key}) : super(key: key);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  String? _bookUrl;
  String? _bookFileType;
  String? _bookTitle;
  String? _localFilePath;
  bool _isLoading = true;
  bool _isInitialized = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<String, dynamic>) {
        _bookUrl = args['url'];
        _bookFileType = args['fileType']?.toLowerCase() ?? 'pdf';
        _bookTitle = args['title'] ?? 'Чтение книги';
        _isInitialized = true;
        _loadAndOpenBook();
      }
    }
  }

  Future<void> _loadAndOpenBook() async {
    if (_bookUrl == null || _bookUrl!.isEmpty) {
      setState(() {
        _error = 'Файл книги отсутствует';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = _bookUrl!.split('/').last;
      final localPath = '${appDir.path}/books/$fileName';
      final localFile = File(localPath);

      if (await localFile.exists()) {
        _localFilePath = localPath;
        setState(() => _isLoading = false);
        _openWithExternalApp();
        return;
      }

      final dir = Directory('${appDir.path}/books');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Скачиваем файл
      final response = await http.get(Uri.parse(_bookUrl!));
      
      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        _localFilePath = localPath;
        setState(() => _isLoading = false);
        _openWithExternalApp();
      } else {
        throw Exception('Failed to download: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading book: $e');
      setState(() {
        _error = 'Не удалось загрузить книгу. Проверьте интернет-соединение.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openWithExternalApp() async {
    if (_localFilePath == null) return;
    
    final result = await OpenFile.open(_localFilePath);
    
    if (mounted) {
      if (result.type != ResultType.done) {
        // Не удалось открыть
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось открыть файл. Ошибка: ${result.message}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      // Возвращаемся на предыдущий экран через 1 секунду
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    await _loadAndOpenBook();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _bookTitle ?? 'Чтение книги',
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Вернуться'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Загрузка книги...'),
            SizedBox(height: 8),
            Text('Пожалуйста, подождите', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_localFilePath == null) {
      return const Center(child: Text('Файл не найден'));
    }

    // Показываем информацию и кнопку открытия
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              _bookTitle ?? 'Книга',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _bookFileType?.toUpperCase() ?? 'PDF',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Файл загружен и готов к открытию'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _openWithExternalApp,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Открыть в приложении', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Вернуться'),
            ),
          ],
        ),
      ),
    );
  }
}