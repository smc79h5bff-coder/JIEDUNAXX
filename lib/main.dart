import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/debug/crash_logger.dart';
import 'core/storage/pref_keys.dart';
import 'core/storage/shared_preferences_provider.dart';
import 'features/reader/reader_load_log.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 崩溃诊断日志（写文件，可从"诊断"页查看）。
    await CrashLogger.instance.init();

    // ============================================================
    // 日志系统默认关闭（ReaderLoadLog.enabled = false）。
    //
    // 需要排查问题时：
    //   1. 打开 reader_load_log.dart，把 enabled 改成 true
    //   2. 取消下面两行注释
    //   3. 重新编译运行
    //
    // 排查完记得都改回去，避免长期记录影响性能。
    // ============================================================

    // ReaderLoadLog.instance.installErrorHooks();
    // ReaderLoadLog.instance.installFrameMonitor();

    final prefsSw = Stopwatch()..start();
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyKeys(prefs);
    ReaderLoadLog.instance.info(
      'SharedPreferences 加载 ${prefsSw.elapsedMilliseconds}ms',
    );

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const DocDiffApp(),
      ),
    );
  }, (error, stack) {
    CrashLogger.instance.log('Zone', error.toString(), stack);
  });
}

/// 一次性迁移：把 6 个历史上漏加前缀的 key，搬到带 `jianming.` 的新 key。
///
/// 幂等：
///   · 新 key 已有值   → 不动（用户已经在用新版，别覆盖）
///   · 旧 key 没值     → 不动（用户没改过这几项，迁移无事可做）
///   · 两个都有值时     → 保留新 key，旧 key 也不删（防止误伤）
/// 只在 App 启动时跑一次。跑完之后旧 key 就删了，下次启动找不到，不会重复搬。
Future<void> _migrateLegacyKeys(SharedPreferences prefs) async {
  const migrations = <String, String>{
    'comparison_notes': PrefKeys.comparisonNotes,
    'groupedContextLines': PrefKeys.groupedContextLines,
    'colorGroupedEqualIgnoringWsBg': PrefKeys.colorGroupedEqualIgnoringWsBg,
    'colorGroupedWsHighlight': PrefKeys.colorGroupedWsHighlight,
    'colorGroupedFindYellow': PrefKeys.colorGroupedFindYellow,
    'colorGroupedFindPink': PrefKeys.colorGroupedFindPink,
  };

  var migrated = 0;
  for (final e in migrations.entries) {
    if (prefs.containsKey(e.value)) continue;
    final oldValue = prefs.getString(e.key);
    if (oldValue == null) continue;
    await prefs.setString(e.value, oldValue);
    await prefs.remove(e.key);
    migrated++;
  }
  if (migrated > 0) {
    // 有日志系统就记一笔，方便以后排查
    ReaderLoadLog.instance.info('[migrate] 迁移 $migrated 个历史 key');
  }
}
