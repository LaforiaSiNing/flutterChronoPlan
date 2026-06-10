import 'package:isar/isar.dart';

part 'event_model.g.dart';

@collection
class EventModel {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String title;

  String? description;

  @Index()
  late DateTime startTime;

  @Index()
  late DateTime endTime;

  bool isAllDay = false;

  /// 地点（字符串/坐标等）
  String? location;

  /// 优先级：0=低，1=中，2=高
  @Index()
  int priority = 1;

  /// 分类：例如“工作/生活/学习”
  @Index()
  String category = 'Personal';

  /// 重复规则（RRULE 字符串）
  /// 例如："FREQ=MONTHLY;BYMONTHDAY=15"（每月 15 号）
  /// 例如："FREQ=YEARLY;BYMONTH=1;BYMONTHDAY=1"（每年 1 月 1 日）
  String? recurrenceRule;
  
  /// 农历重复（日程/生日等）
  /// 格式："LUNAR;MONTH=1;DAY=1"（农历正月初一）
  String? lunarRecurrence;

  /// 是否已完成/归档（主要用于非重复事件）
  bool isCompleted = false;

  /// 弹性习惯开关
  @Index()
  bool isFlexibleHabit = false;

  /// 弹性习惯内容 1
  String? flexibleHabit1;

  /// 弹性习惯内容 2
  String? flexibleHabit2;

  /// 弹性习惯内容 3
  String? flexibleHabit3;

  /// 重复事件的已完成实例日期列表，逗号分隔的 yyyy-MM-dd 格式
  String? completedDates;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}