import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../models/wall.dart';
import '../models/furniture.dart';
import 'room_modeling_event.dart';
import 'room_modeling_state.dart';

class RoomModelingBloc extends Bloc<RoomModelingEvent, RoomModelingState> {
  final _uuid = const Uuid();
  static const double snapDistance = 20.0;
  static const double pixelsPerMeter = 50.0;

  RoomModelingBloc() : super(const RoomModelingState()) {
    on<ToolSelected>(_onToolSelected);
    on<StepChanged>(_onStepChanged);
    on<WallSelected>(_onWallSelected);
    on<DeleteSelectedWall>(_onDeleteSelectedWall);
    on<DeleteSelectedFurniture>(_onDeleteSelectedFurniture);
    on<UpdateSelectedFurniture>(_onUpdateSelectedFurniture);
    on<RoomHeightChanged>(_onRoomHeightChanged);
    on<CanvasPanStart>(_onCanvasPanStart);
    on<CanvasPanUpdate>(_onCanvasPanUpdate);
    on<CanvasPanEnd>(_onCanvasPanEnd);
    on<CanvasTap>(_onCanvasTap);
    on<ClearRoom>(_onClearRoom);
  }

  void _onToolSelected(ToolSelected event, Emitter<RoomModelingState> emit) {
    emit(state.copyWith(activeTool: event.tool, clearSelection: true));
  }

  void _onStepChanged(StepChanged event, Emitter<RoomModelingState> emit) {
    if (event.step == RoomModelingStep.furnishing && !state.isRoomClosed) {
      return;
    }

    // Default tool when switching steps
    RoomModelingTool newTool = RoomModelingTool.wall;
    if (event.step == RoomModelingStep.furnishing) {
      // Default tool for furnishing could be anything, let's say door or just none/select
      // But we removed select. Let's default to door for now or keep previous if valid.
      newTool = RoomModelingTool.door;
    }

    emit(state.copyWith(
      currentStep: event.step,
      activeTool: newTool,
      clearSelection: true,
    ));
  }

  void _onWallSelected(WallSelected event, Emitter<RoomModelingState> emit) {
    emit(state.copyWith(selectedWallId: event.wallId));
  }

  void _onDeleteSelectedWall(
    DeleteSelectedWall event,
    Emitter<RoomModelingState> emit,
  ) {
    if (state.selectedWallId == null) return;

    final updatedWalls =
        state.walls.where((w) => w.id != state.selectedWallId).toList();
    final (isClosed, polygon) = _checkIfRoomIsClosed(updatedWalls);

    emit(
      state.copyWith(
        walls: updatedWalls,
        isRoomClosed: isClosed,
        roomPolygon: polygon,
        clearSelection: true,
      ),
    );
  }

  void _onDeleteSelectedFurniture(
    DeleteSelectedFurniture event,
    Emitter<RoomModelingState> emit,
  ) {
    if (state.selectedFurnitureId == null) return;

    final updatedFurniture = state.furniture
        .where((f) => f.id != state.selectedFurnitureId)
        .toList();

    emit(state.copyWith(furniture: updatedFurniture, clearSelection: true));
  }

  void _onUpdateSelectedFurniture(
    UpdateSelectedFurniture event,
    Emitter<RoomModelingState> emit,
  ) {
    final selectedId = state.selectedFurnitureId;
    if (selectedId == null) return;

    final index = state.furniture.indexWhere((f) => f.id == selectedId);
    if (index == -1) return;

    var target = state.furniture[index];

    if (event.size != null) {
      target = target.copyWith(
        size: _constrainFurnitureSize(target, event.size!),
      );
    }

    if (event.rotation != null && !target.isOpening) {
      target = target.copyWith(rotation: _normalizeAngle(event.rotation!));
    }

    if (event.sillHeightMeters != null && target.type == FurnitureType.window) {
      target = target.copyWith(
        sillHeightMeters: _clampWindowMetric(event.sillHeightMeters!),
      );
    }

    if (event.openingHeightMeters != null &&
        target.type == FurnitureType.window) {
      target = target.copyWith(
        openingHeightMeters: _clampWindowMetric(event.openingHeightMeters!),
      );
    }

    final updatedFurniture = [...state.furniture];
    updatedFurniture[index] = target;

    emit(state.copyWith(furniture: updatedFurniture));
  }

