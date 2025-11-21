import 'package:flutter_test/flutter_test.dart';
import 'package:silent_sos/services/ai_context.dart';

void main() {
  test('triage high for unconscious', () {
    final ctx = {'symptoms': ['I am unconscious'], 'vitals': {'pulse': 30}};
    final r = AIContext.triage(ctx);
    expect(r, 'high');
  });

  test('triage medium for chest pain', () {
    final ctx = {'symptoms': ['severe chest pain'], 'vitals': {}};
    final r = AIContext.triage(ctx);
    expect(r, 'medium');
  });

  test('triage low for minor issue', () {
    final ctx = {'symptoms': ['mild headache'], 'vitals': {'pulse': 75}};
    final r = AIContext.triage(ctx);
    expect(r, 'low');
  });
}
