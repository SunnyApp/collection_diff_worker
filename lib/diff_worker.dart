import 'package:worker_service/worker_service.dart';

RunnerService? _diffRunner;

RunnerService? get diffRunner {
  return _diffRunner ??= initializeDiffRunner((config) => config
    ..poolSize = 5
    ..defaultTimeout = Duration(seconds: 60)
    ..failOnError = false
    ..autoclose = true
    ..debugName = "diffRunner");
}

set diffRunner(RunnerService? runner) {
  if (_diffRunner != null) {
    _diffRunner!.close();
  }
  _diffRunner = runner;
}

RunnerService? initializeDiffRunner(void config(RunnerBuilder builder)) {
  diffRunner = RunnerFactory.global.create(config);
  return _diffRunner;
}