  void _onCanvasPanStart(
    CanvasPanStart event,
    Emitter<RoomModelingState> emit,
  ) {
    if (state.currentStep == RoomModelingStep.furnishing) {
      if (state.selectedFurnitureId != null) {
        final furniture = state.furniture.firstWhere(
          (f) => f.id == state.selectedFurnitureId,
        );
        final position = event.position;

        final interaction = _getFurnitureInteraction(position, furniture);

        if (interaction != FurnitureInteraction.none) {
          emit(
            state.copyWith(
              furnitureInteraction: interaction,
              initialFurnitureState: furniture,
              dragStart: position,
            ),
          );
        }
      }
      return;
    }

    if (state.currentStep == RoomModelingStep.structure) {
      final position = event.position;

      // 1. Check if we are grabbing a handle of the selected wall
      if (state.selectedWallId != null) {
        final selectedWall =
            state.walls.firstWhere((w) => w.id == state.selectedWallId);

        int? movingEndpoint;
        Offset? vertexPos;

        if ((selectedWall.start - position).distance < 20.0) {
          movingEndpoint = 0;
          vertexPos = selectedWall.start;
        } else if ((selectedWall.end - position).distance < 20.0) {
          movingEndpoint = 1;
          vertexPos = selectedWall.end;
        }

        if (movingEndpoint != null && vertexPos != null) {
          // Find all walls connected to this vertex and which endpoint is connected
          final movingWallEndpoints = <String, int>{};
          for (final wall in state.walls) {
            if ((wall.start - vertexPos).distance < 0.001) {
              movingWallEndpoints[wall.id] = 0;
            } else if ((wall.end - vertexPos).distance < 0.001) {
              movingWallEndpoints[wall.id] = 1;
            }
          }

          emit(state.copyWith(
            movingWallEndpoint: movingEndpoint,
            movingWallEndpoints: movingWallEndpoints,
            dragStart: position,
          ));
          return;
        }
      }

      if (state.isRoomClosed) return; // Cannot add walls if room is closed

      // Snap start point to existing wall endpoints
      Offset startPoint = event.position;
      for (final wall in state.walls) {
        if ((wall.start - startPoint).distance < snapDistance) {
          startPoint = wall.start;
          break;
        }
        if ((wall.end - startPoint).distance < snapDistance) {
          startPoint = wall.end;
          break;
        }
      }

      emit(
        state.copyWith(
          dragStart: startPoint,
          dragCurrent: startPoint,
          tempWall: Wall(id: 'temp', start: startPoint, end: startPoint),
          clearSelection: true,
        ),
      );
    }
  }

