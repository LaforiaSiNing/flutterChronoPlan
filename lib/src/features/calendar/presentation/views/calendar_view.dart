import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:lunar/lunar.dart';
import '../../application/calendar_providers.dart';
import '../../domain/event_model.dart';
import '../widgets/event_list_item.dart';
import '../widgets/add_event_dialog.dart';
import '../../data/event_repository.dart'; // 用于加载 marker（月视图事件）

import 'event_list_screen.dart';

// 月视图右下角“X个日程”的数据来源（marker）
// 说明：
// - 逐日查询开销大，因此按“月份”批量取回，再在内存里按天过滤
// - TableCalendar 通过 eventLoader(day) 请求某一天的事件列表，用它来驱动 marker

/// 月份 marker 数据：用 Stream 监听 DB 变化，确保新增/编辑后 marker 立即更新；
/// 同时 key 必须是“月份起始日(YYYY-MM-01)”，避免选中不同日期导致同月反复刷新引起数量错乱。
final monthEventsLoaderProvider = StreamProvider.family<List<EventModel>, DateTime>((ref, monthStart) {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.db.asStream().asyncExpand((isar) {
    return isar.eventModels.watchLazy(fireImmediately: true).asyncMap((_) async {
      return repo.getEventsForMonth(monthStart);
    });
  });
});

