import 'dart:async';
import 'dart:typed_data';

import 'package:cenro_application/services/media/report_photo_upload_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);
  const url = 'https://example.com/photo.jpg';

  test('starts immediately, limits concurrency and preserves selection order', () async {
    final calls = <String>[];
    final pending = <Completer<String>>[];
    final queue = ReportPhotoUploadQueue(uploader: (_, name) {
      calls.add(name);
      final result = Completer<String>();
      pending.add(result);
      return result.future;
    });
    addTearDown(queue.dispose);
    final first = queue.add(bytes);
    final second = queue.add(bytes);
    final third = queue.add(bytes);
    expect(calls.length, 2);
    expect(third.status, ReportPhotoUploadStatus.queued);
    final urls = queue.waitForUrls([third, first, second]);
    pending[1].complete('$url?second');
    await Future<void>.delayed(Duration.zero);
    expect(calls.length, 3);
    pending[2].complete('$url?third');
    pending[0].complete('$url?first');
    expect(await urls, ['$url?third', '$url?first', '$url?second']);
    expect(calls.toSet().length, 3);
  });

  test('submit waits for an existing upload and does not upload twice', () async {
    final result = Completer<String>();
    var calls = 0;
    final queue = ReportPhotoUploadQueue(uploader: (_, _) {
      calls++;
      return result.future;
    });
    addTearDown(queue.dispose);
    final photo = queue.add(bytes);
    var finished = false;
    final urls = queue.waitForUrls([photo]).then((value) {
      finished = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(finished, isFalse);
    result.complete(url);
    expect(await urls, [url]);
    expect(await queue.waitForUrls([photo]), [url]);
    expect(calls, 1);
  });

  test('failure stays explicit and retries reuse the same stable public ID', () async {
    final names = <String>[];
    final queue = ReportPhotoUploadQueue(uploader: (_, name) async {
      names.add(name);
      if (names.length == 1) throw TimeoutException('Offline');
      return url;
    });
    addTearDown(queue.dispose);
    final photo = queue.add(bytes);
    await expectLater(queue.waitForUrls([photo]),
        throwsA(isA<ReportPhotoUploadException>()));
    expect(photo.status, ReportPhotoUploadStatus.failed);
    expect(photo.error, isA<TimeoutException>());
    queue.retry(photo);
    expect(await queue.waitForUrls([photo]), [url]);
    expect(names[0], names[1]);
    expect(photo.error, isNull);
  });

  test('removed pending photos never upload and late active results are ignored', () async {
    final result = Completer<String>();
    var calls = 0;
    final queue = ReportPhotoUploadQueue(concurrency: 1, uploader: (_, _) {
      calls++;
      return result.future;
    });
    addTearDown(queue.dispose);
    final active = queue.add(bytes);
    final queued = queue.add(bytes);
    queue.remove(queued);
    queue.remove(active);
    result.complete(url);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    expect(active.status, ReportPhotoUploadStatus.removed);
    expect(active.url, isNull);
    await expectLater(queue.waitForUrls([active]),
        throwsA(isA<ReportPhotoUploadException>()));
  });

  test('dispose settles waiters, stops queued work and ignores late completion', () async {
    final result = Completer<String>();
    var calls = 0;
    final queue = ReportPhotoUploadQueue(concurrency: 1, uploader: (_, _) {
      calls++;
      return result.future;
    });
    final first = queue.add(bytes);
    final second = queue.add(bytes);
    final waiting = expectLater(queue.waitForUrls([first, second]),
        throwsA(isA<ReportPhotoUploadException>()));
    queue.dispose();
    await waiting;
    result.complete(url);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    expect(() => queue.add(bytes), throwsStateError);
  });

  test('invalid upload URLs fail rather than appearing successful', () async {
    final queue = ReportPhotoUploadQueue(uploader: (_, _) async => 'http://example.com');
    addTearDown(queue.dispose);
    final photo = queue.add(bytes);
    await expectLater(queue.waitForUrls([photo]),
        throwsA(isA<ReportPhotoUploadException>()));
    expect(photo.status, ReportPhotoUploadStatus.failed);
  });

  test('removed slots are not reused for new photos', () async {
    final names = <String>[];
    final queue = ReportPhotoUploadQueue(uploader: (_, name) async {
      names.add(name);
      return url;
    });
    addTearDown(queue.dispose);
    final first = queue.add(bytes);
    await queue.waitForUrls([first]);
    queue.remove(first);
    final second = queue.add(bytes);
    await queue.waitForUrls([second]);
    expect(names[0], isNot(names[1]));
  });
}
