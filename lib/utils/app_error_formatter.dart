import 'dart:async';
import 'dart:io';

class AppErrorFormatter {
  const AppErrorFormatter._();

  static String format(
    Object error, {
    String? fallback,
  }) {
    final message = _normalize(error);
    if (message.isNotEmpty) {
      return message;
    }
    return fallback ?? 'Something went wrong. Please try again.';
  }

  static String _normalize(Object error) {
    if (error is TimeoutException) {
      return 'The operation took too long. Please try again.';
    }
    if (error is SocketException) {
      return 'No internet connection. Check your network and try again.';
    }
    if (error is HandshakeException) {
      return 'A secure network connection could not be created. Please try again.';
    }
    if (error is HttpException) {
      return error.message.trim().isEmpty
          ? 'A network request failed. Please try again.'
          : error.message.trim();
    }
    if (error is FileSystemException) {
      return _fileSystemMessage(error);
    }
    if (error is ArgumentError) {
      return _clean(error.message?.toString() ?? error.toString());
    }
    if (error is FormatException) {
      return error.message.trim().isEmpty
          ? 'The file format could not be processed.'
          : error.message.trim();
    }

    final raw = _clean(error.toString());
    final lower = raw.toLowerCase();

    if (lower.isEmpty || lower == 'null') {
      return '';
    }
    if (lower.contains('pathnotfoundexception') ||
        lower.contains('cannot find the path') ||
        lower.contains('cannot find the file') ||
        lower.contains('no such file or directory')) {
      return 'The selected file could not be found. It may have been moved or deleted.';
    }
    if (lower.contains('permission denied') ||
        lower.contains('access is denied')) {
      return 'Permission was denied while accessing this file.';
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('network is unreachable')) {
      return 'No internet connection. Check your network and try again.';
    }
    if (lower.contains('timed out')) {
      return 'The operation took too long. Please try again.';
    }

    return raw;
  }

  static String _fileSystemMessage(FileSystemException error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('cannot find the path') ||
        lower.contains('cannot find the file') ||
        lower.contains('no such file or directory')) {
      return 'The selected file could not be found. It may have been moved or deleted.';
    }
    if (lower.contains('permission denied') ||
        lower.contains('access is denied')) {
      return 'Permission was denied while accessing this file.';
    }
    return 'This file could not be accessed. Check that it still exists and try again.';
  }

  static String _clean(String raw) {
    var value = raw.trim();
    const prefixes = <String>[
      'Error: ',
      'Exception: ',
      'CloudStorageException: ',
      'FileSystemException: ',
      'HttpException: ',
      'FormatException: ',
      'Invalid argument(s): ',
    ];

    var changed = true;
    while (changed) {
      changed = false;
      for (final prefix in prefixes) {
        if (value.startsWith(prefix)) {
          value = value.substring(prefix.length).trim();
          changed = true;
        }
      }
    }

    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
