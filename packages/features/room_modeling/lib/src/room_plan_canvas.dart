import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/room_modeling_bloc.dart';
import 'bloc/room_modeling_event.dart';
import 'bloc/room_modeling_state.dart';
import 'models/wall.dart';
import 'models/furniture.dart';

class RoomPlanCanvas extends StatelessWidget {
  const RoomPlanCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoomModelingBloc, RoomModelingState>(
      builder: (context, state) {
        return GestureDetector(
          onPanStart: (details) {
            context.read<RoomModelingBloc>().add(
                  CanvasPanStart(details.localPosition),
                );
          },
          onPanUpdate: (details) {
            context.read<RoomModelingBloc>().add(
                  CanvasPanUpdate(details.localPosition),
                );
          },
          onPanEnd: (details) {
            context.read<RoomModelingBloc>().add(const CanvasPanEnd());
          },
          onTapUp: (details) {
            context.read<RoomModelingBloc>().add(
                  CanvasTap(details.localPosition),
                );
          },
          child: Container(
            color: Colors.white, // Canvas background
            child: CustomPaint(
              painter: RoomPainter(
                walls: state.walls,
                tempWall: state.tempWall,
                dragCurrent: state.dragCurrent,
                isRoomClosed: state.isRoomClosed,
                furniture: state.furniture,
                selectedWallId: state.selectedWallId,
              ),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }
}

class RoomPainter extends CustomPainter {
  final List<Wall> walls;
  final List<Furniture> furniture;
  final Wall? tempWall;
  final Offset? dragCurrent;
  final bool isRoomClosed;
  final String? selectedWallId;

  RoomPainter({
    required this.walls,
    this.furniture = const [],
    this.tempWall,
    this.dragCurrent,
    required this.isRoomClosed,
    this.selectedWallId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final wallPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final selectedWallPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final tempWallPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.5)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final jointPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw existing walls
    for (final wall in walls) {
      final isSelected = wall.id == selectedWallId;
      canvas.drawLine(
          wall.start, wall.end, isSelected ? selectedWallPaint : wallPaint);
      canvas.drawCircle(wall.start, 3.0, jointPaint);
      canvas.drawCircle(wall.end, 3.0, jointPaint);

      // Draw dimensions
      _drawDimension(canvas, textPainter, wall);

      if (isSelected) {
        // Draw handles
        final handlePaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.fill;

        canvas.drawCircle(wall.start, 8.0, handlePaint);
        canvas.drawCircle(wall.end, 8.0, handlePaint);

        // Draw white center for handle
        final handleCenterPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

        canvas.drawCircle(wall.start, 4.0, handleCenterPaint);
        canvas.drawCircle(wall.end, 4.0, handleCenterPaint);
      }
    }

    // Draw angles between connected walls
    for (int i = 0; i < walls.length; i++) {
      for (int j = i + 1; j < walls.length; j++) {
        _drawAngle(canvas, textPainter, walls[i], walls[j]);
      }
    }

    // Draw temp wall
    if (tempWall != null) {
      canvas.drawLine(tempWall!.start, tempWall!.end, tempWallPaint);
      canvas.drawCircle(tempWall!.start, 4.0, jointPaint);
      canvas.drawCircle(tempWall!.end, 4.0, jointPaint);

      // Draw dimension for temp wall
      _drawDimension(canvas, textPainter, tempWall!);

      // Draw angle between temp wall and connected existing walls
      for (final wall in walls) {
        _drawAngle(canvas, textPainter, wall, tempWall!);
      }
    }

    // Draw snap indicator if dragging
    if (dragCurrent != null) {
      canvas.drawCircle(
        dragCurrent!,
        6.0,
        Paint()..color = Colors.blue.withValues(alpha: 0.3),
      );
    }

    // Draw room closed indicator (fill)
    if (isRoomClosed && walls.isNotEmpty) {
      // This is a simplification. For a real filled polygon we need to order vertices.
      // But for visual feedback that the room is closed, we can change the background or something.
      // Here I'll just draw a green border around the canvas to indicate success.
      /*
      final borderPaint = Paint()
        ..color = Colors.green
        ..strokeWidth = 10.0
        ..style = PaintingStyle.stroke;
      canvas.drawRect(Offset.zero & size, borderPaint);
      */
    }

    // Draw furniture
    for (final item in furniture) {
      _drawFurniture(canvas, item);
    }
  }

  void _drawDimension(Canvas canvas, TextPainter textPainter, Wall wall) {
    final midPoint = (wall.start + wall.end) / 2;
    final length = (wall.start - wall.end).distance;
    // Assuming 50 pixels = 1 meter
    final text = '${(length / 50).toStringAsFixed(2)} m';

    textPainter.text = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    );
    textPainter.layout();

    // Draw background for text to make it readable over grid/lines
    final textRect = Rect.fromCenter(
      center: midPoint,
      width: textPainter.width + 6,
      height: textPainter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(textRect, const Radius.circular(4)),
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
    textPainter.paint(
      canvas,
      midPoint - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _drawAngle(
    Canvas canvas,
    TextPainter textPainter,
    Wall w1,
    Wall w2,
  ) {
    Offset? commonPoint;
    Offset? p1;
    Offset? p2;

    const double epsilon = 1.0;

    if ((w1.start - w2.start).distance < epsilon) {
      commonPoint = w1.start;
      p1 = w1.end;
      p2 = w2.end;
    } else if ((w1.start - w2.end).distance < epsilon) {
      commonPoint = w1.start;
      p1 = w1.end;
      p2 = w2.start;
    } else if ((w1.end - w2.start).distance < epsilon) {
      commonPoint = w1.end;
      p1 = w1.start;
      p2 = w2.end;
    } else if ((w1.end - w2.end).distance < epsilon) {
      commonPoint = w1.end;
      p1 = w1.start;
      p2 = w2.start;
    }

    if (commonPoint != null && p1 != null && p2 != null) {
      final v1 = p1 - commonPoint;
      final v2 = p2 - commonPoint;

      final dot = v1.dx * v2.dx + v1.dy * v2.dy;
      final mag1 = v1.distance;
      final mag2 = v2.distance;

      if (mag1 > 0 && mag2 > 0) {
        final cosAngle = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
        final angleRad = acos(cosAngle);
        final angleDeg = angleRad * 180 / pi;

        // Only draw if not 90 degrees (with some tolerance)
        if ((angleDeg - 90).abs() > 0.1) {
          // Draw arc
          final angle1 = v1.direction;
          final angle2 = v2.direction;
          var delta = angle2 - angle1;
          while (delta <= -pi) {
            delta += 2 * pi;
          }
          while (delta > pi) {
            delta -= 2 * pi;
          }

          final arcPaint = Paint()
            ..color = Colors.red
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;

          canvas.drawArc(
            Rect.fromCircle(center: commonPoint, radius: 25),
            angle1,
            delta,
            false,
            arcPaint,
          );

          final text = '${angleDeg.toStringAsFixed(1)}°';

          textPainter.text = TextSpan(
            text: text,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          );
          textPainter.layout();

          // Calculate position for text (along bisector)
          final v1Norm = v1 / mag1;
          final v2Norm = v2 / mag2;
          var bisector = v1Norm + v2Norm;
          if (bisector.distance == 0) {
            // Collinear opposite vectors, angle is 180
            bisector = Offset(-v1Norm.dy, v1Norm.dx); // Perpendicular
          } else {
            bisector = bisector / bisector.distance;
          }

          // Position text slightly further out than the arc
          final textPos = commonPoint + bisector * 40.0;

          // Draw background
          final textRect = Rect.fromCenter(
            center: textPos,
            width: textPainter.width + 6,
            height: textPainter.height + 4,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(textRect, const Radius.circular(4)),
            Paint()..color = Colors.white.withValues(alpha: 0.8),
          );

          textPainter.paint(
            canvas,
            textPos - Offset(textPainter.width / 2, textPainter.height / 2),
          );
        }
      }
    }
  }

  void _drawFurniture(Canvas canvas, Furniture item) {
    canvas.save();
    canvas.translate(item.position.dx, item.position.dy);
    canvas.rotate(item.rotation);

    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    switch (item.type) {
      case FurnitureType.door:
        // Door frame/clearing
        // We assume door width is around 40-50 units.
        // Draw arc
        final rect = Rect.fromCircle(center: const Offset(-25, 0), radius: 50);
        canvas.drawArc(rect, 0, -pi / 2, true, strokePaint);
        // Draw door panel (already drawn by drawArc with useCenter=true, but let's be explicit if needed)
        break;

      case FurnitureType.window:
        // Clear wall
        canvas.drawRect(const Rect.fromLTWH(-25, -6, 50, 12), fillPaint);
        // Frame
        canvas.drawRect(const Rect.fromLTWH(-25, -6, 50, 12), strokePaint);
        // Glass/Sill
        canvas.drawLine(const Offset(-25, 0), const Offset(25, 0), strokePaint);
        // Inner lines
        canvas.drawLine(const Offset(-25, -3), const Offset(25, -3),
            strokePaint..strokeWidth = 0.5);
        canvas.drawLine(const Offset(-25, 3), const Offset(25, 3),
            strokePaint..strokeWidth = 0.5);
        break;

      case FurnitureType.chair:
        // Seat
        canvas.drawRect(const Rect.fromLTWH(-10, -10, 20, 20), fillPaint);
        canvas.drawRect(const Rect.fromLTWH(-10, -10, 20, 20), strokePaint);
        // Backrest
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-10, -15, 20, 5),
            const Radius.circular(2),
          ),
          fillPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-10, -15, 20, 5),
            const Radius.circular(2),
          ),
          strokePaint,
        );
        break;

      case FurnitureType.table:
        // Table top
        canvas.drawCircle(Offset.zero, 20, fillPaint);
        canvas.drawCircle(Offset.zero, 20, strokePaint);
        break;

      case FurnitureType.sofa:
        // Main body
        canvas.drawRect(const Rect.fromLTWH(-30, -15, 60, 30), fillPaint);
        canvas.drawRect(const Rect.fromLTWH(-30, -15, 60, 30), strokePaint);
        // Backrest
        canvas.drawRect(const Rect.fromLTWH(-30, -20, 60, 5), fillPaint);
        canvas.drawRect(const Rect.fromLTWH(-30, -20, 60, 5), strokePaint);
        // Armrests
        canvas.drawRect(const Rect.fromLTWH(-35, -15, 5, 30), fillPaint);
        canvas.drawRect(const Rect.fromLTWH(-35, -15, 5, 30), strokePaint);
        canvas.drawRect(const Rect.fromLTWH(30, -15, 5, 30), fillPaint);
        canvas.drawRect(const Rect.fromLTWH(30, -15, 5, 30), strokePaint);
        // Cushions separation
        canvas.drawLine(const Offset(0, -15), const Offset(0, 15),
            strokePaint..strokeWidth = 0.5);
        break;

      case FurnitureType.bed:
        // Bed frame
        canvas.drawRect(const Rect.fromLTWH(-25, -40, 50, 80), fillPaint);
        canvas.drawRect(const Rect.fromLTWH(-25, -40, 50, 80), strokePaint);
        // Pillows
        canvas.drawRect(const Rect.fromLTWH(-20, -35, 18, 12), strokePaint);
        canvas.drawRect(const Rect.fromLTWH(2, -35, 18, 12), strokePaint);
        // Duvet fold
        canvas.drawLine(const Offset(-25, 0), const Offset(25, 0),
            strokePaint..strokeWidth = 0.5);
        // Fold diagonal
        canvas.drawLine(const Offset(10, 0), const Offset(25, 15),
            strokePaint..strokeWidth = 0.5);
        break;

      case FurnitureType.bathtub:
        // Frame
        canvas.drawRect(const Rect.fromLTWH(-35, -15, 70, 30), fillPaint);
        canvas.drawRect(const Rect.fromLTWH(-35, -15, 70, 30), strokePaint);
        // Tub (rounded rect)
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-30, -10, 60, 20),
            const Radius.circular(10),
          ),
          strokePaint,
        );
        // Drain
        canvas.drawCircle(const Offset(25, 0), 2.0, strokePaint);
        break;

