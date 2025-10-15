import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:remixicon/remixicon.dart';

class VideoThumbnail extends StatelessWidget {
  final AssetEntity? assetEntity;

  const VideoThumbnail({super.key, required this.assetEntity});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 60,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: assetEntity != null
            ? FutureBuilder<Uint8List?>(
                future: assetEntity!.thumbnailDataWithSize(
                  const ThumbnailSize(160, 120),
                ),
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
              )
            : _buildPlaceholder(),
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
