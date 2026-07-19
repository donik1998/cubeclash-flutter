import 'package:equatable/equatable.dart';

/// One page of a cursor-paginated collection.
///
/// Mirrors the wire shape from docs → API Design: `{ items, next_cursor }`.
/// A `null` [nextCursor] means the caller has reached the end.
class Page<T> extends Equatable {
  const Page({required this.items, this.nextCursor});

  const Page.empty()
      : items = const <Never>[],
        nextCursor = null;

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  /// Appends [next] onto this page, keeping the newer cursor. Used by
  /// infinite-scroll list states as pages arrive.
  Page<T> append(Page<T> next) => Page<T>(
        items: <T>[...items, ...next.items],
        nextCursor: next.nextCursor,
      );

  Page<R> map<R>(R Function(T item) transform) => Page<R>(
        items: items.map(transform).toList(),
        nextCursor: nextCursor,
      );

  @override
  List<Object?> get props => <Object?>[items, nextCursor];
}
