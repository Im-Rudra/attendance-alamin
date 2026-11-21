// A text field bound to one string setting. It saves by itself shortly after
// the teacher stops typing (and when focus leaves or the screen closes), so
// there is no Save button. A phone field only saves a valid number.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/widgets/digits_formatter.dart';
import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_repository.dart';

class SettingTextField extends ConsumerStatefulWidget {
  const SettingTextField({
    super.key,
    required this.settingKey,
    required this.label,
    this.helper,
    this.hint,
    this.isPhone = false,
    this.maxLength = 60,
  });

  final SettingKey<String> settingKey;
  final String label;
  final String? helper;
  final String? hint;

  /// Validates and normalises as a Bangladeshi mobile number.
  final bool isPhone;
  final int maxLength;

  @override
  ConsumerState<SettingTextField> createState() => _SettingTextFieldState();
}

class _SettingTextFieldState extends ConsumerState<SettingTextField> {
  final TextEditingController _controller = TextEditingController();
  late final SettingsRepository _repo = ref.read(settingsRepositoryProvider);
  Timer? _timer;
  Timer? _savedTimer;
  bool _saved = false;
  bool _touched = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repo.get<String>(widget.settingKey).then((String v) {
      if (!mounted || _touched) return;
      _controller.text = v;
    }, onError: (Object _) {});
  }

  /// The text to store, or null when the input is not valid.
  String? _valueToStore() {
    final String raw = _controller.text;
    if (!widget.isPhone) return raw.trim();
    try {
      return Validators.phone(raw) ?? '';
    } on AppException {
      return null;
    }
  }

  void _changed(String _) {
    _touched = true;
    final String? v = _valueToStore();
    if (_error != null || v == null) {
      Object? err;
      if (v == null) {
        try {
          Validators.phone(_controller.text);
        } on AppException catch (e) {
          err = e;
        }
      }
      setState(() => _error = err);
    }
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), _commit);
  }

  void _commit() {
    _timer?.cancel();
    if (!_touched) return;
    final String? v = _valueToStore();
    if (v == null) return;
    _repo.set<String>(widget.settingKey, v).then((_) {
      if (!mounted) return;
      setState(() => _saved = true);
      _savedTimer?.cancel();
      _savedTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _saved = false);
      });
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _commit();
    _savedTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Focus(
      onFocusChange: (bool focused) {
        if (!focused) _commit();
      },
      child: BhorTextField(
        controller: _controller,
        keyboardType: widget.isPhone ? TextInputType.phone : TextInputType.text,
        inputFormatters: widget.isPhone
            ? <TextInputFormatter>[DigitsFormatter(context.fmt, maxLength: 20, phone: true)]
            : null,
        textInputAction: TextInputAction.done,
        maxLength: widget.maxLength,
        label: widget.label,
        hint: widget.hint,
        helper: widget.helper,
        error: _error == null ? null : errorText(l10n, _error!),
        onChanged: _changed,
        onSubmitted: (_) => _commit(),
        suffix: AnimatedSwitcher(
          duration: BhorMotion.base,
          switchInCurve: BhorMotion.ease,
          child: _saved
              ? Row(
                  key: const ValueKey<String>('saved'),
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(BhorIcons.checkCircleFill, size: 16, color: context.bhor.colors.ok),
                    const SizedBox(width: 4),
                    Text(
                      l10n.setSavedTick,
                      style: context.bhor.type.meta.copyWith(color: context.bhor.colors.ok),
                    ),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey<String>('idle')),
        ),
      ),
    );
  }
}
