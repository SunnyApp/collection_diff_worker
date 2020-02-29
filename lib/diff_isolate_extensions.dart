import 'dart:isolate';

import 'package:collection_diff/algorithms/set_diff.dart';
import 'package:collection_diff/collection_diff.dart';
import 'package:collection_diff/diff_algorithm.dart';
import 'package:collection_diff/list_diff_model.dart';
import 'package:collection_diff/map_diff.dart';
import 'package:collection_diff_isolate/diff_isolate.dart';
import 'package:logging/logging.dart';

final _log = Logger("asyncDiff");

int i = 0;

extension ListDiffAsyncExtensions<E> on List<E> {
  Future<ListDiffs<E>> differencesAsync(List<E> other,
      {String debugName, DiffEquality<E> equality, ListDiffAlgorithm algorithm}) async {
    try {
      algorithm ??= const MyersDiff();
      final originalArgs = ListDiffArguments<E>.copied(this, other, equality);
      final name = "${Isolate.current.debugName}: listDiff[${debugName ?? "-"}]";
      if (Isolate.current.isMain && this is Iterable<DiffDelegate>) {
        final arguments = ListDiffArguments<DiffDelegate>.copied(
          this.map((s) => (s as DiffDelegate).delegate),
          other.map((s) => (s as DiffDelegate).delegate),
          DiffEquality.ofDiffDelegate(),
          id: "${originalArgs.id}.delegate",
          debugName: "$debugName (delegate)",
        );
        final context = ListDiffContext<DiffDelegate>(algorithm, arguments, debugName: "$debugName (delegate)");
        final diff = await _runAsync(executeListDiff, context, name: name);
        if (diff == null) {
          return ListDiffs<E>.empty();
        }
        final undelegated = diff.undelegate<E>(originalArgs);
        return undelegated;
      } else {
        final arguments = ListDiffArguments<E>.copied(this, other, equality);
        final context = ListDiffContext<E>(algorithm, arguments, debugName: debugName);
        if (Isolate.current.isNotMain) {
          _log.info("Running $debugName in ${Isolate.current.debugName}:");
          return executeListDiff(context);
        } else {
          final diff = await _runAsync(executeListDiff, context, name: name);
          return diff.recast(originalArgs);
        }
      }
    } catch (e, stack) {
      _log.severe("$debugName setDiff $e", e, stack);
      rethrow;
    }
  }
}

Future<O> _runAsync<I, O>(O fn(I input), I input, {String name}) {
  _log.finer("Isolate input: ${input?.runtimeType} $input");
  return Future.sync(() => diffRunner.run(fn, input, name: name));
}

extension SetDiffAsyncExtensions<E> on Set<E> {
  Future<SetDiffs<E>> differencesAsync(Set<E> other,
      {bool checkEquality = true, String debugName, DiffEquality<E> equality, SetDiffAlgorithm algorithm}) async {
    try {
      algorithm ??= const DefaultSetDiffAlgorithm();
      final arguments = SetDiffArguments<E>.copied(this, other, checkEquality, equality);
      final context = SetDiffContext<E>(algorithm, arguments, debugName: debugName);
      final name = "${Isolate.current.debugName}: setDiff[${debugName ?? "-"}]";

      if (Isolate.current.isMain && this is Iterable<DiffDelegate>) {
        final delegateArgs = SetDiffArguments<DiffDelegate>.copied(this.map((s) => (s as DiffDelegate).delegate),
            other.map((s) => (s as DiffDelegate).delegate), true, DiffEquality.ofDiffDelegate());
        final context = SetDiffContext<DiffDelegate>(algorithm, delegateArgs, debugName: "$debugName (delegate)");
        final diff = await _runAsync(executeSetDiff, context, name: name);
        return diff.undelegate(arguments);
      } else {
        final diff = await _runAsync(executeSetDiff, context, name: name);
        return diff.recast<E>(arguments);
      }
    } catch (e, stack) {
      _log.severe("$debugName setDiff $e", e, stack);
      rethrow;
    }
  }
}

extension MapDiffAsyncExtensions<K, V> on Map<K, V> {
  Future<MapDiffs<K, V>> differencesAsync(
    Map<K, V> other, {
    bool checkValues = true,
    String debugName,
    DiffEquality<K> keyEquality,
    DiffEquality<V> valueEquality,
    MapDiffAlgorithm algorithm,
  }) async {
    try {
      algorithm ??= const DefaultMapDiffAlgorithm();
      final args = MapDiffArguments<K, V>.copied(this, other,
          checkValues: checkValues ?? true, keyEquality: keyEquality, valueEquality: valueEquality);
      final context = MapDiffContext(algorithm, args, isTimed: true, debugName: debugName);
      final name = "${Isolate.current.debugName}: setDiff[${debugName ?? "-"}]";

      if (this is Map<K, DiffDelegate>) {
        final delegateArgs = MapDiffArguments<K, DiffDelegate>.copied(
          this.whereValuesNotNull().map((k, s) => MapEntry(k, (s as DiffDelegate).delegate)),
          other.whereValuesNotNull().map((k, s) => MapEntry(k, (s as DiffDelegate).delegate)),
          checkValues: checkValues,
          keyEquality: keyEquality,
          valueEquality: DiffEquality.ofDiffDelegate(),
        );
        final context = MapDiffContext<K, DiffDelegate>(algorithm, delegateArgs, debugName: "$debugName (delegate)");
        final diff = await _runAsync(executeMapDiff, context, name: name);
        return diff.undelegate<K, V>(args);
      } else {
        if (Isolate.current.isNotMain) {
          return executeMapDiff(context);
        } else {
          final diff = await _runAsync(executeMapDiff, context, name: name);
          return diff.recast<K, V>(args);
        }
      }
    } catch (e, stack) {
      _log.severe("$debugName setDiff $e", e, stack);
      rethrow;
    }
  }
}

