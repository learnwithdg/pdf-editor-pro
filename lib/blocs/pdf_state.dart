import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../models/pdf_document.dart';
import 'pdf_event.dart';

abstract class PdfState extends Equatable {
  const PdfState();

  @override
  List<Object?> get props => [];
}

class PdfInitial extends PdfState {
  const PdfInitial();
}

class PdfLoading extends PdfState {
  const PdfLoading();
}

class PdfLoaded extends PdfState {
  const PdfLoaded({
    required this.document,
    this.currentPage = 0,
    this.zoomLevel = 1.0,
    this.isEditMode = false,
    this.selectedTool = ToolType.none,
    this.selectedShape = ShapeType.rectangle,
    this.selectedColor = const Color(0xFF0E6B5C),
    this.isSaving = false,
    this.error,
  });

  final PdfFileDocument document;
  final int currentPage;
  final double zoomLevel;
  final bool isEditMode;
  final ToolType selectedTool;
  final ShapeType selectedShape;
  final Color selectedColor;
  final bool isSaving;
  final String? error;

  PdfLoaded copyWith({
    PdfFileDocument? document,
    int? currentPage,
    double? zoomLevel,
    bool? isEditMode,
    ToolType? selectedTool,
    ShapeType? selectedShape,
    Color? selectedColor,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return PdfLoaded(
      document: document ?? this.document,
      currentPage: currentPage ?? this.currentPage,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      isEditMode: isEditMode ?? this.isEditMode,
      selectedTool: selectedTool ?? this.selectedTool,
      selectedShape: selectedShape ?? this.selectedShape,
      selectedColor: selectedColor ?? this.selectedColor,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
        document,
        currentPage,
        zoomLevel,
        isEditMode,
        selectedTool,
        selectedShape,
        selectedColor,
        isSaving,
        error,
      ];
}

class PdfError extends PdfState {
  const PdfError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class PdfPasswordRequired extends PdfState {
  const PdfPasswordRequired({
    required this.filePath,
    required this.fileName,
    this.message,
  });

  final String filePath;
  final String fileName;
  final String? message;

  @override
  List<Object?> get props => [filePath, fileName, message];
}
