import 'package:flutter_test/flutter_test.dart';

import 'package:hwcontrol_dashboard/model_manager.dart';

void main() {
  test('AI model metadata stays within distribution budget', () {
    expect(HWControlModelManager.modelName, 'gemma-3-1b-it-Q5_K_M.gguf');
    expect(HWControlModelManager.modelSizeBytes, lessThan(1000000000));
    expect(HWControlModelManager.modelSha256, hasLength(64));
    expect(
      RegExp(r'^[0-9a-f]{64}$').hasMatch(HWControlModelManager.modelSha256),
      isTrue,
    );
  });

  test('model URL is pinned to the expected provider and file', () {
    final uri = Uri.parse(HWControlModelManager.modelUrl);
    expect(uri.scheme, 'https');
    expect(uri.host, 'huggingface.co');
    expect(uri.path, contains('second-state/gemma-3-1b-it-GGUF'));
    expect(uri.path, endsWith('gemma-3-1b-it-Q5_K_M.gguf'));
  });
}