class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now(); // 自定义头部年/月选择器依赖它
  
  @override
  void initState() {
    super.initState();
    // 初始聚焦日期与“当前选中日期”保持一致
    _focusedDay = ref.read(selectedDateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final eventsAsync = ref.watch(dayEventsProvider(selectedDate));
    
    // 监听当月事件（key 归一到 YYYY-MM-01，避免选中日期变化导致同月反复刷新）
    final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final monthEventsAsync = ref.watch(monthEventsLoaderProvider(monthStart));

    // 界面主色调：优雅蓝色（同时保留作为强调色）
    const Color primaryBlue = Color.fromRGBO(78, 110, 242, 1);

    return Scaffold(
      // 替换为动态主题背景色，支持深色模式
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryBlue,
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddEventDialog(selectedDate: selectedDate),
          );
        },
        label: const Text('新建日程', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
      body: Row(
        children: [
          // 左侧：日历
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // 替换为动态表面色，深色模式下自动变暗
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                // 无阴影，更扁平
              ),
              child: Column(
                children: [
                  _buildCustomHeader(primaryBlue),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // 星期标题高度略微降低，更紧凑
                          const daysOfWeekHeight = 36.0;
                          final cellSize = constraints.maxWidth / 7;
                          // 行高设为宽度的85%，使格子不再完全正方形，更紧凑
                          final rowHeight = cellSize * 0.85;
                          final desiredCalendarHeight = daysOfWeekHeight + rowHeight * 6;

                          Widget calendar = TableCalendar(
                            locale: 'zh_CN',
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay,
                            calendarFormat: _calendarFormat,
                            selectedDayPredicate: (day) {
                              return isSameDay(selectedDate, day);
                            },
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _focusedDay = focusedDay;
                              });
                              ref.read(selectedDateProvider.notifier).state = selectedDay;
                            },
                            onPageChanged: (focusedDay) {
                              setState(() {
                                _focusedDay = focusedDay;
                              });
                            },
                            headerVisible: false,
                            daysOfWeekHeight: daysOfWeekHeight,
                            daysOfWeekStyle: DaysOfWeekStyle(
                              weekdayStyle: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                              weekendStyle: TextStyle(fontSize: 14, color: Colors.red[300]),
                            ),
                            rowHeight: rowHeight, // 使用压缩后的行高
                        
                            eventLoader: (day) {
                              return monthEventsAsync.when(
                                data: (events) {
                                  return events.where((e) => isSameDay(e.startTime, day) && !e.isCompleted).toList();
                                },
                                loading: () => [],
                                error: (_, __) => [],
                              );
                            },
                        
                            calendarBuilders: CalendarBuilders(
                              defaultBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, false, primaryBlue: primaryBlue),
                              selectedBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, true, primaryBlue: primaryBlue),
                              todayBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, false, isToday: true, primaryBlue: primaryBlue),
                              outsideBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, false, isOutside: true, primaryBlue: primaryBlue),
                              
                              markerBuilder: (context, day, events) {
                                if (events.isEmpty) return null;
                                // 将标记从底部中央改为左上角，避免遮挡单元格内容
                                return Positioned(
                                  top: 2,
                                  left: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primaryBlue,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${events.length}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );

                          if (desiredCalendarHeight <= constraints.maxHeight + 0.5) {
                            return calendar;
                          }

                          return SingleChildScrollView(
                            primary: false,
                            physics: const ClampingScrollPhysics(),
                            child: SizedBox(
                              height: desiredCalendarHeight,
                              child: calendar,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 右侧：当天日程列表
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
              decoration: BoxDecoration(
                // 替换为动态表面色
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Text(
                      DateFormat.yMMMMEEEEd('zh_CN').format(selectedDate),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        // 替换为主题文字色，适应深色模式
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  // 分割线使用主题色
                  Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor),
                  Expanded(
                    child: eventsAsync.when(
                      data: (events) {
                        if (events.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_busy, size: 64,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                                const SizedBox(height: 16),
                                Text('暂无日程',
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                        fontSize: 15)),
                              ],
                            ),
                          );
                        }
                        // 使用 prototypeItem 强制设置每项高度为原来的 75%，配合内部已压缩的 EventListItem 达到整体紧凑
                        return ListView.builder(
                          padding: const EdgeInsets.only(top: 8),
                          itemCount: events.length,
                          // 设置一个较矮的参考项，使每项高度固定为约 60（原来约 80）
                          prototypeItem: SizedBox(
                            height: 60,
                            child: EventListItem(event: events.first),
                          ),
                          itemBuilder: (context, index) {
                            final event = events[index];
                            return EventListItem(event: event);
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text('Error: $err')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 自定义头部，加入主色调，深色模式下文字颜色适配
  Widget _buildCustomHeader(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.list, color: Theme.of(context).colorScheme.onSurface),
            tooltip: '所有日程',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EventListScreen()),
              );
            },
          ),
          const Spacer(),
          // 年份选择
          DropdownButton<int>(
            value: _focusedDay.year,
            underline: const SizedBox(),
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500),
            items: List.generate(10, (index) => 2020 + index).map((year) {
              return DropdownMenuItem(value: year, child: Text('$year年'));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _focusedDay = DateTime(val, _focusedDay.month, _focusedDay.day);
                });
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.chevron_left, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, _focusedDay.day);
              });
            },
          ),
          // 月份选择
          DropdownButton<int>(
            value: _focusedDay.month,
            underline: const SizedBox(),
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500),
            items: List.generate(12, (index) => index + 1).map((month) {
              return DropdownMenuItem(value: month, child: Text('$month月'));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, val, _focusedDay.day);
                });
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, _focusedDay.day);
              });
            },
          ),
          const Spacer(),
          // 今天按钮
          OutlinedButton(
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _focusedDay = now;
              });
              ref.read(selectedDateProvider.notifier).state = now;
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primaryColor),
              foregroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('今天'),
          ),
        ],
      ),
    );
  }

  // 日历单元格构建，增加 primaryBlue 参数用于颜色统一，内部已兼容深色模式（通过字体颜色判断）
  Widget _buildCalendarCell(BuildContext context, DateTime day, bool isSelected, {bool isToday = false, bool isOutside = false, Color primaryBlue = const Color.fromRGBO(78, 110, 242, 1)}) {
    final solar = Solar.fromDate(day);
    final lunar = solar.getLunar();
    final lunarDay = lunar.getDayInChinese();
    final lunarMonth = lunar.getMonthInChinese();
    
    List<String> festivals = lunar.getFestivals();
    
    String displayText = '$lunarDay';
    bool isFestival = false;
    
    if (festivals.isNotEmpty) {
      displayText = festivals.first;
      isFestival = true;
    } else {
      final jieQi = lunar.getJieQi();
      if (jieQi.isNotEmpty) {
        displayText = jieQi;
        isFestival = true;
      } else if (lunar.getDay() == 1) {
        displayText = '$lunarMonth月';
        isFestival = true;
      }
    }

    String dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    Holiday? holiday = HolidayUtil.getHoliday(dateStr);
    bool isOffDay = false;
    bool isWorkDay = false;
    
    if (holiday != null) {
      isOffDay = !holiday.isWork();
      isWorkDay = holiday.isWork();
    }

    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    
    // 日期数字颜色（使用主题文字色作为基准，再微调）
    Color dateColor = Theme.of(context).colorScheme.onSurface;
    if (isOutside) dateColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.3);
    else if (isToday) dateColor = primaryBlue;
    else if (isWeekend) dateColor = Colors.red[400]!;

    // 农历/节日文字颜色
    Color lunarColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    if (isOutside) lunarColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.2);
    else if (isFestival) lunarColor = isWeekend ? Colors.red[400]! : primaryBlue;
    
    // 背景色
    Color? cellBgColor;
    if (isOffDay && !isOutside) {
        cellBgColor = const Color(0xFFFFF0F0);
    } else if (isSelected) {
        cellBgColor = primaryBlue.withOpacity(0.1);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: cellBgColor ?? Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: primaryBlue, width: 1.5) : null,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      // 日期数字缩小，更紧凑
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: dateColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayText,
                    style: TextStyle(
                      // 农历文字也稍微缩小
                      fontSize: 10,
                      color: lunarColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isToday)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: primaryBlue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('今', style: TextStyle(color: Colors.white, fontSize: 9)),
            ),
          ),
        if (isOffDay && !isOutside)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('休', style: TextStyle(color: Colors.white, fontSize: 9)),
            ),
          ),
        if (isWorkDay && !isOutside)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('班', style: TextStyle(color: Colors.white, fontSize: 9)),
            ),
          ),
      ],
    );
  }
}