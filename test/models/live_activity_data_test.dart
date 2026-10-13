import 'package:flutter_test/flutter_test.dart';
import 'package:video_slimmer/src/models/live_activity_data.dart';

void main() {
  group('LiveActivityData.toMap', () {
    test('omits null values that UserDefaults cannot store', () {
      const LiveActivityData inputData = LiveActivityData(
        progress: 0.25,
        currentIndex: 1,
        totalCount: 3,
        status: 'compressing',
      );

      final Map<String, dynamic> actualMap = inputData.toMap();

      expect(actualMap.containsKey('remainingSeconds'), isFalse);
      expect(actualMap.containsKey('currentVideoName'), isFalse);
      expect(actualMap['progress'], 0.25);
      expect(actualMap['status'], 'compressing');
    });

    test('includes non-null optional values', () {
      const LiveActivityData inputData = LiveActivityData(
        progress: 0.5,
        currentIndex: 2,
        totalCount: 3,
        remainingSeconds: 30,
        currentVideoName: 'video.mov',
        status: 'compressing',
      );

      final Map<String, dynamic> actualMap = inputData.toMap();

      expect(actualMap['remainingSeconds'], 30);
      expect(actualMap['currentVideoName'], 'video.mov');
    });

    test('includes null values when preparing an update', () {
      const LiveActivityData inputData = LiveActivityData(
        progress: 0.75,
        currentIndex: 2,
        totalCount: 3,
        status: 'compressing',
      );

      final Map<String, dynamic> actualMap = inputData.toMap(
        includeNullValues: true,
      );

      expect(actualMap.containsKey('remainingSeconds'), isTrue);
      expect(actualMap['remainingSeconds'], isNull);
      expect(actualMap.containsKey('currentVideoName'), isTrue);
      expect(actualMap['currentVideoName'], isNull);
    });
  });
}
