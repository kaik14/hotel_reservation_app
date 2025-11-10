/// ✅ 系统专属图标（本地 assets）
/// 记得把图标放在：assets/icons/hotel_icon.png
const String systemIconAsset = 'assets/icons/hotel_icon.png';

/// ✅ InfoMessage 数据模型
class InfoMessage {
  final String title; // 消息标题
  final String message; // 消息内容
  final String senderIcon; // 'system' → 系统图标；其他为用户/网络图标
  final DateTime timestamp; // 消息时间
  bool isRead; // 是否已读

  InfoMessage({
    required this.title,
    required this.message,
    required this.senderIcon,
    required this.timestamp,
    this.isRead = false,
  });

  /// ✅ 将对象转换成 JSON（可存 Firebase / SharedPreferences）
  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "message": message,
      "senderIcon": senderIcon,
      "timestamp": timestamp.toIso8601String(),
      "isRead": isRead,
    };
  }

  /// ✅ 从 JSON 转换回对象（用于恢复状态）
  factory InfoMessage.fromJson(Map<String, dynamic> json) {
    return InfoMessage(
      title: json["title"] ?? "",
      message: json["message"] ?? "",
      senderIcon: json["senderIcon"] ?? "system",
      timestamp: DateTime.tryParse(json["timestamp"] ?? "") ?? DateTime.now(),
      isRead: json["isRead"] ?? false,
    );
  }
}

/// ✅ 全局消息列表（所有通知都存在这里）
List<InfoMessage> infoMessages = [];
