import 'dart:math' as math;
import 'eat_ast.dart';

class EatRuntimeException implements Exception {
  final String message;
  final int line;
  final int column;

  EatRuntimeException(this.message, {required this.line, required this.column});

  @override
  String toString() => 'EatRuntimeException: $message at line $line, column $column';
}

class _EatReturnException {
  final dynamic value;
  _EatReturnException(this.value);
}

class _EatBreakException {}

class _EatContinueException {}

abstract class EatCallable {
  dynamic call(
    EatInterpreter interpreter,
    List<dynamic> positionalArgs,
    Map<String, dynamic> keywordArgs, {
    required int line,
    required int column,
  });
}

class EatNativeFunction extends EatCallable {
  final String name;
  final Function fn;

  EatNativeFunction(this.name, this.fn);

  @override
  dynamic call(
    EatInterpreter interpreter,
    List<dynamic> positionalArgs,
    Map<String, dynamic> keywordArgs, {
    required int line,
    required int column,
  }) {
    try {
      return fn(positionalArgs, keywordArgs);
    } catch (e) {
      throw EatRuntimeException('Error in $name(): ${e.toString()}', line: line, column: column);
    }
  }

  @override
  String toString() => '<built-in function $name>';
}

class EatUserFunction extends EatCallable {
  final EatDef declaration;
  final EatEnvironment closure;

  EatUserFunction(this.declaration, this.closure);

  @override
  dynamic call(
    EatInterpreter interpreter,
    List<dynamic> positionalArgs,
    Map<String, dynamic> keywordArgs, {
    required int line,
    required int column,
  }) {
    final environment = EatEnvironment(closure);

    // 1. Fill parameters with default values
    for (final entry in declaration.defaultArgs.entries) {
      environment.define(entry.key, interpreter.evaluate(entry.value, closure));
    }

    // 2. Bind positional arguments
    for (int i = 0; i < declaration.params.length; i++) {
      final paramName = declaration.params[i];
      if (i < positionalArgs.length) {
        environment.define(paramName, positionalArgs[i]);
      }
    }

    // 3. Bind keyword arguments
    for (final entry in keywordArgs.entries) {
      if (declaration.params.contains(entry.key)) {
        environment.define(entry.key, entry.value);
      }
    }

    try {
      interpreter.executeBlock(declaration.body, environment);
    } on _EatReturnException catch (ret) {
      return ret.value;
    }

    return null;
  }

  @override
  String toString() => '<function ${declaration.name}>';
}

class EatEnvironment {
  final EatEnvironment? parent;
  final Map<String, dynamic> _values = {};

  EatEnvironment([this.parent]);

  void define(String name, dynamic value) {
    _values[name] = value;
  }

  dynamic get(String name, {required int line, required int column}) {
    if (_values.containsKey(name)) {
      return _values[name];
    }
    if (parent != null) {
      return parent!.get(name, line: line, column: column);
    }
    throw EatRuntimeException('Undefined variable "$name"', line: line, column: column);
  }

  bool has(String name) {
    if (_values.containsKey(name)) return true;
    return parent?.has(name) ?? false;
  }

  void assign(String name, dynamic value, {required int line, required int column}) {
    if (_values.containsKey(name)) {
      _values[name] = value;
      return;
    }
    if (parent != null && parent!.has(name)) {
      parent!.assign(name, value, line: line, column: column);
      return;
    }
    // Python local binding by default
    _values[name] = value;
  }
}

class EatInterpreter {
  final EatEnvironment globals = EatEnvironment();
  final List<String> outputLogs = [];
  int maxSteps = 100000;
  int _stepCount = 0;

  EatInterpreter({int? maxExecutionSteps}) {
    if (maxExecutionSteps != null) {
      maxSteps = maxExecutionSteps;
    }
    _installBuiltins();
  }

  void reset() {
    _stepCount = 0;
    outputLogs.clear();
  }

