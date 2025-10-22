import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:remixicon/remixicon.dart';

class VideoThumbnail extends StatelessWidget {
  final String id;

  const VideoThumbnail({super.key, required this.id});

  Future<Uint8List?> _getThumbnail(String id) async {
    final assetEntity = await AssetEntity.fromId(id);
    if (assetEntity != null) {
      return await assetEntity.thumbnailDataWithSize(
        const ThumbnailSize(160, 120),
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
          future: _getThumbnail(id),
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