  void _onCanvasPanUpdate(
    CanvasPanUpdate event,
    Emitter<RoomModelingState> emit,
  ) {
    if (state.furnitureInteraction != FurnitureInteraction.none &&
        state.selectedFurnitureId != null &&
        state.initialFurnitureState != null &&
        state.dragStart != null) {
      final currentPos = event.position;
      final initial = state.initialFurnitureState!;
      final delta = currentPos - state.dragStart!;

      Furniture updatedFurniture = initial;

      if (state.furnitureInteraction == FurnitureInteraction.move) {
        final desiredPosition = initial.position + delta;
        Offset constrained;
        if (initial.isOpening && initial.attachedWallId != null) {
          constrained = _projectOntoAttachedWall(initial, desiredPosition);
        } else {
          constrained = _clampFurnitureCenter(
            initial,
            desiredPosition,
            event.canvasSize,
          );
        }
        updatedFurniture = initial.copyWith(position: constrained);
      } else if (state.furnitureInteraction == FurnitureInteraction.rotate &&
          !initial.isOpening) {
        final center = initial.position;
        final dx = currentPos.dx - center.dx;
        final dy = currentPos.dy - center.dy;
        final angle = atan2(dy, dx);
        updatedFurniture = initial.copyWith(rotation: angle + pi / 2);
      } else if (state.furnitureInteraction == FurnitureInteraction.resize) {
        final localPos = _globalToLocal(currentPos, initial);
        final newSize = _computeResizedSize(initial, localPos);
        updatedFurniture = initial.copyWith(size: newSize);
      }

      final updatedFurnitureList = state.furniture
          .map((f) => f.id == updatedFurniture.id ? updatedFurniture : f)
          .toList();

      emit(state.copyWith(furniture: updatedFurnitureList));
      return;
    }

    if (state.movingWallEndpoint != null && state.selectedWallId != null) {
      final position = event.position;
      Offset newPos = position;
      bool snappedToVertex = false;
      List<SnapGuideLine> snapGuides = [];

      // Snap to other walls (Vertex Snapping)
      for (final wall in state.walls) {
        // Don't snap to walls that are currently moving
        if (state.movingWallEndpoints.containsKey(wall.id)) continue;

        if ((wall.start - newPos).distance < snapDistance) {
          newPos = wall.start;
          snappedToVertex = true;
          break;
        }
        if ((wall.end - newPos).distance < snapDistance) {
          newPos = wall.end;
          snappedToVertex = true;
          break;
        }
      }

      // Alignment Snapping (if not snapped to vertex)
      if (!snappedToVertex) {
        // Collect anchors from moving walls
        final anchors = <Offset>[];
        for (final entry in state.movingWallEndpoints.entries) {
          final wall = state.walls.firstWhere((w) => w.id == entry.key);
          // If endpoint 0 is moving, anchor is endpoint 1 (end)
          // If endpoint 1 is moving, anchor is endpoint 0 (start)
          anchors.add(entry.value == 0 ? wall.end : wall.start);
        }

        final snapResult = _calculateSnapPosition(
          newPos,
          anchors,
          state.walls,
          excludeWallIds: state.movingWallEndpoints.keys.toList(),
        );
        newPos = snapResult.$1;
        snapGuides = snapResult.$2;
      }

      final updatedWalls = state.walls.map((w) {
        // Only update walls that were identified as moving at the start of the drag
        if (!state.movingWallEndpoints.containsKey(w.id)) {
          return w;
        }

        final endpointIndex = state.movingWallEndpoints[w.id];

        if (endpointIndex == 0) {
          return w.copyWith(start: newPos);
        } else {
          return w.copyWith(end: newPos);
        }
      }).toList();

      // Check for intersections and invalid walls
      bool invalid = false;
      for (final wall in updatedWalls) {
        // Only check walls that moved
        if (!state.movingWallEndpoints.containsKey(wall.id)) continue;

        // Check length (prevent points)
        if ((wall.start - wall.end).distance < 5.0) {
          invalid = true;
          break;
        }

        for (final other in updatedWalls) {
          if (wall.id == other.id) continue;

          // Ignore connected walls (sharing a vertex)
          if ((wall.start - other.start).distance < 0.001 ||
              (wall.start - other.end).distance < 0.001 ||
              (wall.end - other.start).distance < 0.001 ||
              (wall.end - other.end).distance < 0.001) {
            continue;
          }

          if (_doSegmentsIntersect(
              wall.start, wall.end, other.start, other.end)) {
            invalid = true;
            break;
          }

          // Check T-junctions (point on segment)
          if (_isPointOnSegment(wall.start, other.start, other.end) ||
              _isPointOnSegment(wall.end, other.start, other.end) ||
              _isPointOnSegment(other.start, wall.start, wall.end) ||
              _isPointOnSegment(other.end, wall.start, wall.end)) {
            invalid = true;
            break;
          }
        }
        if (invalid) break;
      }

      if (invalid) {
        return;
      }

      final (isClosed, polygon) = _checkIfRoomIsClosed(updatedWalls);

      final adjustedFurniture = _repositionAttachedOpenings(
        state.furniture,
        state.walls,
        updatedWalls,
        state.movingWallEndpoints.keys.toSet(),
      );

      emit(state.copyWith(
        walls: updatedWalls,
        furniture: adjustedFurniture,
        isRoomClosed: isClosed,
        roomPolygon: polygon,
        dragCurrent: newPos,
        snapGuides: snapGuides,
        clearSnapGuide: snapGuides.isEmpty,
      ));
      return;
    }

    if (state.currentStep == RoomModelingStep.structure &&
        state.tempWall != null &&
        state.dragStart != null) {
      Offset endPoint = event.position;
      bool snappedToWall = false;
      List<SnapGuideLine> snapGuides = [];

      // Snap end point to existing wall endpoints (excluding the start point of current wall if it's the same)
      for (final wall in state.walls) {
        if ((wall.start - endPoint).distance < snapDistance) {
          endPoint = wall.start;
          snappedToWall = true;
          break;
        }
        if ((wall.end - endPoint).distance < snapDistance) {
          endPoint = wall.end;
          snappedToWall = true;
          break;
        }
      }

      // Alignment Snapping (if not snapped to vertex)
      if (!snappedToWall) {
        final snapResult = _calculateSnapPosition(
          endPoint,
          [state.dragStart!],
          state.walls,
        );
        endPoint = snapResult.$1;
        snapGuides = snapResult.$2;
      }

      // Check for intersections for temp wall
      bool invalid = false;
      final tempStart = state.tempWall!.start;
      final tempEnd = endPoint;

      // Check length
      if ((tempStart - tempEnd).distance < 5.0) invalid = true;

      if (!invalid) {
        for (final wall in state.walls) {
          // Ignore if connected at start or end (snapped)
          if ((tempStart - wall.start).distance < 0.001 ||
              (tempStart - wall.end).distance < 0.001 ||
              (tempEnd - wall.start).distance < 0.001 ||
              (tempEnd - wall.end).distance < 0.001) {
            continue;
          }

          if (_doSegmentsIntersect(tempStart, tempEnd, wall.start, wall.end)) {
            invalid = true;
            break;
          }

          // Check T-junctions
          if (_isPointOnSegment(tempStart, wall.start, wall.end) ||
              _isPointOnSegment(tempEnd, wall.start, wall.end) ||
              _isPointOnSegment(wall.start, tempStart, tempEnd) ||
              _isPointOnSegment(wall.end, tempStart, tempEnd)) {
            invalid = true;
            break;
          }
        }
      }

      if (invalid) {
        return;
      }

      emit(
        state.copyWith(
          dragCurrent: endPoint,
          tempWall: state.tempWall?.copyWith(end: endPoint),
          snapGuides: snapGuides,
          clearSnapGuide: snapGuides.isEmpty,
        ),
      );
    }
  }

