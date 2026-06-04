import 'dart:ui';

import 'package:equatable/equatable.dart';

const double kA4PageWidth = 595.0;
const double kA4PageHeight = 842.0;
const double kLetterPageWidth = 612.0;
const double kLetterPageHeight = 792.0;

enum TextPdfPagePreset { a4, letter }

enum TextPdfAlignment { left, center, right, justify }

enum TextPdfFontFamily { sans, serif, mono, display }

enum TextPdfTextEffect { none, shadow, outline, raised3d }

enum TextPdfImageFit { cover, contain }

enum TextPdfImageFilter { none, grayscale, sepia, warm }

enum TextPdfShapeKind { rectangle, roundedRectangle, circle }

abstract class TextPdfElement extends Equatable {
  const TextPdfElement({
    required this.id,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.rotation = 0,
  });

  final String id;
  final double left;
  final double top;
  final double width;
  final double height;
  final double rotation;
}

class TextPdfTextBlock extends TextPdfElement {
  const TextPdfTextBlock({
    required super.id,
    required super.left,
    required super.top,
    required super.width,
    required super.height,
    required this.text,
    this.fontSize = 18,
    this.textColor = const Color(0xFF1C1917),
    this.fillColor = const Color(0x00000000),
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.alignment = TextPdfAlignment.left,
    this.fontFamily = TextPdfFontFamily.sans,
    this.textEffect = TextPdfTextEffect.none,
    this.padding = 8,
    this.lineSpacing = 2,
    this.letterSpacing = 0,
    this.boxBorderColor = const Color(0x00000000),
    this.boxBorderWidth = 0,
    this.cornerRadius = 12,
    this.textBorderColor = const Color(0xFF111827),
    this.textBorderWidth = 1,
    this.shadowColor = const Color(0x66000000),
    this.shadowOffsetX = 3,
    this.shadowOffsetY = 3,
    super.rotation,
  });

  final String text;
  final double fontSize;
  final Color textColor;
  final Color fillColor;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final TextPdfAlignment alignment;
  final TextPdfFontFamily fontFamily;
  final TextPdfTextEffect textEffect;
  final double padding;
  final double lineSpacing;
  final double letterSpacing;
  final Color boxBorderColor;
  final double boxBorderWidth;
  final double cornerRadius;
  final Color textBorderColor;
  final double textBorderWidth;
  final Color shadowColor;
  final double shadowOffsetX;
  final double shadowOffsetY;

  TextPdfTextBlock copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
    String? text,
    double? fontSize,
    Color? textColor,
    Color? fillColor,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    TextPdfAlignment? alignment,
    TextPdfFontFamily? fontFamily,
    TextPdfTextEffect? textEffect,
    double? padding,
    double? lineSpacing,
    double? letterSpacing,
    Color? boxBorderColor,
    double? boxBorderWidth,
    double? cornerRadius,
    Color? textBorderColor,
    double? textBorderWidth,
    Color? shadowColor,
    double? shadowOffsetX,
    double? shadowOffsetY,
    double? rotation,
  }) {
    return TextPdfTextBlock(
      id: id,
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      fillColor: fillColor ?? this.fillColor,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strikethrough: strikethrough ?? this.strikethrough,
      alignment: alignment ?? this.alignment,
      fontFamily: fontFamily ?? this.fontFamily,
      textEffect: textEffect ?? this.textEffect,
      padding: padding ?? this.padding,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      boxBorderColor: boxBorderColor ?? this.boxBorderColor,
      boxBorderWidth: boxBorderWidth ?? this.boxBorderWidth,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      textBorderColor: textBorderColor ?? this.textBorderColor,
      textBorderWidth: textBorderWidth ?? this.textBorderWidth,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowOffsetX: shadowOffsetX ?? this.shadowOffsetX,
      shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        left,
        top,
        width,
        height,
        rotation,
        text,
        fontSize,
        textColor,
        fillColor,
        bold,
        italic,
        underline,
        strikethrough,
        alignment,
        fontFamily,
        textEffect,
        padding,
        lineSpacing,
        letterSpacing,
        boxBorderColor,
        boxBorderWidth,
        cornerRadius,
        textBorderColor,
        textBorderWidth,
        shadowColor,
        shadowOffsetX,
        shadowOffsetY,
      ];
}

class TextPdfTableCell extends Equatable {
  const TextPdfTableCell({
    required this.text,
    this.backgroundColor = const Color(0x00000000),
  });

  final String text;
  final Color backgroundColor;

