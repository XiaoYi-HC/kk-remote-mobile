import '../../core/utils/json_utils.dart';

class FaqCategory {
  const FaqCategory({required this.id, required this.name, this.sort = 0});

  final int id;
  final String name;
  final int sort;

  factory FaqCategory.fromJson(Map<String, dynamic> json) {
    return FaqCategory(
      id: asInt(json['id']),
      name: asString(json['name']),
      sort: asInt(json['sort']),
    );
  }
}

class FaqItem {
  const FaqItem({
    this.id = 0,
    this.categoryId = 0,
    this.categoryName = '',
    this.question = '',
    this.answer = '',
    this.keywords = '',
    this.hot = false,
    this.views = 0,
  });

  final int id;
  final int categoryId;
  final String categoryName;
  final String question;
  final String answer;
  final String keywords;
  final bool hot;
  final int views;

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      id: asInt(json['id']),
      categoryId: asInt(json['categoryId']),
      categoryName: asString(json['categoryName']),
      question: asString(json['question']),
      answer: asString(json['answer']),
      keywords: asString(json['keywords']),
      hot: asBool(json['hot']),
      views: asInt(json['views']),
    );
  }
}

class FaqResult {
  const FaqResult({this.categories = const [], this.list = const []});

  final List<FaqCategory> categories;
  final List<FaqItem> list;

  factory FaqResult.fromJson(Map<String, dynamic> json) {
    return FaqResult(
      categories: asList(json['categories'])
          .map((item) => FaqCategory.fromJson(asMap(item)))
          .toList(),
      list: asList(json['list']).map((item) => FaqItem.fromJson(asMap(item))).toList(),
    );
  }
}

class MessageItem {
  const MessageItem({
    this.id = 0,
    this.category = 'system',
    this.title = '',
    this.content = '',
    this.read = false,
    this.refId = 0,
    this.createdAt,
  });

  final int id;
  final String category;
  final String title;
  final String content;
  final bool read;
  final int refId;
  final DateTime? createdAt;

  String get categoryLabel {
    switch (category) {
      case 'support':
        return '客服回复';
      case 'offline':
        return '设备告警';
      default:
        return '系统公告';
    }
  }

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    return MessageItem(
      id: asInt(json['id']),
      category: asString(json['category'], fallback: 'system'),
      title: asString(json['title']),
      content: asString(json['content']),
      read: asBool(json['read']),
      refId: asInt(json['refId']),
      createdAt: asDate(json['createdAt']),
    );
  }
}

class MessageListResult {
  const MessageListResult({this.list = const [], this.unread = 0, this.total = 0});

  final List<MessageItem> list;
  final int unread;
  final int total;

  factory MessageListResult.fromJson(Map<String, dynamic> json) {
    return MessageListResult(
      list: asList(json['list']).map((item) => MessageItem.fromJson(asMap(item))).toList(),
      unread: asInt(json['unread']),
      total: asInt(json['total']),
    );
  }
}
