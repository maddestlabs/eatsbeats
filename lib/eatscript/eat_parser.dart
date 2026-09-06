import 'eat_ast.dart';
import 'eat_token.dart';

class EatParserException implements Exception {
  final String message;
  final int line;
  final int column;

  EatParserException(this.message, {required this.line, required this.column});

  @override
  String toString() => 'EatParserException: $message at line $line, column $column';
}

class EatParser {
  final List<EatToken> tokens;
  int _current = 0;

  EatParser(this.tokens);

  EatProgram parse() {
    final statements = <EatStatement>[];
    _skipNewlines();

    while (!_isAtEnd()) {
      statements.add(_statement());
      _skipNewlines();
    }

    final line = statements.isNotEmpty ? statements.first.line : 1;
    final col = statements.isNotEmpty ? statements.first.column : 1;
    return EatProgram(statements: statements, line: line, column: col);
  }

  // ==========================================
  // Statements
  // ==========================================

  EatStatement _statement() {
    _skipNewlines();

    if (_match(EatTokenType.kwDef)) {
      return _defStatement();
    }
    if (_match(EatTokenType.kwIf)) {
      return _ifStatement();
    }
    if (_match(EatTokenType.kwFor)) {
      return _forStatement();
    }
    if (_match(EatTokenType.kwWhile)) {
      return _whileStatement();
    }
    if (_match(EatTokenType.kwReturn)) {
      return _returnStatement();
    }
    if (_match(EatTokenType.kwPass)) {
      final tok = _previous();
      _match(EatTokenType.newline);
      return EatPass(line: tok.line, column: tok.column);
    }
    if (_match(EatTokenType.kwBreak)) {
      final tok = _previous();
      _match(EatTokenType.newline);
      return EatBreak(line: tok.line, column: tok.column);
    }
    if (_match(EatTokenType.kwContinue)) {
      final tok = _previous();
      _match(EatTokenType.newline);
      return EatContinue(line: tok.line, column: tok.column);
    }
    if (_match(EatTokenType.kwImport)) {
      final tok = _previous();
      while (!_check(EatTokenType.newline) && !_check(EatTokenType.eof)) {
        _advance();
      }
      _match(EatTokenType.newline);
      return EatPass(line: tok.line, column: tok.column);
    }
    if (_match(EatTokenType.kwFrom)) {
      final tok = _previous();
      while (!_check(EatTokenType.newline) && !_check(EatTokenType.eof)) {
        _advance();
      }
      _match(EatTokenType.newline);
      return EatPass(line: tok.line, column: tok.column);
    }

    return _assignOrExprStatement();
  }

  EatStatement _defStatement() {
    final defToken = _previous();
    final nameTok = _consume(EatTokenType.identifier, 'Expected function name after "def"');
    _consume(EatTokenType.leftParen, 'Expected "(" after function name');

    final params = <String>[];
    final defaultArgs = <String, EatExpression>{};

    if (!_check(EatTokenType.rightParen)) {
      do {
        final pTok = _consume(EatTokenType.identifier, 'Expected parameter name');
        params.add(pTok.lexeme);

        if (_match(EatTokenType.assign)) {
          defaultArgs[pTok.lexeme] = _expression();
        }
      } while (_match(EatTokenType.comma));
    }

    _consume(EatTokenType.rightParen, 'Expected ")" after parameter list');
    _consume(EatTokenType.colon, 'Expected ":" after function signature');

    final body = _block();
    return EatDef(
      name: nameTok.lexeme,
      params: params,
      defaultArgs: defaultArgs,
      body: body,
      line: defToken.line,
      column: defToken.column,
    );
  }

  EatStatement _ifStatement() {
    final ifTok = _previous();
    final condition = _expression();
    _consume(EatTokenType.colon, 'Expected ":" after if condition');
    final thenBranch = _block();

    final elifs = <EatElif>[];
    while (_match(EatTokenType.kwElif)) {
      final elifTok = _previous();
      final elifCond = _expression();
      _consume(EatTokenType.colon, 'Expected ":" after elif condition');
      final elifBody = _block();
      elifs.add(EatElif(
        condition: elifCond,
        body: elifBody,
        line: elifTok.line,
        column: elifTok.column,
      ));
    }

    List<EatStatement>? elseBranch;
    if (_match(EatTokenType.kwElse)) {
      _consume(EatTokenType.colon, 'Expected ":" after else');
      elseBranch = _block();
    }

    return EatIf(
      condition: condition,
      thenBranch: thenBranch,
      elifs: elifs,
      elseBranch: elseBranch,
      line: ifTok.line,
      column: ifTok.column,
    );
  }

