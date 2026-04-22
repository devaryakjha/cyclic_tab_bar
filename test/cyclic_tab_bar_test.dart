import 'package:cyclic_tab_bar/cyclic_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CyclicTabBar and CyclicTabBarView stay in sync', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DefaultTabController(
          length: 3,
          child: Scaffold(
            body: Column(
              children: [
                CyclicTabBar(
                  
                  tabs: [
                    Tab(text: 'Home'),
                    Tab(text: 'Explore'),
                    Tab(text: 'Profile'),
                  ],
                ),
                Expanded(
                  child: CyclicTabBarView(
                    children: [
                      Center(child: Text('Home panel')),
                      Center(child: Text('Explore panel')),
                      Center(child: Text('Profile panel')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Home panel'), findsOneWidget);
    expect(find.text('Explore panel'), findsNothing);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    expect(find.text('Explore panel'), findsOneWidget);
    expect(find.text('Home panel'), findsNothing);
  });
}
