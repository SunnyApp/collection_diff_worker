import 'package:collection/collection.dart';
import 'package:collection_diff/collection_diff.dart';
import 'package:collection_diff/diff_equality.dart';
import 'package:collection_diff/list_diff_model.dart';
import 'package:collection_diff_isolate/collection_diff_isolate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("all", () {
    setUp(() {
      increment = 1;
    });

    test("List diff - insert", () async {
      final list1 = [1, 2, 3, 4, 6, 7];
      final list2 = [1, 2, 3, 4, 5, 6, 7];

      final diff = await list1.differencesAsync(list2);
      expect(diff.length, equals(1));
      final result = diff.first;
      expect(result is InsertDiff, isTrue);
      expect(result.insert.index, equals(4));
    });

    test("List diff - remove", () async {
      final list1 = [1, 2, 3, 4, 5, 6, 7];
      final list2 = [1, 2, 3, 4, 6, 7];

      final diff = await list1.differencesAsync(list2);
      expect(diff.length, equals(1));
      expect(diff, hasDelete((delete) => delete.index == 4));
    });

    test("List diff - swapremove", () async {
      final list1 = [1, 2, 3, 4, 6, 7];
      final list2 = [1, 2, 3, 4, 5, 6];

      final diff = await list1.differencesAsync(list2);
      expect(diff.length, equals(2));
      expect(diff, hasDelete((delete) => delete.index == 5));
      expect(diff, hasInsert((insert) => insert.item == 5 && insert.index == 4));
    });

    test("List diff - swap", () async {
      final list1 = [1, 2, 3, 4, 5, 6];
      final list2 = [1, 2, 3, 4, 6, 7];

      final diff = await list1.differencesAsync(list2);
      expect(diff[0], isA<InsertDiff>());
      expect(diff[1], isA<DeleteDiff>());
      expect(diff, hasInsert<int>((insert) => insert.index == 6 && insert.item == 7));
      expect(diff, hasDelete<int>((delete) => delete.index == 4));
    });

    test("List diff - keys - Keyed", () async {
      final list1 = generateFromNames([
        "Captain America",
        "Captain Marvel",
        "Thor",
      ]);

      final list2 = [list1[0], list1[1].rename("The Binary"), list1[2]];
      final diff = await list1.differencesAsync(list2);
      expect(diff.length, equals(1));
    });

    test("List diff - Rename an item - Using toString as keyGenerator", () async {
      final list1 = generateFromNames([
        "Bob",
        "John",
        "Richard",
        "James",
      ]);

      final list2 = [...list1]..[2] = list1[2].rename("Dick");

      final diff = await list1.differencesAsync(list2);
      expect(diff.length, equals(1));
      expect(diff, hasReplace((replace) => replace.index == 2));
    });

    test("List diff - nokeys - rename the first", () async {
      final list1 = generateFromNames([
        "Bob",
        "John",
        "Richard",
        "James",
      ]);

      final list2 = [list1[0].rename("Robert"), list1[1], list1[2], list1[3]];

      final diff = await list1.differencesAsync(list2);
      expect(diff.length, equals(1));
      expect(diff, hasReplace((replace) => replace.index == 0));
    });
//
    test("List diff - longer list - move backwards", () async {
      final list1 = generateFromNames(["Bob", "John", "Eric", "Richard", "James", "Lady", "Tramp", "Randy", "Donald"]);

      final list2 = [...list1]
        ..insert(8, list1[2])
        ..removeAt(2);

      final diff = await list1.differencesAsync(list2);
      expect(diff.length, equals(2));
      expect(diff, hasDelete((move) => move.delete.index == 2));
      expect(diff, hasInsert((move) => move.insert.index == 8));
    });

    test("List diff - longer list - move element up", () async {
      final list1 = generateFromNames(["Bob", "John", "Eric", "Richard", "James", "Lady", "Tramp", "Randy", "Donald"]);

      final list2 = [...list1]..move(7, 2);

      final diff = await list1.differencesAsync(list2);

      expect(diff.length, equals(2));
      expect(diff, hasDelete((move) => move.index == 7));
      expect(diff, hasInsert((insert) => insert.index == 2));
    });

    test("List diff - longer list - move 2 elements up", () async {
      final list1 = generateFromNames(["Bob", "John", "Eric", "Richard", "James", "Lady", "Tramp", "Randy", "Donald"]);

      final list2 = [...list1]..move(7, 3)..move(8, 2);
      final diff = await list1.differencesAsync(list2);

      expect(diff.length, equals(3));
      expect(diff, hasDelete((delete) => delete.size == 2 && delete.index == 7));
      expect(diff, hasInsert((insert) => insert.index == 3));
      expect(diff, hasInsert((insert) => insert.index == 2));
    });

    test("List diff - insert beginning", () async {
      final list1 = generateFromNames(["Bob", "John", "Eric", "Richard", "James", "Lady", "Tramp", "Randy", "Donald"]);
      final list2 = [...list1]..insert(0, Renamable("Kevin"));
      final diff = await list1.differencesAsync(list2);
      expect(diff.length, equals(1));
      expect(diff, hasInsert((insert) => insert.index == 0));
    });

    test("List diff - insert middle", () async {
      final list1 = generateFromNames(["Bob", "John", "Eric", "Richard", "James", "Lady", "Tramp", "Randy", "Donald"]);

      final list2 = [...list1]..insert(4, Renamable("Kevin"));

      final diff = await list1.differencesAsync(list2);

      expect(diff.length, equals(1));
      expect(diff, hasInsert((insert) => insert.index == 4));
    });
