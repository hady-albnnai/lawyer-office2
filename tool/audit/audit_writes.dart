import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// يبحث عن أنماط «الكتابة الصامتة»:
///
/// 1. WRITE_NO_REFRESH: تعديل يُكتب في قاعدة البيانات دون invalidate
///    ولا setState ولا Stream حيّ، فتبقى الشاشة تعرض بيانات قديمة.
/// 2. WRITE_NO_ERROR_PATH: كتابة بلا try/catch، فأي فشل يظهر كخطأ
///    أحمر غير مفهوم بدل رسالة واضحة.
/// 3. SUCCESS_BEFORE_AWAIT: رسالة نجاح تُعرض قبل انتهاء العملية.

const writeMarkers = [
  'insert',
  'update',
  'delete',
  'write(',
  'create',
  'save',
  'add',
  'terminate',
  'close',
  'complete',
  'link',
  'assign',
];

const refreshMarkers = [
  'invalidate',
  'setState',
  'refresh',
  '.state =',
  'watch(', // Stream حيّ
];

class WriteVisitor extends RecursiveAstVisitor<void> {
  WriteVisitor(this.path, this.source);
  final String path;
  final String source;
  final List<String> findings = [];

  int lineOf(int o) {
    var l = 1;
    for (var i = 0; i < o && i < source.length; i++) {
      if (source[i] == '\n') l++;
    }
    return l;
  }

  void _check(String name, FunctionBody body, int offset) {
    final text = body.toSource();

    // هل يكتب فعلاً عبر مستودع/DAO؟
    final writesViaRepo = RegExp(
      r'\.(read|watch)\([^)]*(?:[Rr]epository|[Dd]ao|[Ss]ervice)[^)]*\)\s*\.\s*(\w+)',
    ).hasMatch(text) ||
        RegExp(r'(?:[Rr]epository|[Dd]ao)\w*\.\s*(\w+)\(').hasMatch(text);

    if (!writesViaRepo) return;

    final looksLikeWrite = writeMarkers.any((m) =>
        RegExp('\\.\\s*\\w*${RegExp.escape(m)}\\w*\\s*\\(',
                caseSensitive: false)
            .hasMatch(text));
    if (!looksLikeWrite) return;

    final hasRefresh = refreshMarkers.any(text.contains);
    final hasTry = text.contains('try');
    final showsSuccess =
        RegExp(r'(تم |تمت |نجح)').hasMatch(text) && text.contains('SnackBar');

    // رسالة نجاح قبل await؟
    var successBeforeAwait = false;
    if (showsSuccess) {
      final snack = text.indexOf('showSnackBar');
      final firstAwait = text.indexOf('await');
      if (snack >= 0 && firstAwait >= 0 && snack < firstAwait) {
        successBeforeAwait = true;
      }
    }

    final line = lineOf(offset);
    if (successBeforeAwait) {
      findings.add('[SUCCESS_BEFORE_AWAIT] $path:$line  $name');
    }
    if (!hasRefresh && showsSuccess) {
      findings.add('[WRITE_NO_REFRESH] $path:$line  $name');
    }
    if (!hasTry && showsSuccess) {
      findings.add('[WRITE_NO_ERROR_PATH] $path:$line  $name');
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration n) {
    _check(n.name.lexeme, n.body, n.offset);
    super.visitMethodDeclaration(n);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration n) {
    _check(n.name.lexeme, n.functionExpression.body, n.offset);
    super.visitFunctionDeclaration(n);
  }
}

void main(List<String> args) {
  final all = <String>[];
  for (final path in args) {
    final src = File(path).readAsStringSync();
    final unit =
        parseFile(path: path, featureSet: FeatureSet.latestLanguageVersion())
            .unit;
    final v = WriteVisitor(path, src);
    unit.accept(v);
    all.addAll(v.findings);
  }
  for (final f in all) {
    print(f);
  }
  print('TOTAL:${all.length}');
}
