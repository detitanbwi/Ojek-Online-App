import 'package:flutter/material.dart';

class CustomPullToRefresh extends StatefulWidget {
  final Widget child;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;
  final Color subTitleColor;

  const CustomPullToRefresh({
    super.key,
    required this.child,
    required this.isRefreshing,
    required this.onRefresh,
    required this.subTitleColor,
  });

  @override
  State<CustomPullToRefresh> createState() => _CustomPullToRefreshState();
}

class _CustomPullToRefreshState extends State<CustomPullToRefresh> {
  double _pullDistance = 0.0;
  bool _canTrigger = false;

  @override
  Widget build(BuildContext context) {
    final double displayHeight = widget.isRefreshing ? 60.0 : _pullDistance.clamp(0.0, 80.0);

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (widget.isRefreshing) return false;

        if (notification is ScrollUpdateNotification) {
          final double metrics = notification.metrics.pixels;
          if (metrics < 0) {
            setState(() {
              _pullDistance = -metrics;
              if (_pullDistance > 80.0) {
                _canTrigger = true;
              }
            });
          } else {
            if (_pullDistance != 0.0) {
              setState(() {
                _pullDistance = 0.0;
              });
            }
          }
        } else if (notification is ScrollEndNotification) {
          if (_canTrigger) {
            _canTrigger = false;
            widget.onRefresh();
          }
          setState(() {
            _pullDistance = 0.0;
          });
        }
        return false;
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: widget.isRefreshing ? const Duration(milliseconds: 200) : Duration.zero,
            curve: Curves.fastOutSlowIn,
            height: displayHeight,
            width: double.infinity,
            color: Colors.transparent,
            child: displayHeight > 15
                ? Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.isRefreshing) ...[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Memperbarui data...',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.subTitleColor.withOpacity(0.7),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else ...[
                          Icon(
                            _pullDistance >= 80.0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _pullDistance >= 80.0 ? 'Lepas untuk memperbarui' : 'Tarik untuk memperbarui',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.subTitleColor.withOpacity(0.7),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ]
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
