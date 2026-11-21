import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/omni_integration_contracts.dart';
import '../config/omni_theme.dart';
import '../providers/omni_driver_provider.dart';

/// Card flexível de configuração de Domínio / Servidor Backend (IP numérico ou domínio nominal)
/// Salva em SharedPreferences (Android / iOS) com 1:1 paridade ao BackendDomainConfigCard.tsx
class BackendDomainConfigCard extends StatefulWidget {
  final bool compact;
  final void Function(String domain, String ajaxUrl)? onSaved;

  const BackendDomainConfigCard({
    super.key,
    this.compact = false,
    this.onSaved,
  });

  @override
  State<BackendDomainConfigCard> createState() =>
      _BackendDomainConfigCardState();
}

class _BackendDomainConfigCardState extends State<BackendDomainConfigCard> {
  late final TextEditingController _controller;
  bool _testing = false;
  String? _feedbackText;
  String _feedbackType = 'success'; // 'success' | 'warning' | 'error'

  @override
  void initState() {
    super.initState();
    final provider = context.read<OmniDriverProvider>();
    _controller = TextEditingController(text: provider.backendDomain);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _previewEndpoint(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return OmniRouterConfig.baseUrl;
    if (!OmniRouterConfig.isValidBackendDomainInput(trimmed)) {
      return 'Formato de domínio/URL inválido';
    }
    return OmniRouterConfig.resolveAjaxEndpointFromDomain(trimmed);
  }

  Future<void> _handleSave(OmniDriverProvider p) async {
    try {
      final saved = await p.saveBackendDomain(_controller.text);
      final domain = saved['domain'] ?? OmniRouterConfig.defaultDomain;
      final ajaxUrl = saved['ajaxUrl'] ?? OmniRouterConfig.baseUrl;
      _controller.text = domain;
      if (!mounted) return;
      setState(() {
        _feedbackType = 'success';
        _feedbackText = 'Domínio salvo em cache! Endpoint ativo: $ajaxUrl';
      });
      widget.onSaved?.call(domain, ajaxUrl);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedbackType = 'error';
        _feedbackText = e.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  Future<void> _handleReset(OmniDriverProvider p) async {
    final reset = await p.resetBackendDomain();
    final domain = reset['domain'] ?? OmniRouterConfig.defaultDomain;
    _controller.text = domain;
    if (!mounted) return;
    setState(() {
      _feedbackType = 'warning';
      _feedbackText = 'Restaurado para o endereço padrão em cache: $domain';
    });
  }

  Future<void> _handleTest(OmniDriverProvider p) async {
    setState(() {
      _testing = true;
      _feedbackText = null;
    });
    try {
      if (_controller.text.trim() != p.backendDomain) {
        await p.saveBackendDomain(_controller.text);
      }
      final res = await p.testBackendDomain();
      if (!mounted) return;
      setState(() {
        _feedbackType = res['ok'] == true ? 'success' : 'warning';
        _feedbackText = (res['message'] ?? '').toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedbackType = 'error';
        _feedbackText = e.toString().replaceFirst('FormatException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final preview = _previewEndpoint(_controller.text);

    Color fbColor = OmniTheme.neonEmerald;
    if (_feedbackType == 'warning') fbColor = OmniTheme.amber400;
    if (_feedbackType == 'error') fbColor = OmniTheme.neonRose;

    return Container(
      padding: EdgeInsets.all(widget.compact ? 14 : 16),
      decoration: OmniTheme.neonCardDecoration(active: p.hasCustomBackendDomain),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: OmniTheme.alpha(OmniTheme.neonCyan, 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: OmniTheme.alpha(OmniTheme.neonCyan, 0.35)),
                ),
                child: const Icon(Icons.public_rounded,
                    color: OmniTheme.neonCyan, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Domínio / Servidor Backend (AJAX)',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Aceita IP numérico (http://192.168...) ou domínio nominal (https://meusite...).',
                      style: TextStyle(fontSize: 10.5, color: OmniTheme.slate400),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              OmniPillBadge(
                text: p.hasCustomBackendDomain ? 'CACHE ✓' : 'PADRÃO',
                color: p.hasCustomBackendDomain
                    ? OmniTheme.neonCyan
                    : OmniTheme.slate400,
              ),
            ],
          ),
          const SizedBox(height: 12),

          const Text(
            'URL ou Domínio do Servidor WordPress / Backend OMNI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: OmniTheme.slate300,
            ),
          ),
          const SizedBox(height: 6),

          TextField(
            controller: _controller,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            style: OmniTheme.monoStyle(fontSize: 12.5, color: Colors.white),
            decoration: InputDecoration(
              hintText:
                  'Ex: http://192.168.12.9/servshop ou https://meusite.com.br',
              hintStyle:
                  OmniTheme.monoStyle(fontSize: 11, color: OmniTheme.slate500),
              filled: true,
              fillColor: OmniTheme.slate950,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: OmniTheme.slate700),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: OmniTheme.neonCyan),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Preview do endpoint AJAX resolvido
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: OmniTheme.slate950,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OmniTheme.slate800),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Endpoint AJAX resolvido (Cache: ${p.backendDomain}):',
                  style:
                      const TextStyle(fontSize: 10, color: OmniTheme.slate400),
                ),
                const SizedBox(height: 3),
                Text(
                  preview,
                  style: OmniTheme.monoStyle(
                      fontSize: 11, color: OmniTheme.neonCyan),
                ),
              ],
            ),
          ),

          if (_feedbackText != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: OmniTheme.alpha(fbColor, 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: OmniTheme.alpha(fbColor, 0.45)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _feedbackType == 'success'
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    size: 16,
                    color: fbColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _feedbackText!,
                      style: TextStyle(fontSize: 11, color: fbColor),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _handleSave(p),
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Salvar em Cache'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OmniTheme.neonCyan,
                  foregroundColor: const Color(0xFF05080F),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _testing ? null : () => _handleTest(p),
                icon: _testing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: OmniTheme.neonCyan),
                      )
                    : const Icon(Icons.wifi_tethering_rounded,
                        size: 16, color: OmniTheme.neonCyan),
                label: Text(
                  _testing ? 'Testando...' : 'Testar Conexão',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: OmniTheme.slate700),
                ),
              ),
              TextButton.icon(
                onPressed: () => _handleReset(p),
                icon: const Icon(Icons.restart_alt_rounded,
                    size: 16, color: OmniTheme.slate400),
                label: const Text(
                  'Restaurar Padrão',
                  style: TextStyle(fontSize: 11, color: OmniTheme.slate400),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Abre o modal rápido de configuração de Domínio / Servidor Backend em qualquer tela
Future<void> showBackendDomainDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: OmniTheme.bgDark,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: OmniTheme.alpha(OmniTheme.neonCyan, 0.45)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.public_rounded,
                    color: OmniTheme.neonCyan, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Configurar Domínio / Servidor Backend',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded,
                      color: OmniTheme.slate400, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const BackendDomainConfigCard(compact: true),
          ],
        ),
      ),
    ),
  );
}