//
    test("List diff - insert middle big list", () async {
      final list1 = generateFromNames([...Iterable.generate(5000, (i) => "Guy$i")]);

      final list2 = [...list1]..insert(100, Renamable("Kevin"));

      final start = DateTime.now();
      final diff = await list1.differencesAsync(list2);
      final duration = start.difference(DateTime.now());
      print("Duration: $duration");
      expect(duration.inMicroseconds, lessThan(1000));
      expect(diff.length, 1);
      expect(diff, hasInsert((insert) => insert.index == 100));
    });

    test("List diff - remove beginning", () async {
      final list1 = generateFromNames(["Bob", "John", "Eric", "Richard", "James", "Lady", "Tramp", "Randy", "Donald"]);

      final list2 = [...list1];
      list2.removeAt(0);

      final diff = await list1.differencesAsync(list2);

      expect(diff.length, equals(1));
      expect(diff, hasDelete((delete) => delete.index == 0));
    });

    test("List diff - remove middle", () async {
      final list1 = generateFromNames(["Bob", "John", "Eric", "Richard", "James", "Lady", "Tramp", "Randy", "Donald"]);

      final list2 = [...list1];
      list2.removeAt(4);

      final diff = await list1.differencesAsync(list2);
      expect(diff.length, equals(1));
      expect(diff, hasDelete((delete) => delete.index == 4));
    });

    test("List diff - using equals", () async {
      final list1 = generateFromNames(["Captain America", "Captain Marvel", "Thor"]);
      final list2 = [...list1]..[1] = list1[1].rename("The Binary");

      final diff = await list1.differencesAsync(list2);
      expect(diff.length, equals(1));
      expect(diff, hasReplace((replace) => replace.index == 1));
    });

    test("Set diff - remove beginning", () async {
      final set1 =
          generateFromNames(["Bob", "John", "Eric", "Richard", "James", "Lady", "Tramp", "Randy", "Donald"]).toSet();

      final set2 = {...set1}..removeWhere((r) => r.id == "1");

      final diff = set1.differences(set2);

      expect(diff.length, equals(1));
      expect(diff, hasRemove((remove) => remove.items.first.id == "1"));
    });

    test("Set diff - remove all", () async {
      final set1 =
          generateFromNames(["Bob", "John", "Eric", "Richard", "James", "Lady", "Tramp", "Randy", "Donald"]).toSet();

      final set2 = <Renamable>{};

      final diff = set1.differences(set2);

      expect(diff.length, equals(1));
      expect(diff, hasRemove((remove) => remove.items.length == 9));
    });

    test("Set diff - add all", () async {
      final set1 = <Renamable>{};
      final set2 =
          generateFromNames(["Bob", "John", "Eric", "Richard", "James", "Lady", "Tramp", "Randy", "Donald"]).toSet();

      final diff = set1.differences(set2);

      expect(diff.length, equals(1));
      expect(diff, hasAdd((add) => add.items.length == 9));
    });

    test("Map diff - passing illegal map isolates", () async {
      final map1 = Map.fromEntries(
          generateFromNames(["Bob", "John", "Eric", "Richard", "James", "Lady", "Tramp", "Randy", "Donald"])
              .map((i) => MapEntry(i.id, i))).toIllegalMap();

      final map2 = map1.map((k, v) => MapEntry(k, v.rename(v.name.toUpperCase()))).toIllegalMap();

      /// No errors when running the diff (ensures a defensive copy was made)
      await map1.differencesAsync(map2);
    });

    test("List diff - using diff delegates", () async {
      final list1 =
          generateDiffableFromNames(["Bob", "John", "Eric", "Richard", "James", "Lady", "Tramp", "Randy", "Donald"]);

      final list2 = [...list1]..[0] = RenamableDiffable.ofId("1", "Robert");

      /// No errors when running the diff (ensures a defensive copy was made)
      final result = await list1.differencesAsync(list2);
      expect(result.args.id, endsWith("delegate"));
    });

    test("List diff - delete using diff delegates", () async {
      final list1 =
          generateDiffableFromNames(["Bob", "John", "Eric", "Richard", "James", "Lady", "Tramp", "Randy", "Donald"]);

      final list2 = [...list1]..removeAt(1);

      /// No errors when running the diff (ensures a defensive copy was made)
      final result = await list1.differencesAsync(list2);
      expect(result.args.id, endsWith("delegate"));
      expect(result, hasDelete((delete) => delete.index == 1 && delete.size == 1));
    });

    test("Map diff sanity check", () async {
      final set1 = <String, Renamable>{};
      final set2 = Map.fromEntries(
          generateFromNames(["Bob", "John", "Eric", "Richard", "James", "Lady", "Tramp", "Randy", "Donald"])
              .map((i) => MapEntry(i.id, i)));

      final diff = await set1.differencesAsync(set2);

      expect(diff.length, equals(9));
    });
  });
}