  dynamic interpret(EatProgram program) {
    _stepCount = 0;
    dynamic lastResult;
    for (final stmt in program.statements) {
      lastResult = execute(stmt, globals);
    }
    return lastResult;
  }

  dynamic execute(EatStatement stmt, EatEnvironment env) {
    _tick(stmt.line, stmt.column);

    if (stmt is EatExprStmt) {
      return evaluate(stmt.expr, env);
    } else if (stmt is EatAssign) {
      return _executeAssign(stmt, env);
    } else if (stmt is EatDef) {
      final fn = EatUserFunction(stmt, env);
      env.define(stmt.name, fn);
      return fn;
    } else if (stmt is EatIf) {
      return _executeIf(stmt, env);
    } else if (stmt is EatForIn) {
      return _executeForIn(stmt, env);
    } else if (stmt is EatWhile) {
      return _executeWhile(stmt, env);
    } else if (stmt is EatReturn) {
      final val = stmt.value != null ? evaluate(stmt.value!, env) : null;
      throw _EatReturnException(val);
    } else if (stmt is EatBreak) {
      throw _EatBreakException();
    } else if (stmt is EatContinue) {
      throw _EatContinueException();
    } else if (stmt is EatPass) {
      return null;
    }

    throw EatRuntimeException('Unknown statement type ${stmt.runtimeType}',
        line: stmt.line, column: stmt.column);
  }

  void executeBlock(List<EatStatement> statements, EatEnvironment env) {
    for (final stmt in statements) {
      execute(stmt, env);
    }
  }

  dynamic _executeAssign(EatAssign stmt, EatEnvironment env) {
    final target = stmt.target;
    final rValue = evaluate(stmt.value, env);

    if (target is EatIdentifier) {
      final name = target.name;
      if (stmt.op == '=') {
        env.assign(name, rValue, line: stmt.line, column: stmt.column);
      } else {
        final current = env.get(name, line: stmt.line, column: stmt.column);
        final updated = _applyAssignOp(current, stmt.op, rValue, stmt.line, stmt.column);
        env.assign(name, updated, line: stmt.line, column: stmt.column);
      }
      return rValue;
    }

    if (target is EatIndex) {
      final obj = evaluate(target.target, env);
      final idx = evaluate(target.index, env);

      if (obj is List) {
        if (idx is! num) {
          throw EatRuntimeException('List index must be integer, got ${idx.runtimeType}',
              line: target.line, column: target.column);
        }
        var i = idx.toInt();
        if (i < 0) i += obj.length;
        if (i < 0 || i >= obj.length) {
          throw EatRuntimeException('List index $idx out of range (length ${obj.length})',
              line: target.line, column: target.column);
        }
        if (stmt.op == '=') {
          obj[i] = rValue;
        } else {
          obj[i] = _applyAssignOp(obj[i], stmt.op, rValue, stmt.line, stmt.column);
        }
        return rValue;
      } else if (obj is Map) {
        if (stmt.op == '=') {
          obj[idx] = rValue;
        } else {
          obj[idx] = _applyAssignOp(obj[idx], stmt.op, rValue, stmt.line, stmt.column);
        }
        return rValue;
      }

      throw EatRuntimeException('Cannot index-assign to type ${obj.runtimeType}',
          line: target.line, column: target.column);
    }

    if (target is EatDot) {
      final obj = evaluate(target.target, env);
      if (obj is Map) {
        if (stmt.op == '=') {
          obj[target.property] = rValue;
        } else {
          obj[target.property] = _applyAssignOp(obj[target.property], stmt.op, rValue, stmt.line, stmt.column);
        }
        return rValue;
      }
      throw EatRuntimeException('Cannot set property on type ${obj.runtimeType}',
          line: target.line, column: target.column);
    }

    throw EatRuntimeException('Invalid assignment target', line: stmt.line, column: stmt.column);
  }