  bool _isPointOnSegment(Offset p, Offset a, Offset b) {
    const double epsilon = 0.5;
    // Check bounding box
    if (p.dx < min(a.dx, b.dx) - epsilon ||
        p.dx > max(a.dx, b.dx) + epsilon ||
        p.dy < min(a.dy, b.dy) - epsilon ||
        p.dy > max(a.dy, b.dy) + epsilon) {
      return false;
    }
    // Check cross product for collinearity
    final cp = (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
    if (cp.abs() > epsilon) return false;
    // Check if strictly inside (not endpoints)
    if ((p - a).distance < epsilon || (p - b).distance < epsilon) return false;
    return true;
  }

  bool _doSegmentsIntersect(Offset p1, Offset p2, Offset p3, Offset p4) {
    double ccw(Offset a, Offset b, Offset c) {
      return (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
    }

    return ccw(p1, p3, p4) * ccw(p2, p3, p4) < 0 &&
        ccw(p1, p2, p3) * ccw(p1, p2, p4) < 0;
  }

  (Offset, List<SnapGuideLine>) _calculateSnapPosition(
    Offset currentPos,
    List<Offset> anchors,
    List<Wall> allWalls, {
    List<String> excludeWallIds = const [],
  }) {
    // 1. Identify Candidate Lines
    final candidateLines =
        <(Offset, Offset)>[]; // (Origin, DirectionNormalized)

    // A. Lines from Anchors (Constraint Lines)
    for (final anchor in anchors) {
      // Horizontal
      candidateLines.add((anchor, const Offset(1, 0)));
      // Vertical
      candidateLines.add((anchor, const Offset(0, 1)));
    }

    // B. Perpendicular Lines from All Walls (Global Guides)
    for (final wall in allWalls) {
      if (excludeWallIds.contains(wall.id)) continue;

      final vec = wall.end - wall.start;
      final len = vec.distance;
      if (len > 0.001) {
        final dir = vec / len;
        final perp = Offset(-dir.dy, dir.dx);

        // Add perpendicular lines at start and end
        candidateLines.add((wall.start, perp));
        candidateLines.add((wall.end, perp));
      }
    }

    // 2. Find all lines close to currentPos
    final closeLines = <(Offset, Offset, Offset)>[]; // (Origin, Dir, ProjPoint)

    for (final line in candidateLines) {
      final origin = line.$1;
      final dir = line.$2;

      // Project currentPos onto line
      final v = currentPos - origin;
      final projLen = v.dx * dir.dx + v.dy * dir.dy;
      final projPoint = origin + dir * projLen;

      final dist = (currentPos - projPoint).distance;
      if (dist < snapDistance) {
        closeLines.add((origin, dir, projPoint));
      }
    }

    if (closeLines.isEmpty) {
      return (currentPos, []);
    }

    // 3. Check for Intersection Snap (if >= 2 lines)
    if (closeLines.length >= 2) {
      // Find best intersection
      Offset? bestIntersection;
      double minIntDist = snapDistance;
      List<SnapGuideLine> bestGuides = [];

      for (int i = 0; i < closeLines.length; i++) {
        for (int j = i + 1; j < closeLines.length; j++) {
          final l1 = closeLines[i];
          final l2 = closeLines[j];

          // Check if parallel
          final det = l1.$2.dx * l2.$2.dy - l1.$2.dy * l2.$2.dx;
          if (det.abs() < 0.001) continue; // Parallel

          // Find intersection
          final dx = l2.$1.dx - l1.$1.dx;
          final dy = l2.$1.dy - l1.$1.dy;

          final t1 = (dx * l2.$2.dy - dy * l2.$2.dx) / det;
          final intersection = l1.$1 + l1.$2 * t1;

          final dist = (currentPos - intersection).distance;
          if (dist < minIntDist) {
            minIntDist = dist;
            bestIntersection = intersection;

            bestGuides = [
              SnapGuideLine(l1.$1, intersection),
              SnapGuideLine(l2.$1, intersection),
            ];
          }
        }
      }

      if (bestIntersection != null) {
        return (bestIntersection, bestGuides);
      }
    }

    // 4. Fallback to Single Line Snap (closest)
    double minLineDist = snapDistance;
    (Offset, Offset, Offset)? bestLine;

    for (final line in closeLines) {
      final dist = (currentPos - line.$3).distance;
      if (dist < minLineDist) {
        minLineDist = dist;
        bestLine = line;
      }
    }

    if (bestLine == null) return (currentPos, []);

    final lineOrigin = bestLine.$1;
    final lineDir = bestLine.$2;
    final lineProj = bestLine.$3;

    // 5. Check for Point Projection on this line
    Offset finalSnap = lineProj;
    List<SnapGuideLine> guides = [SnapGuideLine(lineOrigin, finalSnap)];
    double minPointDist = snapDistance;

    // Collect all interesting points (endpoints of other walls)
    final interestingPoints = <Offset>[];
    for (final wall in allWalls) {
      if (excludeWallIds.contains(wall.id)) continue;
      interestingPoints.add(wall.start);
      interestingPoints.add(wall.end);
    }

    for (final p in interestingPoints) {
      // Project p onto bestLine
      final v = p - lineOrigin;
      final projLen = v.dx * lineDir.dx + v.dy * lineDir.dy;
      final pProj = lineOrigin + lineDir * projLen;

      // Check if the projected point is close to our current projection on the line
      final dist = (lineProj - pProj).distance;
      if (dist < minPointDist) {
        minPointDist = dist;
        finalSnap = pProj;

        guides = [
          SnapGuideLine(lineOrigin, finalSnap),
          SnapGuideLine(p, finalSnap),
        ];
      }
    }

    // Update the end point of the first guide if we snapped to a point projection
    if (guides.isNotEmpty) {
      guides[0] = SnapGuideLine(guides[0].start, finalSnap);
    }

    return (finalSnap, guides);
  }

  void _onCanvasPanEnd(CanvasPanEnd event, Emitter<RoomModelingState> emit) {
    if (state.furnitureInteraction != FurnitureInteraction.none) {
      emit(state.copyWith(clearDrag: true));
      return;
    }

    if (state.movingWallEndpoint != null) {
      emit(state.copyWith(clearDrag: true));
      return;
    }

    if (state.currentStep == RoomModelingStep.structure &&
        state.tempWall != null) {
      final newWall = state.tempWall!.copyWith(id: _uuid.v4());

      // Don't add zero-length walls
      if ((newWall.start - newWall.end).distance < 5.0) {
        emit(state.copyWith(clearDrag: true));
        return;
      }

      final updatedWalls = List<Wall>.from(state.walls)..add(newWall);
      final (isClosed, polygon) = _checkIfRoomIsClosed(updatedWalls);

      emit(
        state.copyWith(
          walls: updatedWalls,
          isRoomClosed: isClosed,
          roomPolygon: polygon,
          clearDrag: true,
        ),
      );
    }
  }

  void _onCanvasTap(CanvasTap event, Emitter<RoomModelingState> emit) {
    if (state.currentStep == RoomModelingStep.structure) {
      // Hit test for walls
      final position = event.position;
      String? hitWallId;

      // Simple hit test: distance to line segment
      for (final wall in state.walls) {
        final point = _projectPointOnSegment(position, wall.start, wall.end);
        if ((point - position).distance < 10.0) {
          hitWallId = wall.id;
          break;
        }
      }

      emit(state.copyWith(selectedWallId: hitWallId));
      return;
    }

    if (!state.isRoomClosed) return;
    // Furnishing step logic below

    final position = event.position;

    // Check if we tapped on existing furniture
    for (final furniture in state.furniture.reversed) {
      if (furniture.id == state.selectedFurnitureId) {
        // For selected furniture, check body AND handles
        if (_getFurnitureInteraction(position, furniture) !=
            FurnitureInteraction.none) {
          return; // Tapped on selected furniture/handles, keep selection
        }
      } else {
        // For other furniture, only check body
        if (_isPointInRotatedRect(position, furniture)) {
          emit(state.copyWith(selectedFurnitureId: furniture.id));
          return;
        }
      }
    }

    // If we have a selection and clicked empty space, deselect
    if (state.selectedFurnitureId != null) {
      emit(state.copyWith(clearSelection: true));
      return;
    }

    FurnitureType type;

    switch (state.activeTool) {
      case RoomModelingTool.door:
        type = FurnitureType.door;
        break;
      case RoomModelingTool.window:
        type = FurnitureType.window;
        break;
      case RoomModelingTool.chair:
        type = FurnitureType.chair;
        break;
      case RoomModelingTool.table:
        type = FurnitureType.table;
        break;
      case RoomModelingTool.sofa:
        type = FurnitureType.sofa;
        break;
      case RoomModelingTool.bed:
        type = FurnitureType.bed;
        break;
      case RoomModelingTool.bathtub:
        type = FurnitureType.bathtub;
        break;
      case RoomModelingTool.toilet:
        type = FurnitureType.toilet;
        break;
      case RoomModelingTool.sink:
        type = FurnitureType.sink;
        break;
      default:
        return;
    }

    // For doors and windows, we need to find the nearest wall and snap to it
    String? attachedWallId;
    Offset finalPosition = position;
    double rotation = 0.0;

    if (type == FurnitureType.door || type == FurnitureType.window) {
      Wall? nearestWall;
      double minDistance = double.infinity;
      Offset? projectedPoint;

      for (final wall in state.walls) {
        final point = _projectPointOnSegment(position, wall.start, wall.end);
        final distance = (point - position).distance;
        if (distance < minDistance) {
          minDistance = distance;
          nearestWall = wall;
          projectedPoint = point;
        }
      }

      if (nearestWall != null && minDistance < 30.0) {
        // Snap threshold
        attachedWallId = nearestWall.id;
        finalPosition = projectedPoint!;
        // Calculate rotation to align with wall
        final dx = nearestWall.end.dx - nearestWall.start.dx;
        final dy = nearestWall.end.dy - nearestWall.start.dy;
        rotation = atan2(dy, dx);
      } else {
        // If not close enough to a wall, don't place door/window
        return;
      }
    }

    final newFurniture = Furniture(
      id: _uuid.v4(),
      type: type,
      position: finalPosition,
      rotation: rotation,
      size: Furniture.defaultSize(type),
      attachedWallId: attachedWallId,
      sillHeightMeters: type == FurnitureType.window
          ? Furniture.defaultWindowSillHeightMeters
          : null,
      openingHeightMeters: type == FurnitureType.window
          ? Furniture.defaultWindowHeightMeters
          : null,
    );

    // Check if furniture is inside the room (if not attached to a wall)
    if (attachedWallId == null && state.roomPolygon != null) {
      if (!_isPointInPolygon(finalPosition, state.roomPolygon!)) {
        return;
      }
    }

    emit(
      state.copyWith(furniture: List.from(state.furniture)..add(newFurniture)),
    );
  }

  bool _isPointInPolygon(Offset point, List<Offset> polygon) {
    int intersectCount = 0;
    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];

      if ((p1.dy > point.dy) != (p2.dy > point.dy) &&
          point.dx <
              (p2.dx - p1.dx) * (point.dy - p1.dy) / (p2.dy - p1.dy) + p1.dx) {
        intersectCount++;
      }
    }
    return intersectCount % 2 == 1;
  }