  TextPdfTableCell copyWith({
    String? text,
    Color? backgroundColor,
  }) {
    return TextPdfTableCell(
      text: text ?? this.text,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  @override
  List<Object?> get props => <Object?>[text, backgroundColor];
}

class TextPdfTableBlock extends TextPdfElement {
  const TextPdfTableBlock({
    required super.id,
    required super.left,
    required super.top,
    required super.width,
    required super.height,
    required this.rows,
    required this.columns,
    required this.cells,
    this.fontSize = 14,
    this.textColor = const Color(0xFF1C1917),
    this.borderColor = const Color(0x00000000),
    this.headerFillColor = const Color(0x00000000),
    this.cellFillColor = const Color(0x00000000),
    this.borderWidth = 0,
    this.cornerRadius = 16,
    super.rotation,
  });

  final int rows;
  final int columns;
  final List<TextPdfTableCell> cells;
  final double fontSize;
  final Color textColor;
  final Color borderColor;
  final Color headerFillColor;
  final Color cellFillColor;
  final double borderWidth;
  final double cornerRadius;

  TextPdfTableBlock copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
    int? rows,
    int? columns,
    List<TextPdfTableCell>? cells,
    double? fontSize,
    Color? textColor,
    Color? borderColor,
    Color? headerFillColor,
    Color? cellFillColor,
    double? borderWidth,
    double? cornerRadius,
    double? rotation,
  }) {
    return TextPdfTableBlock(
      id: id,
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      cells: cells ?? this.cells,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      borderColor: borderColor ?? this.borderColor,
      headerFillColor: headerFillColor ?? this.headerFillColor,
      cellFillColor: cellFillColor ?? this.cellFillColor,
      borderWidth: borderWidth ?? this.borderWidth,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        left,
        top,
        width,
        height,
        rotation,
        rows,
        columns,
        cells,
        fontSize,
        textColor,
        borderColor,
        headerFillColor,
        cellFillColor,
        borderWidth,
        cornerRadius,
      ];
}

class TextPdfImageBlock extends TextPdfElement {
  const TextPdfImageBlock({
    required super.id,
    required super.left,
    required super.top,
    required super.width,
    required super.height,
    required this.imagePath,
    this.fit = TextPdfImageFit.cover,
    this.filter = TextPdfImageFilter.none,
    this.opacity = 1,
    this.borderRadius = 18,
    this.borderColor = const Color(0x00000000),
    this.borderWidth = 0,
    this.zoom = 1,
    this.focusX = 0.5,
    this.focusY = 0.5,
    super.rotation,
  });

  final String imagePath;
  final TextPdfImageFit fit;
  final TextPdfImageFilter filter;
  final double opacity;
  final double borderRadius;
  final Color borderColor;
  final double borderWidth;
  final double zoom;
  final double focusX;
  final double focusY;

  TextPdfImageBlock copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
    String? imagePath,
    TextPdfImageFit? fit,
    TextPdfImageFilter? filter,
    double? opacity,
    double? borderRadius,
    Color? borderColor,
    double? borderWidth,
    double? zoom,
    double? focusX,
    double? focusY,
    double? rotation,
  }) {
    return TextPdfImageBlock(
      id: id,
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      imagePath: imagePath ?? this.imagePath,
      fit: fit ?? this.fit,
      filter: filter ?? this.filter,
      opacity: opacity ?? this.opacity,
      borderRadius: borderRadius ?? this.borderRadius,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      zoom: zoom ?? this.zoom,
      focusX: focusX ?? this.focusX,
      focusY: focusY ?? this.focusY,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        left,
        top,
        width,
        height,
        rotation,
        imagePath,
        fit,
        filter,
        opacity,
        borderRadius,
        borderColor,
        borderWidth,
        zoom,
        focusX,
        focusY,
      ];
}

class TextPdfShapeBlock extends TextPdfElement {
  const TextPdfShapeBlock({
    required super.id,
    required super.left,
    required super.top,
    required super.width,
    required super.height,
    required this.shapeKind,
    this.fillColor = const Color(0xFFE0F2FE),
    this.borderColor = const Color(0x00000000),
    this.borderWidth = 0,
    this.cornerRadius = 20,
    this.labelText = '',
    this.labelColor = const Color(0xFF1C1917),
    this.labelFontSize = 18,
    this.labelBold = false,
    super.rotation,
  });

  final TextPdfShapeKind shapeKind;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final double cornerRadius;
  final String labelText;
  final Color labelColor;
  final double labelFontSize;
  final bool labelBold;

  TextPdfShapeBlock copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
    TextPdfShapeKind? shapeKind,
    Color? fillColor,
    Color? borderColor,
    double? borderWidth,
    double? cornerRadius,
    String? labelText,
    Color? labelColor,
    double? labelFontSize,
    bool? labelBold,
    double? rotation,
  }) {
    return TextPdfShapeBlock(
      id: id,
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      shapeKind: shapeKind ?? this.shapeKind,
      fillColor: fillColor ?? this.fillColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      labelText: labelText ?? this.labelText,
      labelColor: labelColor ?? this.labelColor,
      labelFontSize: labelFontSize ?? this.labelFontSize,
      labelBold: labelBold ?? this.labelBold,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        left,
        top,
        width,
        height,
        rotation,
        shapeKind,
        fillColor,
        borderColor,
        borderWidth,
        cornerRadius,
        labelText,
        labelColor,
        labelFontSize,
        labelBold,
      ];
}

class TextPdfPage extends Equatable {
  const TextPdfPage({
    required this.id,
    required this.preset,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.elements = const <TextPdfElement>[],
  });

  final String id;
  final TextPdfPagePreset preset;
  final Color backgroundColor;
  final List<TextPdfElement> elements;

  double get pageWidth =>
      preset == TextPdfPagePreset.a4 ? kA4PageWidth : kLetterPageWidth;

  double get pageHeight =>
      preset == TextPdfPagePreset.a4 ? kA4PageHeight : kLetterPageHeight;

  TextPdfPage copyWith({
    TextPdfPagePreset? preset,
    Color? backgroundColor,
    List<TextPdfElement>? elements,
  }) {
    return TextPdfPage(
      id: id,
      preset: preset ?? this.preset,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      elements: elements ?? this.elements,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, preset, backgroundColor, elements];
}

class TextPdfDocumentModel extends Equatable {
  const TextPdfDocumentModel({
    required this.title,
    required this.pages,
  });

  final String title;
  final List<TextPdfPage> pages;

  TextPdfDocumentModel copyWith({
    String? title,
    List<TextPdfPage>? pages,
  }) {
    return TextPdfDocumentModel(
      title: title ?? this.title,
      pages: pages ?? this.pages,
    );
  }

  @override
  List<Object?> get props => <Object?>[title, pages];
}