  dynamic _applyAssignOp(dynamic left, String op, dynamic right, int line, int col) {
    switch (op) {
      case '+=':
        return _evalAdd(left, right, line, col);
      case '-=':
        return _evalSubtract(left, right, line, col);
      case '*=':
        return _evalMultiply(left, right, line, col);
      case '/=':
        return _evalDivide(left, right, line, col);
      default:
        throw EatRuntimeException('Unsupported assignment operator $op', line: line, column: col);
    }
  }

  dynamic _executeIf(EatIf stmt, EatEnvironment env) {
    if (_isTruthy(evaluate(stmt.condition, env))) {
      executeBlock(stmt.thenBranch, env);
      return null;
    }

    for (final elif in stmt.elifs) {
      if (_isTruthy(evaluate(elif.condition, env))) {
        executeBlock(elif.body, env);
        return null;
      }
    }

    if (stmt.elseBranch != null) {
      executeBlock(stmt.elseBranch!, env);
    }
    return null;
  }

  dynamic _executeForIn(EatForIn stmt, EatEnvironment env) {
    final iterableVal = evaluate(stmt.iterable, env);
    Iterable items;

    if (iterableVal is Iterable) {
      items = iterableVal;
    } else if (iterableVal is Map) {
      items = iterableVal.keys;
    } else if (iterableVal is String) {
      items = iterableVal.split('');
    } else {
      throw EatRuntimeException('Type ${iterableVal.runtimeType} is not iterable',
          line: stmt.line, column: stmt.column);
    }

    for (final item in items) {
      env.define(stmt.variable, item);
      try {
        executeBlock(stmt.body, env);
      } on _EatContinueException {
        continue;
      } on _EatBreakException {
        break;
      }
    }
    return null;
  }

  dynamic _executeWhile(EatWhile stmt, EatEnvironment env) {
    while (_isTruthy(evaluate(stmt.condition, env))) {
      _tick(stmt.line, stmt.column);
      try {
        executeBlock(stmt.body, env);
      } on _EatContinueException {
        continue;
      } on _EatBreakException {
        break;
      }
    }
    return null;
  }

  // ==========================================
  // Expression Evaluation
  // ==========================================

