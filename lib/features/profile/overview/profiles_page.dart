import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/profile/notifier/profiles_update_notifier.dart';
import 'package:hiddify/features/profile/overview/profiles_notifier.dart';
import 'package:hiddify/features/profile/widget/profile_tile.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProfilesPage extends HookConsumerWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final asyncProfiles = ref.watch(profilesNotifierProvider);

    return Scaffold(
      body: asyncProfiles.when(
        data: (data) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 112),
            children: [
              _ProfilesHeader(
                onUpdate: () => ref
                    .read(foregroundProfilesUpdateNotifierProvider.notifier)
                    .trigger(),
                onSort: () => ref
                    .read(dialogNotifierProvider.notifier)
                    .showSortProfiles(),
              ),
              const Gap(24),
              Text(
                '导入远程配置文件',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap(14),
              _ImportSubscriptionRow(
                onTap: () async => await ref
                    .read(bottomSheetsNotifierProvider.notifier)
                    .showAddProfile(),
              ),
              const Gap(28),
              Text(
                '当前生效的主动配置',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap(12),
              if (data.isEmpty)
                Text(
                  '暂无订阅配置',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                for (final profile in data) ProfileTile(profile: profile),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(t.presentShortError(error)),
      ),
    );
  }
}

class _ProfilesHeader extends StatelessWidget {
  const _ProfilesHeader({required this.onUpdate, required this.onSort});

  final VoidCallback onUpdate;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            '配置订阅',
            style: theme.textTheme.displaySmall?.copyWith(
              fontFamily: 'serif',
              fontWeight: FontWeight.w300,
              letterSpacing: 2,
            ),
          ),
        ),
        IconButton(
          onPressed: onUpdate,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: '更新订阅',
        ),
        IconButton(
          onPressed: onSort,
          icon: const Icon(Icons.sort_rounded),
          tooltip: '排序',
        ),
      ],
    );
  }
}

class _ImportSubscriptionRow extends StatelessWidget {
  const _ImportSubscriptionRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.onSurface),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '请在此处粘贴订阅 URL 链接...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      ),
    );
  }
}
