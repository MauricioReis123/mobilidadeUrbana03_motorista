import 'package:flutter/material.dart';
import '../config/omni_theme.dart';

class ComboboxOption {
  final String value;
  final String label;
  final String? hint;

  const ComboboxOption({
    required this.value,
    required this.label,
    this.hint,
  });
}

/// Combobox Autocompletar para Marca & Modelo FIPE/OMNI — seguro contra overflow em Android
class VehicleAutocompleteField extends StatefulWidget {
  final String label;
  final String value;
  final String placeholder;
  final List<ComboboxOption> options;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final ValueChanged<ComboboxOption> onSelectOption;

  const VehicleAutocompleteField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.options,
    this.isLoading = false,
    required this.onChanged,
    required this.onSelectOption,
  });

  @override
  State<VehicleAutocompleteField> createState() =>
      _VehicleAutocompleteFieldState();
}

class _VehicleAutocompleteFieldState extends State<VehicleAutocompleteField> {
  late TextEditingController _controller;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant VehicleAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _norm(String s) => s.toLowerCase().trim();

  List<ComboboxOption> get _filtered {
    final q = _norm(widget.value);
    if (q.isEmpty) return widget.options.take(20).toList();
    final starts = <ComboboxOption>[];
    final contains = <ComboboxOption>[];
    for (final opt in widget.options) {
      final nl = _norm(opt.label);
      if (nl.startsWith(q)) {
        starts.add(opt);
      } else if (nl.contains(q)) {
        contains.add(opt);
      }
      if (starts.length + contains.length >= 20) break;
    }
    return [...starts, ...contains].take(20).toList();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _filtered;
    final quickHint = widget.value.trim().isNotEmpty &&
            matches.isNotEmpty &&
            _norm(matches.first.label) != _norm(widget.value)
        ? matches.first
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: OmniTheme.slate400,
                ),
              ),
            ),
            if (widget.isLoading)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: OmniTheme.neonCyan,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'FIPE',
                    style: TextStyle(
                      fontSize: 10,
                      color: OmniTheme.neonCyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 5),
        TextField(
          controller: _controller,
          style: const TextStyle(fontSize: 12, color: OmniTheme.textPrimary),
          onTap: () => setState(() => _isOpen = true),
          onChanged: (val) {
            widget.onChanged(val);
            if (!_isOpen) setState(() => _isOpen = true);
          },
          decoration: InputDecoration(
            hintText: widget.placeholder,
            suffixIcon: IconButton(
              icon: Icon(
                _isOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: _isOpen ? OmniTheme.neonCyan : OmniTheme.slate400,
              ),
              onPressed: () => setState(() => _isOpen = !_isOpen),
            ),
          ),
        ),
        if (_isOpen && quickHint != null) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: () {
              widget.onSelectOption(quickHint);
              setState(() => _isOpen = false);
            },
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    size: 12, color: OmniTheme.neonCyan),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Completar com: ${quickHint.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: OmniTheme.neonCyan,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_isOpen)
          Container(
            margin: const EdgeInsets.only(top: 5),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: OmniTheme.slate950,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: OmniTheme.alpha(OmniTheme.neonCyan, 0.4)),
              boxShadow: [
                BoxShadow(
                  color: OmniTheme.alpha(Colors.black, 0.65),
                  blurRadius: 16,
                ),
              ],
            ),
            child: matches.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text(
                      'Nenhuma correspondência na lista — você pode usar o texto digitado livremente.',
                      style: TextStyle(fontSize: 11, color: OmniTheme.slate400),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: matches.length,
                    itemBuilder: (context, idx) {
                      final opt = matches[idx];
                      return InkWell(
                        onTap: () {
                          widget.onSelectOption(opt);
                          setState(() => _isOpen = false);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  opt.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: OmniTheme.slate200,
                                  ),
                                ),
                              ),
                              if (opt.hint != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  opt.hint!,
                                  style: OmniTheme.monoStyle(
                                    fontSize: 10,
                                    color: OmniTheme.slate400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}
