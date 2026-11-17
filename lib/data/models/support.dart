import '../../core/utils/json_utils.dart';

class SupportConversation {
  const SupportConversation({
    this.id = 0,
    this.status = 'queued',
    this.agentId = 0,
    this.agentName = '',
    this.lastMessage = '',
    this.lastMessageAt,
    this.unreadUser = 0,
    this.source = '',
    this.clientType = '',
    this.rating = 0,
    this.claimedAt,
    this.closedAt,
  });

  final int id;
  final String status;
  final int agentId;
  final String agentName;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadUser;
  final String source;
  final String clientType;
  final int rating;
  final DateTime? claimedAt;
  final DateTime? closedAt;

  bool get isHumanOnline => agentId > 0 && status == 'active';
  bool get isQueued => status == 'queued';
  bool get isClosed => status == 'closed';

  factory SupportConversation.fromJson(Map<String, dynamic> json) {
    return SupportConversation(
      id: asInt(json['id']),
      status: asString(json['status'], fallback: 'queued'),
      agentId: asInt(json['agentId']),
      agentName: asString(json['agentName']),
      lastMessage: asString(json['lastMessage']),
      lastMessageAt: asDate(json['lastMessageAt']),
      unreadUser: asInt(json['unreadUser']),
      source: asString(json['source']),
      clientType: asString(json['clientType']),
      rating: asInt(json['rating']),
      claimedAt: asDate(json['claimedAt']),
      closedAt: asDate(json['closedAt']),
    );
  }

  SupportConversation copyWith({int? agentId, String? agentName, String? status}) {
    return SupportConversation(
      id: id,
      status: status ?? this.status,
      agentId: agentId ?? this.agentId,
      agentName: agentName ?? this.agentName,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      unreadUser: unreadUser,
      source: source,
      clientType: clientType,
      rating: rating,
      claimedAt: claimedAt,
      closedAt: closedAt,
    );
  }
}

class SupportMessage {
  const SupportMessage({
    this.id = 0,
    this.localId = '',
    this.conversationId = 0,
    this.senderType = 'user',
    this.senderId = 0,
    this.senderName = '',
    this.contentType = 'text',
    this.content = '',
    this.attachmentId = 0,
    this.attachmentUrl = '',
    this.read = false,
    this.createdAt,
    this.sending = false,
    this.failed = false,
  });

  final int id;
  final String localId;
  final int conversationId;
  final String senderType;
  final int senderId;
  final String senderName;
  final String contentType;
  final String content;
  final int attachmentId;
  final String attachmentUrl;
  final bool read;
  final DateTime? createdAt;
  final bool sending;
  final bool failed;

  bool get isMine => senderType == 'user';
  bool get isSystem => senderType == 'system';
  bool get isBot => senderType == 'bot';
  bool get isAgent => senderType == 'agent';
  bool get isImage => contentType == 'image';

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: asInt(json['id']),
      conversationId: asInt(json['conversationId']),
      senderType: asString(json['senderType'], fallback: 'user'),
      senderId: asInt(json['senderId']),
      senderName: asString(json['senderName']),
      contentType: asString(json['contentType'], fallback: 'text'),
      content: asString(json['content']),
      attachmentId: asInt(json['attachmentId']),
      attachmentUrl: asString(json['attachmentUrl']),
      read: asBool(json['read']),
      createdAt: asDate(json['createdAt']),
    );
  }

  SupportMessage copyWith({bool? sending, bool? failed, int? id, String? attachmentUrl}) {
    return SupportMessage(
      id: id ?? this.id,
      localId: localId,
      conversationId: conversationId,
      senderType: senderType,
      senderId: senderId,
      senderName: senderName,
      contentType: contentType,
      content: content,
      attachmentId: attachmentId,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      read: read,
      createdAt: createdAt,
      sending: sending ?? this.sending,
      failed: failed ?? this.failed,
    );
  }
}

class SupportSocketEvent {
  const SupportSocketEvent({required this.type, this.data = const {}, this.ts});

  final String type;
  final Map<String, dynamic> data;
  final DateTime? ts;

  factory SupportSocketEvent.fromJson(Map<String, dynamic> json) {
    return SupportSocketEvent(
      type: asString(json['type']),
      data: asMap(json['data']),
      ts: asDate(json['ts']),
    );
  }
}

class Ticket {
  const Ticket({
    this.id = 0,
    this.phone = '',
    this.email = '',
    this.problemType = '',
    this.content = '',
    this.status = 'pending',
    this.isReport = false,
    this.priority = 0,
    this.handlerName = '',
    this.replyCount = 0,
    this.lastReplyAt,
    this.createdAt,
    this.closedAt,
  });

  final int id;
  final String phone;
  final String email;
  final String problemType;
  final String content;
  final String status;
  final bool isReport;
  final int priority;
  final String handlerName;
  final int replyCount;
  final DateTime? lastReplyAt;
  final DateTime? createdAt;
  final DateTime? closedAt;

  String get statusLabel {
    switch (status) {
      case 'pending':
        return '待处理';
      case 'processing':
        return '处理中';
      case 'replied':
        return '已回复';
      case 'closed':
        return '已关闭';
      default:
        return status;
    }
  }

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: asInt(json['id']),
      phone: asString(json['phone']),
      email: asString(json['email']),
      problemType: asString(json['problemType']),
      content: asString(json['content']),
      status: asString(json['status'], fallback: 'pending'),
      isReport: asBool(json['isReport']),
      priority: asInt(json['priority']),
      handlerName: asString(json['handlerName']),
      replyCount: asInt(json['replyCount']),
      lastReplyAt: asDate(json['lastReplyAt']),
      createdAt: asDate(json['createdAt']),
      closedAt: asDate(json['closedAt']),
    );
  }
}

class TicketReply {
  const TicketReply({
    this.id = 0,
    this.adminName = '',
    this.content = '',
    this.createdAt,
  });

  final int id;
  final String adminName;
  final String content;
  final DateTime? createdAt;

  factory TicketReply.fromJson(Map<String, dynamic> json) {
    return TicketReply(
      id: asInt(json['id']),
      adminName: asString(json['adminName']),
      content: asString(json['content']),
      createdAt: asDate(json['createdAt']),
    );
  }
}

class TicketAttachment {
  const TicketAttachment({
    this.id = 0,
    this.fileName = '',
    this.filePath = '',
    this.mime = '',
    this.size = 0,
  });

  final int id;
  final String fileName;
  final String filePath;
  final String mime;
  final int size;

  factory TicketAttachment.fromJson(Map<String, dynamic> json) {
    return TicketAttachment(
      id: asInt(json['id']),
      fileName: asString(json['fileName']),
      filePath: asString(json['filePath']),
      mime: asString(json['mime']),
      size: asInt(json['size']),
    );
  }
}

class TicketDetail {
  const TicketDetail({this.ticket, this.replies = const [], this.attachments = const []});

  final Ticket? ticket;
  final List<TicketReply> replies;
  final List<TicketAttachment> attachments;

  factory TicketDetail.fromJson(Map<String, dynamic> json) {
    return TicketDetail(
      ticket: json['ticket'] is Map ? Ticket.fromJson(asMap(json['ticket'])) : null,
      replies: asList(json['replies']).map((item) => TicketReply.fromJson(asMap(item))).toList(),
      attachments: asList(json['attachments'])
          .map((item) => TicketAttachment.fromJson(asMap(item)))
          .toList(),
    );
  }
}
