import 'package:collection_diff/algorithms/set_diff.dart';
import 'package:collection_diff/collection_diff.dart';
import 'package:collection_diff/diff_algorithm.dart';
import 'package:collection_diff/list_diff_model.dart';
import 'package:collection_diff/map_diff.dart';
import 'package:collection_diff_isolate/diff_isolate.dart';

extension ListDiffAsyncExtensions<E> on List<E> {
  Future<ListDiffs<E>> differencesAsync(List<E> other, {DiffEquality<E> equality, ListDiffAlgorithm algorithm}) async {
    algorithm ??= const MyersDiff();
    final arguments = ListDiffArguments<E>([...?this], [...?other], equality);
    final context = ListDiffContext<E>(algorithm, arguments);
    final diff = await diffRunner.run(executeListDiff, context);
    return diff.recast<E>(arguments);
  }
}

extension SetDiffAsyncExtensions<E> on Set<E> {
  Future<SetDiffs<E>> differencesAsync(Set<E> other,
      {bool checkEquality = true, DiffEquality<E> equality, SetDiffAlgorithm algorithm}) async {
    algorithm ??= const DefaultSetDiffAlgorithm();
    final arguments = SetDiffArguments<E>({...?this}, {...?other}, checkEquality, equality);
    final context = SetDiffContext<E>(algorithm, arguments);
    final diff = await diffRunner.run(executeSetDiff, context);
    return diff.recast<E>(arguments);
  }
}

extension MapDiffAsyncExtensions<K, V> on Map<K, V> {
  Future<MapDiffs<K, V>> differencesAsync(
    Map<K, V> other, {
    bool checkValues = true,
    DiffEquality<K> keyEquality,
    DiffEquality<V> valueEquality,
    MapDiffAlgorithm algorithm,
  }) async {
    algorithm ??= const DefaultMapDiffAlgorithm();
    final args = MapDiffArguments(this, other,
        checkValues: checkValues ?? true, keyEquality: keyEquality, valueEquality: valueEquality);
    final context = MapDiffContext(algorithm, args);

    final diff = await diffRunner.run(executeMapDiff, context);
    return diff.recast<K, V>(args);
  }
}

extension IterableDiffAsyncExtensions<E> on Iterable<E> {
  Future<SetDiffs<E>> differencesAsSetAsync(Iterable<E> other,
      {DiffEquality<E> equality, SetDiffAlgorithm algorithm}) async {
    final asSet = this.toSet();
    return await asSet.differencesAsync(other.toSet(), equality: equality, algorithm: algorithm);
  }

  Future<ListDiffs<E>> differencesAsListAsync(Iterable<E> other,
      {DiffEquality<E> equality, ListDiffAlgorithm algorithm}) async {
    return await this.toList().differencesAsync(other.toList(), equality: equality, algorithm: algorithm);
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
}

extension SetDiffsExtensions on SetDiffs {
  SetDiffs<E> recast<E>(SetDiffArguments<E> args) {
    return SetDiffs<E>.ofOperations(this.operations.map((d) => d.recast(args)).toList(growable: false), args);
  }
}

extension MapDiffsExtension on MapDiffs {
  MapDiffs<K, V> recast<K, V>(MapDiffArguments<K, V> args) {
    return MapDiffs<K, V>.ofOperations(this.operations.map((d) => d.recast(args)).toList(growable: false), args);
  }
}

class ListDiffContext<E> {
  final ListDiffAlgorithm algorithm;
  final ListDiffArguments<E> arguments;

  const ListDiffContext(this.algorithm, this.arguments);
}

class SetDiffContext<E> {
  final SetDiffAlgorithm algorithm;
  final SetDiffArguments<E> arguments;

  const SetDiffContext(this.algorithm, this.arguments);
}

class MapDiffContext<K, V> {
  final MapDiffAlgorithm algorithm;
  final MapDiffArguments<K, V> arguments;

  const MapDiffContext(this.algorithm, this.arguments);
}

ListDiffs<E> executeListDiff<E>(ListDiffContext<E> context) {
  return context.algorithm.execute<E>(context.arguments);
}

MapDiffs<K, V> executeMapDiff<K, V>(MapDiffContext<K, V> context) {
  return context.algorithm.execute<K, V>(context.arguments);
}

SetDiffs<E> executeSetDiff<E>(SetDiffContext<E> context) {
  try {
    final res = context.algorithm.execute<E>(context.arguments);
    return res;
  } catch (e) {
    print(e);
    rethrow;
  }
}
