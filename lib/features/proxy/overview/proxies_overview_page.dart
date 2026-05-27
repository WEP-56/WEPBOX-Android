import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/proxy/widget/proxy_tile.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProxiesOverviewPage extends HookConsumerWidget with PresLogger {
  const ProxiesOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    final proxies = ref.watch(proxiesOverviewNotifierProvider);
    final sortBy = ref.watch(proxiesSortNotifierProvider);

    // final selectActiveProxyMutation = useMutation(
    //   initialOnFailure: (error) => CustomToast.error(t.presentShortError(error)).show(context),
    // );

    return Scaffold(
      body: proxies.when(
        data: (group) => group != null
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = PlatformUtils.isMobile && width < 600
                      ? 1
                      : max(1, (width / 268).floor());
                  return CustomScrollView(
                    slivers: [
                      SliverSafeArea(
                        bottom: false,
                        sliver: SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
                          sliver: SliverToBoxAdapter(
                            child: _ProxyHeader(
                              sortBy: sortBy,
                              sortOptions: ProxiesSort.values,
                              onSort: ref
                                  .read(proxiesSortNotifierProvider.notifier)
                                  .update,
                              onTestDelay: () async => await ref
                                  .read(
                                    proxiesOverviewNotifierProvider.notifier,
                                  )
                                  .urlTest("select"),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 112),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisExtent: 82,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final proxy = group.items[index];
                            return ProxyTile(
                              proxy,
                              selected: group.selected == proxy.tag,
                              onTap: () async {
                                await ref
                                    .read(
                                      proxiesOverviewNotifierProvider.notifier,
                                    )
                                    .changeProxy(group.tag, proxy.tag);
                              },
                            );
                          }, childCount: group.items.length),
                        ),
                      ),
                    ],
                  );
                },
              )
            : Center(child: Text(t.pages.proxies.empty)),
        error: (error, stackTrace) =>
            Center(child: Text(t.presentShortError(error))),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ProxyHeader extends StatelessWidget {
  const _ProxyHeader({
    required this.sortBy,
    required this.sortOptions,
    required this.onSort,
    required this.onTestDelay,
  });

  final ProxiesSort sortBy;
  final List<ProxiesSort> sortOptions;
  final ValueChanged<ProxiesSort> onSort;
  final VoidCallback onTestDelay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '节点节点',
          style: theme.textTheme.displaySmall?.copyWith(
            fontFamily: 'serif',
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            Text(
              '请选择接入基站',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onTestDelay,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(64, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('延迟整备'),
            ),
            PopupMenuButton<ProxiesSort>(
              initialValue: sortBy,
              onSelected: onSort,
              icon: const Icon(FluentIcons.arrow_sort_24_regular, size: 18),
              itemBuilder: (context) => [
                for (final option in sortOptions)
                  PopupMenuItem(value: option, child: Text(option.name)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
