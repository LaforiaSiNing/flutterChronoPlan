import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/event_repository.dart';
import '../../domain/event_model.dart';
import '../../../categories/application/category_providers.dart';

import 'package:isar/isar.dart'; //已完成日程相关
import '../../application/calendar_providers.dart';//修改bug
import 'add_event_dialog.dart';

class EventListItem extends ConsumerWidget {
  final EventModel event;
  final VoidCallback? onCompletionChanged;

  const EventListItem({
    super.key, 
    required this.event,
    this.onCompletionChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听分类列表，用于获取当前日程分类的颜色
    final categoriesAsync = ref.watch(eventCategoriesProvider);
    
    Color categoryColor = Colors.blue; // 默认兜底颜色
    
    categoriesAsync.whenData((categories) {
      final category = categories.firstWhere(
        (c) => c.name == event.category,
        orElse: () => categories.firstWhere((c) => c.name == '默认', orElse: () => categories.first),
      );
      categoryColor = Color(category.colorValue);
    });

    final isRecurring = event.recurrenceRule != null || event.lunarRecurrence != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // 适当增加上下间距
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3), // 更轻的背景色
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)), // 更细的描边
      ),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AddEventDialog(
              selectedDate: event.startTime,
              eventToEdit: event,
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0), // 卡片内边距
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1) 左侧颜色条
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                
                // 2) 主体信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题
                      Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: event.isCompleted ? TextDecoration.lineThrough : null,
                          color: event.isCompleted ? Colors.grey : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      
                      // 时间 & 地点
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${DateFormat.Hm().format(event.startTime)} - ${DateFormat.Hm().format(event.endTime)}',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                          if (event.location != null && event.location!.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.location!,
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                      // 分类标签 & 备注
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              event.category,
                              style: TextStyle(fontSize: 11, color: categoryColor, fontWeight: FontWeight.w500),
                            ),
                          ),
                          if (event.description != null && event.description!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                event.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // 3) 操作区（重复标识 -> 选中 -> 删除）
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isRecurring) ...[
                      Tooltip(
                        message: '重复任务',
                        child: Icon(Icons.repeat, size: 18, color: Colors.grey[400]),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // 根据是否为弹性计划显示不同的勾选组件
                    if (event.isFlexibleHabit) ...[
                      // 弹性计划：三个子目标复选框
                      _buildFlexSubCheckbox(
                        context,
                        ref,
                        event.flexibleHabit1 ?? '一级',
                        event.flexibleHabit1Completed,
                        (val) => _toggleFlexibleDate(ref, 1, val),
                      ),
                      const SizedBox(height: 4),
                      _buildFlexSubCheckbox(
                        context,
                        ref,
                        event.flexibleHabit2 ?? '二级',
                        event.flexibleHabit2Completed,
                        (val) => _toggleFlexibleDate(ref, 2, val),
                      ),
                      const SizedBox(height: 4),
                      _buildFlexSubCheckbox(
                        context,
                        ref,
                        event.flexibleHabit3 ?? '三级',
                        event.flexibleHabit3Completed,
                        (val) => _toggleFlexibleDate(ref, 3, val),
                      ),
                    ] else ...[
                      // 普通日程的单个复选框（保持原有逻辑）
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: event.isCompleted,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          activeColor: categoryColor,
                          onChanged: (val) async {
                            final repo = ref.read(eventRepositoryProvider);
                            final isar = await repo.db;
                            final master = await isar.eventModels.get(event.id);
                            if (master == null) return;

                            final dateStr = DateFormat('yyyy-MM-dd').format(event.startTime);

                            if (master.recurrenceRule != null || master.lunarRecurrence != null) {
                              // 重复事件：更新 completedDates 列表
                              final dates = master.completedDates?.split(',').where((s) => s.isNotEmpty).toList() ?? [];
                              if (val == true) {
                                if (!dates.contains(dateStr)) dates.add(dateStr);
                              } else {
                                dates.remove(dateStr);
                              }
                              master.completedDates = dates.isEmpty ? null : dates.join(',');
                            } else {
                              // 普通事件：直接修改 isCompleted
                              master.isCompleted = val ?? false;
                            }
                            await repo.updateEvent(master);
                            onCompletionChanged?.call();
                            // 强制刷新当天日程列表，确保复选框状态立即更新
                            ref.invalidate(dayEventsProvider(event.startTime));//修改每周，不重复无法框选
                          },//已完成日程选项。
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                      splashRadius: 20,
                      onPressed: () {
                        _confirmDelete(context, ref);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 弹性计划子目标复选框构建器
  Widget _buildFlexSubCheckbox(BuildContext context, WidgetRef ref, String text, bool value, Function(bool?) onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  /// 切换弹性计划某个子目标的完成状态（更新对应日期列表）
  Future<void> _toggleFlexibleDate(WidgetRef ref, int index, bool? value) async {
    final repo = ref.read(eventRepositoryProvider);
    final isar = await repo.db;
    final master = await isar.eventModels.get(event.id);
    if (master == null) return;
    final dateStr = DateFormat('yyyy-MM-dd').format(event.startTime);
    String? targetList;
    switch (index) {
      case 1: targetList = master.flexibleHabit1CompletedDates; break;
      case 2: targetList = master.flexibleHabit2CompletedDates; break;
      case 3: targetList = master.flexibleHabit3CompletedDates; break;
      default: return;
    }
    final dates = targetList?.split(',').where((s) => s.isNotEmpty).toList() ?? [];
    if (value == true) {
      if (!dates.contains(dateStr)) dates.add(dateStr);
    } else {
      dates.remove(dateStr);
    }
    final newList = dates.isEmpty ? null : dates.join(',');
    switch (index) {
      case 1: master.flexibleHabit1CompletedDates = newList; break;
      case 2: master.flexibleHabit2CompletedDates = newList; break;
      case 3: master.flexibleHabit3CompletedDates = newList; break;
    }
    await repo.updateEvent(master);
    onCompletionChanged?.call();
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除日程'),
        content: const Text('确定要删除这个日程吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(eventRepositoryProvider).deleteEvent(event.id);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}