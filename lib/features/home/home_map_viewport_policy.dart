/// A GPS response owns a viewport only until a newer user/map intent occurs.
class HomeMapViewportPolicy {
  int _generation = 0;
  bool _initialClaimed = false;
  int get generation => _generation;
  int? claimInitialCenter({required bool hasDestination}) {
    if (_initialClaimed) return null;
    _initialClaimed = true;
    return hasDestination || _generation != 0 ? null : _generation;
  }

  void invalidate() => _generation++;
  int beginExplicitCenter() => ++_generation;
  bool canApply(int generation) => generation == _generation;
}