  dynamic evaluate(EatExpression expr, EatEnvironment env) {
    _tick(expr.line, expr.column);

    if (expr is EatLiteral) {
      return expr.value;
    }
    if (expr is EatIdentifier) {
      return env.get(expr.name, line: expr.line, column: expr.column);
    }
    if (expr is EatListLiteral) {
      return expr.elements.map((e) => evaluate(e, env)).toList();
    }
    if (expr is EatDictLiteral) {
      final map = <String, dynamic>{};
      for (final entry in expr.entries) {
        dynamic key;
        if (entry.key is EatIdentifier && !env.has((entry.key as EatIdentifier).name)) {
          key = (entry.key as EatIdentifier).name;
        } else {
          key = evaluate(entry.key, env);
        }
        final val = evaluate(entry.value, env);
        map[key.toString()] = val;
      }
      return map;
    }
    if (expr is EatUnaryOp) {
      final right = evaluate(expr.operand, env);
      switch (expr.op) {
        case '-':
          if (right is num) return -right;
          throw EatRuntimeException('Unary "-" requires number, got ${right.runtimeType}',
              line: expr.line, column: expr.column);
        case '+':
          if (right is num) return right;
          throw EatRuntimeException('Unary "+" requires number, got ${right.runtimeType}',
              line: expr.line, column: expr.column);
        case 'not':
          return !_isTruthy(right);
        default:
          throw EatRuntimeException('Unknown unary operator "${expr.op}"',
              line: expr.line, column: expr.column);
      }
    }
    if (expr is EatBinaryOp) {
      return _evalBinaryOp(expr, env);
    }
    if (expr is EatCall) {
      final callee = evaluate(expr.callee, env);
      final posArgs = expr.positionalArgs.map((a) => evaluate(a, env)).toList();
      final kwArgs = <String, dynamic>{};
      for (final entry in expr.keywordArgs.entries) {
        kwArgs[entry.key] = evaluate(entry.value, env);
      }

      if (callee is EatCallable) {
        return callee.call(this, posArgs, kwArgs, line: expr.line, column: expr.column);
      }
      if (callee is Function) {
        try {
          return Function.apply(callee, posArgs, kwArgs.map((k, v) => MapEntry(Symbol(k), v)));
        } catch (_) {
          return Function.apply(callee, posArgs);
        }
      }

      throw EatRuntimeException('Object of type ${callee.runtimeType} is not callable',
          line: expr.line, column: expr.column);
    }
    if (expr is EatIndex) {
      final target = evaluate(expr.target, env);
      final index = evaluate(expr.index, env);

      if (target is List) {
        if (index is! num) {
          throw EatRuntimeException('List index must be integer, got ${index.runtimeType}',
              line: expr.line, column: expr.column);
        }
        var i = index.toInt();
        if (i < 0) i += target.length;
        if (i < 0 || i >= target.length) {
          throw EatRuntimeException('List index $index out of range (length ${target.length})',
              line: expr.line, column: expr.column);
        }
        return target[i];
      }
      if (target is Map) {
        return target[index.toString()];
      }
      if (target is String) {
        if (index is! num) {
          throw EatRuntimeException('String index must be integer, got ${index.runtimeType}',
              line: expr.line, column: expr.column);
        }
        var i = index.toInt();
        if (i < 0) i += target.length;
        if (i < 0 || i >= target.length) {
          throw EatRuntimeException('String index $index out of range',
              line: expr.line, column: expr.column);
        }
        return target[i];
      }
      throw EatRuntimeException('Cannot index type ${target.runtimeType}',
          line: expr.line, column: expr.column);
    }
    if (expr is EatSlice) {
      final target = evaluate(expr.target, env);
      final start = expr.start != null ? (evaluate(expr.start!, env) as num).toInt() : null;
      final stop = expr.stop != null ? (evaluate(expr.stop!, env) as num).toInt() : null;

      if (target is List) {
        return _sliceList(target, start, stop);
      }
      if (target is String) {
        return _sliceString(target, start, stop);
      }
      throw EatRuntimeException('Cannot slice type ${target.runtimeType}',
          line: expr.line, column: expr.column);
    }
    if (expr is EatDot) {
      final target = evaluate(expr.target, env);
      final prop = expr.property;

      if (target is Map) {
        if (target.containsKey(prop)) return target[prop];
        // Built-in map methods
        if (prop == 'get') {
          return EatNativeFunction('get', (pos, kw) {
            final key = pos.isNotEmpty ? pos[0].toString() : '';
            final def = pos.length > 1 ? pos[1] : null;
            return target.containsKey(key) ? target[key] : def;
          });
        }
        if (prop == 'keys') {
          return EatNativeFunction('keys', (pos, kw) => target.keys.toList());
        }
        if (prop == 'values') {
          return EatNativeFunction('values', (pos, kw) => target.values.toList());
        }
        return target[prop];
      }

      if (target is List) {
        if (prop == 'append') {
          return EatNativeFunction('append', (pos, kw) {
            if (pos.isNotEmpty) target.add(pos[0]);
            return null;
          });
        }
        if (prop == 'pop') {
          return EatNativeFunction('pop', (pos, kw) {
            return target.isNotEmpty ? target.removeLast() : null;
          });
        }
        if (prop == 'extend') {
          return EatNativeFunction('extend', (pos, kw) {
            if (pos.isNotEmpty && pos[0] is Iterable) target.addAll(pos[0]);
            return null;
          });
        }
        if (prop == 'clear') {
          return EatNativeFunction('clear', (pos, kw) {
            target.clear();
            return null;
          });
        }
      }

      throw EatRuntimeException('Object of type ${target.runtimeType} has no property or method "$prop"',
          line: expr.line, column: expr.column);
    }

    throw EatRuntimeException('Unknown expression type ${expr.runtimeType}',
        line: expr.line, column: expr.column);
  }