  Offset _projectPointOnSegment(Offset p, Offset a, Offset b) {
    final ap = p - a;
    final ab = b - a;
    final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
    final dot = ap.dx * ab.dx + ap.dy * ab.dy;
    final t = (dot / ab2).clamp(0.0, 1.0);
    return a + ab * t;
  }

  void _onRoomHeightChanged(
    RoomHeightChanged event,
    Emitter<RoomModelingState> emit,
  ) {
    var sanitized = event.heightMeters;
    if (!sanitized.isFinite) {
      sanitized = RoomModelingState.defaultRoomHeightMeters;
    }
    sanitized = min(max(sanitized, 2.0), 5.0);
    emit(state.copyWith(roomHeightMeters: sanitized));
  }

  void _onClearRoom(ClearRoom event, Emitter<RoomModelingState> emit) {
    emit(const RoomModelingState());
  }

  List<Furniture> _repositionAttachedOpenings(
    List<Furniture> furniture,
    List<Wall> previousWalls,
    List<Wall> updatedWalls,
    Set<String> movedWallIds,
  ) {
    if (movedWallIds.isEmpty) {
      return furniture;
    }

    final prevLookup = {for (final wall in previousWalls) wall.id: wall};
    final newLookup = {for (final wall in updatedWalls) wall.id: wall};

    bool changed = false;
    final result = <Furniture>[];

    for (final item in furniture) {
      final wallId = item.attachedWallId;
      if (!item.isOpening || wallId == null || !movedWallIds.contains(wallId)) {
        result.add(item);
        continue;
      }

      final prevWall = prevLookup[wallId];
      final newWall = newLookup[wallId];
      if (prevWall == null || newWall == null) {
        result.add(item);
        continue;
      }

      final relative = _relativePositionAlongWall(prevWall, item.position);
      final newPosition = _positionAlongWallWithMargin(
        newWall,
        relative,
        item.size.width / 2,
      );
      final newRotation = _wallAngle(newWall);

      result.add(
        item.copyWith(position: newPosition, rotation: newRotation),
      );
      changed = true;
    }

    return changed ? result : furniture;
  }

