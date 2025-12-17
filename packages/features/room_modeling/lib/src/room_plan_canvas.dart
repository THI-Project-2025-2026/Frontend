import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/room_modeling_bloc.dart';
import 'bloc/room_modeling_event.dart';
import 'bloc/room_modeling_state.dart';
import 'models/furniture.dart';
import 'models/wall.dart';
import 'room_modeling_l10n.dart';

class RoomPlanCanvas extends StatelessWidget {
  const RoomPlanCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoomModelingBloc, RoomModelingState>(
      builder: (context, state) {
        final palette = _RoomCanvasPalette();
        return LayoutBuilder(
          builder: (context, constraints) {
            final mediaSize = MediaQuery.sizeOf(context);
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : mediaSize.width;
            final height = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : mediaSize.height;
            final canvasSize = Size(width, height);

            return GestureDetector(
              onPanStart: (details) {
                context.read<RoomModelingBloc>().add(
                      CanvasPanStart(details.localPosition, canvasSize),
                    );
              },
              onPanUpdate: (details) {
                context.read<RoomModelingBloc>().add(
                      CanvasPanUpdate(details.localPosition, canvasSize),
                    );
              },
              onPanEnd: (details) {
                context.read<RoomModelingBloc>().add(const CanvasPanEnd());
              },
              onTapUp: (details) {
                context.read<RoomModelingBloc>().add(
                      CanvasTap(details.localPosition, canvasSize),
                    );
              },
              child: Container(
                color: palette.background,
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
                    palette: palette,
                  ),
                  size: canvasSize,
                ),
              ),
            );
          },
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
  final _RoomCanvasPalette palette;
  final String metersSuffix;
  final String degreesSuffix;

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
    required this.palette,
  })  : metersSuffix = RoomModelingL10n.metersSuffix(),
        degreesSuffix = RoomModelingL10n.degreesSuffix();

  @override
  void paint(Canvas canvas, Size size) {
    if (isRoomClosed && roomPolygon != null && roomPolygon!.isNotEmpty) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = palette.exterior,
      );
      final path = Path()..addPolygon(roomPolygon!, true);
      canvas.drawPath(path, Paint()..color = palette.interior);
    }

    final wallPaint = Paint()
      ..color = palette.wall
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final selectedWallPaint = Paint()
      ..color = palette.wallSelected
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final tempWallPaint = Paint()
      ..color = palette.tempWall
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final wall in walls) {
      final isSelected = wall.id == selectedWallId;
      canvas.drawLine(
        wall.start,
        wall.end,
        isSelected ? selectedWallPaint : wallPaint,
      );

      _drawDimension(canvas, textPainter, wall);

      if (isSelected) {
        final handlePaint = Paint()
          ..color = palette.selectionHandle
          ..style = PaintingStyle.fill;
        final handleCenterPaint = Paint()
          ..color = palette.selectionHandleCenter
          ..style = PaintingStyle.fill;

        canvas.drawCircle(wall.start, 8.0, handlePaint);
        canvas.drawCircle(wall.end, 8.0, handlePaint);
        canvas.drawCircle(wall.start, 4.0, handleCenterPaint);
        canvas.drawCircle(wall.end, 4.0, handleCenterPaint);
      }
    }

    for (int i = 0; i < walls.length; i++) {
      for (int j = i + 1; j < walls.length; j++) {
        _drawAngle(canvas, textPainter, walls[i], walls[j]);
      }
    }

    for (final guide in snapGuides) {
      final guidePaint = Paint()
        ..color = palette.snapLine
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(guide.start, guide.end, guidePaint);

      final midPoint = (guide.start + guide.end) / 2;
      final length = (guide.start - guide.end).distance;
      final text = '${(length / 50).toStringAsFixed(2)} $metersSuffix';

      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: palette.snapText,
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
        Paint()..color = palette.snapBackground,
      );
      textPainter.paint(
        canvas,
        midPoint - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    if (tempWall != null) {
      canvas.drawLine(tempWall!.start, tempWall!.end, tempWallPaint);
      _drawDimension(canvas, textPainter, tempWall!);

      for (final wall in walls) {
        _drawAngle(canvas, textPainter, wall, tempWall!);
      }
    }

    if (dragCurrent != null) {
      canvas.drawCircle(
        dragCurrent!,
        6.0,
        Paint()..color = palette.dragIndicator,
      );
    }

    for (final item in furniture) {
      _drawFurniture(canvas, item);
    }

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
    final text = '${(length / 50).toStringAsFixed(2)} $metersSuffix';

    textPainter.text = TextSpan(
      text: text,
      style: TextStyle(
        color: palette.dimensionText,
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
      Paint()..color = palette.dimensionBackground,
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

        if ((angleDeg - 90).abs() > 0.1) {
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
            ..color = palette.angleArc
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;

          canvas.drawArc(
            Rect.fromCircle(center: commonPoint, radius: 25),
            angle1,
            delta,
            false,
            arcPaint,
          );

          final text = '${angleDeg.toStringAsFixed(1)}$degreesSuffix';

          textPainter.text = TextSpan(
            text: text,
            style: TextStyle(
              color: palette.angleText,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          );
          textPainter.layout();

          final v1Norm = v1 / mag1;
          final v2Norm = v2 / mag2;
          var bisector = v1Norm + v2Norm;
          if (bisector.distance == 0) {
            bisector = Offset(-v1Norm.dy, v1Norm.dx);
          } else {
            bisector = bisector / bisector.distance;
          }

          final textPos = commonPoint + bisector * 40.0;

          final textRect = Rect.fromCenter(
            center: textPos,
            width: textPainter.width + 6,
            height: textPainter.height + 4,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(textRect, const Radius.circular(4)),
            Paint()..color = palette.angleBackground,
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

    final borderPaint = Paint()
      ..color = palette.selectionBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: width + 10,
      height: height + 10,
    );
    canvas.drawRect(rect, borderPaint);

    final isOpening = Furniture.isOpeningType(item.type);

    final handlePaint = Paint()..color = palette.selectionHandle;
    canvas.drawCircle(Offset(halfWidth, halfHeight), 6.0, handlePaint);
    canvas.drawCircle(
      Offset(halfWidth, halfHeight),
      3.0,
      Paint()..color = palette.selectionHandleCenter,
    );

    if (!isOpening) {
      final rotateHandlePos = Offset(0, -halfHeight - 30);
      canvas.drawLine(
        Offset(0, -halfHeight - 5),
        rotateHandlePos,
        Paint()
          ..color = palette.rotateHandleLine
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        rotateHandlePos,
        6.0,
        Paint()..color = palette.rotateHandleFill,
      );
      canvas.drawCircle(
        rotateHandlePos,
        3.0,
        Paint()..color = palette.rotateHandleCenter,
      );
    }

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
      ..color = palette.furnitureStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillPaint = Paint()
      ..color = palette.furnitureFill
      ..style = PaintingStyle.fill;

    switch (item.type) {
      case FurnitureType.door:
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          strokePaint,
        );
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
        final seatRect = Rect.fromCenter(
          center: Offset(0, height * 0.1),
          width: width,
          height: height * 0.8,
        );
        final seatRRect = RRect.fromRectAndRadius(
          seatRect,
          const Radius.circular(4.0),
        );
        canvas.drawRRect(seatRRect, fillPaint);
        canvas.drawRRect(seatRRect, strokePaint);
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
      case FurnitureType.deskchair:
        // Desk chair: similar to chair but with a neck/headrest indicator
        final seatRect = Rect.fromCenter(
          center: Offset(0, height * 0.1),
          width: width,
          height: height * 0.75,
        );
        final seatRRect = RRect.fromRectAndRadius(
          seatRect,
          const Radius.circular(4.0),
        );
        canvas.drawRRect(seatRRect, fillPaint);
        canvas.drawRRect(seatRRect, strokePaint);

        final backrestRect = Rect.fromLTWH(
          -halfWidth,
          -halfHeight,
          width,
          height * 0.35,
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

        // Small headrest bar
        canvas.drawLine(
          Offset(-halfWidth * 0.6, -halfHeight + 4),
          Offset(halfWidth * 0.6, -halfHeight + 4),
          strokePaint,
        );
        break;
      case FurnitureType.table:
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          fillPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          strokePaint,
        );
        break;
      case FurnitureType.sofa:
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          fillPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          strokePaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(-halfWidth, -halfHeight, width, height * 0.2),
          strokePaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(-halfWidth, -halfHeight, width * 0.15, height),
          strokePaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(
              halfWidth - width * 0.15, -halfHeight, width * 0.15, height),
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
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: width, height: height),
            const Radius.circular(8.0),
          ),
          fillPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: width, height: height),
            const Radius.circular(8.0),
          ),
          strokePaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: width * 0.8, height: height * 0.8),
            const Radius.circular(6.0),
          ),
          strokePaint,
        );
        canvas.drawCircle(
          Offset(width * 0.35, 0),
          min(width, height) * 0.08,
          strokePaint,
        );
        break;
      case FurnitureType.toilet:
        canvas.drawRect(
          Rect.fromLTWH(
            -halfWidth,
            -halfHeight,
            width,
            height * 0.25,
          ),
          strokePaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(0, height * 0.1),
              width: width * 0.8,
              height: height * 0.7,
            ),
            const Radius.circular(4.0),
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
      case FurnitureType.closet:
        // Closet: rectangle with vertical door lines
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          fillPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          strokePaint,
        );
        // Draw door dividers
        canvas.drawLine(Offset.zero, Offset(0, halfHeight), strokePaint);
        canvas.drawLine(Offset.zero, Offset(0, -halfHeight), strokePaint);
        break;
      case FurnitureType.desk:
        // Desk: rectangle with drawer indication
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          fillPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          strokePaint,
        );
        // Draw drawer lines
        canvas.drawLine(
          Offset(-halfWidth, height * 0.25),
          Offset(halfWidth, height * 0.25),
          strokePaint,
        );
        break;
      case FurnitureType.shelf:
        // Shelf: rectangle with horizontal lines
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          fillPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          strokePaint,
        );
        // Draw shelves
        canvas.drawLine(
          Offset(-halfWidth, 0),
          Offset(halfWidth, 0),
          strokePaint,
        );
        break;
      case FurnitureType.stove:
        // Stove: square with circles for burners
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          fillPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          strokePaint,
        );
        // Draw 4 burners
        final burnerRadius = min(width, height) * 0.15;
        final offset = min(width, height) * 0.25;
        canvas.drawCircle(Offset(-offset, -offset), burnerRadius, strokePaint);
        canvas.drawCircle(Offset(offset, -offset), burnerRadius, strokePaint);
        canvas.drawCircle(Offset(-offset, offset), burnerRadius, strokePaint);
        canvas.drawCircle(Offset(offset, offset), burnerRadius, strokePaint);
        break;
      case FurnitureType.fridge:
        // Fridge: rectangle with horizontal line for freezer compartment
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          fillPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          strokePaint,
        );
        canvas.drawLine(
          Offset(-halfWidth, -height * 0.25),
          Offset(halfWidth, -height * 0.25),
          strokePaint,
        );
        break;
      case FurnitureType.shower:
        // Shower: square with diagonal lines for tiles
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          fillPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          strokePaint,
        );
        // Draw shower head indicator
        canvas.drawCircle(
          Offset(-halfWidth * 0.6, -halfHeight * 0.6),
          min(width, height) * 0.1,
          strokePaint,
        );
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

