import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:hiddify/features/settings/notifier/reset_tunnel/reset_tunnel_notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 112),
          children: [
            Text(
              '全局设置',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontFamily: 'serif',
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            _SectionLabel('分流路由系统'),
            SettingsSection(
              title: '路由模式选择',
              subtitle: '绕过中国大陆地区 (Geosite 规则驱动)',
              icon: Icons.route_rounded,
              checked: false,
              namedLocation: context.namedLocation('general'),
            ),
            SettingsSection(
              title: 'TUN 虚拟网卡模式',
              subtitle: '接管整机网络流量，实现无缝透明代理',
              icon: Icons.check_circle_rounded,
              checked: true,
              namedLocation: context.namedLocation('routeOptions'),
            ),
            const SizedBox(height: 26),
            _SectionLabel('高级策略'),
            SettingsSection(
              title: '安全 DNS 规则',
              subtitle: 'Sing-box 智能防污染 DNS (QUIC 优先)',
              icon: Icons.dns_rounded,
              checked: false,
              namedLocation: context.namedLocation('dnsOptions'),
            ),
            SettingsSection(
              title: t.pages.settings.inbound.title,
              subtitle: '代理入口与本地端口',
              icon: Icons.input_rounded,
              checked: false,
              namedLocation: context.namedLocation('inboundOptions'),
            ),
            SettingsSection(
              title: t.pages.settings.tlsTricks.title,
              subtitle: 'TLS 分片与握手细节',
              icon: Icons.content_cut_rounded,
              checked: false,
              namedLocation: context.namedLocation('tlsTricks'),
            ),
            SettingsSection(
              title: t.pages.settings.warp.title,
              subtitle: 'Cloudflare WARP 出站策略',
              icon: Icons.cloud_rounded,
              checked: false,
              namedLocation: context.namedLocation('warpOptions'),
            ),
            if (PlatformUtils.isIOS)
              Material(
                child: ListTile(
                  title: Text(t.pages.settings.resetTunnel),
                  leading: const Icon(Icons.autorenew_rounded),
                  onTap: () async {
                    await ref.read(resetTunnelNotifierProvider.notifier).run();
                  },
                ),
              ),
            if (Breakpoint(context).isMobile()) ...[
              SettingsSection(
                title: t.pages.logs.title,
                subtitle: '查看运行日志',
                icon: Icons.description_rounded,
                checked: false,
                namedLocation: context.namedLocation('logs'),
              ),
              SettingsSection(
                title: t.pages.about.title,
                subtitle: '版本、许可与开源信息',
                icon: Icons.info_rounded,
                checked: false,
                namedLocation: context.namedLocation('about'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsSection extends HookConsumerWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.namedLocation,
    this.subtitle,
    this.checked = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String namedLocation;
  final bool checked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.go(namedLocation),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (checked)
              Icon(icon, color: theme.colorScheme.primary)
            else
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
