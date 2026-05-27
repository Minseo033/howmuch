import 'package:flutter/material.dart';
import 'package:howmuch/features/home/presentation/state/home_mock_data.dart';

class HomeMapCanvas extends StatelessWidget {
  const HomeMapCanvas({super.key, required this.stores});

  final List<NearbyStore> stores;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8F1E7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MapGridPainter(colorScheme.outlineVariant),
              ),
            ),
            const Positioned(
              left: 132,
              top: 126,
              child: _CurrentLocationMarker(),
            ),
            const Positioned(
              left: 42,
              top: 72,
              child: _StoreMarker(label: '한식', icon: Icons.restaurant),
            ),
            const Positioned(
              right: 48,
              top: 94,
              child: _StoreMarker(label: '분식', icon: Icons.ramen_dining),
            ),
            const Positioned(
              left: 88,
              bottom: 54,
              child: _StoreMarker(label: '카페', icon: Icons.local_cafe),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    '지도 API 교체 영역',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreMarker extends StatelessWidget {
  const _StoreMarker({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colorScheme.onPrimary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.location_pin, color: colorScheme.primary, size: 28),
      ],
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colorScheme.secondary,
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.surface, width: 4),
      ),
      child: Icon(Icons.person_pin_circle, color: colorScheme.onSecondary),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1;

    for (var i = 0; i < 6; i++) {
      final y = size.height * (i + 1) / 7;
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 30), paint);
    }

    for (var i = 0; i < 5; i++) {
      final x = size.width * (i + 1) / 6;
      canvas.drawLine(Offset(x, 0), Offset(x - 28, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
