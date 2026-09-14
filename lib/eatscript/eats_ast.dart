abstract class EatNode {
  final int line;
  final int column;

  const EatNode({required this.line, required this.column});
}

// ==========================================
// Statements
// ==========================================

abstract class EatStatement extends EatNode {
  const EatStatement({required super.line, required super.column});
}

class EatProgram extends EatNode {
  final List<EatStatement> statements;

  const EatProgram({
    required this.statements,
    required super.line,
    required super.column,
  });
}

class EatDef extends EatStatement {
  final String name;
  final List<String> params;
  final Map<String, EatExpression> defaultArgs;
  final List<EatStatement> body;

  const EatDef({
    required this.name,
    required this.params,
    required this.defaultArgs,
    required this.body,
    required super.line,
    required super.column,
  });
}

class EatElif {
  final EatExpression condition;
  final List<EatStatement> body;
  final int line;
  final int column;

  const EatElif({
    required this.condition,
    required this.body,
    required this.line,
    required this.column,
  });
}

class EatIf extends EatStatement {
  final EatExpression condition;
  final List<EatStatement> thenBranch;
  final List<EatElif> elifs;
  final List<EatStatement>? elseBranch;

  const EatIf({
    required this.condition,
    required this.thenBranch,
    this.elifs = const [],
    this.elseBranch,
    required super.line,
    required super.column,
  });
}

class EatForIn extends EatStatement {
  final String variable;
  final EatExpression iterable;
  final List<EatStatement> body;

  const EatForIn({
    required this.variable,
    required this.iterable,
    required this.body,
    required super.line,
    required super.column,
  });
}

class EatWhile extends EatStatement {
  final EatExpression condition;
  final List<EatStatement> body;

  const EatWhile({
    required this.condition,
    required this.body,
    required super.line,
    required super.column,
  });
}

class EatAssign extends EatStatement {
  final EatExpression target;
  final String op; // '=', '+=', '-=', '*=', '/='
  final EatExpression value;

  const EatAssign({
    required this.target,
    required this.op,
    required this.value,
    required super.line,
    required super.column,
  });
}

class EatReturn extends EatStatement {
  final EatExpression? value;

  const EatReturn({
    this.value,
    required super.line,
    required super.column,
  });
}

class EatExprStmt extends EatStatement {
  final EatExpression expr;

  const EatExprStmt({
    required this.expr,
    required super.line,
    required super.column,
  });
}

class EatPass extends EatStatement {
  const EatPass({required super.line, required super.column});
}

class EatBreak extends EatStatement {
  const EatBreak({required super.line, required super.column});
}

class EatContinue extends EatStatement {
  const EatContinue({required super.line, required super.column});
}

// ==========================================
// Expressions
// ==========================================

abstract class EatExpression extends EatNode {
  const EatExpression({required super.line, required super.column});
}

class EatLiteral extends EatExpression {
  final dynamic value;

  const EatLiteral(
    this.value, {
    required super.line,
    required super.column,
  });
}

class EatIdentifier extends EatExpression {
  final String name;

  const EatIdentifier(
    this.name, {
    required super.line,
    required super.column,
  });
}

class EatBinaryOp extends EatExpression {
  final EatExpression left;
  final String op;
  final EatExpression right;

  const EatBinaryOp({
    required this.left,
    required this.op,
    required this.right,
    required super.line,
    required super.column,
  });
}

class EatUnaryOp extends EatExpression {
  final String op;
  final EatExpression operand;

  const EatUnaryOp({
    required this.op,
    required this.operand,
    required super.line,
    required super.column,
  });
}

class EatCall extends EatExpression {
  final EatExpression callee;
  final List<EatExpression> positionalArgs;
  final Map<String, EatExpression> keywordArgs;

  const EatCall({
    required this.callee,
    required this.positionalArgs,
    required this.keywordArgs,
    required super.line,
    required super.column,
  });
}

class EatIndex extends EatExpression {
  final EatExpression target;
  final EatExpression index;

  const EatIndex({
    required this.target,
    required this.index,
    required super.line,
    required super.column,
  });
}

class EatSlice extends EatExpression {
  final EatExpression target;
  final EatExpression? start;
  final EatExpression? stop;
  final EatExpression? step;

  const EatSlice({
    required this.target,
    this.start,
    this.stop,
    this.step,
    required super.line,
    required super.column,
  });
}

class EatDot extends EatExpression {
  final EatExpression target;
  final String property;

  const EatDot({
    required this.target,
    required this.property,
    required super.line,
    required super.column,
  });
}

class EatListLiteral extends EatExpression {
  final List<EatExpression> elements;

  const EatListLiteral({
    required this.elements,
    required super.line,
    required super.column,
  });
}

class EatDictEntry {
  final EatExpression key;
  final EatExpression value;

  const EatDictEntry({required this.key, required this.value});
}

class EatDictLiteral extends EatExpression {
  final List<EatDictEntry> entries;

  const EatDictLiteral({
    required this.entries,
    required super.line,
    required super.column,
  });
}
