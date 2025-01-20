import 'package:flutter/material.dart';
import 'dart:async'; 

/// This is a simplified version of debounced search based on the following example:
/// https://api.flutter.dev/flutter/material/Autocomplete-class.html?v=1.0.20#material.Autocomplete.5
typedef _Debounceable<S, T> = Future<S?> Function(T parameter);

/// Returns a new function that is a debounced version of the given function.
/// This means that the original function will be called only after no calls
/// have been made for the given Duration.
_Debounceable<S, T> _debounce<S, T>(_Debounceable<S?, T> function) {
  _DebounceTimer? debounceTimer;

  return (T parameter) async {
    if (debounceTimer != null && !debounceTimer!.isCompleted) {
      debounceTimer!.cancel();
    }
    debounceTimer = _DebounceTimer(duration: const Duration(milliseconds: 500));
    try {
      await debounceTimer!.future;
    } catch (error) {
      print(error); // Should be 'Debounce cancelled' when cancelled.
      return null;
    }
    return function(parameter);
  };
}

// A wrapper around Timer used for debouncing.
class _DebounceTimer {
  _DebounceTimer({required this.duration}) {
    _timer = Timer(duration, _onComplete);
  }

  late final Timer _timer;
  final Duration duration;
  final Completer<void> _completer = Completer<void>();

  void _onComplete() {
    _completer.complete();
  }

  Future<void> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void cancel() {
    _timer.cancel();
    _completer.completeError('Debounce cancelled');
  }
}

class DebouncedSearchBar<T> extends StatefulWidget {
  const DebouncedSearchBar({
    super.key,
    required this.onResultSelected,
    required this.searchFunction,
    required this.titleBuilder,
    this.hintText,
    this.initialValue,
    this.leadingIconBuilder,
    this.subtitleBuilder,
  });

  final String? hintText;
  final T? initialValue;
  final Widget? Function(T result)? titleBuilder;
  final Widget? Function(T result)? subtitleBuilder;
  final Widget? Function(T result)? leadingIconBuilder;
  final Function(T result)? onResultSelected;
  final Future<Iterable<T>> Function(String query) searchFunction;

  @override
  State<StatefulWidget> createState() => _DebouncedSearchBarState<T>();
}

class _DebouncedSearchBarState<T> extends State<DebouncedSearchBar<T>> {
  final _searchController = SearchController();
  late final _Debounceable<Iterable<T>?, String> _debouncedSearch;

  _selectResult(T result) {
    widget.onResultSelected?.call(result);
  }

  Future<Iterable<T>> _search(String query) async {
    if (query.isEmpty) {
      return <T>[];
    }

    try {
      final results = await widget.searchFunction(query);
      return results;
    } catch (error) {
      return <T>[];
    }
  }

  @override
  void initState() {
    super.initState();
    _debouncedSearch = _debounce<Iterable<T>?, String>(_search);
    _searchController.text = widget.initialValue != null 
        ? widget.initialValue.toString() 
        : '';
  }

  @override
  void didUpdateWidget(DebouncedSearchBar<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _searchController.text = widget.initialValue != null 
          ? widget.initialValue.toString() 
          : '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _searchController,
      builder: (BuildContext context, SearchController controller) {
        return SearchBar(
          controller: controller,
          padding: const WidgetStatePropertyAll<EdgeInsets>(
              EdgeInsets.symmetric(horizontal: 16.0)),
          onTap: () {
            controller.openView();
          },
          leading: const Icon(Icons.search),
          hintText: widget.hintText,
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController controller) async {
        final Future<Iterable<T>?> future = _debouncedSearch(controller.text);
        try {
          final Iterable<T>? results = await future;
          if (results == null || results.isEmpty) {
            return <Widget>[];
          }
          return results.map((result) {
            return ListTile(
              title: widget.titleBuilder?.call(result),
              subtitle: widget.subtitleBuilder?.call(result),
              leading: widget.leadingIconBuilder?.call(result),
              onTap: () {
                _selectResult(result);
                controller.closeView(result.toString());
              },
            );
          }).toList();
        } catch (error) {
          return <Widget>[];
        }
      },
    );
  }
}