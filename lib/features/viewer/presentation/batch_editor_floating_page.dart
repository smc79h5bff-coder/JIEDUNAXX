import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 批处理编辑器（文本编辑器 / 行编辑器 / 行编辑器3）共用的悬浮翻页按钮。
///
/// 渲染逻辑照搬 diff_viewer_screen 里的 _buildFloatingButton：
/// 一个空心方框，按屏幕百分比定位，点击触发回调。

Widget buildBatchPageFloatingButton({
  required BuildContext context,
  required double size,
  required double x,
  required double y,
  required double opacity,
  required double borderWidth,
  required Color color,
  required VoidCallback onTap,
}) {
  final mq = MediaQuery.of(context);
  final screenW = mq.size.width;
  final screenH = mq.size.height;

  final left = screenW * (x / 100) - size / 2;
  final top = screenH * (y / 100) - size / 2;

  return Positioned(
    left: left,
    top: top,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(
            color: color.withValues(alpha: opacity / 100),
            width: borderWidth,
          ),
        ),
      ),
    ),
  );
}

/// 在批处理编辑器里翻一屏，且保留 1 行重叠：
/// 下一屏的第一行 = 上一屏的最后一行。
///
/// 做法：每次滚动「视口高度 - 一个行高」的距离。
/// 对固定行高的行编辑器/行编辑器3 完全精准；文本编辑器若某行折行，
/// 仍按单行高近似，效果同“重叠一行”。
void pageByOneLine(ScrollController ctrl, double lineHeight,
    {required bool down}) {
  if (!ctrl.hasClients) return;
  final pos = ctrl.position;
  final delta = pos.viewportDimension - lineHeight;
  if (delta <= 0) return;
  final target = (down ? pos.pixels + delta : pos.pixels - delta)
      .clamp(0.0, pos.maxScrollExtent);
  if ((target - pos.pixels).abs() < 0.5) return;
  ctrl.jumpTo(target);
}
