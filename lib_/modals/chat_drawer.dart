import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../providers/omni_driver_provider.dart';

/// Gaveta de Chat Seguro Mascarado Motorista <-> Passageiro — 1:1 com ChatDrawer.tsx
class ChatDrawerModal extends StatefulWidget {
  const ChatDrawerModal({super.key});

  @override
  State<ChatDrawerModal> createState() => _ChatDrawerModalState();
}

class _ChatDrawerModalState extends State<ChatDrawerModal> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _lastMsgCount = 0;

  static const List<String> _quickReplies = [
    'Já estou a caminho!',
    'Cheguei no ponto de embarque.',
    'Estou aguardando com o pisca-alerta ligado.',
    'Tudo certo com o trajeto!',
  ];

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _send(OmniDriverProvider p, String text) {
    if (text.trim().isEmpty) return;
    p.sendChatMessage(text);
    _msgController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    if (!p.chatOpen) {
      _lastMsgCount = 0;
      return const SizedBox.shrink();
    }

    if (p.chatMessages.length != _lastMsgCount) {
      _lastMsgCount = p.chatMessages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
        if (p.unreadChatCount > 0) {
          p.markChatMessagesRead();
        }
      });
    }

    return Material(
      color: OmniTheme.alpha(Colors.black, 0.78),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          decoration: BoxDecoration(
            color: OmniTheme.slate950,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
                color: OmniTheme.alpha(OmniTheme.neonCyan, 0.4)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_rounded,
                          size: 16, color: OmniTheme.neonCyan),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Chat Protegido • ${p.activeTrip?.passenger.name ?? "Passageiro"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => p.setChatOpen(false),
                        icon: const Icon(Icons.close_rounded,
                            color: OmniTheme.slate400),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: OmniTheme.slate800),

                // Lista de mensagens
                Expanded(
                  child: p.chatMessages.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Nenhuma mensagem ainda.\nEnvie um aviso em tempo real ao passageiro.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: OmniTheme.slate400,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(14),
                          itemCount: p.chatMessages.length,
                          itemBuilder: (context, idx) {
                            final m = p.chatMessages[idx];
                            final normalizedRole = m.sender.toUpperCase();
                            final isDriver = normalizedRole == 'DRIVER';
                            final isSystem = normalizedRole == 'SYSTEM';
                            if (isSystem) {
                              return Center(
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: OmniTheme.slate900,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    m.text,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: OmniTheme.slate400,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return Align(
                              alignment: isDriver
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 9),
                                constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.72),
                                decoration: BoxDecoration(
                                  color: isDriver
                                      ? OmniTheme.alpha(OmniTheme.neonCyan, 0.18)
                                      : OmniTheme.slate800,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDriver
                                        ? OmniTheme.alpha(
                                            OmniTheme.neonCyan, 0.45)
                                        : OmniTheme.slate700,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isDriver
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.text,
                                      style: const TextStyle(
                                          fontSize: 12.5, color: Colors.white),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      m.timestamp,
                                      style: const TextStyle(
                                          fontSize: 9.5,
                                          color: OmniTheme.slate400),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Respostas Rápidas (horizontal scroll)
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickReplies.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, idx) {
                      final reply = _quickReplies[idx];
                      return ActionChip(
                        backgroundColor: OmniTheme.slate900,
                        side: const BorderSide(color: OmniTheme.slate700),
                        label: Text(
                          reply,
                          style: const TextStyle(
                              fontSize: 11, color: OmniTheme.neonCyan),
                        ),
                        onPressed: () => _send(p, reply),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Campo de digitação fixo no rodapé
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    4,
                    12,
                    12 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Enviar mensagem protegida...',
                          ),
                          onSubmitted: (val) => _send(p, val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _send(p, _msgController.text),
                        style: IconButton.styleFrom(
                          backgroundColor: OmniTheme.neonCyan,
                          foregroundColor: const Color(0xFF05080F),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
