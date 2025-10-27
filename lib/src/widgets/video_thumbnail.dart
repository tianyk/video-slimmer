import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:remixicon/remixicon.dart';

class VideoThumbnail extends StatefulWidget {
  final String id;
  final int width;
  final int height;

  const VideoThumbnail(
      {super.key, required this.id, this.width = 80, this.height = 60});

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  late final Future<Uint8List?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    // 在 initState 中初始化 Future，确保只创建一次
    _thumbnailFuture = _loadThumbnail();
  }

  // 获取缩略图，使用2倍缩略图，提高清晰度
  Future<Uint8List?> _loadThumbnail() async {
    const int scale = 2;
    final assetEntity = await AssetEntity.fromId(widget.id);
    return await assetEntity?.thumbnailDataWithSize(
      ThumbnailSize(widget.width * scale, widget.height * scale),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width.toDouble(),
      height: widget.height.toDouble(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<Uint8List?>(
          future: _thumbnailFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                width: widget.width.toDouble(),
                height: widget.height.toDouble(),
              );
            }
            return _buildPlaceholder();
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Icon(
        Remix.video_line,
        color: Colors.grey[600],
      ),
    );
  }
}
