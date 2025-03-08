import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:html/parser.dart' as html_parser;
import 'package:dio/io.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class DownloadProgress {
  final double progress;
  final double speed;
  final String status;

  DownloadProgress({
    required this.progress,
    required this.speed,
    required this.status,
  });
}

// Storage location enum
enum StorageLocation { external, internal }

class DownloadManager {
  final _progressController = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get downloadProgress => _progressController.stream;
  bool _isDownloading = false;
  CancelToken? _cancelToken;
  final Dio _dio = Dio();

  // Get the preferred storage location from SharedPreferences
  Future<StorageLocation> getPreferredStorageLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final isInternal = prefs.getBool('useInternalStorage') ?? false;
    return isInternal ? StorageLocation.internal : StorageLocation.external;
  }

  // Set the preferred storage location
  Future<void> setPreferredStorageLocation(StorageLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      'useInternalStorage',
      location == StorageLocation.internal,
    );
  }

  // Get the appropriate download directory based on storage preference
  Future<Directory?> getDownloadDirectory() async {
    final storageLocation = await getPreferredStorageLocation();

    if (storageLocation == StorageLocation.internal) {
      // Use app's internal documents directory
      return await getApplicationDocumentsDirectory();
    } else {
      // Use external storage directory
      return await getExternalStorageDirectory();
    }
  }

  Future<String?> _extractDownloadLink(String url, String html) async {
    try {
      debugPrint('Extracting download link from HTML content...');
      final document = html_parser.parse(html);
      String? downloadUrl;

      if (url.contains('ddownload.com')) {
        debugPrint('Processing ddownload.com URL...');

        // First try to find direct download link
        final directLink =
            document
                .querySelector('a[href*="/download/"]')
                ?.attributes['href'] ??
            document.querySelector('a.btn_download')?.attributes['href'] ??
            document.querySelector('a[class*="download"]')?.attributes['href'];

        if (directLink != null) {
          debugPrint('Found direct download link: $directLink');
          return directLink.startsWith('http')
              ? directLink
              : 'https://ddownload.com$directLink';
        }

        // If no direct link, try form submission
        final form = document.querySelector('form[name="F1"]');
        if (form != null) {
          debugPrint('Found download form, attempting submission...');
          final inputs = form.querySelectorAll('input');
          final formData = <String, String>{};

          for (var input in inputs) {
            final name = input.attributes['name'];
            final value = input.attributes['value'];
            if (name != null && value != null) {
              formData[name] = value;
              debugPrint('Form field: $name = $value');
            }
          }

          // Add any missing required fields
          if (!formData.containsKey('op')) formData['op'] = 'download2';
          if (!formData.containsKey('id')) {
            final idMatch = RegExp(r'/([^/]+)$').firstMatch(url);
            if (idMatch != null) formData['id'] = idMatch.group(1)!;
          }

          debugPrint('Submitting form with data: $formData');
          final response = await _dio.post(
            url,
            data: FormData.fromMap(formData),
            options: Options(
              headers: {
                ..._dio.options.headers,
                'Origin': 'https://ddownload.com',
                'Referer': url,
                'Content-Type': 'application/x-www-form-urlencoded',
              },
              followRedirects: true,
              validateStatus: (status) => true,
            ),
          );

          debugPrint('Form submission response status: ${response.statusCode}');
          if (response.statusCode == 200) {
            final responseDoc = html_parser.parse(response.data);
            final downloadLink =
                responseDoc
                    .querySelector('a[href*="/download/"]')
                    ?.attributes['href'] ??
                responseDoc
                    .querySelector('a.btn_download')
                    ?.attributes['href'] ??
                responseDoc
                    .querySelector('a[class*="download"]')
                    ?.attributes['href'];

            if (downloadLink != null) {
              debugPrint(
                'Found download link after form submission: $downloadLink',
              );
              return downloadLink.startsWith('http')
                  ? downloadLink
                  : 'https://ddownload.com$downloadLink';
            }
          }
        }
      } else if (url.contains('modsfire.com')) {
        debugPrint('Processing modsfire.com URL...');

        // Try multiple selectors for modsfire.com
        final selectors = [
          'a.download-button',
          'a[href*="/download/"]',
          'a[class*="download"]',
          'a[href*="download"]',
          'a.btn-download',
        ];

        for (final selector in selectors) {
          final element = document.querySelector(selector);
          if (element != null) {
            downloadUrl = element.attributes['href'];
            if (downloadUrl != null) {
              debugPrint(
                'Found modsfire download link with selector $selector: $downloadUrl',
              );
              if (!downloadUrl.startsWith('http')) {
                downloadUrl = 'https://modsfire.com$downloadUrl';
              }
              return downloadUrl;
            }
          }
        }

        // Try to find any link containing 'download'
        final allLinks = document.querySelectorAll('a');
        for (final link in allLinks) {
          final href = link.attributes['href'];
          if (href != null &&
              (href.contains('download') || href.contains('get'))) {
            debugPrint('Found potential modsfire download link: $href');
            return href.startsWith('http') ? href : 'https://modsfire.com$href';
          }
        }
      }

      debugPrint('No download link found in the HTML content');
      return null;
    } catch (e) {
      debugPrint('Error extracting download link: $e');
      return null;
    }
  }

  Future<String?> _getDirectDownloadUrl(String url) async {
    try {
      debugPrint('Getting download page from: $url');

      final response = await _dio.get(
        url,
        options: Options(
          headers: {..._dio.options.headers, 'Referer': url},
          followRedirects: true,
          validateStatus: (status) => true,
        ),
      );

      debugPrint('Response status: ${response.statusCode}');

      // Handle redirects
      if (response.statusCode == 301 || response.statusCode == 302) {
        final location = response.headers.value('location');
        if (location != null) {
          debugPrint('Following redirect to: $location');
          return await _getDirectDownloadUrl(location);
        }
      }

      // Handle successful response
      if (response.statusCode == 200) {
        final downloadUrl = await _extractDownloadLink(url, response.data);
        if (downloadUrl != null) {
          debugPrint('Found download URL: $downloadUrl');
          return downloadUrl;
        }
      }

      // If we get here, try one more time with a different User-Agent
      if (!url.contains('tried_alternate_ua')) {
        debugPrint('Retrying with alternate User-Agent...');
        final alternateUrl =
            '$url${url.contains('?') ? '&' : '?'}tried_alternate_ua=1';
        return await _dio
            .get(
              alternateUrl,
              options: Options(
                headers: {
                  ..._dio.options.headers,
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                  'Referer': url,
                },
                followRedirects: true,
                validateStatus: (status) => true,
              ),
            )
            .then((response) async {
              if (response.statusCode == 200) {
                return await _extractDownloadLink(url, response.data);
              }
              return null;
            });
      }

      debugPrint('Could not find download link after all attempts');
      return null;
    } catch (e) {
      debugPrint('Error getting direct download URL: $e');
      return null;
    }
  }

  Future<String> _getDownloadPath(String fileName) async {
    Directory? directory;

    if (Platform.isAndroid) {
      // Request storage permission
      final status = await Permission.storage.request();
      if (status.isGranted) {
        // Try to get the Downloads directory
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          // Fallback to external storage
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            directory = extDir;
          }
        }
      }
    }

    // Fallback to app's documents directory if needed
    directory ??= await getApplicationDocumentsDirectory();

    // Create downloads directory if it doesn't exist
    final downloadsDir = Directory('${directory.path}/Downloads');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    // Ensure .apk extension
    if (!fileName.toLowerCase().endsWith('.apk')) {
      fileName = '$fileName.apk';
    }

    return '${downloadsDir.path}/$fileName';
  }

  Future<void> downloadFile(String url, String fileName) async {
    if (_isDownloading) {
      _progressController.add(
        DownloadProgress(
          progress: 0,
          speed: 0,
          status: 'Already downloading another file',
        ),
      );
      return;
    }

    _isDownloading = true;
    _cancelToken = CancelToken();

    try {
      // Request storage permission
      if (!kIsWeb) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission denied');
        }
      }

      // Get download directory based on preference
      final downloadDir = await getDownloadDirectory();
      if (downloadDir == null) {
        throw Exception('Could not access download directory');
      }

      // Create Download folder if it doesn't exist
      final saveDir = Directory('${downloadDir.path}/Download');
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // Ensure the filename has .apk extension
      if (!fileName.toLowerCase().endsWith('.apk')) {
        fileName = '$fileName.apk';
      }

      final savePath = '${saveDir.path}/$fileName';
      debugPrint('Downloading to: $savePath');

      // Check if file already exists
      final file = File(savePath);
      if (await file.exists()) {
        // If file exists, delete it first
        await file.delete();
      }

      // Start download
      _progressController.add(
        DownloadProgress(progress: 0, speed: 0, status: 'Starting download...'),
      );

      DateTime startTime = DateTime.now();
      int lastBytes = 0;
      double lastSpeed = 0;

      await _dio.download(
        url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            // Calculate progress
            final progress = (received / total * 100);

            // Calculate speed (bytes per second)
            final now = DateTime.now();
            final timeDiff = now.difference(startTime).inMilliseconds;

            // Update speed calculation every 500ms
            if (timeDiff >= 500) {
              final byteDiff = received - lastBytes;
              final seconds = timeDiff / 1000;
              final speed = byteDiff / seconds / 1024; // KB/s

              // Smooth speed calculation
              lastSpeed =
                  lastSpeed == 0 ? speed : (lastSpeed * 0.7 + speed * 0.3);

              // Reset for next calculation
              startTime = now;
              lastBytes = received;
            }

            // Format status message
            String status = 'Downloading...';
            if (progress >= 100) {
              status = 'Download complete';
            }

            // Send progress update
            _progressController.add(
              DownloadProgress(
                progress: progress,
                speed: lastSpeed,
                status: status,
              ),
            );
          }
        },
      );

      _progressController.add(
        DownloadProgress(progress: 100, speed: 0, status: 'Download complete'),
      );

      debugPrint('Download completed: $savePath');
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        _progressController.add(
          DownloadProgress(progress: 0, speed: 0, status: 'Download cancelled'),
        );
      } else {
        _progressController.add(
          DownloadProgress(
            progress: 0,
            speed: 0,
            status: 'Error: ${e.toString()}',
          ),
        );
      }
      debugPrint('Download error: $e');
    } finally {
      _isDownloading = false;
      _cancelToken = null;
    }
  }

  // Get a list of downloaded files
  Future<List<File>> getDownloadedFiles() async {
    List<File> files = [];

    try {
      // Check external storage
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final externalDownloadDir = Directory('${externalDir.path}/Download');
        if (await externalDownloadDir.exists()) {
          final externalFiles =
              externalDownloadDir
                  .listSync()
                  .whereType<File>()
                  .where((file) => file.path.toLowerCase().endsWith('.apk'))
                  .toList();
          files.addAll(externalFiles);
        }
      }

      // Check internal storage
      final internalDir = await getApplicationDocumentsDirectory();
      final internalDownloadDir = Directory('${internalDir.path}/Download');
      if (await internalDownloadDir.exists()) {
        final internalFiles =
            internalDownloadDir
                .listSync()
                .whereType<File>()
                .where((file) => file.path.toLowerCase().endsWith('.apk'))
                .toList();
        files.addAll(internalFiles);
      }

      return files;
    } catch (e) {
      debugPrint('Error getting downloaded files: $e');
      return [];
    }
  }

  void cancelDownload() {
    if (_isDownloading && _cancelToken != null) {
      _cancelToken!.cancel('Download cancelled by user');
      _isDownloading = false;
    }
  }

  void dispose() {
    _progressController.close();
  }
}