  double _relativePositionAlongWall(Wall wall, Offset point) {
    final vector = wall.end - wall.start;
    final lenSquared = vector.dx * vector.dx + vector.dy * vector.dy;
    if (lenSquared < 0.0001) {
      return 0.5;
    }

    final projection = ((point.dx - wall.start.dx) * vector.dx +
            (point.dy - wall.start.dy) * vector.dy) /
        lenSquared;
    return projection.clamp(0.0, 1.0);
  }

  Offset _positionAlongWallWithMargin(
    Wall wall,
    double relative,
    double halfLength,
  ) {
    final vector = wall.end - wall.start;
    final length = vector.distance;
    if (length < 0.001) {
      return wall.start;
    }

    final direction = vector / length;
    final margin = min(halfLength, length / 2);
    final targetDistance = (relative.clamp(0.0, 1.0)) * length;
    final clampedDistance = targetDistance.clamp(margin, length - margin);

    return wall.start + direction * clampedDistance;
  }

  double _wallAngle(Wall wall) {
    final dx = wall.end.dx - wall.start.dx;
    final dy = wall.end.dy - wall.start.dy;
    return atan2(dy, dx);
  }

  double _clampWindowMetric(double value) {
    if (!value.isFinite) {
      return Furniture.defaultWindowHeightMeters;
    }
    return value.clamp(0.05, 5.0);
  }

