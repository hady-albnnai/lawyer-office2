import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/error/error.dart';
void main(List<String> a) {
  var bad = 0;
  for (final p in a) {
    final r = parseFile(path: p, featureSet: FeatureSet.latestLanguageVersion());
    final e = r.errors.where((x) => x.errorCode.errorSeverity.name == 'ERROR').toList();
    if (e.isEmpty) continue;
    bad++;
    print('### $p');
    for (final x in e.take(5)) { print('  ${x.errorCode.name}: ${x.message}'); }
  }
  print(bad == 0 ? 'PARSE OK' : '$bad files broken');
}
