import '../services/localization_service.dart';

String tr(String sourceText) {
  return LocalizationService.instance.translate(sourceText);
}