extension IterableDiffAsyncExtensions<E> on Iterable<E> {
  Future<SetDiffs<E>> differencesAsSetAsync(Iterable<E> other,
      {String debugName, DiffEquality<E> equality, SetDiffAlgorithm algorithm}) async {
    final asSet = this.toSet();
    return await asSet.differencesAsync(other.toSet(), debugName: debugName, equality: equality, algorithm: algorithm);
  }

  Future<ListDiffs<E>> differencesAsListAsync(Iterable<E> other,
      {String debugName, DiffEquality<E> equality, ListDiffAlgorithm algorithm}) async {
    return await this
        .toList()
        .differencesAsync(other.toList(), debugName: debugName, equality: equality, algorithm: algorithm);
  }
}

extension ListDiffsExtensions on ListDiffs {
  ListDiffs<E> recast<E>(ListDiffArguments<E> args) {
    return ListDiffs<E>.ofOperations(
        this.operations.map((final op) {
          if (op is DeleteDiff) {
            return DeleteDiff<E>(args, op.index, op.size);
          } else if (op is InsertDiff) {
            return InsertDiff<E>(args, op.index, op.size, op.items.cast<E>());
          } else if (op is ReplaceDiff) {
            return ReplaceDiff<E>(args, op.index, op.size, op.items.cast<E>());
          } else {
            throw "Unknown type";
          }
        }).toList(growable: false),
        args);
  }

  /// This occurs when the diff was delegated - which means that instead of passing the real instance to the isolate, we
  /// passed a safe delegate.  When the method returns, we need to rehydrate the results by looking the delegates up
  /// in a map.
  ListDiffs<E> undelegate<E>(ListDiffArguments<E> args) {
    if (this == null) {
      _log.warning("Got a null listDiffs<$E>");
      return ListDiffs.empty(args);
    }
    final delegateArgs = args as ListDiffArguments<DiffDelegate>;
    // Create a mapping of diffKey to replacement
    final reverseMapping = Map.fromEntries(delegateArgs.replacement.map((d) => MapEntry(d.diffKey, d as E)));

    if (this.operations == null) {
      throw "BAD BAD $args";
    }
    return ListDiffs<E>.ofOperations(
        this.operations.map((final op) {
          if (op is DeleteDiff) {
            return DeleteDiff<E>(args, op.index, op.size);
          } else if (op is InsertDiff) {
            return InsertDiff<E>(
                args, op.index, op.size, op.items.map((delegate) => reverseMapping[delegate.diffKey]).toList());
          } else if (op is ReplaceDiff) {
            return ReplaceDiff<E>(
                args, op.index, op.size, op.items.map((delegate) => reverseMapping[delegate.diffKey]).toList());
          } else {
            throw "Unknown type";
          }
        }).toList(growable: false),
        args.withId(this.args.id));
  }
}

extension SetDiffsExtensions on SetDiffs {
  SetDiffs<E> recast<E>(SetDiffArguments<E> args) {
    return SetDiffs<E>.ofOperations(
      this.operations.map((d) => d.recast(args)).toList(growable: false),
      this.replacement.cast(),
      args,
    );
  }

  /// This occurs when the diff was delegated - which means that instead of passing the real instance to the isolate, we
  /// passed a safe delegate.  When the method returns, we need to rehydrate the results by looking the delegates up
  /// in a map.
  SetDiffs<E> undelegate<E>(SetDiffArguments<E> args) {
    final delegateArgs = args as SetDiffArguments<DiffDelegate>;
    // Create a mapping of diffKey to replacement
    final reverseMapping = Map.fromEntries(delegateArgs.replacement.map((d) => MapEntry(d.diffKey, d as E)));

    return SetDiffs<E>.ofOperations(
      operations.map((final op) {
        switch (op.type) {
          case SetDiffType.update:
            final opCast = (op as UpdateDiff<DiffDelegate>);
            return UpdateDiff(
              args,
              reverseMapping[opCast.oldValue.diffKey],
              reverseMapping[opCast.newValue.diffKey],
            );
          case SetDiffType.remove:
            return SetDiff.remove(
                args,
                op.items.map((delegate) {
                  return reverseMapping[delegate.diffKey];
                }).toSet());

          case SetDiffType.add:
            return SetDiff.add(
                args,
                op.items.map((delegate) {
                  return reverseMapping[delegate.diffKey];
                }).toSet());
            break;
          default:
            throw "Invalid type";
        }
      }).toList(growable: false),
      replacement.map((delegate) => reverseMapping[delegate.diffKey]).toSet(),
      args,
    );
  }
}

