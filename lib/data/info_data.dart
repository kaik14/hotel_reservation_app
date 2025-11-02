class InfoMessage {
  final String title;      // 消息标题
  final String message;    // 消息内容
  final String senderIcon; // 发件人头像（系统图标、房间图标）
  final DateTime timestamp;
  bool isRead;

  InfoMessage({
    required this.title,
    required this.message,
    required this.senderIcon,
    required this.timestamp,
    this.isRead = false,
  });
}

List<InfoMessage> infoMessages = [];
