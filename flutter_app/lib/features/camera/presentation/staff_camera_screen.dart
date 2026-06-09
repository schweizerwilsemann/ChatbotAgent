import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/features/camera/data/camera_api.dart';
import 'package:sports_venue_chatbot/features/camera/data/camera_models.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final staffCamerasProvider =
    AsyncNotifierProvider<StaffCamerasNotifier, List<CameraInfo>>(
  StaffCamerasNotifier.new,
);

class StaffCamerasNotifier extends AsyncNotifier<List<CameraInfo>> {
  @override
  Future<List<CameraInfo>> build() async {
    return ref.watch(cameraApiProvider).listStaffCameras();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(cameraApiProvider).listStaffCameras(),
    );
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class StaffCameraScreen extends ConsumerStatefulWidget {
  const StaffCameraScreen({super.key});

  @override
  ConsumerState<StaffCameraScreen> createState() => _StaffCameraScreenState();
}

class _StaffCameraScreenState extends ConsumerState<StaffCameraScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(staffCamerasProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final camerasAsync = ref.watch(staffCamerasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera sân'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(staffCamerasProvider.notifier).refresh(),
          ),
        ],
      ),
      body: camerasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text('Lỗi: $error', textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () =>
                    ref.read(staffCamerasProvider.notifier).refresh(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (cameras) {
          if (cameras.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off_outlined,
                      size: 64, color: AppColors.textHint),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Chưa có camera nào',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Liên hệ quản lý để cấu hình camera',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(staffCamerasProvider.notifier).refresh(),
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 16 / 13,
              ),
              itemCount: cameras.length,
              itemBuilder: (context, index) => _CameraThumbnailCard(
                camera: cameras[index],
                onTap: () => _openCameraViewer(context, cameras[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openCameraViewer(BuildContext context, CameraInfo camera) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CameraViewerScreen(camera: camera),
      ),
    );
  }
}

// ─── Camera Thumbnail Card ───────────────────────────────────────────────────

class _CameraThumbnailCard extends StatelessWidget {
  final CameraInfo camera;
  final VoidCallback onTap;

  const _CameraThumbnailCard({required this.camera, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A1A2E),
                Color(0xFF16213E),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Camera preview placeholder
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.videocam,
                      size: 48,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        camera.brandDisplayName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Live badge
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: camera.isActive
                        ? Colors.red.withOpacity(0.85)
                        : Colors.grey.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle,
                          size: 6,
                          color:
                              camera.isActive ? Colors.white : Colors.white54),
                      const SizedBox(width: 3),
                      Text(
                        camera.isActive ? 'LIVE' : 'OFF',
                        style: TextStyle(
                          color:
                              camera.isActive ? Colors.white : Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Camera name + resource label at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        camera.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (camera.resourceLabel != null)
                        Text(
                          camera.resourceLabel!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Camera Viewer Screen ────────────────────────────────────────────────────

class CameraViewerScreen extends StatefulWidget {
  final CameraInfo camera;

  const CameraViewerScreen({super.key, required this.camera});

  @override
  State<CameraViewerScreen> createState() => _CameraViewerScreenState();
}

class _CameraViewerScreenState extends State<CameraViewerScreen> {
  late final Player _player;
  late final VideoController _controller;
  bool _isConnecting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _startPlayback();
  }

  Future<void> _startPlayback() async {
    setState(() {
      _isConnecting = true;
      _error = null;
    });

    try {
      await _player.open(
        Media(
          widget.camera.rtspUrl,
          extras: {
            'rtsp_transport': 'tcp',
          },
        ),
      );

      // Wait a moment to check if connection succeeds
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        setState(() => _isConnecting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _error = 'Không thể kết nối camera: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.camera.name),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startPlayback,
            tooltip: 'Kết nối lại',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Video(
                  controller: controller,
                  controls: NoVideoControls,
                ),
                if (_isConnecting)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Đang kết nối camera...',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_error != null)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _startPlayback,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Live indicator
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Camera info bar
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: Colors.white.withOpacity(0.6)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${widget.camera.resourceLabel ?? widget.camera.name} • '
                    '${widget.camera.ipAddress}:${widget.camera.port}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  VideoController get controller => _controller;
}
