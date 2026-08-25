class LatestRequestTracker {
  int _generation = 0;

  int next() => ++_generation;

  bool isCurrent(int requestId) => requestId == _generation;

  void invalidate() {
    _generation++;
  }
}
