import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraPreviewWidget extends StatefulWidget {
  final CameraController controller;
  final Function(bool)? onFaceDetected;

  const CameraPreviewWidget({
    Key? key,
    required this.controller,
    this.onFaceDetected,
  }) : super(key: key);

  @override
  _CameraPreviewWidgetState createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  @override
  Widget build(BuildContext context) {
    if (!widget.controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(widget.controller),
          CustomPaint(
            painter: FaceOverlayPainter(),
          ),
        ],
      ),
    );
  }
}

class FaceOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Draw face detection overlay
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2.2),
      width: size.width * 0.7,
      height: size.height * 0.6,
    );

    // Draw rounded rectangle
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(20));
    canvas.drawRRect(rrect, paint);

    // Draw corner indicators
    final cornerPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    const cornerSize = 20.0;
    
    // Top-left corner
    canvas.drawRect(
      Rect.fromLTWH(rect.left - 3, rect.top - 3, cornerSize, 6),
      cornerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.left - 3, rect.top - 3, 6, cornerSize),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawRect(
      Rect.fromLTWH(rect.right - cornerSize + 3, rect.top - 3, cornerSize, 6),
      cornerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.right - 3, rect.top - 3, 6, cornerSize),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawRect(
      Rect.fromLTWH(rect.left - 3, rect.bottom - 3, cornerSize, 6),
      cornerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.left - 3, rect.bottom - cornerSize + 3, 6, cornerSize),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawRect(
      Rect.fromLTWH(rect.right - cornerSize + 3, rect.bottom - 3, cornerSize, 6),
      cornerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.right - 3, rect.bottom - cornerSize + 3, 6, cornerSize),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}