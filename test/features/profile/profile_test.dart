import 'package:cubeclash/core/analytics/analytics_service.dart';
import 'package:cubeclash/core/error/failures.dart';
import 'package:cubeclash/core/error/result.dart';
import 'package:cubeclash/features/profile/domain/entities/app_settings.dart';
import 'package:cubeclash/features/profile/domain/entities/user_profile.dart';
import 'package:cubeclash/features/profile/domain/repositories/profile_repository.dart';
import 'package:cubeclash/features/profile/presentation/cubit/friends_cubit.dart';
import 'package:cubeclash/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:cubeclash/features/profile/presentation/cubit/settings_cubit.dart';
import 'package:cubeclash/features/timer/domain/entities/timer_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

/// An in-memory [SettingsRepository] — shared_preferences needs a platform
/// channel, and what matters here is that every change is written through.
class _InMemorySettings implements SettingsRepository {
  AppSettings stored = const AppSettings();
  int saveCount = 0;

  @override
  Future<AppSettings> load() async => stored;

  @override
  Future<void> save(AppSettings settings) async {
    stored = settings;
    saveCount++;
  }
}

void main() {
  group('SettingsCubit', () {
    late _InMemorySettings repository;

    SettingsCubit build() => SettingsCubit(
          repository: repository,
          analytics: const NoopAnalytics(),
        );

    setUp(() => repository = _InMemorySettings());

    test('starts on the documented defaults', () {
      final SettingsCubit cubit = build();

      expect(cubit.state.themeMode, AppThemeMode.system);
      expect(cubit.state.timerStyle, TimerStyle.hold);
      expect(
        cubit.state.inspectionEnabled,
        isTrue,
        reason: 'CubeClash is a competitive app — inspection is on by default',
      );
    });

    test('restores what was persisted', () async {
      repository.stored = const AppSettings(
        themeMode: AppThemeMode.dark,
        timerStyle: TimerStyle.tap,
        inspectionEnabled: false,
      );

      final SettingsCubit cubit = build();
      await cubit.load();

      expect(cubit.state.themeMode, AppThemeMode.dark);
      expect(cubit.state.timerStyle, TimerStyle.tap);
      expect(cubit.state.inspectionEnabled, isFalse);
    });

    test('every change persists immediately — there is no save button',
        () async {
      final SettingsCubit cubit = build();

      await cubit.setThemeMode(AppThemeMode.dark);
      await cubit.setTimerStyle(TimerStyle.tap);
      await cubit.setInspectionEnabled(false);
      await cubit.setHapticsEnabled(false);
      await cubit.setSoundEnabled(false);

      expect(repository.saveCount, 5);
      expect(repository.stored.themeMode, AppThemeMode.dark);
      expect(repository.stored.timerStyle, TimerStyle.tap);
      expect(repository.stored.inspectionEnabled, isFalse);
    });

    test('setting the current value is a no-op', () async {
      final SettingsCubit cubit = build();

      await cubit.setThemeMode(AppThemeMode.system);
      await cubit.setTimerStyle(TimerStyle.hold);

      expect(repository.saveCount, 0);
    });

    test('exposes exactly the slice the timer needs', () async {
      final SettingsCubit cubit = build();
      await cubit.setTimerStyle(TimerStyle.tap);
      await cubit.setInspectionEnabled(false);

      final TimerPreferences prefs = cubit.state.timerPreferences;
      expect(prefs.style, TimerStyle.tap);
      expect(prefs.inspectionEnabled, isFalse);
    });

    test('an unknown persisted theme falls back to system', () {
      expect(AppThemeMode.fromName('chartreuse'), AppThemeMode.system);
      expect(AppThemeMode.fromName(null), AppThemeMode.system);
      expect(AppThemeMode.fromName('dark'), AppThemeMode.dark);
    });
  });

  group('ProfileCubit', () {
    late _MockProfileRepository repository;

    const UserProfile me = UserProfile(
      id: 'me',
      displayName: 'Doniyor',
      email: 'you@example.com',
      countryCode: 'GB',
      elo: 1284,
      solveCount: 142,
    );

    ProfileCubit build() => ProfileCubit(repository: repository);

    setUp(() {
      repository = _MockProfileRepository();
      when(() => repository.getMe())
          .thenAnswer((_) async => const Ok<UserProfile>(me));
      when(() => repository.logout())
          .thenAnswer((_) async => const Ok<void>(null));
    });

    test('loads the profile', () async {
      final ProfileCubit cubit = build();
      await cubit.load();

      expect(cubit.state.profile?.displayName, 'Doniyor');
      expect(cubit.state.isLoading, isFalse);
    });

    test('a failed load surfaces an error rather than a blank profile',
        () async {
      when(() => repository.getMe()).thenAnswer(
        (_) async => const Err<UserProfile>(NetworkFailure('offline')),
      );

      final ProfileCubit cubit = build();
      await cubit.load();

      expect(cubit.state.profile, isNull);
      expect(cubit.state.failure, isA<NetworkFailure>());
      expect(cubit.state.isLoading, isFalse);
    });

    test('updating the display name keeps the returned profile', () async {
      when(() => repository.updateMe(
            displayName: any(named: 'displayName'),
            country: any(named: 'country'),
          )).thenAnswer(
        (_) async => Ok<UserProfile>(me.copyWith(displayName: 'Cuber')),
      );

      final ProfileCubit cubit = build();
      await cubit.load();
      await cubit.updateProfile(displayName: 'Cuber');

      expect(cubit.state.profile?.displayName, 'Cuber');
      expect(cubit.state.isSaving, isFalse);
    });

    test('a rejected update leaves the old name on screen', () async {
      when(() => repository.updateMe(
            displayName: any(named: 'displayName'),
            country: any(named: 'country'),
          )).thenAnswer(
        (_) async => const Err<UserProfile>(ServerFailure('Name taken')),
      );

      final ProfileCubit cubit = build();
      await cubit.load();
      await cubit.updateProfile(displayName: '');

      expect(cubit.state.profile?.displayName, 'Doniyor');
      expect(cubit.state.failure, isA<ServerFailure>());
    });

    test('logout signs you out even when the server call fails', () async {
      // The repository clears local tokens regardless, so reporting failure
      // would be a lie — you *are* signed out.
      when(() => repository.logout()).thenAnswer(
        (_) async => const Err<void>(NetworkFailure('offline')),
      );

      final ProfileCubit cubit = build();
      await cubit.logout();

      expect(cubit.state.signedOut, isTrue);
    });
  });

  group('FriendsCubit', () {
    late _MockProfileRepository repository;

    const List<Friend> friends = <Friend>[
      Friend(
        userId: 'a',
        displayName: 'Ana',
        status: FriendStatus.accepted,
      ),
      Friend(
        userId: 'b',
        displayName: 'Sofia',
        status: FriendStatus.pending,
        incoming: true,
      ),
      Friend(
        userId: 'c',
        displayName: 'Mia',
        status: FriendStatus.pending,
      ),
    ];

    FriendsCubit build() => FriendsCubit(repository: repository);

    setUp(() {
      repository = _MockProfileRepository();
      when(() => repository.getFriends())
          .thenAnswer((_) async => const Ok<List<Friend>>(friends));
      when(() => repository.inviteFriend(any()))
          .thenAnswer((_) async => const Ok<void>(null));
      when(() => repository.acceptFriend(any()))
          .thenAnswer((_) async => const Ok<void>(null));
    });

    test('splits friends from incoming and outgoing requests', () async {
      final FriendsCubit cubit = build();
      await cubit.load();

      expect(cubit.state.accepted.map((Friend f) => f.userId), <String>['a']);
      expect(
        cubit.state.incomingRequests.map((Friend f) => f.userId),
        <String>['b'],
        reason: 'only requests they sent you can be accepted',
      );
      expect(
        cubit.state.outgoingRequests.map((Friend f) => f.userId),
        <String>['c'],
      );
    });

    test('an empty list is the empty state', () async {
      when(() => repository.getFriends())
          .thenAnswer((_) async => const Ok<List<Friend>>(<Friend>[]));

      final FriendsCubit cubit = build();
      await cubit.load();

      expect(cubit.state.isEmpty, isTrue);
      expect(cubit.state.failure, isNull);
    });

    test('a successful invite confirms once and refreshes', () async {
      final FriendsCubit cubit = build();
      await cubit.load();
      await cubit.invite('new@example.com');

      expect(cubit.state.inviteSent, isTrue);
      verify(() => repository.getFriends()).called(2);

      // One-shot: acknowledging clears it so the snackbar can't repeat.
      cubit.acknowledgeInvite();
      expect(cubit.state.inviteSent, isFalse);
    });

    test('a rejected invite reports the reason and does not confirm', () async {
      when(() => repository.inviteFriend(any())).thenAnswer(
        (_) async => const Err<void>(ServerFailure('Already invited')),
      );

      final FriendsCubit cubit = build();
      await cubit.load();
      await cubit.invite('ana@example.com');

      expect(cubit.state.inviteSent, isFalse);
      expect(cubit.state.failure, isA<ServerFailure>());
    });

    test('accepting refreshes the list', () async {
      final FriendsCubit cubit = build();
      await cubit.load();
      await cubit.accept('b');

      verify(() => repository.acceptFriend('b')).called(1);
      verify(() => repository.getFriends()).called(2);
    });

    test('a failed accept keeps the request in place', () async {
      when(() => repository.acceptFriend(any())).thenAnswer(
        (_) async => const Err<void>(ServerFailure('Gone')),
      );

      final FriendsCubit cubit = build();
      await cubit.load();
      await cubit.accept('b');

      expect(cubit.state.failure, isA<ServerFailure>());
      expect(cubit.state.incomingRequests, hasLength(1));
    });
  });
}
