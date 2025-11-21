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

  RoomPainter({
    required this.walls,
    this.furniture = const [],
    this.tempWall,
    this.dragCurrent,
    required this.isRoomClosed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final wallPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final tempWallPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.5)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final jointPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Draw existing walls
    for (final wall in walls) {
      canvas.drawLine(wall.start, wall.end, wallPaint);
      canvas.drawCircle(wall.start, 4.0, jointPaint);
      canvas.drawCircle(wall.end, 4.0, jointPaint);
    }

    // Draw temp wall
    if (tempWall != null) {
      canvas.drawLine(tempWall!.start, tempWall!.end, tempWallPaint);
      canvas.drawCircle(tempWall!.start, 4.0, jointPaint);
      canvas.drawCircle(tempWall!.end, 4.0, jointPaint);
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

  void _drawFurniture(Canvas canvas, Furniture item) {
    canvas.save();
    canvas.translate(item.position.dx, item.position.dy);
    canvas.rotate(item.rotation);

    final paint = Paint()
      ..color = Colors.brown
      ..style = PaintingStyle.fill;

    switch (item.type) {
      case FurnitureType.door:
        // Draw door arc
        final doorPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(-20, 0), radius: 40),
          0,
          -pi / 2,
          true,
          doorPaint,
        );
        break;
      case FurnitureType.window:
        paint.color = Colors.blue.withValues(alpha: 0.5);
        canvas.drawRect(const Rect.fromLTWH(-20, -5, 40, 10), paint);
        break;
      case FurnitureType.chair:
        canvas.drawRect(const Rect.fromLTWH(-10, -10, 20, 20), paint);
        break;
      case FurnitureType.table:
        canvas.drawCircle(Offset.zero, 20, paint);
        break;
      case FurnitureType.sofa:
        canvas.drawRect(const Rect.fromLTWH(-30, -15, 60, 30), paint);
        break;
      case FurnitureType.bed:
        canvas.drawRect(const Rect.fromLTWH(-25, -40, 50, 80), paint);
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
        oldDelegate.isRoomClosed != isRoomClosed;
  }
}
