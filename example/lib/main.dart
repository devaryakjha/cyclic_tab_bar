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

  static const _tabs = [
    Tab(text: 'Overview'),
    Tab(text: 'Metrics'),
    Tab(text: 'Alerts'),
    Tab(text: 'Profile'),
  ];
  static const _titles = [
    'Overview',
    'Metrics',
    'Alerts',
    'Profile',
  ];
  static const _messages = [
    'Baseline source copy of Flutter tabs.',
    'Interaction currently matches Flutter exactly.',
    'Infinite behavior is intentionally deferred.',
    'This package will diverge after the baseline is locked.',
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
                  "This example uses the package copy of Flutter's TabBar and TabBarView. Infinite behavior is not added yet.",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                const CyclicTabBar(tabs: _tabs, isScrollable: true, tabAlignment: TabAlignment.start),
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
