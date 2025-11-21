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
    on<CanvasPanStart>(_onCanvasPanStart);
    on<CanvasPanUpdate>(_onCanvasPanUpdate);
    on<CanvasPanEnd>(_onCanvasPanEnd);
    on<CanvasTap>(_onCanvasTap);
    on<ClearRoom>(_onClearRoom);
  }

  void _onToolSelected(ToolSelected event, Emitter<RoomModelingState> emit) {
    emit(state.copyWith(activeTool: event.tool));
  }

  void _onCanvasPanStart(
    CanvasPanStart event,
    Emitter<RoomModelingState> emit,
  ) {
    if (state.activeTool == RoomModelingTool.wall) {
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
        ),
      );
    }
  }

  void _onCanvasPanUpdate(
    CanvasPanUpdate event,
    Emitter<RoomModelingState> emit,
  ) {
    if (state.activeTool == RoomModelingTool.wall && state.dragStart != null) {
      Offset endPoint = event.position;

      // Snap end point to existing wall endpoints (excluding the start point of current wall if it's the same)
      for (final wall in state.walls) {
        if ((wall.start - endPoint).distance < snapDistance) {
          endPoint = wall.start;
          break;
        }
        if ((wall.end - endPoint).distance < snapDistance) {
          endPoint = wall.end;
          break;
        }
      }

      // Orthogonal snapping (straight lines)
      if ((endPoint.dx - state.dragStart!.dx).abs() < snapDistance) {
        endPoint = Offset(state.dragStart!.dx, endPoint.dy);
      } else if ((endPoint.dy - state.dragStart!.dy).abs() < snapDistance) {
        endPoint = Offset(endPoint.dx, state.dragStart!.dy);
      }

      emit(
        state.copyWith(
          dragCurrent: endPoint,
          tempWall: state.tempWall?.copyWith(end: endPoint),
        ),
      );
    }
  }

  void _onCanvasPanEnd(CanvasPanEnd event, Emitter<RoomModelingState> emit) {
    if (state.activeTool == RoomModelingTool.wall && state.tempWall != null) {
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
    if (!state.isRoomClosed) return;
    if (state.activeTool == RoomModelingTool.wall ||
        state.activeTool == RoomModelingTool.select) {
      return;
    }

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
