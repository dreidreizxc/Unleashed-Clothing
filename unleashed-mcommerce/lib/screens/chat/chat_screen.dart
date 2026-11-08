import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/chat.dart';
import '../../services/chat_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/editorial.dart';

/// One conversation per customer, shared with the store's admin dashboard.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _message = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _error;
  int _lastMessageCount = 0;

  String? get _uid => AppState.instance.user?.uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_uid != null) ChatService.instance.markCustomerMessagesRead(_uid!);
    });
  }

  @override
  void dispose() {
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = _uid;
    if (uid == null || _sending) return;
    final text = _message.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ChatService.instance.sendMessage(
        uid: uid,
        customerName: AppState.instance.profile?.fullName ??
            AppState.instance.displayName,
        text: text,
      );
      if (!mounted) return;
      _message.clear();
      _scrollToEnd();
    } on ChatFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Your message could not be sent. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('MESSAGE THE STORE'),
        actions: [
          IconButton(
            tooltip: 'Refresh conversation',
            onPressed: uid == null
                ? null
                : () => ChatService.instance.markCustomerMessagesRead(uid),
            icon: const Icon(Icons.refresh, size: 20),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: uid == null
          ? const AppStateView.empty(
              icon: Icons.lock_outline,
              title: 'Sign in to message the store',
              message: 'Support conversations are tied to your account.',
            )
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<ChatMessage>>(
                    stream: ChatService.instance.watchMessages(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const AppStateView.loading(
                          message: 'Loading your conversation…',
                        );
                      }
                      if (snapshot.hasError) {
                        return const AppStateView.error(
                          title: 'Messages are unavailable',
                          message:
                              'Messaging becomes available once the store '
                              'publishes its chat rules. Please try again later.',
                        );
                      }
                      final messages =
                          snapshot.data ?? const <ChatMessage>[];
                      if (messages.length != _lastMessageCount) {
                        _lastMessageCount = messages.length;
                        final hasUnreadAdmin = messages.any(
                          (message) => message.fromAdmin && !message.isRead,
                        );
                        if (hasUnreadAdmin) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            ChatService.instance
                                .markCustomerMessagesRead(uid)
                                .then((_) {
                                  if (mounted) _scrollToEnd();
                                });
                          });
                        } else {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _scrollToEnd(),
                          );
                        }
                      }
                      if (messages.isEmpty) {
                        return const AppStateView.empty(
                          icon: Icons.forum_outlined,
                          title: 'Start a conversation',
                          message:
                              'Ask about sizing, delivery, an order or '
                              'anything else. The store replies here.',
                        );
                      }
                      return ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                        itemCount: messages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      AccentMark(),
                                      SizedBox(width: 7),
                                      Eyebrow('Direct line'),
                                      Spacer(),
                                      StatusDot(
                                        label: 'Store support',
                                        color: AppColors.success,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'MESSAGES',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.2,
                                      height: 0.98,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return _MessageBubble(message: messages[index - 1]);
                        },
                      );
                    },
                  ),
                ),
                if (_error != null)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFFBE9E7),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                _Composer(
                  controller: _message,
                  sending: _sending,
                  onSend: _send,
                ),
              ],
            ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.ink)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: AppConfig.maxChatMessageLength,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  enabled: !sending,
                  decoration: const InputDecoration(
                    hintText: 'Type a message…',
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: ElevatedButton(
                  onPressed: sending ? null : onSend,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, size: 19),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final fromAdmin = message.fromAdmin;
    return Align(
      alignment: fromAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: fromAdmin ? AppColors.surface : AppColors.ink,
          border: Border.all(
            color: fromAdmin ? AppColors.line : AppColors.ink,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fromAdmin)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'UNLEASHED SUPPORT',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: AppColors.muted,
                  ),
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: fromAdmin ? AppColors.ink : Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeAgo(message.createdAt),
              style: TextStyle(
                fontSize: 9,
                color: fromAdmin
                    ? AppColors.muted
                    : Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