  Size _computeResizedSize(Furniture furniture, Offset localPoint) {
    final width = max(20.0, localPoint.dx.abs() * 2);
    final height = max(20.0, localPoint.dy.abs() * 2);

    if (_isLinearOpening(furniture.type)) {
      return Size(width, furniture.size.height);
    }

    return Size(width, height);
  }

  Size _constrainFurnitureSize(Furniture furniture, Size desiredSize) {
    final width = max(20.0, desiredSize.width);
    final height = max(20.0, desiredSize.height);

    if (_isLinearOpening(furniture.type)) {
      return Size(width, furniture.size.height);
    }

    return Size(width, height);
  }

  bool _isLinearOpening(FurnitureType type) {
    return Furniture.isOpeningType(type);
  }

  double _normalizeAngle(double angle) {
    final fullCircle = 2 * pi;
    var normalized = angle;
    while (normalized < 0) {
      normalized += fullCircle;
    }
    while (normalized >= fullCircle) {
      normalized -= fullCircle;
    }
    return normalized;
  }

  Offset _clampFurnitureCenter(
    Furniture furniture,
    Offset desiredCenter,
    Size canvasSize,
  ) {
    if (!canvasSize.width.isFinite || !canvasSize.height.isFinite) {
      return desiredCenter;
    }

    final halfExtents = _rotatedHalfExtents(furniture);

    double minX = halfExtents.width;
    double maxX = canvasSize.width - halfExtents.width;
    if (maxX < minX) {
      minX = maxX = canvasSize.width / 2;
    }

    double minY = halfExtents.height;
    double maxY = canvasSize.height - halfExtents.height;
    if (maxY < minY) {
      minY = maxY = canvasSize.height / 2;
    }

    return Offset(
      desiredCenter.dx.clamp(minX, maxX),
      desiredCenter.dy.clamp(minY, maxY),
    );
  }

  Offset _projectOntoAttachedWall(
    Furniture furniture,
    Offset desiredCenter,
  ) {
    final wallId = furniture.attachedWallId;
    if (wallId == null) {
      return desiredCenter;
    }

    Wall? attached;
    for (final wall in state.walls) {
      if (wall.id == wallId) {
        attached = wall;
        break;
      }
    }

    if (attached == null) {
      return desiredCenter;
    }

    final wallVector = attached.end - attached.start;
    final wallLength = wallVector.distance;
    if (wallLength < 0.001) {
      return attached.start;
    }

    final wallDir = wallVector / wallLength;
    final startToDesired = desiredCenter - attached.start;
    final projectedLength =
        startToDesired.dx * wallDir.dx + startToDesired.dy * wallDir.dy;

    final halfLength = furniture.size.width / 2;
    final safeMargin = min(halfLength, wallLength / 2);
    final clampedLength =
        projectedLength.clamp(safeMargin, wallLength - safeMargin);

    return attached.start + wallDir * clampedLength;
  }

  Size _rotatedHalfExtents(Furniture furniture) {
    final width = furniture.size.width;
    final height = furniture.size.height;
    final cosA = cos(furniture.rotation).abs();
    final sinA = sin(furniture.rotation).abs();

    final halfWidth = (width * cosA + height * sinA) / 2;
    final halfHeight = (width * sinA + height * cosA) / 2;

    return Size(halfWidth, halfHeight);
  }

