import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// يدقّق كل معالج تفاعل (onPressed / onTap / onSelected ...) في التطبيق
/// ويصنّفه: هل ينفّذ عملاً حقيقياً أم يكتفي برسالة أو لا يفعل شيئاً؟
///
/// الهدف التقاط «النجاح الوهمي»: زر يقول للمستخدم إن العملية تمّت
/// بينما لا شيء يُكتب ولا يُستدعى.

const handlerNames = {
  'onPressed',
  'onTap',
  'onLongPress',
  'onSelected',
  'onSubmitted',
  'onFieldSubmitted',
  'onConfirm',
  'onSave',
  'onDoubleTap',
};

/// دلائل على عمل حقيقي داخل المعالج.
class Evidence {
  bool awaitsSomething = false;
  bool readsProvider = false;
  bool callsRepository = false;
  bool invalidates = false;
  bool navigates = false;
  bool popsWithValue = false;
  bool setsState = false;
  bool showsDialog = false;
  bool callsLocalMethod = false;
  bool mutatesField = false;
  bool showsMessage = false;
  bool claimsSuccess = false;
  bool isNull = false;
  bool isEmpty = true;

  bool get hasRealWork =>
      awaitsSomething ||
      readsProvider ||
      callsRepository ||
      invalidates ||
      navigates ||
      popsWithValue ||
      setsState ||
      showsDialog ||
      callsLocalMethod ||
      mutatesField;
}

const successWords = ['تم ', 'تمت ', 'نجح', 'أُضيف', 'اضيف', 'حُفظ', 'حفظت'];

class HandlerVisitor extends RecursiveAstVisitor<void> {
  HandlerVisitor(this.path, this.source, this.localMethods);

  final String path;
  final String source;
  final Set<String> localMethods;
  final List<Map<String, Object>> findings = [];

  int lineOf(int offset) {
    var line = 1;
    for (var i = 0; i < offset && i < source.length; i++) {
      if (source[i] == '\n') line++;
    }
    return line;
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    final name = node.name.label.name;
    if (handlerNames.contains(name)) {
      _analyze(name, node.expression);
    }
    super.visitNamedExpression(node);
  }

  void _analyze(String handler, Expression expr) {
    final ev = Evidence();

    if (expr is NullLiteral) {
      ev.isNull = true;
      _record(handler, expr, ev, '');
      return;
    }

    final body = expr is FunctionExpression ? expr.body : null;
    final text = body?.toSource() ?? expr.toSource();
    if (text.trim().isEmpty) {
      _record(handler, expr, ev, text);
      return;
    }
    ev.isEmpty = false;

    // فحص نصّي على مصدر الجسم فقط (لا الملف كله)
    ev.awaitsSomething = RegExp(r'\bawait\b').hasMatch(text);
    ev.readsProvider = RegExp(r'\.(read|watch)\s*\(').hasMatch(text);
    ev.callsRepository =
        RegExp(r'[Rr]epository|[Ss]ervice\b|[Dd]ao\b|\brepo\b').hasMatch(text);
    ev.invalidates = text.contains('invalidate');
    ev.navigates = RegExp(r'context\.(go|push|pop)|GoRouter|Navigator\.')
        .hasMatch(text);
    ev.popsWithValue =
        RegExp(r'\.pop\s*\(\s*(context|ctx)\s*,\s*[^)]').hasMatch(text) ||
            RegExp(r'\.pop\s*\(\s*[A-Za-z_][\w.]*\s*\(').hasMatch(text);
    ev.setsState = text.contains('setState');
    ev.showsDialog =
        RegExp(r'show(Dialog|ModalBottomSheet|DatePicker|TimePicker|Menu)')
            .hasMatch(text);
    ev.mutatesField = RegExp(r'\.state\s*=|_\w+\s*=(?!=)').hasMatch(text);
    ev.showsMessage =
        RegExp(r'showSnackBar|_showSnack|_showMsg|lastMessage').hasMatch(text);
    ev.claimsSuccess = successWords.any(text.contains);

    // استدعاء تابع محلي معرّف في نفس الملف
    for (final m in localMethods) {
      if (RegExp('\\b$m\\s*\\(').hasMatch(text)) {
        ev.callsLocalMethod = true;
        break;
      }
    }

    _record(handler, expr, ev, text);
  }

  void _record(String handler, AstNode node, Evidence ev, String text) {
    String? verdict;

    if (ev.isNull) {
      verdict = 'NULL_HANDLER';
    } else if (ev.isEmpty) {
      verdict = 'EMPTY_HANDLER';
    } else if (ev.claimsSuccess && !ev.hasRealWork) {
      verdict = 'FAKE_SUCCESS'; // الأخطر
    } else if (ev.showsMessage && !ev.hasRealWork) {
      verdict = 'MESSAGE_ONLY';
    } else if (!ev.hasRealWork && !ev.showsMessage) {
      verdict = 'NO_EFFECT';
    }

    if (verdict == null) return;

    findings.add({
      'path': path,
      'line': lineOf(node.offset),
      'handler': handler,
      'verdict': verdict,
      'snippet': text.replaceAll(RegExp(r'\s+'), ' ').trim(),
    });
  }
}

class MethodCollector extends RecursiveAstVisitor<void> {
  final Set<String> names = {};
  @override
  void visitMethodDeclaration(MethodDeclaration n) {
    names.add(n.name.lexeme);
    super.visitMethodDeclaration(n);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration n) {
    names.add(n.name.lexeme);
    super.visitFunctionDeclaration(n);
  }
}

void main(List<String> args) {
  final all = <Map<String, Object>>[];

  for (final path in args) {
    final source = File(path).readAsStringSync();
    final unit =
        parseFile(path: path, featureSet: FeatureSet.latestLanguageVersion())
            .unit;

    final mc = MethodCollector();
    unit.accept(mc);

    final v = HandlerVisitor(path, source, mc.names);
    unit.accept(v);
    all.addAll(v.findings);
  }

  // ترتيب: الأخطر أولاً
  const order = {
    'FAKE_SUCCESS': 0,
    'MESSAGE_ONLY': 1,
    'EMPTY_HANDLER': 2,
    'NO_EFFECT': 3,
    'NULL_HANDLER': 4,
  };
  all.sort((a, b) =>
      order[a['verdict']]!.compareTo(order[b['verdict']]!));

  final counts = <String, int>{};
  for (final f in all) {
    counts[f['verdict'] as String] = (counts[f['verdict'] as String] ?? 0) + 1;
  }

  for (final f in all) {
    final v = f['verdict'];
    if (v == 'NULL_HANDLER') continue; // غالباً تعطيل مقصود
    print('[$v] ${f['path']}:${f['line']}  (${f['handler']})');
    final s = f['snippet'] as String;
    print('    ${s.length > 150 ? '${s.substring(0, 150)}…' : s}');
  }

  print('\n===== الملخص =====');
  counts.forEach((k, v) => print('  $k: $v'));
}