  dynamic _evalBinaryOp(EatBinaryOp expr, EatEnvironment env) {
    // Short-circuiting booleans
    if (expr.op == 'or') {
      final left = evaluate(expr.left, env);
      if (_isTruthy(left)) return left;
      return evaluate(expr.right, env);
    }
    if (expr.op == 'and') {
      final left = evaluate(expr.left, env);
      if (!_isTruthy(left)) return left;
      return evaluate(expr.right, env);
    }

    final left = evaluate(expr.left, env);
    final right = evaluate(expr.right, env);

    switch (expr.op) {
      case '+':
        return _evalAdd(left, right, expr.line, expr.column);
      case '-':
        return _evalSubtract(left, right, expr.line, expr.column);
      case '*':
        return _evalMultiply(left, right, expr.line, expr.column);
      case '/':
        return _evalDivide(left, right, expr.line, expr.column);
      case '//':
        if (left is num && right is num) {
          if (right == 0) throw EatRuntimeException('Integer division by zero', line: expr.line, column: expr.column);
          return (left ~/ right);
        }
        break;
      case '%':
        if (left is num && right is num) {
          if (right == 0) throw EatRuntimeException('Modulo by zero', line: expr.line, column: expr.column);
          return left % right;
        }
        break;
      case '**':
        if (left is num && right is num) return math.pow(left, right);
        break;
      case '==':
        return left == right;
      case '!=':
        return left != right;
      case '<':
        if (left is num && right is num) return left < right;
        break;
      case '<=':
        if (left is num && right is num) return left <= right;
        break;
      case '>':
        if (left is num && right is num) return left > right;
        break;
      case '>=':
        if (left is num && right is num) return left >= right;
        break;
      case 'in':
        if (right is List) return right.contains(left);
        if (right is Map) return right.containsKey(left.toString());
        if (right is String) return right.contains(left.toString());
        throw EatRuntimeException('Right operand of "in" must be list, dict, or string',
            line: expr.line, column: expr.column);
    }

    throw EatRuntimeException(
        'Operator "${expr.op}" not supported between ${left.runtimeType} and ${right.runtimeType}',
        line: expr.line,
        column: expr.column);
  }

  dynamic _evalAdd(dynamic l, dynamic r, int line, int col) {
    if (l is num && r is num) return l + r;
    if (l is String || r is String) return '${l.toString()}${r.toString()}';
    if (l is List && r is List) return [...l, ...r];
    throw EatRuntimeException('Cannot add ${l.runtimeType} and ${r.runtimeType}', line: line, column: col);
  }

  dynamic _evalSubtract(dynamic l, dynamic r, int line, int col) {
    if (l is num && r is num) return l - r;
    throw EatRuntimeException('Cannot subtract ${r.runtimeType} from ${l.runtimeType}', line: line, column: col);
  }

  dynamic _evalMultiply(dynamic l, dynamic r, int line, int col) {
    if (l is num && r is num) return l * r;
    if (l is String && r is int) return l * r;
    if (l is List && r is int) {
      final res = [];
      for (int i = 0; i < r; i++) {
        res.addAll(l);
      }
      return res;
    }
    throw EatRuntimeException('Cannot multiply ${l.runtimeType} by ${r.runtimeType}', line: line, column: col);
  }

  dynamic _evalDivide(dynamic l, dynamic r, int line, int col) {
    if (l is num && r is num) {
      if (r == 0) throw EatRuntimeException('Division by zero', line: line, column: col);
      return l / r;
    }
    throw EatRuntimeException('Cannot divide ${l.runtimeType} by ${r.runtimeType}', line: line, column: col);
  }

  List _sliceList(List target, int? start, int? stop) {
    var s = start ?? 0;
    var e = stop ?? target.length;
    if (s < 0) s += target.length;
    if (e < 0) e += target.length;
    s = s.clamp(0, target.length);
    e = e.clamp(s, target.length);
    return target.sublist(s, e);
  }

