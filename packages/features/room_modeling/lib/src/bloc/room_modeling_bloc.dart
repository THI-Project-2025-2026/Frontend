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

  RoomModelingBloc() : super(const RoomModelingState()) {
    on<ToolSelected>(_onToolSelected);
    on<StepChanged>(_onStepChanged);
    on<WallSelected>(_onWallSelected);
    on<DeleteSelectedWall>(_onDeleteSelectedWall);
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
    final isClosed = _checkIfRoomIsClosed(updatedWalls);

    emit(
      state.copyWith(
        walls: updatedWalls,
        isRoomClosed: isClosed,
        clearSelection: true,
      ),
    );
  }

  void _onCanvasPanStart(
    CanvasPanStart event,
    Emitter<RoomModelingState> emit,
  ) {
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

      final isClosed = _checkIfRoomIsClosed(updatedWalls);

      emit(state.copyWith(
        walls: updatedWalls,
        isRoomClosed: isClosed,
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
      final isClosed = _checkIfRoomIsClosed(updatedWalls);

      emit(
        state.copyWith(
          walls: updatedWalls,
          isRoomClosed: isClosed,
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
      attachedWallId: attachedWallId,
    );

    emit(
      state.copyWith(furniture: List.from(state.furniture)..add(newFurniture)),
    );
  }

  Offset _projectPointOnSegment(Offset p, Offset a, Offset b) {
    final ap = p - a;
    final ab = b - a;
    final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
    final dot = ap.dx * ab.dx + ap.dy * ab.dy;
    final t = (dot / ab2).clamp(0.0, 1.0);
    return a + ab * t;
  }

  void _onClearRoom(ClearRoom event, Emitter<RoomModelingState> emit) {
    emit(const RoomModelingState());
  }

  bool _checkIfRoomIsClosed(List<Wall> walls) {
    if (walls.length < 3) return false;

    // Build adjacency list
    final Map<String, List<String>> adj = {};
    final points = <String>{};

    String pointKey(Offset p) =>
        '${p.dx.toStringAsFixed(1)},${p.dy.toStringAsFixed(1)}';

    for (final wall in walls) {
      final p1 = pointKey(wall.start);
      final p2 = pointKey(wall.end);

      points.add(p1);
      points.add(p2);

      adj.putIfAbsent(p1, () => []).add(p2);
      adj.putIfAbsent(p2, () => []).add(p1);
    }

    // A simple closed room means every vertex has degree >= 2 (usually exactly 2 for a simple polygon)
    // And the graph is connected.
    // For this simple version, let's just check if every node has degree even (Eulerian circuit condition somewhat)
    // or specifically for a single room, degree 2.

    // Let's check if every point has at least 2 connections.
    for (final point in points) {
      if ((adj[point]?.length ?? 0) < 2) {
        return false;
      }
    }

    // Also check connectivity (BFS)
    if (points.isEmpty) return false;
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

    return visited.length == points.length;
  }
}
