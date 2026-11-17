import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/common.dart';
import '../models/support.dart';

class SupportMessagesResult {
  const SupportMessagesResult({this.conversation, this.messages = const []});

  final SupportConversation? conversation;
  final List<SupportMessage> messages;
}

class SupportTransferResult {
  const SupportTransferResult({this.conversation, this.queuePosition = 0});

  final SupportConversation? conversation;
  final int queuePosition;
}

class SupportApi {
  SupportApi(this._api);

  final ApiClient _api;

  Future<List<SupportConversation>> conversations() async {
    final data = await _api.get('/client/support/conversations');
    return asList(data).map((item) => SupportConversation.fromJson(asMap(item))).toList();
  }

  Future<SupportConversation> createConversation({String clientType = 'mobile'}) async {
    final data = await _api.post('/client/support/conversations', data: {
      'clientType': clientType,
      'source': 'mobile',
    });
    return SupportConversation.fromJson(asMap(data));
  }

  Future<SupportMessagesResult> messages(int conversationId) async {
    final data = asMap(await _api.get('/client/support/messages', query: {
      'conversationId': conversationId,
    }));
    return SupportMessagesResult(
      conversation: data['conversation'] is Map
          ? SupportConversation.fromJson(asMap(data['conversation']))
          : null,
      messages: asList(data['list']).map((item) => SupportMessage.fromJson(asMap(item))).toList(),
    );
  }

  Future<SupportMessage> sendMessage({
    required int conversationId,
    required String contentType,
    required String content,
    int attachmentId = 0,
  }) async {
    final data = asMap(await _api.post('/client/support/messages', data: {
      'conversationId': conversationId,
      'contentType': contentType,
      'content': content,
      'attachmentId': attachmentId,
    }));
    return SupportMessage.fromJson(asMap(data['message']));
  }

  Future<SupportTransferResult> transferHuman(int conversationId) async {
    final data = asMap(await _api.post('/client/support/transfer-human', data: {
      'conversationId': conversationId,
    }));
    return SupportTransferResult(
      conversation: data['conversation'] is Map
          ? SupportConversation.fromJson(asMap(data['conversation']))
          : null,
      queuePosition: asInt(data['queuePosition']),
    );
  }

  Future<void> rate({required int conversationId, required int score, String comment = ''}) async {
    await _api.post('/client/support/rating', data: {
      'conversationId': conversationId,
      'score': score,
      'comment': comment,
    });
  }

  Future<String> fallbackText() async {
    final data = asMap(await _api.get('/client/support/auto-replies'));
    return asString(data['fallback'], fallback: '未匹配到答案，请转人工或提交留言工单。');
  }

  Future<AttachmentUpload> uploadAttachment(String filePath) async {
    final data = await _api.uploadFile('/client/uploads', filePath);
    return AttachmentUpload.fromJson(data);
  }

  Future<List<Ticket>> tickets({int page = 1, int pageSize = 20, String? status}) async {
    final data = asMap(await _api.get('/client/tickets', query: {
      'page': page,
      'pageSize': pageSize,
      if (status != null && status.isNotEmpty) 'status': status,
    }));
    return asList(data['list']).map((item) => Ticket.fromJson(asMap(item))).toList();
  }

  Future<Ticket> createTicket({
    required String problemType,
    required String content,
    String phone = '',
    String email = '',
    List<int> attachmentIds = const [],
  }) async {
    final data = asMap(await _api.post('/client/tickets', data: {
      'phone': phone,
      'email': email,
      'problemType': problemType,
      'content': content,
      'attachmentIds': attachmentIds,
    }));
    return Ticket.fromJson(asMap(data['ticket']));
  }

  Future<TicketDetail> ticketDetail(int id) async {
    final data = await _api.get('/client/tickets/$id');
    return TicketDetail.fromJson(asMap(data));
  }
}