  String _sliceString(String target, int? start, int? stop) {
    var s = start ?? 0;
    var e = stop ?? target.length;
    if (s < 0) s += target.length;
    if (e < 0) e += target.length;
    s = s.clamp(0, target.length);
    e = e.clamp(s, target.length);
    return target.substring(s, e);
  }

  bool _isTruthy(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) return val.isNotEmpty;
    if (val is List) return val.isNotEmpty;
    if (val is Map) return val.isNotEmpty;
    return true;
  }

  void _tick(int line, int col) {
    if (++_stepCount > maxSteps) {
      throw EatRuntimeException(
        'Execution exceeded step limit ($maxSteps steps). Check for infinite loops.',
        line: line,
        column: col,
      );
    }
  }

  void _installBuiltins() {
    globals.define('print', EatNativeFunction('print', (pos, kw) {
      final msg = pos.map((p) => p.toString()).join(' ');
      outputLogs.add(msg);
      return null;
    }));

    globals.define('len', EatNativeFunction('len', (pos, kw) {
      if (pos.isEmpty) return 0;
      final arg = pos[0];
      if (arg is List) return arg.length;
      if (arg is Map) return arg.length;
      if (arg is String) return arg.length;
      return 0;
    }));

    globals.define('range', EatNativeFunction('range', (pos, kw) {
      if (pos.isEmpty) return [];
      int start = 0;
      int stop = 0;
      int step = 1;

      if (pos.length == 1) {
        stop = (pos[0] as num).toInt();
      } else if (pos.length == 2) {
        start = (pos[0] as num).toInt();
        stop = (pos[1] as num).toInt();
      } else {
        start = (pos[0] as num).toInt();
        stop = (pos[1] as num).toInt();
        step = (pos[2] as num).toInt();
        if (step == 0) step = 1;
      }

      final list = <int>[];
      if (step > 0) {
        for (int i = start; i < stop; i += step) {
          list.add(i);
        }
      } else {
        for (int i = start; i > stop; i += step) {
          list.add(i);
        }
      }
      return list;
    }));

    globals.define('int', EatNativeFunction('int', (pos, kw) {
      if (pos.isEmpty) return 0;
      final a = pos[0];
      if (a is num) return a.toInt();
      if (a is String) return int.tryParse(a) ?? (double.tryParse(a)?.toInt() ?? 0);
      if (a is bool) return a ? 1 : 0;
      return 0;
    }));

    globals.define('float', EatNativeFunction('float', (pos, kw) {
      if (pos.isEmpty) return 0.0;
      final a = pos[0];
      if (a is num) return a.toDouble();
      if (a is String) return double.tryParse(a) ?? 0.0;
      if (a is bool) return a ? 1.0 : 0.0;
      return 0.0;
    }));

    globals.define('str', EatNativeFunction('str', (pos, kw) {
      if (pos.isEmpty) return '';
      return pos[0].toString();
    }));

    globals.define('bool', EatNativeFunction('bool', (pos, kw) {
      if (pos.isEmpty) return false;
      return _isTruthy(pos[0]);
    }));

    globals.define('abs', EatNativeFunction('abs', (pos, kw) {
      if (pos.isEmpty || pos[0] is! num) return 0;
      return (pos[0] as num).abs();
    }));

    globals.define('min', EatNativeFunction('min', (pos, kw) {
      if (pos.isEmpty) return 0;
      if (pos.length == 1 && pos[0] is List) {
        final l = pos[0] as List;
        if (l.isEmpty) return 0;
        return l.reduce((a, b) => (a as num) < (b as num) ? a : b);
      }
      return pos.reduce((a, b) => (a as num) < (b as num) ? a : b);
    }));

    globals.define('max', EatNativeFunction('max', (pos, kw) {
      if (pos.isEmpty) return 0;
      if (pos.length == 1 && pos[0] is List) {
        final l = pos[0] as List;
        if (l.isEmpty) return 0;
        return l.reduce((a, b) => (a as num) > (b as num) ? a : b);
      }
      return pos.reduce((a, b) => (a as num) > (b as num) ? a : b);
    }));

    globals.define('round', EatNativeFunction('round', (pos, kw) {
      if (pos.isEmpty || pos[0] is! num) return 0;
      final val = (pos[0] as num).toDouble();
      if (pos.length > 1 && pos[1] is num) {
        final dec = (pos[1] as num).toInt();
        final p = math.pow(10, dec);
        return (val * p).round() / p;
      }
      return val.round();
    }));

    globals.define('sum', EatNativeFunction('sum', (pos, kw) {
      if (pos.isEmpty || pos[0] is! List) return 0;
      num total = 0;
      for (final item in pos[0] as List) {
        if (item is num) total += item;
      }
      return total;
    }));

    globals.define('sorted', EatNativeFunction('sorted', (pos, kw) {
      if (pos.isEmpty || pos[0] is! List) return [];
      final list = List.from(pos[0] as List);
      list.sort((a, b) => (a as Comparable).compareTo(b));
      return list;
    }));

    // Math module built-ins
    final mathModule = <String, dynamic>{
      'pi': math.pi,
      'e': math.e,
      'sin': EatNativeFunction('math.sin', (pos, kw) => math.sin((pos.first as num).toDouble())),
      'cos': EatNativeFunction('math.cos', (pos, kw) => math.cos((pos.first as num).toDouble())),
      'tan': EatNativeFunction('math.tan', (pos, kw) => math.tan((pos.first as num).toDouble())),
      'asin': EatNativeFunction('math.asin', (pos, kw) => math.asin((pos.first as num).toDouble())),
      'acos': EatNativeFunction('math.acos', (pos, kw) => math.acos((pos.first as num).toDouble())),
      'atan': EatNativeFunction('math.atan', (pos, kw) => math.atan((pos.first as num).toDouble())),
      'atan2': EatNativeFunction('math.atan2', (pos, kw) => math.atan2((pos[0] as num).toDouble(), (pos[1] as num).toDouble())),
      'exp': EatNativeFunction('math.exp', (pos, kw) => math.exp((pos.first as num).toDouble())),
      'log': EatNativeFunction('math.log', (pos, kw) => math.log((pos.first as num).toDouble())),
      'sqrt': EatNativeFunction('math.sqrt', (pos, kw) => math.sqrt((pos.first as num).toDouble())),
      'pow': EatNativeFunction('math.pow', (pos, kw) => math.pow((pos[0] as num).toDouble(), (pos[1] as num).toDouble())),
      'floor': EatNativeFunction('math.floor', (pos, kw) => (pos.first as num).floor()),
      'ceil': EatNativeFunction('math.ceil', (pos, kw) => (pos.first as num).ceil()),
      'tanh': EatNativeFunction('math.tanh', (pos, kw) {
        final x = (pos.first as num).toDouble();
        final ep = math.exp(x);
        final em = math.exp(-x);
        return (ep - em) / (ep + em);
      }),
      'random': EatNativeFunction('math.random', (pos, kw) => math.Random().nextDouble()),
    };
    globals.define('math', mathModule);

    // Random module built-ins
    final randomModule = <String, dynamic>{
      'random': EatNativeFunction('random.random', (pos, kw) => math.Random().nextDouble()),
      'uniform': EatNativeFunction('random.uniform', (pos, kw) {
        final a = (pos[0] as num).toDouble();
        final b = (pos[1] as num).toDouble();
        return a + math.Random().nextDouble() * (b - a);
      }),
      'choice': EatNativeFunction('random.choice', (pos, kw) {
        if (pos.isEmpty || pos[0] is! List || (pos[0] as List).isEmpty) return null;
        final list = pos[0] as List;
        return list[math.Random().nextInt(list.length)];
      }),
      'randint': EatNativeFunction('random.randint', (pos, kw) {
        final a = (pos[0] as num).toInt();
        final b = (pos[1] as num).toInt();
        return a + math.Random().nextInt(b - a + 1);
      }),
    };
    globals.define('random', randomModule);
  }
}
