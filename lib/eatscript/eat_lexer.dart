import 'eat_token.dart';

class EatLexerException implements Exception {
  final String message;
  final int line;
  final int column;

  EatLexerException(this.message, {required this.line, required this.column});

  @override
  String toString() => 'EatLexerException: $message at line $line, column $column';
}

class EatLexer {
  final String source;
  final List<EatToken> _tokens = [];
  final List<int> _indentStack = [0];
  int _parenDepth = 0; // Tracks (), [], {} for implicit line continuation

  int _start = 0;
  int _current = 0;
  int _line = 1;
  int _column = 1;
  int _startColumn = 1;

  EatLexer(this.source);

  List<EatToken> tokenize() {
    _tokens.clear();
    _indentStack.clear();
    _indentStack.add(0);
    _parenDepth = 0;
    _current = 0;
    _line = 1;
    _column = 1;

    bool atStartOfLine = true;

    while (!_isAtEnd()) {
      if (atStartOfLine) {
        atStartOfLine = false;
        _handleIndentation();
        if (_isAtEnd()) break;
      }

      _start = _current;
      _startColumn = _column;

      final c = _advance();

      switch (c) {
        case ' ':
        case '\t':
        case '\r':
          // Whitespace within line
          break;

        case '\n':
          _line++;
          _column = 1;
          if (_parenDepth == 0) {
            // Only emit newline if the last token was not already a newline/indent/dedent
            if (_tokens.isNotEmpty &&
                _tokens.last.type != EatTokenType.newline &&
                _tokens.last.type != EatTokenType.indent) {
              _tokens.add(EatToken(
                type: EatTokenType.newline,
                lexeme: '\n',
                line: _line - 1,
                column: _startColumn,
              ));
            }
            atStartOfLine = true;
          }
          break;

        case '#':
          // Comment to end of line
          while (_peek() != '\n' && !_isAtEnd()) {
            _advance();
          }
          break;

        case '(':
          _parenDepth++;
          _addToken(EatTokenType.leftParen);
          break;
        case ')':
          if (_parenDepth > 0) _parenDepth--;
          _addToken(EatTokenType.rightParen);
          break;
        case '[':
          _parenDepth++;
          _addToken(EatTokenType.leftBracket);
          break;
        case ']':
          if (_parenDepth > 0) _parenDepth--;
          _addToken(EatTokenType.rightBracket);
          break;
        case '{':
          _parenDepth++;
          _addToken(EatTokenType.leftBrace);
          break;
        case '}':
          if (_parenDepth > 0) _parenDepth--;
          _addToken(EatTokenType.rightBrace);
          break;

        case ':':
          _addToken(EatTokenType.colon);
          break;
        case ',':
          _addToken(EatTokenType.comma);
          break;
        case '.':
          _addToken(EatTokenType.dot);
          break;

        case '+':
          if (_match('=')) {
            _addToken(EatTokenType.plusAssign);
          } else {
            _addToken(EatTokenType.plus);
          }
          break;

        case '-':
          if (_match('=')) {
            _addToken(EatTokenType.minusAssign);
          } else {
            _addToken(EatTokenType.minus);
          }
          break;

        case '*':
          if (_match('*')) {
            _addToken(EatTokenType.power);
          } else if (_match('=')) {
            _addToken(EatTokenType.multiplyAssign);
          } else {
            _addToken(EatTokenType.multiply);
          }
          break;

        case '/':
          if (_match('/')) {
            _addToken(EatTokenType.floorDivide);
          } else if (_match('=')) {
            _addToken(EatTokenType.divideAssign);
          } else {
            _addToken(EatTokenType.divide);
          }
          break;

        case '%':
          _addToken(EatTokenType.modulo);
          break;

        case '=':
          if (_match('=')) {
            _addToken(EatTokenType.equal);
          } else {
            _addToken(EatTokenType.assign);
          }
          break;

        case '!':
          if (_match('=')) {
            _addToken(EatTokenType.notEqual);
          } else {
            throw EatLexerException("Unexpected character '!' (did you mean '!=' or 'not'?)",
                line: _line, column: _startColumn);
          }
          break;

        case '<':
          if (_match('=')) {
            _addToken(EatTokenType.lessEqual);
          } else {
            _addToken(EatTokenType.lessThan);
          }
          break;

        case '>':
          if (_match('=')) {
            _addToken(EatTokenType.greaterEqual);
          } else {
            _addToken(EatTokenType.greaterThan);
          }
          break;

        case '"':
        case "'":
          _scanString(c);
          break;

        default:
          if (_isDigit(c)) {
            _scanNumber(c);
          } else if (_isAlpha(c)) {
            _scanIdentifier();
          } else {
            throw EatLexerException("Unexpected character '$c'",
                line: _line, column: _startColumn);
          }
          break;
      }
    }

    // Trailing newline if needed
    if (_tokens.isNotEmpty &&
        _tokens.last.type != EatTokenType.newline &&
        _tokens.last.type != EatTokenType.dedent) {
      _tokens.add(EatToken(
        type: EatTokenType.newline,
        lexeme: '\n',
        line: _line,
        column: _column,
      ));
    }

    // Emit remaining DEDENT tokens down to 0
    while (_indentStack.length > 1) {
      _indentStack.removeLast();
      _tokens.add(EatToken(
        type: EatTokenType.dedent,
        lexeme: '',
        line: _line,
        column: _column,
      ));
    }

    // Emit EOF
    _tokens.add(EatToken(
      type: EatTokenType.eof,
      lexeme: '',
      line: _line,
      column: _column,
    ));

    return _tokens;
  }