extension MapDiffsExtension<K, V> on MapDiffs<K, V> {
  MapDiffs<KK, VV> recast<KK, VV>(MapDiffArguments<KK, VV> args) {
    return MapDiffs<KK, VV>.ofOperations(this.operations.map((d) => d.recast(args)).toList(growable: false), args);
  }

  /// This occurs when the diff was delegated - which means that instead of passing the real instance to the isolate, we
  /// passed a safe delegate.  When the method returns, we need to rehydrate the results by looking the delegates up
  /// in a map.
  MapDiffs<K, E> undelegate<K, E>(MapDiffArguments<K, E> args) {
    final delegateArgs = args as MapDiffArguments<K, DiffDelegate>;
    // Create a mapping of diffKey to replacement
    final reverseMapping = Map.fromEntries(delegateArgs.replacement.values.map((d) => MapEntry(d.diffKey, d as E)));

    return MapDiffs<K, E>.ofOperations(
      this.operations.map((final _) {
        final op = _.recast<K, DiffDelegate>(delegateArgs);
        switch (op.type) {
          case MapDiffType.change:
            return MapDiff<K, E>.change(
                args, op.key, reverseMapping[op.oldValue.diffKey], reverseMapping[op.value.diffKey]);
          case MapDiffType.unset:
            return MapDiff<K, E>.unset(args, op.key, reverseMapping[op.oldValue.diffKey]);
          case MapDiffType.set:
            return MapDiff<K, E>.set(args, op.key, reverseMapping[op.value.diffKey]);
          default:
            throw "Invalid type";
        }
      }).toList(growable: false),
      args,
    );
  }
}

class ListDiffContext<E> {
  final ListDiffAlgorithm algorithm;
  final ListDiffArguments<E> arguments;
  final String debugName;

  ListDiffContext(this.algorithm, this.arguments, {this.debugName});

  String get id => arguments.id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ListDiffContext && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SetDiffContext<E> {
  final SetDiffAlgorithm algorithm;
  final SetDiffArguments<E> arguments;
  final String debugName;

  String get id => arguments.id;

  SetDiffContext(this.algorithm, this.arguments, {this.debugName});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SetDiffContext && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class MapDiffContext<K, V> {
  final String debugName;
  final MapDiffAlgorithm algorithm;
  final MapDiffArguments<K, V> arguments;
  final bool isTimed;

  String get id => arguments.id;

  const MapDiffContext(this.algorithm, this.arguments, {this.debugName, this.isTimed = false});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SetDiffContext && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

ListDiffs<E> executeListDiff<E>(ListDiffContext<E> context) {
  final start = DateTime.now();
  var result = context.algorithm.execute<E>(context.arguments);

  _logResult(
    "list",
    context.debugName,
    context.arguments.original.length,
    context.arguments.replacement.length,
    result.length,
    start,
  );
  return result;
}

MapDiffs<K, V> executeMapDiff<K, V>(MapDiffContext<K, V> context) {
  final start = DateTime.now();
  final result = context.algorithm.execute<K, V>(context.arguments);
  _logResult("map", context.debugName, context.arguments.original.length, context.arguments.replacement.length,
      result.length, start);
  return result;
}

SetDiffs<E> executeSetDiff<E>(SetDiffContext<E> context) {
  try {
//    final start = DateTime.now();
    final res = context.algorithm.execute<E>(context.arguments);
//    _logResult(
//      "set",
//      context.debugName,
//      context.arguments.original.length,
//      context.arguments.replacement.length,
//      res.length,
//      start,
//    );
    return res;
  } catch (e) {
    print(e);
    rethrow;
  }
}

_logResult(String type, String name, int origLength, int replLength, int resultLength, DateTime start) {
  _log.info({
    Isolate.current.debugName: "$type[${name ?? "-"}]",
    'orig': origLength,
    'repl': replLength,
    'diffs': resultLength,
    'time': "${DateTime.now().difference(start)}"
  });
}

extension IsolateExtension on Isolate {
  bool get isNotMain {
    return debugName != "main";
  }

  bool get isMain {
    return debugName == "main";
  }
}

extension _EntryDiffExtensions<K, V> on Iterable<MapEntry<K, V>> {
  Map<K, V> toMap() {
    return Map.fromEntries(this ?? []);
  }
}

extension _MapDiffExtensions<K, V> on Map<K, V> {
  Map<K, V> whereValuesNotNull() {
    return <K, V>{
      ...?this.entries.where((e) => e.value != null).toMap(),
    };
  }
}
