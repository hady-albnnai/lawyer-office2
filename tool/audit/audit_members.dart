import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// يلتقط ثلاث فئات من أخطاء الأنواع التي لا يمسكها فحص النحو:
///
/// 1. UNDEFINED_MEMBER: استعمال حقل `_x` داخل صف لا يعرّفه
///    (يحدث عند نقل كتلة كود إلى الصف الخطأ).
/// 2. DUPLICATE_TOP_LEVEL: تعريف مكرر لاسم على مستوى الملف.
/// 3. FAMILY_MISUSE: تمرير مزوّد family دون وسيط، أو العكس.

class ClassInfo {
  final String name;
  final Set<String> declared = {};
  final Map<String, int> used = {};
  ClassInfo(this.name);
}

class MemberVisitor extends RecursiveAstVisitor<void> {
  MemberVisitor(this.path, this.source);
  final String path;
  final String source;
  final List<ClassInfo> classes = [];
  final Map<String, List<int>> topLevel = {};

  int lineOf(int o) {
    var l = 1;
    for (var i = 0; i < o && i < source.length; i++) {
      if (source[i] == '\n') l++;
    }
    return l;
  }

  void _collectTop(String name, int offset) {
    topLevel.putIfAbsent(name, () => []).add(lineOf(offset));
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration n) {
    for (final v in n.variables.variables) {
      _collectTop(v.name.lexeme, v.offset);
    }
    super.visitTopLevelVariableDeclaration(n);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration n) {
    if (n.parent is CompilationUnit) _collectTop(n.name.lexeme, n.offset);
    super.visitFunctionDeclaration(n);
  }

  @override
  void visitClassDeclaration(ClassDeclaration n) {
    _collectTop(n.name.lexeme, n.offset);

    // الصفوف التي ترث من غيرها قد تستعمل أعضاء الأب، فنتخطاها
    // لتفادي إنذارات كاذبة كثيرة.
    final extendsOther = n.extendsClause != null &&
        !(n.extendsClause!.superclass.name2.lexeme.startsWith('State') ||
            n.extendsClause!.superclass.name2.lexeme == 'Object');

    final info = ClassInfo(n.name.lexeme);

    for (final m in n.members) {
      if (m is FieldDeclaration) {
        for (final v in m.fields.variables) {
          info.declared.add(v.name.lexeme);
        }
      } else if (m is MethodDeclaration) {
        info.declared.add(m.name.lexeme);
      } else if (m is ConstructorDeclaration) {
        final cn = m.name;
        if (cn != null) info.declared.add(cn.lexeme);
      }
    }

    // جمع الاستعمالات الخاصة (_x) داخل هذا الصف فقط
    if (!extendsOther || n.name.lexeme.contains('State')) {
      final body = n.toSource();
      for (final m in RegExp(r'(?<![\w.$])(_[A-Za-z]\w*)').allMatches(body)) {
        final name = m.group(1)!;
        if (info.declared.contains(name)) continue;
        info.used.putIfAbsent(name, () => n.offset);
      }
    }

    classes.add(info);
    super.visitClassDeclaration(n);
  }
}

void main(List<String> args) {
  var problems = 0;

  for (final path in args) {
    final source = File(path).readAsStringSync();
    final unit =
        parseFile(path: path, featureSet: FeatureSet.latestLanguageVersion())
            .unit;

    final v = MemberVisitor(path, source);
    unit.accept(v);

    // 1) تعريفات مكررة على مستوى الملف
    v.topLevel.forEach((name, lines) {
      if (lines.length > 1) {
        print('[DUPLICATE_TOP_LEVEL] $path  «$name» معرّف ${lines.length} مرة '
            '(أسطر ${lines.join(", ")})');
        problems++;
      }
    });

    // 2) أعضاء خاصة مستعملة وغير معرّفة في الصف
    //    نستثني ما هو معرّف في أي صف آخر بنفس الملف لتقليل الضجيج،
    //    فالهدف التقاط النقل الخاطئ بين الصفوف لا التحليل الكامل.
    final allDeclared = <String>{};
    for (final c in v.classes) {
      allDeclared.addAll(c.declared);
      allDeclared.add(c.name); // اسم الصف نفسه ليس عضواً مفقوداً
    }

    for (final c in v.classes) {
      // صفوف الحالة (State) مستقلة: عضو معرّف في صف آخر لا يعني
      // توفّره هنا، وهذا بالضبط ما يحدث عند نقل كتلة للصف الخطأ.
      final scope = c.name.endsWith('State') ? c.declared : allDeclared;
      for (final name in c.used.keys) {
        if (scope.contains(name)) continue;
        if (c.name == name) continue;
        // أسماء عامة شائعة أو من مكتبات
        if (name.startsWith('_\$')) continue;
        print('[UNDEFINED_MEMBER] $path  الصف ${c.name}: «$name» غير معرّف');
        problems++;
      }
    }

    // 3) سوء استعمال family
    final famDefs = RegExp(
      r'final (\w+) = \w*Provider\.family<',
    ).allMatches(source).map((m) => m.group(1)!).toSet();

    final plainDefs = RegExp(
      r'final (\w+) = \w*Provider<',
    ).allMatches(source).map((m) => m.group(1)!).toSet();

    for (final name in famDefs) {
      // استعمال بلا وسيط: watch(name) بدل watch(name(arg))
      // invalidate و refresh يقبلان الـ family كاملة، فلا يُعدّان خطأً.
      final bad = RegExp('(?:watch|read|listen)\\s*\\(\\s*$name\\s*\\)');
      for (final m in bad.allMatches(source)) {
        print('[FAMILY_MISUSE] $path:${v.lineOf(m.start)}  '
            '«$name» مزوّد family يحتاج وسيطاً');
        problems++;
      }
    }

    for (final name in plainDefs) {
      final bad = RegExp('(?:watch|read)\\s*\\(\\s*$name\\s*\\(');
      for (final m in bad.allMatches(source)) {
        print('[FAMILY_MISUSE] $path:${v.lineOf(m.start)}  '
            '«$name» ليس family لكنه استُدعي بوسيط');
        problems++;
      }
    }
  }

  print(problems == 0 ? 'MEMBERS OK' : '$problems مشكلة');
}
