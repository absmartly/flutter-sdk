import '../helper/number_format/number_format.dart';
import 'evaluator.dart';
import 'operator.dart';

class ExprEvaluator extends Evaluator {
  static final NumberFormat formatter = _getValue();

  static NumberFormat _getValue() {
    final f = NumberFormat.decimalPattern();
    f.maximumFractionDigits = 15;
    f.minimumFractionDigits = 0;
    f.minimumIntegerDigits = 1;
    return formatter;
  }

  final Map<String, Operator> operators;
  final Map<String?, dynamic> vars;

  ExprEvaluator(this.operators, this.vars);

  @override
  dynamic evaluate(dynamic expr) {
    if (expr is List) {
      return operators['and']?.evaluate(this, expr);
    } else if (expr is Map) {
      final map = expr as Map<String?, dynamic>;
      for (final entry in map.entries) {
        final op = operators[entry.key];
        print(op);
        if (op != null) {
          return op.evaluate(this, entry.value);
        }
        break;
      }
    }
    return null;
  }

  @override
  bool booleanConvert(x) {
    if (x is bool) {
      return x;
    } else if (x is String) {
      return x != "false" && x != "0" && x != "";
    } else if (x is num) {
      return x.toInt() != 0;
    }

    return x != null;
  }

  @override
  num? numberConvert(dynamic x) {
    if (x is num) {
      return (x is double) ? x : x.toDouble();
    } else if (x is bool) {
      return x ? 1.0 : 0.0;
    } else if (x is String) {
      try {
        return double.parse(x); // use javascript semantics: numbers are doubles
      } catch (e) {}
    }

    return -1;
  }

  @override
  String? stringConvert(dynamic x) {
    if (x is String) {
      return x;
    } else if (x is bool) {
      return x.toString();
    } else if (x is num) {
      return formatter.format(x);
    }
    return null;
  }

  @override
  dynamic extractVar(String path) {
    final frags = path.split("/");

    dynamic target = vars;

    for (final frag in frags) {
      dynamic? value;
      if (target is List) {
        final list = target;
        try {
          value = list[int.parse(frag)];
        } catch (e) {
          value = null;
        }
      } else if (target is Map) {
        final map = target as Map<String, dynamic>;
        value = map[frag];
      }

      if (value != null) {
        target = value;
        continue;
      }

      return null;
    }

    return target;
  }

  @override
  dynamic compare(dynamic lhs, dynamic rhs) {
    if (lhs == null) {
      return rhs == null ? 0 : null;
    } else if (rhs == null) {
      return null;
    }

    if (lhs is num) {
      final rvalue = numberConvert(rhs);
      if (rvalue != null) {
        return (lhs).compareTo(rvalue);
      }
    } else if (lhs is String) {
      final rvalue = stringConvert(rhs);
      if (rvalue != null) {
        return (lhs).compareTo(rvalue);
      }
    } else if (lhs is bool) {
      final rvalue = booleanConvert(rhs);
      return lhs == rvalue;
    } else if (lhs.runtimeType == rhs.runtimeType && lhs == rhs) {
      return 0;
    }

    return null;
  }
}
