import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:family_map/models/mock_state.dart';
import 'package:family_map/services/location_service.dart';
import 'package:family_map/services/invite_service.dart';
import 'package:family_map/theme.dart';
import 'package:family_map/widgets/glass_panel.dart';

class FamilyCockpitPage extends StatelessWidget {
  const FamilyCockpitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CockpitViewModel(),
      child: const _FamilyCockpitView(),
    );
  }
}

class _FamilyCockpitView extends StatelessWidget {
  const _FamilyCockpitView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CockpitViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Fallback background color if not dark
    final bgColor = isDark ? DarkModeColors.darkSurface : LightModeColors.lightSurface;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background subtle shapes to make the glass effect pop
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppGradients.diamondGradient.colors.first.withValues(alpha: 0.2),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppGradients.emeraldGradient.colors.first.withValues(alpha: 0.15),
              ),
            ),
          ),
          
          // Main Scroll View
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Column(
                spacing: 20.0,
                children: [
                  _buildHeaderPanel(context, viewModel),
                  _buildMapPanel(context, viewModel),
                  _buildChatPanel(context, viewModel),
                  _buildSubscriptionPanel(context, viewModel),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPanel(BuildContext context, CockpitViewModel viewModel) {
    return GlassPanel(
      gradient: AppGradients.diamondGradient,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Family Cockpit',
                  style: context.textStyles.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  viewModel.statusLine,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _InviteButton(viewModel: viewModel),
          const SizedBox(width: 10),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.emeraldGradient,
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withValues(alpha: 0.6),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.explore,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPanel(BuildContext context, CockpitViewModel viewModel) {
    final pos = viewModel.myPosition;
    return GlassPanel(
      gradient: AppGradients.diamondGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Map',
                style: context.textStyles.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  _LocationStatusPill(viewModel: viewModel),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.open_in_full, size: 14, color: Colors.white),
                    label: Text(
                      'Expand',
                      style: context.textStyles.labelSmall?.copyWith(color: Colors.white),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          if (pos != null) ...[
            _CoordinateReadout(position: pos),
            const SizedBox(height: 12),
          ] else if (viewModel.permissionState != LocationPermissionState.granted) ...[
            _EnableLocationRow(viewModel: viewModel),
            const SizedBox(height: 12),
          ],
          // Map representation
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Stack(
              children: [
                // Abstract grid lines
                CustomPaint(
                  size: const Size(double.infinity, 220),
                  painter: GridPainter(),
                ),
                // Locations
                ...viewModel.locations.map((loc) {
                  return AnimatedAlign(
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.easeOutCubic,
                    alignment: FractionalOffset(loc.left, loc.top),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: loc.label == 'You' ? 16 : 14,
                          height: loc.label == 'You' ? 16 : 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: loc.color,
                            boxShadow: [
                              BoxShadow(
                                color: loc.color.withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loc.label,
                          style: context.textStyles.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel(BuildContext context, CockpitViewModel viewModel) {
    return GlassPanel(
      gradient: AppGradients.emeraldGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Family Chat',
                style: context.textStyles.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.white),
                label: Text(
                  'Open',
                  style: context.textStyles.labelSmall?.copyWith(color: Colors.white),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (viewModel.recentMessages.isEmpty)
            Text(
              'No recent messages.',
              style: context.textStyles.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            )
          else
            Column(
              spacing: 12,
              children: viewModel.recentMessages.map((msg) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.text,
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${msg.createdAt.hour}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                            style: context.textStyles.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          if (!viewModel.isPremium) ...[
            const SizedBox(height: 12),
            Text(
              'Upgrade to unlock full chat and rich history.',
              style: context.textStyles.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionPanel(BuildContext context, CockpitViewModel viewModel) {
    return GlassPanel(
      gradient: AppGradients.goldenIceGradient,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewModel.isPremium ? 'Premium Active' : 'Go Premium',
                  style: context.textStyles.titleMedium?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  viewModel.isPremium
                      ? 'Enjoy enhanced visuals and live-second tracking.'
                      : 'Unlock live-second tracking, family chat & lavish UI.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: Colors.black87.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () {
              viewModel.togglePremium();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.4),
              foregroundColor: Colors.black87,
              elevation: 0,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              viewModel.isPremium ? 'Manage' : 'Upgrade',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteButton extends StatefulWidget {
  final CockpitViewModel viewModel;
  const _InviteButton({required this.viewModel});

  @override
  State<_InviteButton> createState() => _InviteButtonState();
}

class _InviteButtonState extends State<_InviteButton> {
  bool _loading = false;

  Future<void> _openInviteSheet() async {
    final familyId = widget.viewModel.familyId;
    if (familyId == null || familyId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Family not ready yet.')));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InviteSheet(familyId: familyId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _loading ? null : _openInviteSheet,
      icon: _loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.group_add, size: 16, color: Colors.white),
      label: Text('Invite', style: context.textStyles.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: const StadiumBorder(),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _InviteSheet extends StatefulWidget {
  final String familyId;
  const _InviteSheet({required this.familyId});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  bool _creating = false;
  String? _code;
  final _emailController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _createCode() async {
    setState(() => _creating = true);
    try {
      final invite = await InviteService.createCodeInvite(familyId: widget.familyId, maxUses: 5);
      setState(() => _code = invite.code);
      await Clipboard.setData(ClipboardData(text: invite.code));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create invite.')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _sendEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _sending = true);
    try {
      final link = await InviteService.sendEmailInvite(familyId: widget.familyId, email: email);
      await Clipboard.setData(ClipboardData(text: link.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite link copied (email may be sent).')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send email invite.')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(left: 12, right: 12, bottom: bottomInset + 12),
      child: GlassPanel(
        gradient: AppGradients.emeraldGradient,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Invite to your family', style: context.textStyles.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Invite code', style: context.textStyles.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black.withValues(alpha: 0.18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Text(
                      _code ?? 'Generate a code to share with family',
                      style: context.textStyles.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _creating ? null : _createCode,
                  style: FilledButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.22), foregroundColor: Colors.white),
                  child: _creating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Generate'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Email invite (optional)', style: context.textStyles.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'name@example.com',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.14),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _sending ? null : _sendEmail,
                  style: FilledButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.22), foregroundColor: Colors.white),
                  child: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tip: recipients can also open /join?code=YOURCODE in the app/web.',
              style: context.textStyles.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.75)),
            ),
          ],
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    const spacing = 20.0;
    
    // Draw vertical lines
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    
    // Draw horizontal lines
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CoordinateReadout extends StatelessWidget {
  final dynamic position;

  const _CoordinateReadout({required this.position});

  @override
  Widget build(BuildContext context) {
    // Using `dynamic` avoids importing geolocator into the page file.
    final lat = (position.latitude as double).toStringAsFixed(5);
    final lon = (position.longitude as double).toStringAsFixed(5);
    final acc = (position.accuracy as double).toStringAsFixed(0);

    return Row(
      children: [
        const Icon(Icons.my_location, size: 16, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Lat $lat  •  Lon $lon  •  ±${acc}m',
            style: context.textStyles.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _EnableLocationRow extends StatelessWidget {
  final CockpitViewModel viewModel;

  const _EnableLocationRow({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final message = switch (viewModel.permissionState) {
      LocationPermissionState.serviceDisabled => 'Location services are off.',
      LocationPermissionState.deniedForever => 'Location permission permanently denied.',
      LocationPermissionState.error => 'Location unavailable right now.',
      _ => 'Location permission needed.',
    };

    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: context.textStyles.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: viewModel.requestLocation,
          icon: const Icon(Icons.near_me, size: 16, color: Colors.white),
          label: Text('Enable', style: context.textStyles.labelMedium?.copyWith(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            elevation: 0,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }
}

class _LocationStatusPill extends StatelessWidget {
  final CockpitViewModel viewModel;

  const _LocationStatusPill({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final isLive = viewModel.permissionState == LocationPermissionState.granted && viewModel.myPosition != null;
    final bg = isLive ? Colors.greenAccent.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.12);
    final icon = isLive ? Icons.wifi_tethering : Icons.location_disabled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            isLive ? 'LIVE' : 'OFF',
            style: context.textStyles.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
