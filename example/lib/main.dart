import 'package:cyclic_tab_bar/cyclic_tab_bar.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cyclic Tab Bar Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0C7D69)),
        useMaterial3: true,
      ),
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatelessWidget {
  const ExampleHomePage({super.key});

  static const _titles = [
    'Overview',
    'Metrics',
    'Alerts',
    'Profile',
    'Billing',
    'Traffic',
    'Playback',
    'Settings',
  ];
  static const _tabs = [
    Tab(text: 'Overview'),
    Tab(text: 'Metrics'),
    Tab(text: 'Alerts'),
    Tab(text: 'Profile'),
    Tab(text: 'Billing'),
    Tab(text: 'Traffic'),
    Tab(text: 'Playback'),
    Tab(text: 'Settings'),
  ];
  static const _messages = [
    'Baseline source copy of Flutter tabs.',
    'Interaction currently matches Flutter exactly.',
    'Infinite behavior is intentionally deferred.',
    'This package will diverge after the baseline is locked.',
    'Use this longer strip to feel the edge extension more clearly.',
    'A real scroll distance makes the cyclic reveal easier to judge.',
    'Trackpad and wheel overscroll should now participate too.',
    'Once the duplicated edge is out of view, the strip should normalize.',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('cyclic_tab_bar example')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DefaultTabController(
            length: _tabs.length,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vendored Flutter tabs first.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  "This example uses a longer scrollable strip so edge extension is easier to test. Pull past either end and look for the next cycle to peek in and attach.",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                const CyclicTabBar(
                  tabs: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorFixedWidth: 64,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: CyclicTabBarView(
                    children: List<Widget>.generate(_tabs.length, (index) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primaryContainer,
                              colorScheme.secondaryContainer,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _titles[index],
                                style: Theme.of(context).textTheme.displaySmall,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _messages[index],
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              Text(
                                'Tab ${index + 1} of ${_tabs.length}',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