  void _handleIndentation() {
    int indentSpaces = 0;
    int peekIdx = _current;

    while (peekIdx < source.length) {
      final ch = source[peekIdx];
      if (ch == ' ') {
        indentSpaces++;
        peekIdx++;
      } else if (ch == '\t') {
        indentSpaces += 4;
        peekIdx++;
      } else {
        break;
      }
    }

    // If blank line or comment line, ignore indentation
    if (peekIdx >= source.length ||
        source[peekIdx] == '\r' ||
        source[peekIdx] == '\n' ||
        source[peekIdx] == '#') {
      return;
    }

    // Advance _current and _column past leading whitespace
    while (_current < peekIdx) {
      _advance();
    }

    final currentIndent = _indentStack.last;

    if (indentSpaces > currentIndent) {
      _indentStack.add(indentSpaces);
      _tokens.add(EatToken(
        type: EatTokenType.indent,
        lexeme: '',
        line: _line,
        column: 1,
      ));
    } else if (indentSpaces < currentIndent) {
      while (_indentStack.last > indentSpaces) {
        _indentStack.removeLast();
        _tokens.add(EatToken(
          type: EatTokenType.dedent,
          lexeme: '',
          line: _line,
          column: 1,
        ));
      }
      if (_indentStack.last != indentSpaces) {
        throw EatLexerException(
          'Inconsistent indentation: expected ${_indentStack.last} spaces but found $indentSpaces',
          line: _line,
          column: 1,
        );
      }
    }
  }

  void _scanString(String quote) {
    bool isTriple = false;
    if (_peek() == quote && _peekNext() == quote) {
      isTriple = true;
      _advance();
      _advance();
    }

    final buffer = StringBuffer();

    while (!_isAtEnd()) {
      if (isTriple) {
        if (_peek() == quote &&
            _peekNext() == quote &&
            _peekAt(2) == quote) {
          _advance();
          _advance();
          _advance();
          _tokens.add(EatToken(
            type: EatTokenType.string,
            lexeme: source.substring(_start, _current),
            literal: buffer.toString(),
            line: _line,
            column: _startColumn,
          ));
          return;
        }
      } else {
        if (_peek() == quote) {
          _advance();
          _tokens.add(EatToken(
            type: EatTokenType.string,
            lexeme: source.substring(_start, _current),
            literal: buffer.toString(),
            line: _line,
            column: _startColumn,
          ));
          return;
        }
        if (_peek() == '\n') {
          throw EatLexerException('Unterminated string literal on line $_line',
              line: _line, column: _startColumn);
        }
      }

      final c = _advance();
      if (c == '\\' && !_isAtEnd()) {
        final esc = _advance();
        switch (esc) {
          case 'n':
            buffer.write('\n');
            break;
          case 't':
            buffer.write('\t');
            break;
          case 'r':
            buffer.write('\r');
            break;
          case '\\':
            buffer.write('\\');
            break;
          case '"':
            buffer.write('"');
            break;
          case "'":
            buffer.write("'");
            break;
          default:
            buffer.write(esc);
            break;
        }
      } else {
        if (c == '\n') {
          _line++;
          _column = 1;
        }
        buffer.write(c);
      }
    }

    throw EatLexerException('Unterminated string literal at end of file',
        line: _line, column: _startColumn);
  }