List<Renamable> generateFromNames(List<String> names) {
  return names.map((name) => Renamable.ofId("${increment++}", name)).toList();
}

List<RenamableDiffable> generateDiffableFromNames(List<String> names) {
  return names.map((name) => RenamableDiffable.ofId("${increment++}", name)).toList();
}

int increment = 1;

/// Tests doing diffs based on keys
class Renamable {
  final String id;
  String name;

  Renamable.ofId(this.id, this.name);

  Renamable(this.name) : id = "${increment++}";

  Renamable rename(String newName) => Renamable.ofId(id, newName);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Renamable && runtimeType == other.runtimeType && id == other.id && name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => 'Renamable{id: $id, name: $name}';
}

/// Tests doing diffs based on keys
class RenamableDiffable with DiffDelegateMixin {
  final String id;
  String name;

  RenamableDiffable.ofId(this.id, this.name);

  RenamableDiffable(this.name) : id = "${increment++}";

  Renamable rename(String newName) => Renamable.ofId(id, newName);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Renamable && runtimeType == other.runtimeType && id == other.id && name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => 'Renamable{id: $id, name: $name}';

  @override
  dynamic get diffKey => id;
}

hasReplace(Predicate<ListDiff> predicate) =>
    _ChangeMatcher<ReplaceDiff>((change) => change is ReplaceDiff && predicate(change.change));

hasDelete<E>(Predicate<DeleteDiff<E>> predicate) =>
    _ChangeMatcher<DeleteDiff<E>>((change) => change is DeleteDiff<E> && predicate(change.delete));

hasRemove<E>(Predicate<SetDiff<E>> predicate) =>
    _SetDiffMatcher<E>((change) => change.type == SetDiffType.remove && predicate(change));

hasAdd<E>(Predicate<SetDiff<E>> predicate) =>
    _SetDiffMatcher<E>((change) => change.type == SetDiffType.add && predicate(change));

hasUpdate<E>(Predicate<SetDiff<E>> predicate) =>
    _SetDiffMatcher<E>((change) => change.type == SetDiffType.update && predicate(change));

hasInsert<E>(Predicate<InsertDiff<E>> predicate) =>
    _ChangeMatcher<InsertDiff<E>>((change) => change is InsertDiff<E> && predicate(change.insert));

//hasMove(Predicate<Move> predicate) => _ChangeMatcher<Move>((change) => change is Move && predicate(change.move));

typedef Predicate<T> = bool Function(T input);

class _ChangeMatcher<D extends ListDiff> extends Matcher {
  final Predicate<D> changeMatch;

  _ChangeMatcher(this.changeMatch);

  @override
  bool matches(final item, Map matchState) {
    if (item is ListDiffs) {
      return item.any((final x) => x is D && (changeMatch?.call(x) ?? true));
    }
    return false;
  }

  @override
  Description describe(Description description) => description.add('hasChange<$D>');
}

class _SetDiffMatcher<E> extends Matcher {
  final Predicate<SetDiff<E>> changeMatch;

  _SetDiffMatcher(this.changeMatch);

  @override
  bool matches(final item, Map matchState) {
    if (item is SetDiffs<E>) {
      return item.any((final x) => (changeMatch?.call(x) ?? true));
    }
    return false;
  }

  @override
  Description describe(Description description) => description.add('hasSetDiff');
}

extension ListExtTest<X> on List<X> {
  void move(int fromIndex, int toIndex) {
    final value = this[fromIndex];
    this.removeAt(fromIndex);
    if (fromIndex > toIndex) {
      this.insert(toIndex, value);
    } else {
      this.insert(toIndex - 1, value);
    }
  }
}

class IllegalMap<K, V> extends DelegatingMap<K, V> {
  IllegalMap([Map<K, V> input]) : super(input ?? <K, V>{});

  static Noop nooper = (_) => "Stars";

  Noop localNoop = (_) => "local";
}

extension MapExtensionsTest<K, V> on Map<K, V> {
  Map<K, V> toIllegalMap() => IllegalMap(this);
}

typedef Noop = dynamic Function(Object input);
