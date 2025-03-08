import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const String _languageKey = 'language';
  static const String englishCode = 'en';
  static const String banglaCode = 'bn';

  // Default language
  static Locale defaultLocale = const Locale(englishCode);

  // Get current locale from saved preferences
  static Future<Locale> getCurrentLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString(_languageKey) ?? 'English';

    if (language == 'বাংলা') {
      return const Locale(banglaCode);
    }
    return const Locale(englishCode);
  }

  // Save language preference
  static Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
  }

  // Get locale code from language name
  static Locale getLocaleFromLanguage(String language) {
    if (language == 'বাংলা') {
      return const Locale(banglaCode);
    }
    return const Locale(englishCode);
  }

  // Translations
  static Map<String, Map<String, String>> translations = {
    englishCode: {
      // General
      'app_name': 'TSBD App Store',
      'loading': 'Loading...',
      'please_wait': 'Please wait',
      'error': 'Error',
      'success': 'Success',
      'cancel': 'Cancel',
      'ok': 'OK',
      'close': 'Close',
      'retry': 'Retry',

      // Navigation
      'home': 'Home',
      'downloads': 'Downloads',
      'info': 'Info',
      'settings': 'Settings',

      // Settings
      'appearance': 'Appearance',
      'dark_mode': 'Dark Mode',
      'enable_dark_theme': 'Enable dark theme',
      'home_screen_layout': 'Home Screen Layout',
      'choose_display': 'Choose how games are displayed',
      'grid': 'Grid',
      'list': 'List',
      'general': 'General',
      'auto_reload': 'Auto Reload',
      'auto_refresh': 'Automatically refresh content',
      'notifications': 'Notifications',
      'enable_notifications': 'Enable download notifications',
      'storage': 'Storage',
      'download_location': 'Download Location',
      'clear_cache': 'Clear Cache',
      'clear_cache_desc': 'Clear app cache and temporary files',
      'language': 'Language',
      'updates': 'Updates',
      'check_updates': 'Check for Updates',
      'check_new_version': 'Check for new app version',
      'version': 'Version',
      'reset_app': 'Reset App',
      'welcome': 'Welcome',
      'customize_app': 'Customize your app experience',

      // Downloads
      'no_downloads': 'No downloads found',
      'downloads_appear': 'Your downloaded APK files will appear here',
      'refresh': 'Refresh',
      'downloaded_apks': 'Downloaded APKs',
      'install': 'Install',
      'share': 'Share',
      'delete': 'Delete',

      // Downloader
      'download_now': 'Download Now',
      'available_in': 'Available in',
      'seconds': 'seconds',
      'download_failed': 'Download failed. Try opening in browser:',
      'open_browser': 'Open in Browser',
      'downloading': 'Downloading...',
      'whats_new': 'What\'s New:',
      'size': 'Size',
      'release': 'Release',

      // Info
      'information': 'Information',
      'features': 'Features',
      'support': 'Support',
      'need_help': 'Need help? Contact us on Telegram:',
      'join_telegram': 'Join Telegram Support',
      'app_information': 'App Information',
      'release_date': 'Release Date',
      'developed_by': 'Developed By',

      // Maintenance
      'maintenance': 'App Under Maintenance',
      'maintenance_message':
          'We are currently performing maintenance on the app to improve your experience.',
      'check_back': 'Please check back later.',
      'estimated': 'Estimated completion:',
      'hours': 'hours',
      'working_improvements': 'Working on improvements...',
      'whats_updated': 'What\'s being updated',
      'performance': 'Performance improvements',
      'new_features': 'New features',
      'bug_fixes': 'Bug fixes',
      'security': 'Security enhancements',
    },

    banglaCode: {
      // General
      'app_name': 'টিএসবিডি অ্যাপ স্টোর',
      'loading': 'লোড হচ্ছে...',
      'please_wait': 'অনুগ্রহ করে অপেক্ষা করুন',
      'error': 'ত্রুটি',
      'success': 'সফল',
      'cancel': 'বাতিল',
      'ok': 'ঠিক আছে',
      'close': 'বন্ধ করুন',
      'retry': 'পুনরায় চেষ্টা করুন',

      // Navigation
      'home': 'হোম',
      'downloads': 'ডাউনলোড',
      'info': 'তথ্য',
      'settings': 'সেটিংস',

      // Settings
      'appearance': 'অ্যাপিয়ারেন্স',
      'dark_mode': 'ডার্ক মোড',
      'enable_dark_theme': 'ডার্ক থিম সক্রিয় করুন',
      'home_screen_layout': 'হোম স্ক্রিন লেআউট',
      'choose_display': 'গেমগুলি কীভাবে প্রদর্শিত হবে তা চয়ন করুন',
      'grid': 'গ্রিড',
      'list': 'তালিকা',
      'general': 'সাধারণ',
      'auto_reload': 'অটো রিলোড',
      'auto_refresh': 'স্বয়ংক্রিয়ভাবে কন্টেন্ট রিফ্রেশ করুন',
      'notifications': 'নোটিফিকেশন',
      'enable_notifications': 'ডাউনলোড নোটিফিকেশন সক্রিয় করুন',
      'storage': 'স্টোরেজ',
      'download_location': 'ডাউনলোড লোকেশন',
      'clear_cache': 'ক্যাশ পরিষ্কার করুন',
      'clear_cache_desc': 'অ্যাপ ক্যাশ এবং অস্থায়ী ফাইল পরিষ্কার করুন',
      'language': 'ভাষা',
      'updates': 'আপডেট',
      'check_updates': 'আপডেট চেক করুন',
      'check_new_version': 'নতুন অ্যাপ ভার্সন চেক করুন',
      'version': 'ভার্সন',
      'reset_app': 'অ্যাপ রিসেট করুন',
      'welcome': 'স্বাগতম',
      'customize_app': 'আপনার অ্যাপ এক্সপেরিয়েন্স কাস্টমাইজ করুন',

      // Downloads
      'no_downloads': 'কোন ডাউনলোড পাওয়া যায়নি',
      'downloads_appear': 'আপনার ডাউনলোড করা APK ফাইলগুলি এখানে দেখাবে',
      'refresh': 'রিফ্রেশ',
      'downloaded_apks': 'ডাউনলোড করা APK',
      'install': 'ইনস্টল করুন',
      'share': 'শেয়ার করুন',
      'delete': 'মুছুন',

      // Downloader
      'download_now': 'এখনই ডাউনলোড করুন',
      'available_in': 'উপলব্ধ হবে',
      'seconds': 'সেকেন্ডে',
      'download_failed': 'ডাউনলোড ব্যর্থ হয়েছে। ব্রাউজারে খোলার চেষ্টা করুন:',
      'open_browser': 'ব্রাউজারে খুলুন',
      'downloading': 'ডাউনলোড হচ্ছে...',
      'whats_new': 'নতুন কী আছে:',
      'size': 'আকার',
      'release': 'রিলিজ',

      // Info
      'information': 'তথ্য',
      'features': 'বৈশিষ্ট্য',
      'support': 'সাপোর্ট',
      'need_help': 'সাহায্য দরকার? টেলিগ্রামে আমাদের সাথে যোগাযোগ করুন:',
      'join_telegram': 'টেলিগ্রাম সাপোর্টে যোগ দিন',
      'app_information': 'অ্যাপ তথ্য',
      'release_date': 'রিলিজ তারিখ',
      'developed_by': 'ডেভেলপার',

      // Maintenance
      'maintenance': 'অ্যাপ রক্ষণাবেক্ষণাধীন',
      'maintenance_message':
          'আমরা বর্তমানে আপনার অভিজ্ঞতা উন্নত করার জন্য অ্যাপে রক্ষণাবেক্ষণ করছি।',
      'check_back': 'অনুগ্রহ করে পরে আবার চেক করুন।',
      'estimated': 'আনুমানিক সমাপ্তি:',
      'hours': 'ঘন্টা',
      'working_improvements': 'উন্নতি করা হচ্ছে...',
      'whats_updated': 'কী আপডেট করা হচ্ছে',
      'performance': 'পারফরম্যান্স উন্নতি',
      'new_features': 'নতুন বৈশিষ্ট্য',
      'bug_fixes': 'বাগ ফিক্স',
      'security': 'সুরক্ষা উন্নতি',
    },
  };

  // Get translated text
  static String getText(BuildContext context, String key) {
    final locale = Localizations.localeOf(context);
    final languageCode = locale.languageCode;

    if (translations.containsKey(languageCode) &&
        translations[languageCode]!.containsKey(key)) {
      return translations[languageCode]![key]!;
    }

    // Fallback to English
    if (translations[englishCode]!.containsKey(key)) {
      return translations[englishCode]![key]!;
    }

    // Return the key if no translation is found
    return key;
  }
}

// Shorthand function for getting translated text
String t(BuildContext context, String key) {
  return LanguageService.getText(context, key);
}