  EatStatement _forStatement() {
    final forTok = _previous();
    final varTok = _consume(EatTokenType.identifier, 'Expected loop variable name after "for"');
    _consume(EatTokenType.kwIn, 'Expected "in" after loop variable');
    final iterable = _expression();
    _consume(EatTokenType.colon, 'Expected ":" after for loop clause');
    final body = _block();

    return EatForIn(
      variable: varTok.lexeme,
      iterable: iterable,
      body: body,
      line: forTok.line,
      column: forTok.column,
    );
  }

  EatStatement _whileStatement() {
    final whileTok = _previous();
    final condition = _expression();
    _consume(EatTokenType.colon, 'Expected ":" after while condition');
    final body = _block();

    return EatWhile(
      condition: condition,
      body: body,
      line: whileTok.line,
      column: whileTok.column,
    );
  }

  EatStatement _returnStatement() {
    final retTok = _previous();
    EatExpression? val;
    if (!_check(EatTokenType.newline) && !_check(EatTokenType.eof) && !_check(EatTokenType.dedent)) {
      val = _expression();
    }
    _match(EatTokenType.newline);
    return EatReturn(value: val, line: retTok.line, column: retTok.column);
  }

  EatStatement _assignOrExprStatement() {
    final expr = _expression();

    if (_matchAny([
      EatTokenType.assign,
      EatTokenType.plusAssign,
      EatTokenType.minusAssign,
      EatTokenType.multiplyAssign,
      EatTokenType.divideAssign,
    ])) {
      final opTok = _previous();
      final val = _expression();
      _match(EatTokenType.newline);
      return EatAssign(
        target: expr,
        op: opTok.lexeme,
        value: val,
        line: opTok.line,
        column: opTok.column,
      );
    }

    _match(EatTokenType.newline);
    return EatExprStmt(expr: expr, line: expr.line, column: expr.column);
  }

  List<EatStatement> _block() {
    if (_match(EatTokenType.newline)) {
      _skipNewlines();
      _consume(EatTokenType.indent, 'Expected indented block');
      final stmts = <EatStatement>[];
      while (!_check(EatTokenType.dedent) && !_isAtEnd()) {
        _skipNewlines();
        if (_check(EatTokenType.dedent) || _isAtEnd()) break;
        stmts.add(_statement());
        _skipNewlines();
      }
      _consume(EatTokenType.dedent, 'Expected dedent after block');
      return stmts;
    } else {
      // Inline block on same line
      return [_statement()];
    }
  }

  // ==========================================
  // Expressions (Pratt Parsing)
  // ==========================================

  EatExpression _expression() {
    return _orExpression();
  }

  EatExpression _orExpression() {
    var expr = _andExpression();
    while (_match(EatTokenType.kwOr)) {
      final op = _previous();
      final right = _andExpression();
      expr = EatBinaryOp(left: expr, op: 'or', right: right, line: op.line, column: op.column);
    }
    return expr;
  }

  EatExpression _andExpression() {
    var expr = _notExpression();
    while (_match(EatTokenType.kwAnd)) {
      final op = _previous();
      final right = _notExpression();
      expr = EatBinaryOp(left: expr, op: 'and', right: right, line: op.line, column: op.column);
    }
    return expr;
  }

  EatExpression _notExpression() {
    if (_match(EatTokenType.kwNot)) {
      final op = _previous();
      final operand = _notExpression();
      return EatUnaryOp(op: 'not', operand: operand, line: op.line, column: op.column);
    }
    return _comparisonExpression();
  }

  EatExpression _comparisonExpression() {
    var expr = _additionExpression();

    while (_matchAny([
      EatTokenType.equal,
      EatTokenType.notEqual,
      EatTokenType.lessThan,
      EatTokenType.lessEqual,
      EatTokenType.greaterThan,
      EatTokenType.greaterEqual,
      EatTokenType.kwIn,
    ])) {
      final op = _previous();
      final right = _additionExpression();
      expr = EatBinaryOp(left: expr, op: op.lexeme, right: right, line: op.line, column: op.column);
    }
    return expr;
  }

