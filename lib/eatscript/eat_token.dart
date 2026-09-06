enum EatTokenType {
  // Whitespace / Structure
  newline,
  indent,
  dedent,
  eof,

  // Literals & Identifiers
  identifier,
  number,
  string,

  // Keywords
  kwDef,
  kwReturn,
  kwIf,
  kwElif,
  kwElse,
  kwFor,
  kwIn,
  kwWhile,
  kwBreak,
  kwContinue,
  kwPass,
  kwImport,
  kwFrom,
  kwAnd,
  kwOr,
  kwNot,
  kwTrue,
  kwFalse,
  kwNone,

  // Arithmetic & String Ops
  plus,
  minus,
  multiply,
  divide,
  floorDivide,
  modulo,
  power,

  // Assignment Ops
  assign,
  plusAssign,
  minusAssign,
  multiplyAssign,
  divideAssign,

  // Comparison Ops
  equal,
  notEqual,
  lessThan,
  lessEqual,
  greaterThan,
  greaterEqual,

  // Delimiters
  leftParen,
  rightParen,
  leftBracket,
  rightBracket,
  leftBrace,
  rightBrace,
  colon,
  comma,
  dot,
}

class EatToken {
  final EatTokenType type;
  final String lexeme;
  final dynamic literal;
  final int line;
  final int column;

  const EatToken({
    required this.type,
    required this.lexeme,
    this.literal,
    required this.line,
    required this.column,
  });

  @override
  String toString() =>
      'EatToken($type, "$lexeme", line: $line, col: $column${literal != null ? ", lit: $literal" : ""})';
}
