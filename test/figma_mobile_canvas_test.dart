import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

void main() {
  group('FigmaMobileCanvas web width policy', () {
    test('uses the full width of narrow browser viewports', () {
      expect(FigmaMobileCanvas.webContentWidthFor(280), 280);
      expect(FigmaMobileCanvas.webContentWidthFor(320), 320);
      expect(FigmaMobileCanvas.webContentWidthFor(390), 390);
    });

    test('caps desktop content at the product shell width', () {
      expect(
        FigmaMobileCanvas.webContentWidthFor(1280),
        FigmaMobileCanvas.maxWebWidth,
      );
    });

    test('does not produce a width for invalid constraints', () {
      expect(FigmaMobileCanvas.webContentWidthFor(0), 0);
      expect(FigmaMobileCanvas.webContentWidthFor(double.infinity), 0);
    });
  });
}