  (bool, List<Offset>?) _checkIfRoomIsClosed(List<Wall> walls) {
    if (walls.length < 3) return (false, null);

    // Build adjacency list
    final Map<String, List<String>> adj = {};
    final points = <String>{};
    final pointToOffset = <String, Offset>{};

    String pointKey(Offset p) =>
        '${p.dx.toStringAsFixed(1)},${p.dy.toStringAsFixed(1)}';

    for (final wall in walls) {
      final p1 = pointKey(wall.start);
      final p2 = pointKey(wall.end);

      points.add(p1);
      points.add(p2);
      pointToOffset[p1] = wall.start;
      pointToOffset[p2] = wall.end;

      adj.putIfAbsent(p1, () => []).add(p2);
      adj.putIfAbsent(p2, () => []).add(p1);
    }

    // Check degree condition
    for (final point in points) {
      if ((adj[point]?.length ?? 0) < 2) {
        return (false, null);
      }
    }

    // Check connectivity (BFS)
    if (points.isEmpty) return (false, null);
    final startNode = points.first;
    final visited = <String>{};
    final queue = [startNode];
    visited.add(startNode);

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final neighbor in adj[current] ?? []) {
        if (!visited.contains(neighbor)) {
          visited.add(neighbor);
          queue.add(neighbor);
        }
      }
    }

    if (visited.length != points.length) return (false, null);

    // Build ordered polygon
    // Start from a point and traverse
    final polygon = <Offset>[];
    final polyVisited = <String>{};
    String current = startNode;
    String? previous;

    // Simple traversal for a single loop
    // Note: This assumes a simple polygon without self-intersections or multiple loops sharing vertices
    // For a robust solution, we'd need a more complex graph traversal, but for this use case:

    while (true) {
      polygon.add(pointToOffset[current]!);
      polyVisited.add(current);

      final neighbors = adj[current]!;
      String? next;

      for (final n in neighbors) {
        if (n != previous) {
          // If we have multiple choices and one is visited (and it's the start), close the loop
          if (n == startNode && polygon.length > 2) {
            return (true, polygon);
          }
          if (!polyVisited.contains(n)) {
            next = n;
            break;
          }
        }
      }

      if (next == null) {
        // Dead end or loop closed but not to start?
        // If we are back at start (handled above), we are good.
        // If we can't move, something is wrong or we are done.
        // Check if last connects to start
        if (neighbors.contains(startNode) &&
            previous != startNode &&
            polygon.length > 2) {
          return (true, polygon);
        }
        return (false, null);
      }

      previous = current;
      current = next;
    }
  }

  FurnitureInteraction _getFurnitureInteraction(
    Offset point,
    Furniture furniture,
  ) {
    // Transform point to local coordinates
    final localPoint = _globalToLocal(point, furniture);
    final halfWidth = furniture.size.width / 2;
    final halfHeight = furniture.size.height / 2;

    // Check rotate handle (top center + 30px up)
    // In local coords, this is (0, -halfHeight - 30)
    // Allow some hit radius
    if (!furniture.isOpening &&
        (localPoint - Offset(0, -halfHeight - 30)).distance < 15.0) {
      return FurnitureInteraction.rotate;
    }

    // Check resize handle (bottom right)
    // In local coords, this is (halfWidth, halfHeight)
    if ((localPoint - Offset(halfWidth, halfHeight)).distance < 15.0) {
      return FurnitureInteraction.resize;
    }

    // Check body (move)
    if (localPoint.dx >= -halfWidth &&
        localPoint.dx <= halfWidth &&
        localPoint.dy >= -halfHeight &&
        localPoint.dy <= halfHeight) {
      return FurnitureInteraction.move;
    }

    return FurnitureInteraction.none;
  }

  bool _isPointInRotatedRect(Offset point, Furniture furniture) {
    final localPoint = _globalToLocal(point, furniture);
    final halfWidth = furniture.size.width / 2;
    final halfHeight = furniture.size.height / 2;

    return localPoint.dx >= -halfWidth &&
        localPoint.dx <= halfWidth &&
        localPoint.dy >= -halfHeight &&
        localPoint.dy <= halfHeight;
  }

  Offset _globalToLocal(Offset point, Furniture furniture) {
    final translated = point - furniture.position;
    final cosA = cos(-furniture.rotation);
    final sinA = sin(-furniture.rotation);
    return Offset(
      translated.dx * cosA - translated.dy * sinA,
      translated.dx * sinA + translated.dy * cosA,
    );
  }
}
