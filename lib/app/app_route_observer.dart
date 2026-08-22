import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appRouteObserverProvider = Provider<RouteObserver<PageRoute<dynamic>>>(
  (ref) => RouteObserver<PageRoute<dynamic>>(),
);
