import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyer_office/data/services/backup_service.dart';
import 'package:path/path.dart' as p;

/// الاستعادة عملية مدمِّرة تكتب فوق بيانات المكتب.
///
/// بعد ترقية archive إلى 4.x صار `ArchiveFile.content` يُرجع مصفوفة
/// فارغة عند تعذّر فكّ الضغط بدل رمي خطأ، فكانت الاستعادة تكتب ملفات
/// فارغة بصمت وتُبلّغ بالنجاح.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('restore_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('ملف zip تالف يرمي RestoreException ولا يُبلّغ بالنجاح', () async {
    final broken = File(p.join(tempDir.path, 'broken.zip'));
    await broken.writeAsBytes([0x00, 0x01, 0x02, 0x03]);

    expect(
      () => BackupService().restoreFromBackup(broken),
      throwsA(isA<RestoreException>()),
    );
  });

  test('ملف غير موجود يرمي خطأً واضحاً', () async {
    final missing = File(p.join(tempDir.path, 'nope.zip'));

    expect(
      () => BackupService().restoreFromBackup(missing),
      throwsA(anything),
    );
  });

  test('أرشيف فارغ يرمي RestoreException', () async {
    final zipPath = p.join(tempDir.path, 'empty.zip');
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    await encoder.close();

    expect(
      () => BackupService().restoreFromBackup(File(zipPath)),
      throwsA(isA<RestoreException>()),
    );
  });

  test('ZipFileEncoder ينتظر اكتمال الكتابة قبل الإغلاق', () async {
    // addFile و close تُرجعان Future؛ استدعاؤهما بلا await كان
    // قد يُغلق الأرشيف قبل كتابة الملفات فتنتج نسخة ناقصة.
    final source = File(p.join(tempDir.path, 'sample.db'));
    final payload = List<int>.generate(5000, (i) => i % 256);
    await source.writeAsBytes(payload);

    final zipPath = p.join(tempDir.path, 'out.zip');
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    await encoder.addFile(source);
    await encoder.close();

    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    expect(archive.length, 1);
    final restored = archive.first.readBytes();
    expect(restored, isNotNull);
    expect(
      restored!.length,
      payload.length,
      reason: 'حجم الملف المستعاد يخالف الأصل — الأرشيف ناقص',
    );
  });
}
