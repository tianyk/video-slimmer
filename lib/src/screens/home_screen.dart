import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../constants/app_theme.dart';
import '../models/video_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _sortBy = AppConstants.defaultSortBy;
  bool _sortDescending = AppConstants.defaultSortDescending;
  String? _selectedFilter;
  final List<VideoModel> _videos = [];

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    // 模拟加载视频数据，实际项目中会从相册加载
    setState(() {
      _videos.clear();
      _videos.addAll([
        VideoModel(
          id: '1',
          title: 'travel_shanghai.mp4',
          path: '/path/to/video1.mp4',
          duration: 180,
          width: 1080,
          height: 1920,
          sizeBytes: 1572864000, // ~1.5GB
          frameRate: 30,
          creationDate: DateTime.now().subtract(const Duration(days: 1)),
          thumbnailPath: '',
          isSelected: false,
        ),
        VideoModel(
          id: '2',
          title: 'family_party.mp4',
          path: '/path/to/video2.mp4',
          duration: 600,
          width: 1920,
          height: 1080,
          sizeBytes: 5368709120, // ~5GB
          frameRate: 60,
          creationDate: DateTime.now().subtract(const Duration(days: 2)),
          thumbnailPath: '',
          isSelected: false,
        ),
      ]);
    });
  }

  int get selectedVideosCount =>
      _videos.where((video) => video.isSelected).length;

  double get totalSelectedSize {
    return _videos
        .where((video) => video.isSelected)
        .fold(0, (sum, video) => sum + video.sizeBytes);
  }

  void _toggleVideoSelection(int index, bool selected) {
    setState(() {
      _videos[index] = _videos[index].copyWith(isSelected: selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortDialog,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadVideos,
        child: _videos.isEmpty
            ? _buildEmptyState()
            : _buildVideoList(),
      ),
      floatingActionButton: selectedVideosCount > 0
          ? SizedBox(
              width: double.infinity,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: FloatingActionButton.extended(
                  onPressed: _onNextPressed,
                  label: Text(
                    '下一步 ($selectedVideosCount)',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Remix.video_line, size: 64, color: AppTheme.prosperityLightGray),
          const SizedBox(height: 16),
          const Text(
            '暂无视频',
            style: AppTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadVideos,
            child: const Text('刷新'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList() {
    return ListView.builder(
      itemCount: _videos.length,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemBuilder: (context, index) {
        final video = _videos[index];
        return _VideoItem(
          video: video,
          onSelectionChanged: (selected) => _toggleVideoSelection(index, selected),
        );
      },
    );
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SizedBox(
          height: 200,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('排序方式', style: TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: const Text('文件大小'),
                trailing: Icon(
                  _sortBy == 'size'
                      ? (_sortDescending ? Icons.arrow_downward : Icons.arrow_upward)
                      : null,
                ),
                onTap: () {
                  setState(() {
                    if (_sortBy == 'size') {
                      _sortDescending = !_sortDescending;
                    } else {
                      _sortBy = 'size';
                      _sortDescending = true;
                    }
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('拍摄时间'),
                trailing: Icon(
                  _sortBy == 'date'
                      ? (_sortDescending ? Icons.arrow_downward : Icons.arrow_upward)
                      : null,
                ),
                onTap: () {
                  setState(() {
                    if (_sortBy == 'date') {
                      _sortDescending = !_sortDescending;
                    } else {
                      _sortBy = 'date';
                      _sortDescending = true;
                    }
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('按分辨率和帧率筛选', style: TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: const Text('全部视频'),
                trailing: _selectedFilter == null ? const Icon(Icons.check) : null,
                onTap: () {
                  setState(() {
                    _selectedFilter = null;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('4K/60fps'),
                trailing: _selectedFilter == '4K60' ? const Icon(Icons.check) : null,
                onTap: () {
                  setState(() {
                    _selectedFilter = '4K60';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('4K/30fps'),
                trailing: _selectedFilter == '4K30' ? const Icon(Icons.check) : null,
                onTap: () {
                  setState(() {
                    _selectedFilter = '4K30';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('1080p/30fps'),
                trailing: _selectedFilter == '1080p30' ? const Icon(Icons.check) : null,
                onTap: () {
                  setState(() {
                    _selectedFilter = '1080p30';
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _onNextPressed() {
    // 跳转到压缩设置页面
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已选择 $selectedVideosCount 个视频 (${getFormattedSize(totalSelectedSize)})',
        ),
      ),
    );
  }

  String getFormattedSize(double bytes) {
    if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}

class _VideoItem extends StatelessWidget {
  final VideoModel video;
  final ValueChanged<bool> onSelectionChanged;

  const _VideoItem({
    required this.video,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: video.isSelected ? 8 : 2, 
      color: video.isSelected ? AppTheme.prosperityDarkGold.withOpacity(0.2) : AppTheme.prosperityGray,
      child: InkWell(
        onTap: () => onSelectionChanged(!video.isSelected),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 缩略图占位符
              Container(
                width: 80,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Remix.video_line, color: Colors.grey[600]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${video.resolutionAndFrameRate} | ${video.formattedDuration} | ${video.fileSize}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: video.isSelected,
                onChanged: (value) => onSelectionChanged(value ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}