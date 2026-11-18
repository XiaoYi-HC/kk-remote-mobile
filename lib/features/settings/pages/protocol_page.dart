import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json_utils.dart';
import '../../../data/protocol_texts.dart';
import '../../../state/app_services.dart';
import '../../../widgets/loading_view.dart';
import '../../../widgets/mobile_page.dart';

/// 协议详情页：以独立页面展示，不使用弹窗。
///
/// 优先展示后台下发的协议内容；后台未配置或内容明显不完整时，
/// 使用本地完整文案兜底，保证用户始终可以看到完整条款。
class ProtocolPage extends StatefulWidget {
  const ProtocolPage({super.key, required this.type});

  final String type;

  @override
  State<ProtocolPage> createState() => _ProtocolPageState();
}

class _ProtocolPageState extends State<ProtocolPage> {
  String _content = '';
  bool _loading = true;

  static const int _minCompleteLength = 500;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fallback = ProtocolTexts.textOf(widget.type);
    var remote = '';
    try {
      final data = await context.read<AppServices>().contentApi.protocolsLatest();
      remote = asString(asMap(data[widget.type])['content']);
    } catch (_) {
      remote = '';
    }
    if (!mounted) return;
    setState(() {
      _content = remote.trim().length >= _minCompleteLength ? remote : fallback;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MobilePage(
      title: ProtocolTexts.titleOf(widget.type),
      child: _loading
          ? const LoadingView(message: '正在加载协议内容…')
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              child: SelectableText(
                _content.isEmpty ? '协议内容暂不可用，请稍后重试。' : _content,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.85,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
    );
  }
}