  EatExpression _additionExpression() {
    var expr = _multiplicationExpression();

    while (_matchAny([EatTokenType.plus, EatTokenType.minus])) {
      final op = _previous();
      final right = _multiplicationExpression();
      expr = EatBinaryOp(left: expr, op: op.lexeme, right: right, line: op.line, column: op.column);
    }
    return expr;
  }

  EatExpression _multiplicationExpression() {
    var expr = _unaryExpression();

    while (_matchAny([
      EatTokenType.multiply,
      EatTokenType.divide,
      EatTokenType.floorDivide,
      EatTokenType.modulo,
    ])) {
      final op = _previous();
      final right = _unaryExpression();
      expr = EatBinaryOp(left: expr, op: op.lexeme, right: right, line: op.line, column: op.column);
    }
    return expr;
  }

  EatExpression _unaryExpression() {
    if (_matchAny([EatTokenType.minus, EatTokenType.plus])) {
      final op = _previous();
      final right = _unaryExpression();
      return EatUnaryOp(op: op.lexeme, operand: right, line: op.line, column: op.column);
    }
    return _powerExpression();
  }

  EatExpression _powerExpression() {
    var expr = _callOrAccessExpression();
    if (_match(EatTokenType.power)) {
      final op = _previous();
      final right = _unaryExpression(); // Right-associative
      expr = EatBinaryOp(left: expr, op: '**', right: right, line: op.line, column: op.column);
    }
    return expr;
  }

  EatExpression _callOrAccessExpression() {
    var expr = _primaryExpression();

    while (true) {
      if (_match(EatTokenType.leftParen)) {
        // Function Call
        expr = _finishCall(expr);
      } else if (_match(EatTokenType.leftBracket)) {
        // Index or Slice
        expr = _finishIndexOrSlice(expr);
      } else if (_match(EatTokenType.dot)) {
        // Dot access
        final propTok = _consume(EatTokenType.identifier, 'Expected property name after "."');
        expr = EatDot(
          target: expr,
          property: propTok.lexeme,
          line: propTok.line,
          column: propTok.column,
        );
      } else {
        break;
      }
    }

    return expr;
  }

  EatExpression _finishCall(EatExpression callee) {
    final posArgs = <EatExpression>[];
    final kwArgs = <String, EatExpression>{};

    if (!_check(EatTokenType.rightParen)) {
      do {
        _skipNewlines();
        if (_check(EatTokenType.rightParen)) break;

        // Check if keyword arg: identifier = expr
        if (_check(EatTokenType.identifier) && _peekNextToken()?.type == EatTokenType.assign) {
          final key = _advance().lexeme;
          _advance(); // '='
          final val = _expression();
          kwArgs[key] = val;
        } else {
          posArgs.add(_expression());
        }
        _skipNewlines();
      } while (_match(EatTokenType.comma));
    }

    _skipNewlines();
    final closeParen = _consume(EatTokenType.rightParen, 'Expected ")" after argument list');
    return EatCall(
      callee: callee,
      positionalArgs: posArgs,
      keywordArgs: kwArgs,
      line: closeParen.line,
      column: closeParen.column,
    );
  }

  EatExpression _finishIndexOrSlice(EatExpression target) {
    // Check if empty start for slice: [:stop]
    if (_match(EatTokenType.colon)) {
      EatExpression? stop;
      if (!_check(EatTokenType.rightBracket) && !_check(EatTokenType.colon)) {
        stop = _expression();
      }
      EatExpression? step;
      if (_match(EatTokenType.colon)) {
        if (!_check(EatTokenType.rightBracket)) {
          step = _expression();
        }
      }
      final closeBracket = _consume(EatTokenType.rightBracket, 'Expected "]" after slice');
      return EatSlice(
        target: target,
        start: null,
        stop: stop,
        step: step,
        line: closeBracket.line,
        column: closeBracket.column,
      );
    }

    final firstExpr = _expression();

    if (_match(EatTokenType.colon)) {
      // Slice: [start:stop:step]
      EatExpression? stop;
      if (!_check(EatTokenType.rightBracket) && !_check(EatTokenType.colon)) {
        stop = _expression();
      }
      EatExpression? step;
      if (_match(EatTokenType.colon)) {
        if (!_check(EatTokenType.rightBracket)) {
          step = _expression();
        }
      }
      final closeBracket = _consume(EatTokenType.rightBracket, 'Expected "]" after slice');
      return EatSlice(
        target: target,
        start: firstExpr,
        stop: stop,
        step: step,
        line: closeBracket.line,
        column: closeBracket.column,
      );
    }

    final closeBracket = _consume(EatTokenType.rightBracket, 'Expected "]" after index');
    return EatIndex(
      target: target,
      index: firstExpr,
      line: closeBracket.line,
      column: closeBracket.column,
    );
  }

