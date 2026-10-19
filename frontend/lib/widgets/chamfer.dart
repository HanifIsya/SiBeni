import 'package:flutter/material.dart';

/// A chamfered (cut) corner border.
///
/// Rounded cards everywhere are the reason an interface reads as a generic
/// template. Mining hardware is angular: plates, brackets and panels. A single
/// 10 px cut on the top-right corner gives every card a recognisable
/// silhouette without shouting, and it costs nothing in layout.
class ChamferBorder extends ShapeBorder {
  const ChamferBorder({
    this.color = const Color(0xFFDDE4ED),
    this.width = 1,
    this.radius = 16,
    this.cut = 10,
  });

  final Color color;
  final double width;
  final double radius;
  final double cut;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  ShapeBorder scale(double t) => ChamferBorder(
        color: color,
        width: width * t,
        radius: radius * t,
        cut: cut * t,
      );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return pathFor(rect, radius: radius, cut: cut, textDirection: textDirection);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return pathFor(
      rect.deflate(width),
      radius: radius,
      cut: cut,
      textDirection: textDirection,
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (width <= 0) return;
    final path = pathFor(
      rect.deflate(width / 2),
      radius: radius,
      cut: cut,
      textDirection: textDirection,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  /// Geometry shared by the border painter and the content clipper so the
  /// stroke and the clipped content can never drift apart.
  static Path pathFor(
    Rect rect, {
    double radius = 16,
    double cut = 10,
    TextDirection? textDirection,
  }) {
    final dir = textDirection ?? TextDirection.ltr;
    final r = radius.clamp(0.0, rect.shortestSide / 2);
    final c = cut.clamp(0.0, rect.shortestSide / 2);
    final path = Path();

    if (c <= 0) {
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
      return path;
    }

    // The cut always lands on the trailing-top corner, so the silhouette is
    // mirrored automatically in right-to-left locales.
    final trailing = dir == TextDirection.rtl;
    final cutStartX = trailing ? rect.left + c : rect.right - c;

    path.moveTo(rect.left + r, rect.top);
    path.lineTo(cutStartX, rect.top);
    path.lineTo(rect.right, rect.top + c);
    path.lineTo(rect.right, rect.bottom - r);
    path.quadraticBezierTo(rect.right, rect.bottom, rect.right - r, rect.bottom);
    path.lineTo(rect.left + r, rect.bottom);
    path.quadraticBezierTo(rect.left, rect.bottom, rect.left, rect.bottom - r);
    path.lineTo(rect.left, rect.top + r);
    path.quadraticBezierTo(rect.left, rect.top, rect.left + r, rect.top);
    path.close();
    return path;
  }
}

/// Clips a child to the same chamfered silhouette used by [ChamferBorder].
class ChamferClipper extends CustomClipper<Path> {
  const ChamferClipper({this.radius = 16, this.cut = 10});

  final double radius;
  final double cut;

  @override
Path getClip(Size size) => ChamferBorder.pathFor(
      Offset.zero & size,
      radius: radius,
      cut: cut,
    );

  @override
  bool shouldReclip(ChamferClipper oldClipper) =>
      oldClipper.radius != radius || oldClipper.cut != cut;
}
