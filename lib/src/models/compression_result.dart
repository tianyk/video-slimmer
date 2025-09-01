class CompressionResult {
  final String inputPath;
  final String outputPath;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final double compressionRatio;
  final String status;
  final String? errorMessage;
  final DateTime createdAt;

  CompressionResult({
    required this.inputPath,
    required this.outputPath,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.compressionRatio,
    required this.status,
    this.errorMessage,
    required this.createdAt,
  });

  int get spaceSavedBytes => originalSizeBytes - compressedSizeBytes;
  
  double get spaceSavedPercentage => 
      originalSizeBytes > 0 ? (spaceSavedBytes / originalSizeBytes) * 100 : 0;

  String get formattedOriginalSize {
    return _formatBytes(originalSizeBytes);
  }

  String get formattedCompressedSize {
    return _formatBytes(compressedSizeBytes);
  }

  String get formattedSpaceSaved {
    return _formatBytes(spaceSavedBytes);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  bool get isSuccess => status == 'completed';
  bool get isError => status == 'error';
  bool get isInProgress => status == 'in_progress';
}