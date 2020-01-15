import 'package:isolate_service/isolate_service.dart';

IsolateService _diffRunner;

IsolateService get diffRunner {
  return _diffRunner ??= initializeDiffRunner((config) => config
    ..poolSize = 5
    ..defaultTimeout = Duration(seconds: 60)
    ..failOnError = false
    ..autoclose = true
    ..debugName = "diffRunner");
}

set diffRunner(IsolateService runner) {
  if (_diffRunner != null) {
    _diffRunner.close();
  }
  _diffRunner = runner;
}

IsolateService initializeDiffRunner(void config(RunnerBuilder builder)) {
  diffRunner = RunnerFactory.global.create(config);
  return _diffRunner;
}
