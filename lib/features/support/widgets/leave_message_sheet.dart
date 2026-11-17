import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/common.dart';
import '../../../data/models/support.dart';
import '../../../state/app_services.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_sheet.dart';
import '../../../widgets/app_text_field.dart';

Future<Ticket?> showLeaveMessageSheet(
  BuildContext context, {
  required AppServices services,
  required bool phoneRequired,
}) {
  return showAppSheet<Ticket>(
    context,
    title: '人工留言',
    subtitle: '留言后可在“我的反馈”查看处理进度与回复',
    heightFactor: 0.8,
    builder: (sheetContext) => LeaveMessageForm(
      services: services,
      phoneRequired: phoneRequired,
    ),
  );
}

class LeaveMessageForm extends StatefulWidget {
  const LeaveMessageForm({
    super.key,
    required this.services,
    required this.phoneRequired,
  });

  final AppServices services;
  final bool phoneRequired;

  @override
  State<LeaveMessageForm> createState() => _LeaveMessageFormState();
}

class _LeaveMessageFormState extends State<LeaveMessageForm> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _contentController = TextEditingController();
  final List<AttachmentUpload> _attachments = [];
  String _problemType = AppConstants.registerProblemTypes.first;
  bool _submitting = false;
  bool _uploading = false;
  String? _error;

  static const _allowedExtensions = ['txt', 'pdf', 'jpg', 'jpeg', 'png', 'webp', 'gif'];

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    setState(() => _error = null);
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
    );
    if (result == null || result.files.isEmpty) return;
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      final ext = Formatters.fileExtension(file.name);
      if (!_allowedExtensions.contains(ext)) {
        setState(() => _error = '仅支持 txt、pdf、jpg、png、webp、gif 文件');
        continue;
      }
      if (file.size > 20 * 1024 * 1024) {
        setState(() => _error = '${file.name} 超过 20MB 上限');
        continue;
      }
      if (_attachments.length >= 5) {
        setState(() => _error = '最多上传 5 个附件');
        break;
      }
      setState(() => _uploading = true);
      try {
        final upload = await widget.services.supportApi.uploadAttachment(path);
        setState(() {
          _attachments.add(upload);
          _error = null;
        });
      } catch (e) {
        setState(() => _error = '附件上传失败：$e');
      } finally {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_uploading) {
      setState(() => _error = '附件仍在上传，请稍候');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final ticket = await widget.services.supportApi.createTicket(
        problemType: _problemType,
        content: _contentController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        attachmentIds: _attachments.map((item) => item.id).toList(),
      );
      if (mounted) Navigator.of(context).pop(ticket);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '请简要描述您的问题或者意见，如有截图可在附件提交。我们会认真阅读后进行回复。',
              style: TextStyle(fontSize: 12, height: 1.6, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _phoneController,
              label: widget.phoneRequired ? '手机号（必填）' : '手机号（选填）',
              hint: '便于客服联系你',
              keyboardType: TextInputType.phone,
              maxLength: 11,
              validator: (value) {
                if (widget.phoneRequired && (value == null || value.trim().isEmpty)) {
                  return '请填写手机号';
                }
                if (value != null && value.trim().isNotEmpty) return Validators.phone(value);
                return null;
              },
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _emailController,
              label: '邮箱（选填）',
              hint: '用于接收工单回复通知',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) return Validators.email(value);
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _problemType,
              decoration: const InputDecoration(labelText: '问题类型'),
              items: AppConstants.registerProblemTypes
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) => setState(() => _problemType = value ?? _problemType),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _contentController,
              label: '留言内容',
              hint: '请描述问题现象、发生时间与操作步骤',
              maxLines: 5,
              minLines: 3,
              maxLength: 2000,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '请填写问题描述';
                if (value.trim().runes.length > 2000) return '留言不能超过 2000 字';
                return null;
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  '附件',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                const Text(
                  'txt / pdf / 图片，单个不超过 20MB',
                  style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _uploading ? null : _pickAttachments,
                  icon: _uploading
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        )
                      : const Icon(Icons.attach_file_rounded, size: 16),
                  label: Text(_uploading ? '上传中' : '添加附件', style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
            if (_attachments.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _attachments
                    .map(
                      (item) => InputChip(
                        avatar: Icon(
                          item.mime.startsWith('image') ? Icons.image_outlined : Icons.description_outlined,
                          size: 16,
                        ),
                        label: Text(
                          '${item.fileName} (${Formatters.bytes(item.size)})',
                          style: const TextStyle(fontSize: 10),
                        ),
                        onDeleted: () {
                          setState(() => _attachments.remove(item));
                        },
                      ),
                    )
                    .toList(),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 11, color: AppColors.danger, height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: '提交留言',
              loading: _submitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
            const Text(
              '提交后工单进入处理队列，客服回复后会在“我的反馈”与站内消息中提醒。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: AppColors.textTertiary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
