import '../../core/utils/json_utils.dart';

class ThirdPartyChannel {
  const ThirdPartyChannel({
    required this.provider,
    required this.name,
    this.icon = '',
    this.appType = '',
    this.sort = 0,
  });

  final String provider;
  final String name;
  final String icon;
  final String appType;
  final int sort;

  factory ThirdPartyChannel.fromJson(Map<String, dynamic> json) {
    return ThirdPartyChannel(
      provider: asString(json['provider']),
      name: asString(json['name']),
      icon: asString(json['icon']),
      appType: asString(json['appType']),
      sort: asInt(json['sort']),
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'name': name,
        'icon': icon,
        'appType': appType,
        'sort': sort,
      };
}

class IceServerConfig {
  const IceServerConfig({required this.urls, this.username, this.credential});

  final List<String> urls;
  final String? username;
  final String? credential;

  factory IceServerConfig.fromJson(Map<String, dynamic> json) {
    return IceServerConfig(
      urls: asList(json['urls']).map((item) => item.toString()).toList(),
      username: asStringOrNull(json['username']),
      credential: asStringOrNull(json['credential']),
    );
  }

  Map<String, dynamic> toWebRtcJson() => {
        'urls': urls,
        if (username != null && username!.isNotEmpty) 'username': username,
        if (credential != null && credential!.isNotEmpty) 'credential': credential,
      };
}

class Announcement {
  const Announcement({
    required this.id,
    this.type = 'notice',
    this.title = '',
    this.content = '',
    this.image = '',
    this.link = '',
    this.pinned = false,
    this.startAt,
    this.endAt,
    this.views = 0,
    this.clicks = 0,
  });

  final int id;
  final String type;
  final String title;
  final String content;
  final String image;
  final String link;
  final bool pinned;
  final DateTime? startAt;
  final DateTime? endAt;
  final int views;
  final int clicks;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: asInt(json['id']),
      type: asString(json['type'], fallback: 'notice'),
      title: asString(json['title']),
      content: asString(json['content']),
      image: asString(json['image']),
      link: asString(json['link']),
      pinned: asBool(json['pinned']),
      startAt: asDate(json['startAt']),
      endAt: asDate(json['endAt']),
      views: asInt(json['views']),
      clicks: asInt(json['clicks']),
    );
  }
}

class AppUpdateInfo {
  const AppUpdateInfo({
    this.platform = '',
    this.version = '',
    this.changelog = '',
    this.downloadUrl = '',
    this.forceUpdate = false,
    this.minCompatible = '',
    this.grayPercent = 0,
  });

  final String platform;
  final String version;
  final String changelog;
  final String downloadUrl;
  final bool forceUpdate;
  final String minCompatible;
  final int grayPercent;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      platform: asString(json['platform']),
      version: asString(json['version']),
      changelog: asString(json['changelog']),
      downloadUrl: asString(json['downloadUrl']),
      forceUpdate: asBool(json['forceUpdate']),
      minCompatible: asString(json['minCompatible']),
      grayPercent: asInt(json['grayPercent']),
    );
  }
}

class AttachmentUpload {
  const AttachmentUpload({
    required this.id,
    required this.fileName,
    required this.size,
    required this.mime,
    required this.url,
  });

  final int id;
  final String fileName;
  final int size;
  final String mime;
  final String url;

  factory AttachmentUpload.fromJson(Map<String, dynamic> json) {
    return AttachmentUpload(
      id: asInt(json['id']),
      fileName: asString(json['fileName']),
      size: asInt(json['size']),
      mime: asString(json['mime']),
      url: asString(json['url']),
    );
  }
}