  EatExpression _primaryExpression() {
    if (_match(EatTokenType.kwTrue)) {
      final t = _previous();
      return EatLiteral(true, line: t.line, column: t.column);
    }
    if (_match(EatTokenType.kwFalse)) {
      final t = _previous();
      return EatLiteral(false, line: t.line, column: t.column);
    }
    if (_match(EatTokenType.kwNone)) {
      final t = _previous();
      return EatLiteral(null, line: t.line, column: t.column);
    }
    if (_match(EatTokenType.number)) {
      final t = _previous();
      return EatLiteral(t.literal, line: t.line, column: t.column);
    }
    if (_match(EatTokenType.string)) {
      final t = _previous();
      return EatLiteral(t.literal, line: t.line, column: t.column);
    }
    if (_match(EatTokenType.identifier)) {
      final t = _previous();
      return EatIdentifier(t.lexeme, line: t.line, column: t.column);
    }

    if (_match(EatTokenType.leftParen)) {
      _skipNewlines();
      final expr = _expression();
      _skipNewlines();
      _consume(EatTokenType.rightParen, 'Expected ")" after grouped expression');
      return expr;
    }

    if (_match(EatTokenType.leftBracket)) {
      // List literal [1, 2, 3]
      final startTok = _previous();
      final elements = <EatExpression>[];
      _skipNewlines();
      if (!_check(EatTokenType.rightBracket)) {
        do {
          _skipNewlines();
          if (_check(EatTokenType.rightBracket)) break;
          elements.add(_expression());
          _skipNewlines();
        } while (_match(EatTokenType.comma));
      }
      _skipNewlines();
      _consume(EatTokenType.rightBracket, 'Expected "]" after list literal');
      return EatListLiteral(elements: elements, line: startTok.line, column: startTok.column);
    }

    if (_match(EatTokenType.leftBrace)) {
      // Dict literal {"a": 1, "b": 2}
      final startTok = _previous();
      final entries = <EatDictEntry>[];
      _skipNewlines();
      if (!_check(EatTokenType.rightBrace)) {
        do {
          _skipNewlines();
          if (_check(EatTokenType.rightBrace)) break;
          final key = _expression();
          _consume(EatTokenType.colon, 'Expected ":" between key and value in dict');
          final val = _expression();
          entries.add(EatDictEntry(key: key, value: val));
          _skipNewlines();
        } while (_match(EatTokenType.comma));
      }
      _skipNewlines();
      _consume(EatTokenType.rightBrace, 'Expected "}" after dict literal');
      return EatDictLiteral(entries: entries, line: startTok.line, column: startTok.column);
    }

    final cur = _peek();
    throw EatParserException('Unexpected token "${cur.lexeme}"', line: cur.line, column: cur.column);
  }

  // ==========================================
  // Helper methods
  // ==========================================

  bool _match(EatTokenType type) {
    if (_check(type)) {
      _advance();
      return true;
    }
    return false;
  }

  bool _matchAny(List<EatTokenType> types) {
    for (final t in types) {
      if (_check(t)) {
        _advance();
        return true;
      }
    }
    return false;
  }

  bool _check(EatTokenType type) {
    if (_isAtEnd()) return type == EatTokenType.eof;
    return _peek().type == type;
  }

  EatToken _advance() {
    if (!_isAtEnd()) _current++;
    return _previous();
  }

  bool _isAtEnd() => _current >= tokens.length || _peek().type == EatTokenType.eof;

  EatToken _peek() {
    if (_current >= tokens.length) return tokens.last;
    return tokens[_current];
  }

  EatToken? _peekNextToken() {
    if (_current + 1 >= tokens.length) return null;
    return tokens[_current + 1];
  }

  EatToken _previous() => tokens[_current - 1];

  EatToken _consume(EatTokenType type, String message) {
    if (_check(type)) return _advance();
    final tok = _peek();
    throw EatParserException('$message (got "${tok.lexeme}")', line: tok.line, column: tok.column);
  }

  void _skipNewlines() {
    while (_check(EatTokenType.newline)) {
      _advance();
    }
  }
}
