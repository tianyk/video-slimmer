import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../constants/app_constants.dart';

/// 负责根据当前 Locale 从 JSON 语言包中加载和提供文案的本地化服务。
class LocalizationService {
  LocalizationService._internal();
  static final LocalizationService instance = LocalizationService._internal();
  String _currentLocaleCode = AppConstants.fallbackLocaleCode;
  Map<String, String> _translations = <String, String>{};

  /// 返回当前正在使用的语言代码，例如 `en-US`。
  String get currentLocaleCode {
    return _currentLocaleCode;
  }

  /// 使用设备语言作为首选语言初始化本地化。
  ///
  /// 需要在应用启动（runApp 之前）调用，确保 Widget 构建时翻译数据已就绪。
  Future<void> initialize() async {
    final Locale deviceLocale =
        WidgetsBinding.instance.platformDispatcher.locale;
    await loadLocale(deviceLocale);
  }

  /// 为给定的 [locale] 加载对应的翻译文案。
  ///
  /// 加载顺序依次为：
  /// 1. 完整语言代码，例如 `ja-JP`
  /// 2. 仅语言部分，例如 `ja`
  /// 3. 在 [AppConstants.fallbackLocaleCode] 中配置的回退语言，例如 `en-US`
  ///
  /// 如果所有尝试都失败，将清空当前翻译 Map，并把当前语言代码重置为回退语言。
  Future<void> loadLocale(Locale locale) async {
    final List<String> candidateCodes = _buildCandidateLocaleCodes(locale);
    candidateCodes.add(AppConstants.fallbackLocaleCode);
    final _LocaleLoadResult? result = await _tryLoadInOrder(candidateCodes);
    if (result != null) {
      _translations = result.translations;
      _currentLocaleCode = result.localeCode;
      return;
    }
    _translations = <String, String>{};
    _currentLocaleCode = AppConstants.fallbackLocaleCode;
  }

  /// 返回 [sourceText] 对应的翻译结果。
  ///
  /// 如果当前翻译 Map 中不存在该 key，或者映射值为空，则直接返回原始的 [sourceText]。
  String translate(String sourceText) {
    final String? translated = _translations[sourceText];
    if (translated == null || translated.isEmpty) {
      return sourceText;
    }
    return translated;
  }

  /// 根据给定的 [locale] 构建候选语言代码列表。
  ///
  /// 例如：`Locale('ja', 'JP')` 会生成：
  /// - `ja-JP`
  /// - `ja`
  ///
  /// 此处不会包含全局回退语言，回退语言会在 [loadLocale] 中统一追加。
  List<String> _buildCandidateLocaleCodes(Locale locale) {
    final List<String> codes = <String>[];
    final String languageCode = locale.languageCode;
    final String countryCode = locale.countryCode ?? '';
    if (languageCode.isNotEmpty && countryCode.isNotEmpty) {
      codes.add('$languageCode-$countryCode');
    }
    if (languageCode.isNotEmpty) {
      codes.add(languageCode);
    }
    final List<String> uniqueCodes = <String>[];
    for (final String code in codes) {
      if (!uniqueCodes.contains(code) &&
          code != AppConstants.fallbackLocaleCode) {
        uniqueCodes.add(code);
      }
    }
    return uniqueCodes;
  }

  /// 按顺序尝试使用 [localeCodes] 加载对应的 JSON 语言包。
  ///
  /// 返回第一个成功加载的结果 [_LocaleLoadResult]。
  /// 如果所有文件都无法加载或解析，将返回 `null`，由调用方决定如何回退。
  Future<_LocaleLoadResult?> _tryLoadInOrder(List<String> localeCodes) async {
    for (final String code in localeCodes) {
      final String assetPath = '${AppConstants.i18nAssetsDirectory}/$code.json';
      try {
        final String jsonString = await rootBundle.loadString(assetPath);
        final Map<String, dynamic> jsonMap =
            json.decode(jsonString) as Map<String, dynamic>;
        final Map<String, String> translations = jsonMap.map(
          (String key, dynamic value) =>
              MapEntry<String, String>(key, value.toString()),
        );
        return _LocaleLoadResult(localeCode: code, translations: translations);
      } on FlutterError {
        // ignore: empty_catches
      } on FormatException {
        // ignore: empty_catches
      }
    }
    return null;
  }
}

/// 表示某个语言包文件成功加载后的结果数据。
class _LocaleLoadResult {
  final String localeCode;
  final Map<String, String> translations;

  const _LocaleLoadResult({
    required this.localeCode,
    required this.translations,
  });
}
