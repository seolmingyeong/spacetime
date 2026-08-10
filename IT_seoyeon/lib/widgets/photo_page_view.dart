import 'package:flutter/material.dart';

/// 여러 장의 네트워크 사진을 넘겨보는 PageView.
/// 각 사진의 실제 가로세로 비율에 맞춰, 현재 보이는 페이지의 비율대로
/// 전체 높이가 자동으로 바뀝니다. (고정 비율로 자르지 않음)
class PhotoPageView extends StatefulWidget {
  final List<String> urls;
  final double fallbackAspectRatio;
  final BorderRadius? borderRadius;

  const PhotoPageView({
    super.key,
    required this.urls,
    this.fallbackAspectRatio = 4 / 3,
    this.borderRadius,
  });

  @override
  State<PhotoPageView> createState() => _PhotoPageViewState();
}

class _PhotoPageViewState extends State<PhotoPageView> {
  late final PageController _controller = PageController();
  late List<double?> _ratios; // 각 사진의 width/height, 아직 모르면 null
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _ratios = List<double?>.filled(widget.urls.length, null);
    for (var i = 0; i < widget.urls.length; i++) {
      _resolveRatio(i, widget.urls[i]);
    }
  }

  void _resolveRatio(int index, String url) {
    final provider = NetworkImage(url);
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (h > 0) {
        setState(() => _ratios[index] = w / h);
      }
      stream.removeListener(listener);
    }, onError: (_, __) {
      stream.removeListener(listener);
    });
    stream.addListener(listener);
  }

  double get _currentRatio =>
      _ratios[_currentPage] ?? widget.fallbackAspectRatio;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: AspectRatio(
        aspectRatio: _currentRatio,
        child: PageView(
          controller: _controller,
          onPageChanged: (index) => setState(() => _currentPage = index),
          children: widget.urls.map((url) {
            return Image.network(
              url,
              fit: BoxFit.contain, // 비율 유지, 잘리지 않음
              errorBuilder: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image)),
            );
          }).toList(),
        ),
      ),
    );

    return widget.borderRadius != null
        ? ClipRRect(borderRadius: widget.borderRadius!, child: content)
        : content;
  }
}