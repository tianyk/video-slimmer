import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:remixicon/remixicon.dart';

class VideoThumbnail extends StatelessWidget {
  final String id;
  final int width;
  final int height;

  const VideoThumbnail({super.key, required this.id, this.width = 160, this.height = 120});

  Future<Uint8List?> _getThumbnail() async {
    final assetEntity = await AssetEntity.fromId(id);
    if (assetEntity != null) {
      return await assetEntity.thumbnailDataWithSize(
        ThumbnailSize(width, height),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 60,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<Uint8List?>(
          future: _getThumbnail(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                width: 80,
                height: 60,
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
