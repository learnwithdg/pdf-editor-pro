import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../models/pdf_document.dart';

abstract class PdfEvent extends Equatable {
  const PdfEvent();

  @override
  List<Object?> get props => [];
}

class LoadPdfEvent extends PdfEvent {
  const LoadPdfEvent(this.filePath, {this.password});
  final String filePath;
  final String? password;
  @override
  List<Object?> get props => [filePath, password];
}

class ClosePdfEvent extends PdfEvent {
  const ClosePdfEvent();
}

class ChangePageEvent extends PdfEvent {
  const ChangePageEvent(this.pageIndex);
  final int pageIndex;
  @override
  List<Object?> get props => [pageIndex];
}

class ZoomInEvent extends PdfEvent {
  const ZoomInEvent();
}

class ZoomOutEvent extends PdfEvent {
  const ZoomOutEvent();
}

class ResetZoomEvent extends PdfEvent {
  const ResetZoomEvent();
}

class SetZoomLevelEvent extends PdfEvent {
  const SetZoomLevelEvent(this.zoomLevel);
  final double zoomLevel;
  @override
  List<Object?> get props => [zoomLevel];
}

class ToggleEditModeEvent extends PdfEvent {
  const ToggleEditModeEvent();
}

class AddAnnotationEvent extends PdfEvent {
  const AddAnnotationEvent({
    required this.pageIndex,
    required this.x,
    required this.y,
    required this.type,
    required this.color,
    this.width,
    this.height,
    this.text,
    this.imageBytes,
    this.imageName,
    this.imageZoom,
    this.imageFocusX,
    this.imageFocusY,
    this.tableRows,
    this.tableColumns,
    this.tableCells = const [],
    this.tableBorderWidth,
    this.textFontSize,
    this.points = const [],
    this.strokeWidth,
    this.shapeType,
  });

  final int pageIndex;
  final double x;
  final double y;
  final ToolType type;
  final Color color;
  final double? width;
  final double? height;
  final String? text;
  final Uint8List? imageBytes;
  final String? imageName;
  final double? imageZoom;
  final double? imageFocusX;
  final double? imageFocusY;
  final int? tableRows;
  final int? tableColumns;
  final List<String> tableCells;
  final double? tableBorderWidth;
  final double? textFontSize;
  final List<Offset> points;
  final double? strokeWidth;
  final ShapeType? shapeType;

  @override
  List<Object?> get props => [
    pageIndex,
    x,
    y,
    type,
    color,
    width,
    height,
    text,
    imageBytes,
    imageName,
    imageZoom,
    imageFocusX,
    imageFocusY,
    tableRows,
    tableColumns,
    tableCells,
    tableBorderWidth,
    textFontSize,
    points,
    strokeWidth,
    shapeType,
  ];
}

class RemoveAnnotationEvent extends PdfEvent {
  const RemoveAnnotationEvent(this.annotationId);
  final String annotationId;
  @override
  List<Object?> get props => [annotationId];
}

class UpdateAnnotationEvent extends PdfEvent {
  const UpdateAnnotationEvent({
    required this.annotationId,
    this.x,
    this.y,
    this.width,
    this.height,
    this.imageZoom,
    this.imageFocusX,
    this.imageFocusY,
    this.tableBorderWidth,
    this.textFontSize,
  });

  final String annotationId;
  final double? x;
  final double? y;
  final double? width;
  final double? height;
  final double? imageZoom;
  final double? imageFocusX;
  final double? imageFocusY;
  final double? tableBorderWidth;
  final double? textFontSize;

  @override
  List<Object?> get props => [
    annotationId,
    x,
    y,
    width,
    height,
    imageZoom,
    imageFocusX,
    imageFocusY,
    tableBorderWidth,
    textFontSize,
  ];
}

class SavePdfEvent extends PdfEvent {
  const SavePdfEvent({this.outputPath});
  final String? outputPath;
  @override
  List<Object?> get props => [outputPath];
}

class SelectToolEvent extends PdfEvent {
  const SelectToolEvent(this.tool, {this.shapeType});
  final ToolType tool;
  final ShapeType? shapeType;
  @override
  List<Object?> get props => [tool, shapeType];
}

class ChangeColorEvent extends PdfEvent {
  const ChangeColorEvent(this.color);
  final Color color;
  @override
  List<Object?> get props => [color];
}

enum ToolType {
  none,
  highlight,
  underline,
  strikethrough,
  text,
  image,
  table,
  pen,
  shape,
  signature,
}
