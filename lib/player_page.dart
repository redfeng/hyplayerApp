import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:hyplayer/config.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerPage extends StatefulWidget {
  final String? videoUrl;

  const PlayerPage({super.key, this.videoUrl});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl != null) {
      _currentUrl = widget.videoUrl;
      _initializePlayer(widget.videoUrl!);
    } else {
      _loadLastVideo();
    }
  }

  Future<void> _loadLastVideo() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUrl = prefs.getString('last_played_url');
    if (lastUrl != null) {
      setState(() {
        _currentUrl = lastUrl;
      });
      _initializePlayer(lastUrl);
    }
  }

  Future<void> _saveLastVideo(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_played_url', url);
  }

  @override
  void didUpdateWidget(PlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoUrl != null && widget.videoUrl != _currentUrl) {
      _currentUrl = widget.videoUrl;
      _disposeControllers();
      _initializePlayer(widget.videoUrl!);
    }
  }

  void _initializePlayer(String originalUrl) {
    final proxyUrl = '$proxyServerUrl/proxy?url=${Uri.encodeComponent(originalUrl)}';
    print('Initializing player for: $originalUrl via proxy: $proxyUrl');

    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(proxyUrl));
    _videoPlayerController!.initialize().then((_) {
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: true,
      );
      _saveLastVideo(originalUrl);
      if (mounted) {
        setState(() {});
        print('Video player initialized');
      }
    }).catchError((error) {
      print('Error initializing video player: $error');
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController = null;
    _videoPlayerController = null;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频播放')),
      body: Center(
        child: _buildPlayerWidget(),
      ),
    );
  }

  Widget _buildPlayerWidget() {
    if (_currentUrl == null) {
      return const Text('请从列表中选择一个视频进行播放');
    }

    // Case 1: Video has an error
    if (_videoPlayerController != null && _videoPlayerController!.value.hasError) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 20),
            const Text(
              '视频加载失败',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _videoPlayerController!.value.errorDescription ?? '未知错误，请稍后重试。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('点击重试'),
              onPressed: () {
                print('Retrying to play $_currentUrl');
                // Reset controllers and re-initialize
                _disposeControllers();
                setState(() {
                  _initializePlayer(_currentUrl!);
                });
              },
            ),
          ],
        ),
      );
    }

    // Case 2: Video is initialized and ready to play
    if (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized) {
      return Chewie(
        controller: _chewieController!,
      );
    }

    // Case 3: Video is loading
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 20),
        Text('正在加载视频...'),
      ],
    );
  }
}
