import 'dart:ui';
import 'package:equatable/equatable.dart';

class Wall extends Equatable {
  final String id;
  final Offset start;
  final Offset end;

  const Wall({required this.id, required this.start, required this.end});

  Wall copyWith({String? id, Offset? start, Offset? end}) {
    return Wall(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  List<Object?> get props => [id, start, end];
}
