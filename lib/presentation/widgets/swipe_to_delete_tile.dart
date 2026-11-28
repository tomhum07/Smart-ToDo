import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Widget quẹt trái để mở nút "Xóa" màu đỏ giống giỏ hàng Shopee.
/// - Chỉ hiển thị nền đỏ "Xóa" khi người dùng thực sự kéo sang trái (tránh xuyên thấu qua thẻ đã hoàn thành).
/// - Quẹt phải hoặc chạm vào nội dung đang mở sẽ đóng lại.
/// - Chạm nút "Xóa" sẽ đóng và gọi callback [onDelete].
class SwipeToDeleteTile extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final double actionWidth;
  final BorderRadius borderRadius;
  final String deleteLabel;
  final bool showIcon;

  const SwipeToDeleteTile({
    super.key,
    required this.child,
    required this.onDelete,
    this.actionWidth = 84,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.deleteLabel = 'Xóa',
    this.showIcon = true,
  });

  @override
  State<SwipeToDeleteTile> createState() => _SwipeToDeleteTileState();
}

class _SwipeToDeleteTileState extends State<SwipeToDeleteTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 0.0, // 0.0 = đóng, 1.0 = mở hết actionWidth
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final nextValue = (_controller.value - delta / widget.actionWidth)
        .clamp(0.0, 1.0);
    _controller.value = nextValue;
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldOpen =
        velocity < -200 || (velocity <= 200 && _controller.value >= 0.35);
    if (shouldOpen) {
      if (_controller.value < 0.99) {
        HapticFeedback.selectionClick();
      }
      _controller.animateTo(1.0, curve: Curves.easeOutCubic);
    } else {
      _controller.animateTo(0.0, curve: Curves.easeOutCubic);
    }
  }

  void _close() {
    if (_controller.value > 0) {
      _controller.animateTo(0.0, curve: Curves.easeOutCubic);
    }
  }

  void _handleDeleteTap() {
    _close();
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final opaqueBg = Theme.of(context).scaffoldBackgroundColor;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final value = _controller.value;
            final isRevealing = value > 0.001;
            final isOpen = value > 0.05;
            final dx = -value * widget.actionWidth;

            return Stack(
              children: [
                // Chỉ dựng nút đỏ "Xóa" khi người dùng đang quẹt sang trái
                if (isRevealing)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _handleDeleteTap,
                        child: Container(
                          width: widget.actionWidth + 12,
                          color: const Color(0xFFEE4D2D),
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: widget.actionWidth,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (widget.showIcon) ...[
                                  const Icon(
                                    LucideIcons.trash2,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(height: 3),
                                ],
                                Text(
                                  widget.deleteLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Nội dung thẻ phía trước trượt sang trái (có nền đục chống xuyên thấu khi kéo thẻ mờ)
                Transform.translate(
                  offset: Offset(dx, 0),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: _handleDragUpdate,
                    onHorizontalDragEnd: _handleDragEnd,
                    onTap: isOpen ? _close : null,
                    child: AbsorbPointer(
                      absorbing: isOpen,
                      child: isRevealing
                          ? ColoredBox(color: opaqueBg, child: child)
                          : child,
                    ),
                  ),
                ),
              ],
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
