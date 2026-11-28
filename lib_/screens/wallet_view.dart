import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../providers/omni_driver_provider.dart';

/// Carteira Financeira OMNI Pay & Saque Pix Instantâneo — 1:1 com WalletView.tsx
class WalletView extends StatelessWidget {
  const WalletView({super.key});

  void _openPixDialog(BuildContext context, OmniDriverProvider p) {
    final amountCtrl = TextEditingController(
      text: p.driver.walletBalance.toStringAsFixed(2),
    );
    final keyCtrl = TextEditingController(
      text: p.driver.bankPayout?.pixKey ?? p.driver.cpf,
    );
    String keyType = p.driver.bankPayout?.pixKeyType ?? 'CPF';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: OmniTheme.slate950,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: OmniTheme.alpha(OmniTheme.neonCyan, 0.45)),
          ),
          title: const Text(
            'Saque Pix Imediato',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo disponível: R\$ ${p.driver.walletBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: OmniTheme.neonEmerald,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: keyType,
                  dropdownColor: OmniTheme.slate900,
                  decoration: const InputDecoration(labelText: 'Tipo de Chave Pix'),
                  items: const [
                    DropdownMenuItem(value: 'CPF', child: Text('CPF')),
                    DropdownMenuItem(value: 'EMAIL', child: Text('E-mail')),
                    DropdownMenuItem(value: 'PHONE', child: Text('Celular')),
                    DropdownMenuItem(value: 'RANDOM', child: Text('Chave Aleatória')),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => keyType = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: keyCtrl,
                  decoration: const InputDecoration(labelText: 'Chave Pix'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: OmniTheme.monoStyle(
                      fontSize: 18, color: OmniTheme.neonCyan),
                  decoration:
                      const InputDecoration(labelText: 'Valor do Saque (R\$)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar',
                  style: TextStyle(color: OmniTheme.slate400)),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(
                        amountCtrl.text.replaceAll(',', '.')) ??
                    0.0;
                final ok = await p.requestPixWithdrawal(
                  amount: amount,
                  pixKey: keyCtrl.text.trim(),
                  keyType: keyType,
                );
                if (ok && ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Transferir Agora'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final driver = p.driver;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Card Principal Saldo OMNI Pay
        Container(
          padding: const EdgeInsets.all(18),
          decoration: OmniTheme.neonCardDecoration(active: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  OmniPillBadge(
                    text: 'OMNI PAY • LIQUIDAÇÃO PIX 24H',
                    color: OmniTheme.neonCyan,
                    icon: Icons.qr_code_2_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Saldo Disponível para Saque',
                style: TextStyle(fontSize: 12, color: OmniTheme.slate400),
              ),
              const SizedBox(height: 4),
              Text(
                'R\$ ${driver.walletBalance.toStringAsFixed(2)}',
                style: OmniTheme.monoStyle(
                  fontSize: 30,
                  color: OmniTheme.neonEmerald,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openPixDialog(context, p),
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('SAQUE PIX IMEDIATO'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3 Métricas Diárias
        Row(
          children: [
            Expanded(
              child: _MetricBox(
                label: 'Ganhos Hoje',
                value: 'R\$ ${driver.todayEarnings.toStringAsFixed(2)}',
                color: OmniTheme.neonEmerald,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricBox(
                label: 'Corridas',
                value: '${driver.todayTripsCount}',
                color: OmniTheme.neonCyan,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricBox(
                label: 'Tempo Online',
                value: '${driver.onlineHoursToday.toStringAsFixed(1)}h',
                color: OmniTheme.amber400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        const Text(
          'Extrato Financeiro Recente',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),

        // Histórico real
        if (p.transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: OmniTheme.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OmniTheme.slate800),
            ),
            child: const Text(
              'Nenhuma movimentação financeira registrada até o momento. Seus ganhos de corridas e saques Pix aparecerão aqui em tempo real.',
              style: TextStyle(fontSize: 12, color: OmniTheme.slate400),
            ),
          )
        else
          ...p.transactions.map((tx) {
            final isPositive = tx.amount >= 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: OmniTheme.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: OmniTheme.slate800),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: OmniTheme.alpha(
                        isPositive ? OmniTheme.neonEmerald : OmniTheme.rose500,
                        0.14,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPositive
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 16,
                      color:
                          isPositive ? OmniTheme.neonEmerald : OmniTheme.rose500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          tx.timestamp,
                          style: const TextStyle(
                              fontSize: 10.5, color: OmniTheme.slate400),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${isPositive ? '+' : ''}R\$ ${tx.amount.toStringAsFixed(2)}',
                    style: OmniTheme.monoStyle(
                      fontSize: 13,
                      color:
                          isPositive ? OmniTheme.neonEmerald : OmniTheme.rose500,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OmniTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OmniTheme.slate800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: OmniTheme.slate400),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniTheme.monoStyle(
              fontSize: 13.5,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
