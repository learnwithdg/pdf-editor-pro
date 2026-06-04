import 'package:flutter/material.dart';

class SignatureResult {
  const SignatureResult({
    required this.points,
    required this.canvasSize,
  });

  final List<Offset> points;
  final Size canvasSize;
}

class SignatureDialog extends StatefulWidget {
  const SignatureDialog({super.key, required this.color});

  final Color color;

  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<SignatureDialog> {
  final List<Offset?> _points = <Offset?>[];
  Size _canvasSize = const Size(320, 280);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Draw Signature'),
      content: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = Size(constraints.maxWidth, 280);
          _canvasSize = canvasSize;
          return Container(
            width: double.maxFinite,
            height: canvasSize.height,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey.shade50,
            ),
            child: GestureDetector(
              onPanStart: (details) {
                setState(() {
                  _points.add(details.localPosition);
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _points.add(details.localPosition);
                });
              },
              onPanEnd: (_) => _points.add(null),
              child: CustomPaint(
                painter: _SignaturePainter(points: _points, color: widget.color),
                size: canvasSize,
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => setState(_points.clear),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _points.whereType<Offset>().length < 2
              ? null
              : () {
                  final result = SignatureResult(
                    points: _points.whereType<Offset>().toList(growable: false),
                    canvasSize: _canvasSize,
                  );
                  Navigator.pop(context, result);
                },
          child: const Text('Add Signature'),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({
    required this.points,
    required this.color,
  });

  final List<Offset?> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.0;

    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}
