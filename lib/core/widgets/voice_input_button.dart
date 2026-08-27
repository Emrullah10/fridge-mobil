import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Bir TextEditingController'a sesle metin yazan mikrofon butonu. Dinlerken
/// tanınan metni canlı olarak controller'a yazar; durunca son hali kalır.
///
/// İzin/kullanılamama durumları nazikçe ele alınır — buton pasifleşir,
/// çökme olmaz (sesli giriş bir kolaylık, zorunlu değil).
class VoiceInputButton extends StatefulWidget {
  const VoiceInputButton({
    super.key,
    required this.controller,
    this.localeId = 'tr_TR',
    this.onFinished,
  });

  final TextEditingController controller;
  final String localeId;
  final VoidCallback? onFinished;

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  final _speech = SpeechToText();
  bool _available = false;
  bool _listening = false;
  bool _initTried = false;

  Future<void> _ensureInit() async {
    if (_initTried) return;
    _initTried = true;
    try {
      _available = await _speech.initialize(
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            if (mounted) setState(() => _listening = false);
            widget.onFinished?.call();
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
    } catch (_) {
      _available = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    await _ensureInit();
    if (!_available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesli giriş bu cihazda kullanılamıyor')),
        );
      }
      return;
    }

    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }

    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        localeId: widget.localeId,
      ),
      onResult: (r) {
        widget.controller.text = r.recognizedWords;
        widget.controller.selection = TextSelection.collapsed(offset: widget.controller.text.length);
      },
    );
  }

  @override
  void dispose() {
    if (_listening) _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: _listening ? 'Dinlemeyi durdur' : 'Sesle söyle',
      onPressed: _toggle,
      icon: Icon(
        _listening ? Icons.stop_circle_rounded : Icons.mic_rounded,
        color: _listening ? cs.error : null,
      ),
    );
  }
}