      case FurnitureType.toilet:
        // Tank
        canvas.drawRect(const Rect.fromLTWH(-10, -15, 20, 10), fillPaint);
        canvas.drawRect(const Rect.fromLTWH(-10, -15, 20, 10), strokePaint);
        // Bowl
        canvas.drawOval(const Rect.fromLTWH(-8, -5, 16, 20), fillPaint);
        canvas.drawOval(const Rect.fromLTWH(-8, -5, 16, 20), strokePaint);
        break;

      case FurnitureType.sink:
        // Counter/Frame
        canvas.drawRect(const Rect.fromLTWH(-15, -15, 30, 30), fillPaint);
        canvas.drawRect(const Rect.fromLTWH(-15, -15, 30, 30), strokePaint);
        // Basin
        canvas.drawCircle(Offset.zero, 10, strokePaint);
        // Tap
        canvas.drawLine(
            const Offset(0, -15), const Offset(0, -10), strokePaint);
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RoomPainter oldDelegate) {
    return oldDelegate.walls != walls ||
        oldDelegate.furniture != furniture ||
        oldDelegate.tempWall != tempWall ||
        oldDelegate.dragCurrent != dragCurrent ||
        oldDelegate.isRoomClosed != isRoomClosed ||
        oldDelegate.selectedWallId != selectedWallId;
  }
}