  void _scanNumber(String firstDigit) {
    bool isHex = false;
    if (firstDigit == '0' && (_peek() == 'x' || _peek() == 'X')) {
      isHex = true;
      _advance(); // 'x'
      while (_isHexDigit(_peek())) {
        _advance();
      }
      final text = source.substring(_start, _current);
      final val = int.tryParse(text) ?? 0;
      _tokens.add(EatToken(
        type: EatTokenType.number,
        lexeme: text,
        literal: val,
        line: _line,
        column: _startColumn,
      ));
      return;
    }

    while (_isDigit(_peek())) {
      _advance();
    }

    bool isFloat = false;
    if (_peek() == '.' && _isDigit(_peekNext())) {
      isFloat = true;
      _advance(); // '.'
      while (_isDigit(_peek())) {
        _advance();
      }
    }

    if (_peek() == 'e' || _peek() == 'E') {
      isFloat = true;
      _advance();
      if (_peek() == '+' || _peek() == '-') {
        _advance();
      }
      while (_isDigit(_peek())) {
        _advance();
      }
    }

    final text = source.substring(_start, _current);
    final num val = isFloat ? (double.tryParse(text) ?? 0.0) : (int.tryParse(text) ?? 0);
    _tokens.add(EatToken(
      type: EatTokenType.number,
      lexeme: text,
      literal: val,
      line: _line,
      column: _startColumn,
    ));
  }

  void _scanIdentifier() {
    while (_isAlphaNumeric(_peek())) {
      _advance();
    }

    final text = source.substring(_start, _current);
    final kwType = _keywords[text];

    if (kwType != null) {
      dynamic literal;
      if (kwType == EatTokenType.kwTrue) literal = true;
      if (kwType == EatTokenType.kwFalse) literal = false;
      if (kwType == EatTokenType.kwNone) literal = null;

      _tokens.add(EatToken(
        type: kwType,
        lexeme: text,
        literal: literal,
        line: _line,
        column: _startColumn,
      ));
    } else {
      _tokens.add(EatToken(
        type: EatTokenType.identifier,
        lexeme: text,
        line: _line,
        column: _startColumn,
      ));
    }
  }

  static const Map<String, EatTokenType> _keywords = {
    'def': EatTokenType.kwDef,
    'return': EatTokenType.kwReturn,
    'if': EatTokenType.kwIf,
    'elif': EatTokenType.kwElif,
    'else': EatTokenType.kwElse,
    'for': EatTokenType.kwFor,
    'in': EatTokenType.kwIn,
    'while': EatTokenType.kwWhile,
    'break': EatTokenType.kwBreak,
    'continue': EatTokenType.kwContinue,
    'pass': EatTokenType.kwPass,
    'import': EatTokenType.kwImport,
    'from': EatTokenType.kwFrom,
    'and': EatTokenType.kwAnd,
    'or': EatTokenType.kwOr,
    'not': EatTokenType.kwNot,
    'True': EatTokenType.kwTrue,
    'False': EatTokenType.kwFalse,
    'None': EatTokenType.kwNone,
    'true': EatTokenType.kwTrue,
    'false': EatTokenType.kwFalse,
    'null': EatTokenType.kwNone,
    'nil': EatTokenType.kwNone,
  };

  bool _isAtEnd() => _current >= source.length;

  String _advance() {
    final c = source[_current++];
    _column++;
    return c;
  }

  bool _match(String expected) {
    if (_isAtEnd()) return false;
    if (source[_current] != expected) return false;
    _current++;
    _column++;
    return true;
  }

  String _peek() {
    if (_isAtEnd()) return '\x00';
    return source[_current];
  }

  String _peekNext() {
    if (_current + 1 >= source.length) return '\x00';
    return source[_current + 1];
  }

  String _peekAt(int offset) {
    if (_current + offset >= source.length) return '\x00';
    return source[_current + offset];
  }

  void _addToken(EatTokenType type) {
    final text = source.substring(_start, _current);
    _tokens.add(EatToken(
      type: type,
      lexeme: text,
      line: _line,
      column: _startColumn,
    ));
  }

  bool _isDigit(String c) {
    final code = c.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  bool _isHexDigit(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 70) ||
        (code >= 97 && code <= 102);
  }

  bool _isAlpha(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        c == '_';
  }

  bool _isAlphaNumeric(String c) {
    return _isAlpha(c) || _isDigit(c);
  }
}
