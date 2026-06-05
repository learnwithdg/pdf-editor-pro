import 'dart:typed_data';
import 'dart:ui' show Color, Offset;
import 'package:equatable/equatable.dart';

enum AnnotationType {
  highlight,
  underline,
  strikethrough,
  text,
  ink,
  shape,
  signature,
  image,
  table,
}

enum ShapeType { line, arrow, rectangle, circle }

enum PdfTextBoxStyle { plain, box, line, rectangle, roundedRectangle, circle }

enum PdfTextAlignment { left, center, right }

class PdfFileDocument extends Equatable {
  const PdfFileDocument({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.pageCount,
    required this.lastModified,
    required this.fileSize,
    this.annotations = const [],
    this.lastSavedPath,
  });

  final String id;
  final String filePath;
  final String fileName;
  final int pageCount;
  final DateTime lastModified;
  final int fileSize;
  final List<PdfAnnotation> annotations;
  final String? lastSavedPath;

  PdfFileDocument copyWith({
    String? id,
    String? filePath,
    String? fileName,
    int? pageCount,
    DateTime? lastModified,
    int? fileSize,
    List<PdfAnnotation>? annotations,
    String? lastSavedPath,
    bool clearLastSavedPath = false,
  }) {
    return PdfFileDocument(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      pageCount: pageCount ?? this.pageCount,
      lastModified: lastModified ?? this.lastModified,
      fileSize: fileSize ?? this.fileSize,
      annotations: annotations ?? this.annotations,
      lastSavedPath: clearLastSavedPath
          ? null
          : lastSavedPath ?? this.lastSavedPath,
    );
  }

  @override
  List<Object?> get props => [
    id,
    filePath,
    fileName,
    pageCount,
    lastModified,
    fileSize,
    annotations,
    lastSavedPath,
  ];
}

class PdfAnnotation extends Equatable {
  const PdfAnnotation({
    required this.id,
    required this.type,
    required this.pageIndex,
    required this.x,
    required this.y,
    this.width = 0.24,
    this.height = 0.045,
    this.color = const Color(0xFFFFEB3B),
    this.text,
    this.imageBytes,
    this.imageName,
    this.imageZoom = 1.0,
    this.imageFocusX = 0.5,
    this.imageFocusY = 0.5,
    this.tableRows,
    this.tableColumns,
    this.tableCells = const [],
    this.tableBorderWidth = 0.0,
    this.textFontSize = 18.0,
    this.textBoxStyle = PdfTextBoxStyle.plain,
    this.textAlignment = PdfTextAlignment.left,
    this.textFillColor = const Color(0x00000000),
    this.textBorderColor = const Color(0xFF111827),
    this.textBorderWidth = 0.0,
    this.textBold = false,
    this.textItalic = false,
    this.textUnderline = false,
    this.strokeWidth = 2.0,
    this.points = const [],
    this.shapeType,
  });

  final String id;
  final AnnotationType type;
  final int pageIndex;
  final double x;
  final double y;
  final double width;
  final double height;
  final Color color;
  final String? text;
  final Uint8List? imageBytes;
  final String? imageName;
  final double imageZoom;
  final double imageFocusX;
  final double imageFocusY;
  final int? tableRows;
  final int? tableColumns;
  final List<String> tableCells;
  final double tableBorderWidth;
  final double textFontSize;
  final PdfTextBoxStyle textBoxStyle;
  final PdfTextAlignment textAlignment;
  final Color textFillColor;
  final Color textBorderColor;
  final double textBorderWidth;
  final bool textBold;
  final bool textItalic;
  final bool textUnderline;
  final double strokeWidth;
  final List<Offset> points;
  final ShapeType? shapeType;

  PdfAnnotation copyWith({
    String? id,
    AnnotationType? type,
    int? pageIndex,
    double? x,
    double? y,
    double? width,
    double? height,
    Color? color,
    String? text,
    Uint8List? imageBytes,
    String? imageName,
    double? imageZoom,
    double? imageFocusX,
    double? imageFocusY,
    int? tableRows,
    int? tableColumns,
    List<String>? tableCells,
    double? tableBorderWidth,
    double? textFontSize,
    PdfTextBoxStyle? textBoxStyle,
    PdfTextAlignment? textAlignment,
    Color? textFillColor,
    Color? textBorderColor,
    double? textBorderWidth,
    bool? textBold,
    bool? textItalic,
    bool? textUnderline,
    double? strokeWidth,
    List<Offset>? points,
    ShapeType? shapeType,
  }) {
    return PdfAnnotation(
      id: id ?? this.id,
      type: type ?? this.type,
      pageIndex: pageIndex ?? this.pageIndex,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      color: color ?? this.color,
      text: text ?? this.text,
      imageBytes: imageBytes ?? this.imageBytes,
      imageName: imageName ?? this.imageName,
      imageZoom: imageZoom ?? this.imageZoom,
      imageFocusX: imageFocusX ?? this.imageFocusX,
      imageFocusY: imageFocusY ?? this.imageFocusY,
      tableRows: tableRows ?? this.tableRows,
      tableColumns: tableColumns ?? this.tableColumns,
      tableCells: tableCells ?? this.tableCells,
      tableBorderWidth: tableBorderWidth ?? this.tableBorderWidth,
      textFontSize: textFontSize ?? this.textFontSize,
      textBoxStyle: textBoxStyle ?? this.textBoxStyle,
      textAlignment: textAlignment ?? this.textAlignment,
      textFillColor: textFillColor ?? this.textFillColor,
      textBorderColor: textBorderColor ?? this.textBorderColor,
      textBorderWidth: textBorderWidth ?? this.textBorderWidth,
      textBold: textBold ?? this.textBold,
      textItalic: textItalic ?? this.textItalic,
      textUnderline: textUnderline ?? this.textUnderline,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      points: points ?? this.points,
      shapeType: shapeType ?? this.shapeType,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    pageIndex,
    x,
    y,
    width,
    height,
    color,
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
    textBoxStyle,
    textAlignment,
    textFillColor,
    textBorderColor,
    textBorderWidth,
    textBold,
    textItalic,
    textUnderline,
    strokeWidth,
    points,
    shapeType,
  ];
}
