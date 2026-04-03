/// 안전한 수학 연산 계산기 도구
class CalculatorTool {
  /// 수학 표현식을 평가합니다.
  /// 지원: +, -, *, /, ^, (, ), sqrt, log, sin, cos, tan, pi, e
  String run(String expression) {
    try {
      final result = _evaluate(expression.trim());
      return result.toString();
    } catch (e) {
      return '계산 오류: $e';
    }
  }

  double _evaluate(String expr) {
    expr = expr.replaceAll(' ', '');
    // 상수 치환
    expr = expr.replaceAll('pi', '3.141592653589793');
    expr = expr.replaceAll('PI', '3.141592653589793');
    expr = expr.replaceAll(RegExp(r'(?<![a-zA-Z])e(?![a-zA-Z])'), '2.718281828459045');

    final parser = _ExprParser(expr);
    final result = parser.parseExpression();
    if (parser.pos < expr.length) {
      throw FormatException('예상하지 못한 문자: ${expr[parser.pos]}');
    }
    return result;
  }
}

class _ExprParser {
  final String input;
  int pos = 0;

  _ExprParser(this.input);

  double parseExpression() {
    var result = parseTerm();
    while (pos < input.length && (input[pos] == '+' || input[pos] == '-')) {
      final op = input[pos++];
      final term = parseTerm();
      result = op == '+' ? result + term : result - term;
    }
    return result;
  }

  double parseTerm() {
    var result = parsePower();
    while (pos < input.length && (input[pos] == '*' || input[pos] == '/')) {
      final op = input[pos++];
      final factor = parsePower();
      if (op == '/' && factor == 0) throw Exception('0으로 나눌 수 없습니다');
      result = op == '*' ? result * factor : result / factor;
    }
    return result;
  }

  double parsePower() {
    var result = parseUnary();
    if (pos < input.length && input[pos] == '^') {
      pos++;
      final exp = parseUnary();
      result = _pow(result, exp);
    }
    return result;
  }

  double parseUnary() {
    if (pos < input.length && input[pos] == '-') {
      pos++;
      return -parseUnary();
    }
    return parsePrimary();
  }

  double parsePrimary() {
    // 함수 호출
    for (final fn in ['sqrt', 'log', 'sin', 'cos', 'tan', 'abs']) {
      if (input.startsWith(fn, pos)) {
        pos += fn.length;
        if (pos < input.length && input[pos] == '(') {
          pos++; // skip (
          final arg = parseExpression();
          if (pos < input.length && input[pos] == ')') pos++;
          return _applyFunc(fn, arg);
        }
      }
    }

    // 괄호
    if (pos < input.length && input[pos] == '(') {
      pos++;
      final result = parseExpression();
      if (pos < input.length && input[pos] == ')') pos++;
      return result;
    }

    // 숫자
    final start = pos;
    while (pos < input.length && (RegExp(r'[0-9.]').hasMatch(input[pos]))) {
      pos++;
    }
    if (start == pos) throw FormatException('숫자가 예상됩니다 (위치: $pos)');
    return double.parse(input.substring(start, pos));
  }

  double _applyFunc(String name, double arg) {
    return switch (name) {
      'sqrt' => _sqrt(arg),
      'log'  => _log(arg),
      'sin'  => _sin(arg),
      'cos'  => _cos(arg),
      'tan'  => _tan(arg),
      'abs'  => arg.abs(),
      _      => throw Exception('알 수 없는 함수: $name'),
    };
  }

  static double _pow(double base, double exp) {
    double result = 1;
    for (var i = 0; i < exp.toInt(); i++) {
      result *= base;
    }
    return result;
  }

  static double _sqrt(double x) {
    if (x < 0) throw Exception('음수의 제곱근');
    double guess = x / 2;
    for (var i = 0; i < 100; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double _log(double x) {
    if (x <= 0) throw Exception('0 이하의 로그');
    double result = 0;
    double term = (x - 1) / (x + 1);
    double termSq = term * term;
    double current = term;
    for (var n = 1; n <= 200; n += 2) {
      result += current / n;
      current *= termSq;
    }
    return 2 * result;
  }

  static double _sin(double x) {
    x = x % (2 * 3.141592653589793);
    double result = 0, term = x;
    for (var n = 1; n <= 20; n++) {
      result += term;
      term *= -x * x / ((2 * n) * (2 * n + 1));
    }
    return result;
  }

  static double _cos(double x) => _sin(x + 3.141592653589793 / 2);
  static double _tan(double x) => _sin(x) / _cos(x);
}
