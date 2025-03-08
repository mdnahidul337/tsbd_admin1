import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AdService {
  static const String _bannerAdUnitId =
      'ca-app-pub-4717511271155428/1187344182';
  static const String _interstitialAdUnitId =
      'ca-app-pub-4717511271155428/5153643381';
  static const String _rewardedAdUnitId =
      'ca-app-pub-4717511271155428/1214398378';
  static const String _nativeAdUnitId =
      'ca-app-pub-4717511271155428/3110768120';

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  NativeAd? _nativeAd;
  Timer? _bannerRefreshTimer;
  bool _isRewardedAdLoading = false;
  bool _isBannerAdLoading = false;
  bool _isInitialized = false;
  final bool _isDisposed = false;

  // Singleton pattern
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;

    debugPrint('Initializing AdService...');

    if (!kIsWeb) {
      await MobileAds.instance.initialize();

      // Set test device IDs if in development
      MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: ['TEST_DEVICE_ID'], // Replace with your test device ID
        ),
      );
    }

    // Load initial ads
    if (!kIsWeb) {
      _loadBannerAd();
      loadRewardedAd();
    }

    _isInitialized = true;
    debugPrint('AdService initialized successfully');
  }

  void _loadBannerAd() {
    if (_isBannerAdLoading || _bannerAd != null || kIsWeb) return;

    debugPrint('Loading banner ad...');
    _isBannerAdLoading = true;

    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Banner ad loaded successfully');
          _isBannerAdLoading = false;
          _startBannerRefreshTimer();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load: $error');
          ad.dispose();
          _bannerAd = null;
          _isBannerAdLoading = false;
          // Retry after failure
          Future.delayed(const Duration(seconds: 30), _loadBannerAd);
        },
        onAdOpened: (ad) => debugPrint('Banner ad opened'),
        onAdClosed: (ad) => debugPrint('Banner ad closed'),
      ),
    );

    _bannerAd?.load();
  }

  void loadBannerAd({required Function(Ad) onAdLoaded}) {
    if (kIsWeb) {
      debugPrint('Banner ads are not supported on web platform');
      return;
    }

    if (_bannerAd != null) {
      onAdLoaded(_bannerAd!);
      return;
    }

    debugPrint('Loading new banner ad...');
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Banner ad loaded successfully');
          onAdLoaded(ad);
          _startBannerRefreshTimer();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load: $error');
          ad.dispose();
          _bannerAd = null;
          // Retry after failure
          Future.delayed(const Duration(seconds: 30), () {
            loadBannerAd(onAdLoaded: onAdLoaded);
          });
        },
        onAdOpened: (ad) => debugPrint('Banner ad opened'),
        onAdClosed: (ad) => debugPrint('Banner ad closed'),
      ),
    );

    _bannerAd?.load();
  }

  void _startBannerRefreshTimer() {
    _bannerRefreshTimer?.cancel();
    _bannerRefreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      refreshBannerAd();
    });
  }

  void refreshBannerAd() {
    debugPrint('Refreshing banner ad...');
    final oldAd = _bannerAd;
    _bannerAd = null;
    oldAd?.dispose();
    _loadBannerAd();
  }

  Future<void> loadInterstitialAd() async {
    await InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          debugPrint('Interstitial ad loaded successfully');
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial ad failed to load: $error');
        },
      ),
    );
  }

  Future<void> showInterstitialAd() async {
    if (_interstitialAd == null) {
      debugPrint('Interstitial ad not ready');
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadInterstitialAd(); // Load the next interstitial
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        loadInterstitialAd(); // Retry loading
      },
    );

    await _interstitialAd!.show();
    _interstitialAd = null;
  }

  Future<void> loadRewardedAd() async {
    if (_isRewardedAdLoading || _rewardedAd != null || kIsWeb) return;

    _isRewardedAdLoading = true;
    debugPrint('Loading rewarded ad...');

    try {
      await RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('Rewarded ad loaded successfully');
            _rewardedAd = ad;
            _isRewardedAdLoading = false;

            _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                debugPrint('Rewarded ad showed full screen content');
              },
              onAdDismissedFullScreenContent: (ad) {
                debugPrint('Rewarded ad dismissed');
                ad.dispose();
                _rewardedAd = null;
                loadRewardedAd(); // Preload the next ad
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint('Rewarded ad failed to show: $error');
                ad.dispose();
                _rewardedAd = null;
                loadRewardedAd(); // Retry loading
              },
              onAdImpression: (ad) {
                debugPrint('Rewarded ad impression recorded');
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint('Rewarded ad failed to load: $error');
            _rewardedAd = null;
            _isRewardedAdLoading = false;
            // Retry after a delay
            Future.delayed(const Duration(seconds: 5), loadRewardedAd);
          },
        ),
      );
    } catch (e) {
      debugPrint('Error loading rewarded ad: $e');
      _isRewardedAdLoading = false;
      _rewardedAd = null;
    }
  }

  Future<void> showRewardedAd(
    OnUserEarnedRewardCallback onUserEarnedReward,
  ) async {
    if (kIsWeb) {
      debugPrint('Rewarded ads are not supported on web platform');
      return;
    }

    if (_rewardedAd == null) {
      debugPrint('Rewarded ad not ready, loading...');
      await loadRewardedAd();
      // Wait for ad to load with timeout
      int attempts = 0;
      while (_rewardedAd == null && attempts < 10) {
        await Future.delayed(const Duration(seconds: 1));
        attempts++;
      }
      if (_rewardedAd == null) {
        throw Exception('Failed to load rewarded ad after multiple attempts');
      }
    }

    debugPrint('Showing rewarded ad...');
    await _rewardedAd!.show(onUserEarnedReward: onUserEarnedReward);
  }

  Future<void> loadNativeAd({required Function(Ad) onAdLoaded}) async {
    _nativeAd = NativeAd(
      adUnitId: _nativeAdUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('Native ad loaded successfully');
          onAdLoaded(ad);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Native ad failed to load: $error');
          ad.dispose();
          _nativeAd = null;
        },
      ),
    );

    await _nativeAd?.load();
  }

  void dispose() {
    _bannerRefreshTimer?.cancel();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _nativeAd?.dispose();
  }

  BannerAd? get bannerAd => _bannerAd;
  NativeAd? get nativeAd => _nativeAd;
}
