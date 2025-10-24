import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:remixicon/remixicon.dart';

class VideoThumbnail extends StatelessWidget {
  final String id;
  final int width;
  final int height;

  const VideoThumbnail({super.key, required this.id, this.width = 80, this.height = 60});

  // 获取缩略图，使用2倍缩略图，提高清晰度
  Future<Uint8List?> _getThumbnail({required String id, int scale = 2}) async {
    final assetEntity = await AssetEntity.fromId(id);
    return await assetEntity?.thumbnailDataWithSize(
      ThumbnailSize(width * scale, height * scale),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width.toDouble(),
      height: height.toDouble(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<Uint8List?>(
          future: _getThumbnail(id: id),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                width: width.toDouble(),
                height: height.toDouble(),
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
