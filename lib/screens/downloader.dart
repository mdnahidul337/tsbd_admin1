import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tsbd_app/utils/download_manager.dart';
import 'package:tsbd_app/services/ad_service.dart';
import 'package:tsbd_app/screens/home.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DownloaderScreen extends StatefulWidget {
  final GameFile game;

  const DownloaderScreen({super.key, required this.game});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  int _countdown = 15;
  bool _canDownload = false;
  bool _isLoadingAd = false;
  bool _hasError = false;
  double _downloadProgress = 0.0;
  String _downloadSpeed = '0 KB/s';
  String _downloadStatus = 'Waiting...';
  final DownloadManager _downloadManager = DownloadManager();
  final AdService _adService = AdService();
  StreamSubscription? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Pre-load the rewarded ad only on mobile platforms
    if (!kIsWeb) {
      _adService.loadRewardedAd().catchError((e) {
        debugPrint('Failed to pre-load rewarded ad: $e');
      });
    }
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          if (_countdown > 0) {
            _countdown--;
            _startCountdown();
          } else {
            _canDownload = true;
          }
        });
      }
    });
  }

  Future<void> _startDownload() async {
    if (!_canDownload) return;
    if (_isLoadingAd) return;

    if (kIsWeb) {
      // On web, start download directly without showing ad
      _initiateDownload();
      return;
    }

    setState(() {
      _isLoadingAd = true;
      _downloadStatus = 'Loading reward ad...';
    });

    try {
      await _adService.showRewardedAd((ad, reward) {
        debugPrint('User earned reward: ${reward.amount} ${reward.type}');
        _initiateDownload();
      });
    } catch (e) {
      debugPrint('Failed to show rewarded ad: $e');
      // Show error to user
      if (mounted) {
        setState(() {
          _downloadStatus = 'Failed to load ad. Starting download...';
        });
      }
      // If ad fails, allow download anyway
      _initiateDownload();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAd = false;
        });
      }
    }
  }

  Future<void> _openInBrowser() async {
    final url = Uri.parse(widget.game.downloadLink);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      debugPrint('Error opening URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open link: $e')));
      }
    }
  }

  void _initiateDownload() {
    setState(() {
      _downloadStatus = 'Starting download...';
      _hasError = false;
    });

    _downloadSubscription = _downloadManager.downloadProgress.listen(
      (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress.progress / 100;
            _downloadSpeed = '${progress.speed.toStringAsFixed(2)} KB/s';
            _downloadStatus = progress.status;
            if (progress.status.startsWith('Error')) {
              _hasError = true;
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _downloadStatus = 'Error: $error';
            _hasError = true;
          });
        }
      },
    );

    _downloadManager.downloadFile(widget.game.downloadLink, widget.game.title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.game.title), elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Game image with gradient overlay
            Stack(
              children: [
                Hero(
                  tag: 'game-${widget.game.id ?? widget.game.title}',
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: widget.game.thumbnail,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                      errorWidget:
                          (context, url, error) => Container(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.error,
                              color: Theme.of(context).colorScheme.error,
                              size: 48,
                            ),
                          ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Theme.of(
                            context,
                          ).colorScheme.surface.withOpacity(0.8),
                          Theme.of(context).colorScheme.surface,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Game details card
                  Container(
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Game stats in a row
                        Row(
                          children: [
                            _buildStatItem(
                              context,
                              'Size',
                              widget.game.size,
                              Icons.sd_storage,
                            ),
                            const SizedBox(width: 16),
                            _buildStatItem(
                              context,
                              'Release',
                              widget.game.releaseDate,
                              Icons.calendar_today,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'What\'s New:',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.game.whatsNew,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(height: 1.5),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Download progress section
                  if (_downloadProgress > 0)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Downloading...',
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Text(
                                '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: _downloadProgress,
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            minHeight: 8,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.speed,
                                    size: 16,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _downloadSpeed,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _downloadStatus,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color:
                                      _hasError
                                          ? Theme.of(context).colorScheme.error
                                          : Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Download button section
                  Center(
                    child: Column(
                      children: [
                        if (!_canDownload)
                          Column(
                            children: [
                              TweenAnimationBuilder<int>(
                                tween: IntTween(begin: 15, end: _countdown),
                                duration: const Duration(seconds: 1),
                                builder: (context, value, child) {
                                  return Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 64,
                                        height: 64,
                                        child: CircularProgressIndicator(
                                          value: 1 - (value / 15),
                                          strokeWidth: 6,
                                          backgroundColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.surfaceVariant,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                        ),
                                      ),
                                      Text(
                                        '$value',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Available in $_countdown seconds',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        if (_hasError) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Download failed. Try opening in browser:',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _openInBrowser,
                              icon: const Icon(Icons.open_in_browser),
                              label: const Text('Open in Browser'),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    Theme.of(
                                      context,
                                    ).colorScheme.secondaryContainer,
                                foregroundColor:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                                minimumSize: const Size(double.infinity, 54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ] else
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: double.infinity,
                            height: 54,
                            child: FilledButton.icon(
                              onPressed:
                                  _canDownload && !_isLoadingAd
                                      ? _startDownload
                                      : null,
                              icon:
                                  _isLoadingAd
                                      ? Container(
                                        width: 18,
                                        height: 18,
                                        margin: const EdgeInsets.only(right: 8),
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : const Icon(Icons.download),
                              label: Text(
                                _isLoadingAd
                                    ? 'Loading Ad...'
                                    : _canDownload
                                    ? 'Download Now'
                                    : 'Please Wait',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
