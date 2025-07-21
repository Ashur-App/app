import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';

class ReelVideoPlayer extends StatefulWidget {
  final String? videoUrl;
  final VideoPlayerController? controller;
  final bool isActive;
  final VoidCallback? onRetry;

  const ReelVideoPlayer({
    super.key,
    required this.videoUrl,
    this.controller,
    required this.isActive,
    this.onRetry,
  });

  @override
  State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = false;
  Timer? _controlsTimer;
  bool _hasError = false;
  int _retryCount = 0;
  static const int _maxRetries = 2;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.controller != oldWidget.controller) {
      _initializeController();
    }
    
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _playVideo();
      } else {
        _pauseVideo();
      }
    }
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeController() async {
    if (widget.controller != null) {
      _controller = widget.controller;
      _isInitialized = true;
      _hasError = false;
      if (widget.isActive) {
        _playVideo();
      }
      setState(() {});
      return;
    }

    if (widget.videoUrl == null || widget.videoUrl!.isEmpty) {
      _hasError = true;
      setState(() {});
      return;
    }

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        if (widget.isActive) {
          _playVideo();
        }
      }
    } catch (e) {
      _hasError = true;
      _retryCount++;
      if (_retryCount <= _maxRetries) {
        await Future.delayed(Duration(milliseconds: 500));
        await _initializeController();
      } else {
        setState(() {});
      }
    }
  }

  void _playVideo() {
    if (_controller != null && _isInitialized) {
      _controller!.play();
      _controller!.setLooping(true);
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _pauseVideo() {
    if (_controller != null && _isInitialized) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pauseVideo();
    } else {
      _playVideo();
    }
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });
    
    _controlsTimer?.cancel();
    _controlsTimer = Timer(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 12),
            Text('فشل تحميل الفيديو', style: TextStyle(color: Colors.white)),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: widget.onRetry,
              child: Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _togglePlayPause();
        _showControlsTemporarily();
      },
      child: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
          if (_showControls)
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(45),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.7),
                    width: 2.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(45),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Center(
                      child: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 54,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.7),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 4,
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white.withOpacity(0.5),
                    backgroundColor: Colors.white.withOpacity(0.2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 