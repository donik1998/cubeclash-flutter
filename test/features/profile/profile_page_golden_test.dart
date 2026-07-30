import 'package:bloc_test/bloc_test.dart';
import 'package:cubeclash/core/analytics/analytics_service.dart';
import 'package:cubeclash/core/di/injection.dart';
import 'package:cubeclash/features/profile/domain/entities/app_settings.dart';
import 'package:cubeclash/features/profile/domain/entities/user_profile.dart';
import 'package:cubeclash/features/profile/domain/repositories/profile_repository.dart';
import 'package:cubeclash/features/profile/presentation/cubit/friends_cubit.dart';
import 'package:cubeclash/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:cubeclash/features/profile/presentation/cubit/settings_cubit.dart';
import 'package:cubeclash/features/profile/presentation/pages/friends_page.dart';
import 'package:cubeclash/features/profile/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/harness.dart';
import '../../support/in_memory_settings_repository.dart';

class _MockProfileCubit extends MockCubit<ProfileState>
    implements ProfileCubit {}

class _MockFriendsCubit extends MockCubit<FriendsState>
    implements FriendsCubit {}

void main() {
  setUpAll(initTestFonts);

  late _MockProfileCubit profileCubit;
  late _MockFriendsCubit friendsCubit;

  late InMemorySettingsRepository settingsStore;

  setUp(() async {
    await configureDependencies();

    // shared_preferences goes through a platform channel that never answers
    // under `flutter test`.
    settingsStore = InMemorySettingsRepository();
    sl
      ..unregister<SettingsRepository>()
      ..registerSingleton<SettingsRepository>(settingsStore)
      ..unregister<SettingsCubit>()
      ..registerSingleton<SettingsCubit>(
        SettingsCubit(
          repository: settingsStore,
          analytics: const NoopAnalytics(),
        ),
      );

    profileCubit = _MockProfileCubit();
    friendsCubit = _MockFriendsCubit();

    when(profileCubit.load).thenAnswer((_) async {});
    when(() => profileCubit.close()).thenAnswer((_) async {});
    when(friendsCubit.load).thenAnswer((_) async {});
    when(() => friendsCubit.close()).thenAnswer((_) async {});

    sl
      ..unregister<ProfileCubit>()
      ..registerFactory<ProfileCubit>(() => profileCubit)
      ..unregister<FriendsCubit>()
      ..registerFactory<FriendsCubit>(() => friendsCubit);
  });

  tearDown(resetDependencies);

  const Size phone = Size(390, 780);

  const UserProfile me = UserProfile(
    id: 'me',
    displayName: 'Doniyor',
    email: 'you@example.com',
    countryCode: 'GB',
    elo: 1284,
    bestSingleMs: 8420,
    bestAo5Ms: 10960,
    bestAo12Ms: 11540,
    solveCount: 142,
  );

  /// Wraps in the app-wide SettingsCubit, as `app.dart` does.
  Widget scoped(Widget page) => BlocProvider<SettingsCubit>.value(
        value: sl<SettingsCubit>(),
        child: page,
      );

  Future<void> goldenFor(
    WidgetTester tester,
    Widget page, {
    required String name,
  }) async {
    for (final (String suffix, Brightness brightness) in <(String, Brightness)>[
      ('light', Brightness.light),
      ('dark', Brightness.dark),
    ]) {
      await tester.binding.setSurfaceSize(phone);
      await tester.pumpWidget(
        harnessPage(scoped(page), brightness: brightness, size: phone),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${name}_$suffix.png'),
      );
    }
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('settings', (WidgetTester tester) async {
    whenListen(
      profileCubit,
      const Stream<ProfileState>.empty(),
      initialState: const ProfileState(profile: me, isLoading: false),
    );
    await sl<SettingsCubit>().setThemeMode(AppThemeMode.dark);
    await goldenFor(tester, const SettingsPage(), name: 'settings');
  });

  testWidgets('friends', (WidgetTester tester) async {
    whenListen(
      friendsCubit,
      const Stream<FriendsState>.empty(),
      initialState: const FriendsState(
        isLoading: false,
        friends: <Friend>[
          Friend(
            userId: 'b',
            displayName: 'Sofia Rossi',
            status: FriendStatus.pending,
            countryCode: 'IT',
            bestSingleMs: 7250,
            incoming: true,
          ),
          Friend(
            userId: 'a',
            displayName: 'Ana Silva',
            status: FriendStatus.accepted,
            countryCode: 'BR',
            bestSingleMs: 6310,
          ),
          Friend(
            userId: 'c',
            displayName: 'Mia Andersen',
            status: FriendStatus.pending,
            countryCode: 'NO',
            bestSingleMs: 7690,
          ),
        ],
      ),
    );
    await goldenFor(tester, const FriendsPage(), name: 'friends');
  });

  testWidgets('friends empty', (WidgetTester tester) async {
    whenListen(
      friendsCubit,
      const Stream<FriendsState>.empty(),
      initialState: const FriendsState(isLoading: false),
    );
    await goldenFor(tester, const FriendsPage(), name: 'friends_empty');
  });
}
