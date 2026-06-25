import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class ChatMessage {
  final String senderRole;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.senderRole,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      senderRole: json['sender_role'] as String? ?? json['senderRole'] as String? ?? 'victim',
      content: json['content'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String caseId;
  final String myRole; // 'volunteer' | 'victim'
  final String? myId;  // volunteerId nếu là TNV, null nếu là nạn nhân
  final String? peerPhone; // SĐT đối phương để gọi

  const ChatScreen({
    super.key,
    required this.caseId,
    required this.myRole,
    this.myId,
    this.peerPhone,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static String get _wsBaseUrl =>
      kIsWeb ? 'ws://127.0.0.1:3000' : 'wss://floodaid.onrender.com';

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  bool _wsConnected = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _connectWs();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _wsSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await ApiService.getChatMessages(widget.caseId);
    if (mounted) {
      setState(() {
        _messages.clear();
        _messages.addAll(history.map(ChatMessage.fromJson));
      });
      _scrollToBottom();
    }
  }

  void _connectWs() {
    try {
      final wsUrl = '$_wsBaseUrl/ws/gps'
          '?caseId=${widget.caseId}'
          '&role=${widget.myRole}'
          '${widget.myId != null ? '&volunteerId=${widget.myId}' : ''}';

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _wsSub = _channel!.stream.listen(
        (raw) {
          try {
            final msg = json.decode(raw as String) as Map<String, dynamic>;
            if (msg['type'] == 'connected') {
              if (mounted) setState(() => _wsConnected = true);
            } else if (msg['type'] == 'chat') {
              final incoming = ChatMessage.fromJson(msg);
              // Tránh duplicate echo: bỏ qua tin của chính mình (đã thêm optimistic)
              if (msg['senderRole'] == widget.myRole && _messages.isNotEmpty) {
                final last = _messages.last;
                if (last.content == incoming.content && last.senderRole == incoming.senderRole) {
                  return;
                }
              }
              if (mounted) {
                setState(() => _messages.add(incoming));
                _scrollToBottom();
              }
            }
          } catch (_) {}
        },
        onDone: () {
          if (mounted) setState(() => _wsConnected = false);
        },
        onError: (_) {
          if (mounted) setState(() => _wsConnected = false);
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[ChatScreen] WS connect error: $e');
    }
  }

  void _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    _inputController.clear();
    setState(() => _isSending = true);

    // Optimistic UI
    final optimistic = ChatMessage(
      senderRole: widget.myRole,
      content: text,
      createdAt: DateTime.now(),
    );
    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    if (_wsConnected && _channel != null) {
      // Gửi qua WebSocket
      try {
        _channel!.sink.add(json.encode({'type': 'chat', 'content': text}));
      } catch (e) {
        debugPrint('[ChatScreen] WS send error: $e');
        await _fallbackSend(text);
      }
    } else {
      // Fallback REST
      await _fallbackSend(text);
    }

    if (mounted) setState(() => _isSending = false);
  }

  Future<void> _fallbackSend(String text) async {
    await ApiService.sendChatMessage(
      widget.caseId,
      widget.myRole,
      text,
      senderId: widget.myId,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _callPeer() async {
    final phone = widget.peerPhone;
    if (phone == null || phone.isEmpty) return;
    debugPrint('[ChatScreen] Gọi điện: phone="$phone"');
    final uri = Uri.parse('tel:$phone');
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('[ChatScreen] launchUrl error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.myRole == 'volunteer' ? 'Chat với Nạn nhân' : 'Chat với TNV',
              style: AppTypography.headingMedium.copyWith(
                fontSize: 16.sp,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _wsConnected ? Colors.green : Colors.grey,
                  ),
                ),
                SizedBox(width: 4.w),
                Text(
                  _wsConnected ? 'Real-time' : 'Offline',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: _wsConnected ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (widget.peerPhone != null && widget.peerPhone!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone_in_talk, color: Colors.green),
              tooltip: 'Gọi điện',
              onPressed: _callPeer,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có tin nhắn nào.\nBắt đầu liên lạc với ${widget.myRole == 'volunteer' ? 'nạn nhân' : 'đội cứu hộ'}.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14.sp,
                        height: 1.6,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildBubble(_messages[index]);
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isMe = msg.senderRole == widget.myRole;
    final bubbleColor = isMe ? AppColors.primary : Colors.grey.shade200;
    final textColor = isMe ? Colors.white : AppColors.textPrimary;
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final label = isMe
        ? 'Bạn'
        : (widget.myRole == 'volunteer' ? 'Nạn nhân' : 'TNV');

    final timeStr =
        '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Text(
            '$label · $timeStr',
            style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
          ),
          SizedBox(height: 4.h),
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isMe ? 18.r : 4.r),
                topRight: Radius.circular(isMe ? 4.r : 18.r),
                bottomLeft: Radius.circular(18.r),
                bottomRight: Radius.circular(18.r),
              ),
            ),
            child: Text(
              msg.content,
              style: TextStyle(
                color: textColor,
                fontSize: 14.sp,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                style: TextStyle(fontSize: 15.sp),
                decoration: InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14.sp),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.r),
                    borderSide: BorderSide(color: AppColors.surfaceBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.r),
                    borderSide: BorderSide(color: AppColors.surfaceBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.r),
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            SizedBox(width: 8.w),
            SizedBox(
              width: 44.w,
              height: 44.w,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  elevation: 2,
                ),
                child: _isSending
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.send_rounded, color: Colors.white, size: 20.r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
