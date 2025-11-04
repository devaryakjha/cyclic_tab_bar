import 'package:flutter/material.dart';
import 'package:cyclic_tab_bar/cyclic_tab_bar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CyclicTabBar Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CyclicTabBar Demo'),
      ),
      body: const _Content(),
    );
  }
}

class _Content extends StatefulWidget {
  const _Content();

  @override
  __ContentState createState() => __ContentState();
}

class __ContentState extends State<_Content> {
  final contents = List.generate(25, (index) => index + 1);

  String _convertContent(int number) => number.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return DefaultCyclicTabController(
      contentLength: contents.length,
      initialIndex: 0, // Can be any valid index (0 to contentLength-1)
      child: Column(
        children: [
          // Wrapped tab bar with custom decoration
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade100,
                  Colors.purple.shade100,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CyclicTabBar(
              contentLength: contents.length,
              onTabTap: (index) {
                debugPrint('tapped $index');
              },
              tabBuilder: (index, isSelected) => Text(
                _convertContent(contents[index]),
                style: TextStyle(
                  color: isSelected ? Colors.pink : Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              separator: const BorderSide(color: Colors.black12, width: 2.0),
              indicatorColor: Colors.pink,
            ),
          ),
          // Page view
          Expanded(
            child: CyclicTabBarView(
              contentLength: contents.length,
              onPageChanged: (index) => debugPrint('page changed to $index.'),
              pageBuilder: (context, index, _) {
                return SizedBox.expand(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: contents[index] / 10),
                    ),
                    child: Center(
                      child: Text(
                        _convertContent(contents[index]),
                        style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                              color: contents[index] / 10 > 0.6
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