class _RoomCanvasPalette {
  final Color background = RoomModelingColors.color('canvas.background');
  final Color exterior = RoomModelingColors.color('canvas.outside');
  final Color interior = RoomModelingColors.color('canvas.inside');
  final Color wall = RoomModelingColors.color('canvas.wall');
  final Color wallSelected = RoomModelingColors.color('canvas.wall_selected');
  final Color tempWall = RoomModelingColors.color('canvas.temp_wall');
  final Color selectionHandle =
      RoomModelingColors.color('canvas.selection_handle');
  final Color selectionHandleCenter =
      RoomModelingColors.color('canvas.selection_handle_center');
  final Color snapLine = RoomModelingColors.color('canvas.snap_line');
  final Color snapText = RoomModelingColors.color('canvas.snap_text');
  final Color snapBackground =
      RoomModelingColors.color('canvas.snap_background');
  final Color dragIndicator = RoomModelingColors.color('canvas.drag_indicator');
  final Color dimensionText = RoomModelingColors.color('canvas.dimension_text');
  final Color dimensionBackground =
      RoomModelingColors.color('canvas.dimension_background');
  final Color angleArc = RoomModelingColors.color('canvas.angle_arc');
  final Color angleText = RoomModelingColors.color('canvas.angle_text');
  final Color angleBackground =
      RoomModelingColors.color('canvas.angle_background');
  final Color selectionFill = RoomModelingColors.color('canvas.selection_fill');
  final Color selectionBorder =
      RoomModelingColors.color('canvas.selection_border');
  final Color rotateHandleLine =
      RoomModelingColors.color('canvas.rotate_handle_line');
  final Color rotateHandleFill =
      RoomModelingColors.color('canvas.rotate_handle_fill');
  final Color rotateHandleCenter =
      RoomModelingColors.color('canvas.rotate_handle_center');
  final Color furnitureStroke =
      RoomModelingColors.color('canvas.furniture_stroke');
  final Color furnitureFill = RoomModelingColors.color('canvas.furniture_fill');
}
