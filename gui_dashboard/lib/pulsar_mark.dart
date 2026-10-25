import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated rendering of the canonical Pulsar four-point gradient-star mark.
class PulsarMark extends StatefulWidget {
  const PulsarMark({
    super.key,
    this.size = 76,
    this.animate = true,
    this.showBackground = false,
  });

  final double size;
  final bool animate;
  final bool showBackground;

  @override
  State<PulsarMark> createState() => _PulsarMarkState();
}

class _PulsarMarkState extends State<PulsarMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mark = AnimatedBuilder(
      animation: _controller,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: const _PulsarPainter(),
      ),
      builder: (context, child) {
        final phase = _controller.value * 2 * math.pi;
        final pulse = widget.animate ? 1 + math.sin(phase) * 0.025 : 1.0;
        final tilt = widget.animate ? math.sin(phase) * 0.012 : 0.0;
        return Transform.rotate(
          angle: tilt,
          child: Transform.scale(scale: pulse, child: child),
        );
      },
    );

    return Semantics(
      image: true,
      label: 'Pulsar, HWcontrol2.0 mascot',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: widget.showBackground
            ? DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFF080B12)),
                child: Center(child: mark),
              )
            : mark,
      ),
    );
  }
}

class _PulsarPainter extends CustomPainter {
  const _PulsarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * .5, h * .035)
      ..cubicTo(w * .43, h * .035, w * .46, h * .26, w * .25, h * .40)
      ..cubicTo(w * .13, h * .48, w * .035, h * .47, w * .035, h * .5)
      ..cubicTo(w * .035, h * .54, w * .24, h * .52, w * .39, h * .75)
      ..cubicTo(w * .47, h * .87, w * .46, h * .965, w * .5, h * .965)
      ..cubicTo(w * .54, h * .965, w * .53, h * .78, w * .73, h * .61)
      ..cubicTo(w * .84, h * .53, w * .965, h * .54, w * .965, h * .5)
      ..cubicTo(w * .965, h * .46, w * .76, h * .47, w * .61, h * .25)
      ..cubicTo(w * .53, h * .13, w * .55, h * .035, w * .5, h * .035)
      ..close();

    final shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: <Color>[
        Color(0xFF08D8E9),
        Color(0xFF075BFF),
        Color(0xFF9B25F5),
        Color(0xFFEF2DB4),
        Color(0xFFFF874A),
      ],
      stops: <double>[0, .29, .56, .78, 1],
    ).createShader(Offset.zero & size);
    canvas.drawPath(path, Paint()..shader = shader);

    final symbolPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = w * .055
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    // Bold, geometric greater-than sign.
    final chevron = Path()
      ..moveTo(w * .405, h * .445)
      ..lineTo(w * .49, h * .5)
      ..lineTo(w * .405, h * .555);
    canvas.drawPath(chevron, symbolPaint);

    canvas.drawLine(
      Offset(w * .535, h * .5),
      Offset(w * .605, h * .5),
      symbolPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PulsarPainter oldDelegate) => false;
}
