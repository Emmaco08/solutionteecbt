// Windows video check (D-167), its own step because video needs a graphics card and sound output, which GitHub's
// Windows machines do not have (the video plugin stops the app there instead of reporting an error). On GitHub this
// step is information only; on a real computer it must pass.
//   flutter test integration_test/windows_video_test.dart -d windows --dart-define=FIXTURES=<abs path to fixtures>
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';

const fixtures = String.fromEnvironment('FIXTURES');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('video lessons play (picture; sound needs speakers)', () async {
    final v = VideoPlayerController.file(File('$fixtures${Platform.pathSeparator}clip.mp4'));
    await v.initialize().timeout(const Duration(seconds: 20));
    expect(v.value.isInitialized, isTrue);
    expect(v.value.duration.inMilliseconds, greaterThan(500));
    expect(v.value.size.width, 64);
    await v.play();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await v.pause();
    await v.dispose();
  });
}
