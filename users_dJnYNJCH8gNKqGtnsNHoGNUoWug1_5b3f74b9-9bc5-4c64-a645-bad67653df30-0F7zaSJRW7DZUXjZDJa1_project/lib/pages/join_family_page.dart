import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:family_map/services/invite_service.dart';
import 'package:family_map/theme.dart';

class JoinFamilyPage extends StatefulWidget {
  final String? prefillCode;
  const JoinFamilyPage({super.key, this.prefillCode});

  @override
  State<JoinFamilyPage> createState() => _JoinFamilyPageState();
}

class _JoinFamilyPageState extends State<JoinFamilyPage> {
  late final TextEditingController _codeController;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.prefillCode ?? '');
    if ((widget.prefillCode ?? '').trim().isNotEmpty) {
      // Auto-attempt if we got here from a deep link.
      WidgetsBinding.instance.addPostFrameCallback((_) => _join());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await InviteService.acceptInviteCode(code: code);
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not join. Check the code and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? DarkModeColors.darkSurface : LightModeColors.lightSurface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Join a Family'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Enter an invite code', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Example: 7K2M9QXWAB',
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _join(),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _loading ? null : _join,
                    child: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Join'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
