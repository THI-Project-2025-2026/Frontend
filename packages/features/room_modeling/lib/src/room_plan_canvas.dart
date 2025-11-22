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
                selectedFurnitureId: state.selectedFurnitureId,
                snapGuides: state.snapGuides,
                roomPolygon: state.roomPolygon,
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
  final String? selectedFurnitureId;
  final List<SnapGuideLine> snapGuides;
  final List<Offset>? roomPolygon;

  RoomPainter({
    required this.walls,
    this.furniture = const [],
    this.tempWall,
    this.dragCurrent,
    required this.isRoomClosed,
    this.selectedWallId,
    this.selectedFurnitureId,
    this.snapGuides = const [],
    this.roomPolygon,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw outside area if room is closed
    if (isRoomClosed && roomPolygon != null && roomPolygon!.isNotEmpty) {
      // Fill the entire canvas with "outside" color
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: 0.4),
      );

      // Draw the room polygon with "inside" color (white)
      final path = Path()..addPolygon(roomPolygon!, true);
      canvas.drawPath(path, Paint()..color = Colors.white);
    }

    final wallPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final selectedWallPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final tempWallPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.5)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw existing walls
    for (final wall in walls) {
      final isSelected = wall.id == selectedWallId;
      canvas.drawLine(
          wall.start, wall.end, isSelected ? selectedWallPaint : wallPaint);
      // canvas.drawCircle(wall.start, 3.0, jointPaint);
      // canvas.drawCircle(wall.end, 3.0, jointPaint);

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

    // Draw snap guides
    for (final guide in snapGuides) {
      final guidePaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.5)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(guide.start, guide.end, guidePaint);

      // Draw distance for snap guide
      final midPoint = (guide.start + guide.end) / 2;
      final length = (guide.start - guide.end).distance;
      final text = '${(length / 50).toStringAsFixed(2)} m';

      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.red.withValues(alpha: 0.8),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();

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

    // Draw temp wall
    if (tempWall != null) {
      canvas.drawLine(tempWall!.start, tempWall!.end, tempWallPaint);
      // canvas.drawCircle(tempWall!.start, 4.0, jointPaint);
      // canvas.drawCircle(tempWall!.end, 4.0, jointPaint);

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

    // Draw selection overlay on top
    if (selectedFurnitureId != null) {
      try {
        final selectedItem =
            furniture.firstWhere((f) => f.id == selectedFurnitureId);
        _drawSelectionOverlay(canvas, selectedItem);
      } catch (_) {
        // Item might have been deleted
      }
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

  void _drawSelectionOverlay(Canvas canvas, Furniture item) {
    canvas.save();
    canvas.translate(item.position.dx, item.position.dy);
    canvas.rotate(item.rotation);

    final width = item.size.width;
    final height = item.size.height;
    final halfWidth = width / 2;
    final halfHeight = height / 2;

    final selectionPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: width + 10,
      height: height + 10,
    );
    canvas.drawRect(rect, selectionPaint);
    canvas.drawRect(rect, borderPaint);

    // Draw resize handle (bottom right)
    final handlePaint = Paint()..color = Colors.blue;
    canvas.drawCircle(Offset(halfWidth, halfHeight), 6.0, handlePaint);
    canvas.drawCircle(
      Offset(halfWidth, halfHeight),
      3.0,
      Paint()..color = Colors.white,
    );

    // Draw rotate handle (top center)
    final rotateHandlePos = Offset(0, -halfHeight - 30);
    canvas.drawLine(
      Offset(0, -halfHeight - 5),
      rotateHandlePos,
      Paint()
        ..color = Colors.blue
        ..strokeWidth = 2,
    );
    canvas.drawCircle(rotateHandlePos, 6.0, handlePaint);
    canvas.drawCircle(rotateHandlePos, 3.0, Paint()..color = Colors.white);

    canvas.restore();
  }

  void _drawFurniture(Canvas canvas, Furniture item) {
    canvas.save();
    canvas.translate(item.position.dx, item.position.dy);
    canvas.rotate(item.rotation);

    final width = item.size.width;
    final height = item.size.height;
    final halfWidth = width / 2;
    final halfHeight = height / 2;

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
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          strokePaint,
        );
        // Draw arc for swing
        canvas.drawArc(
          Rect.fromLTWH(-halfWidth, -width, width * 2, width * 2),
          pi,
          pi / 2,
          true,
          strokePaint,
        );
        break;

      case FurnitureType.window:
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          fillPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          strokePaint,
        );
        canvas.drawLine(
          Offset(-halfWidth, 0),
          Offset(halfWidth, 0),
          strokePaint,
        );
        break;

      case FurnitureType.chair:
        // Seat (slightly rounded)
        final seatRect = Rect.fromCenter(
          center: Offset(0, height * 0.1), // Shift seat down slightly
          width: width,
          height: height * 0.8,
        );
        final seatRRect = RRect.fromRectAndRadius(
          seatRect,
          const Radius.circular(4.0),
        );

        canvas.drawRRect(seatRRect, fillPaint);
        canvas.drawRRect(seatRRect, strokePaint);

        // Backrest (curved)
        final backrestRect = Rect.fromLTWH(
          -halfWidth,
          -halfHeight,
          width,
          height * 0.25,
        );
        final backrestRRect = RRect.fromRectAndCorners(
          backrestRect,
          topLeft: const Radius.circular(8.0),
          topRight: const Radius.circular(8.0),
          bottomLeft: const Radius.circular(4.0),
          bottomRight: const Radius.circular(4.0),
        );

        canvas.drawRRect(backrestRRect, fillPaint);
        canvas.drawRRect(backrestRRect, strokePaint);
        break;

      case FurnitureType.table:
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          fillPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          strokePaint,
        );
        break;

      case FurnitureType.sofa:
        // Body
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          fillPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          strokePaint,
        );
        // Backrest
        canvas.drawRect(
          Rect.fromLTWH(
            -halfWidth,
            -halfHeight,
            width,
            height * 0.2,
          ),
          strokePaint,
        );
        // Armrests
        canvas.drawRect(
          Rect.fromLTWH(
            -halfWidth,
            -halfHeight,
            width * 0.15,
            height,
          ),
          strokePaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            halfWidth - width * 0.15,
            -halfHeight,
            width * 0.15,
            height,
          ),
          strokePaint,
        );
        break;

      case FurnitureType.bed:
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          fillPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          strokePaint,
        );
        // Pillows
        canvas.drawRect(
          Rect.fromLTWH(
            -halfWidth + width * 0.1,
            -halfHeight + height * 0.05,
            width * 0.35,
            height * 0.2,
          ),
          strokePaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            halfWidth - width * 0.45,
            -halfHeight + height * 0.05,
            width * 0.35,
            height * 0.2,
          ),
          strokePaint,
        );
        break;

      case FurnitureType.bathtub:
        // Outer rim
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: width, height: height),
            Radius.circular(min(width, height) / 4),
          ),
          fillPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: width, height: height),
            Radius.circular(min(width, height) / 4),
          ),
          strokePaint,
        );
        // Inner rim
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: width * 0.8, height: height * 0.8),
            Radius.circular(min(width, height) / 5),
          ),
          strokePaint,
        );
        // Drain
        canvas.drawCircle(
            Offset(width * 0.35, 0), min(width, height) * 0.08, strokePaint);
        break;

      case FurnitureType.toilet:
        // Tank
        canvas.drawRect(
          Rect.fromLTWH(
            -halfWidth,
            -halfHeight,
            width,
            height * 0.25,
          ),
          strokePaint,
        );
        // Bowl
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, height * 0.1),
            width: width * 0.8,
            height: height * 0.7,
          ),
          strokePaint,
        );
        break;

      case FurnitureType.sink:
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          fillPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          strokePaint,
        );
        canvas.drawCircle(Offset.zero, min(width, height) / 3, strokePaint);
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
        oldDelegate.selectedWallId != selectedWallId ||
        oldDelegate.selectedFurnitureId != selectedFurnitureId ||
        oldDelegate.snapGuides != snapGuides ||
        oldDelegate.roomPolygon != roomPolygon;
  }
}
