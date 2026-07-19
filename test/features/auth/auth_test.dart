import 'package:cubeclash/core/error/failures.dart';
import 'package:cubeclash/core/error/result.dart';
import 'package:cubeclash/core/network/auth_interceptor.dart';
import 'package:cubeclash/core/network/token_storage.dart';
import 'package:cubeclash/features/auth/domain/repositories/auth_repository.dart';
import 'package:cubeclash/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('AuthValidators', () {
    test('accepts ordinary addresses', () {
      expect(AuthValidators.email('you@example.com'), isNull);
      expect(AuthValidators.email('a.b+tag@sub.example.co.uk'), isNull);
      expect(AuthValidators.email('  spaced@example.com  '), isNull);
    });

    test('rejects what is obviously not an address', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('nope'), isNotNull);
      expect(AuthValidators.email('no@domain'), isNotNull);
      expect(AuthValidators.email('@example.com'), isNotNull);
      expect(AuthValidators.email('two spaces@example.com'), isNotNull);
    });

    test('passwords are judged on length, not composition', () {
      expect(AuthValidators.password('correcthorse'), isNull);
      expect(AuthValidators.password('12345678'), isNull);
      expect(AuthValidators.password('short'), isNotNull);
      expect(AuthValidators.password(''), isNotNull);
    });

    test('display names have sane bounds', () {
      expect(AuthValidators.displayName('Ada'), isNull);
      expect(AuthValidators.displayName('  Ada  '), isNull);
      expect(AuthValidators.displayName(''), isNotNull);
      expect(AuthValidators.displayName('A'), isNotNull);
      expect(AuthValidators.displayName('x' * 25), isNotNull);
    });
  });

  group('AuthCubit', () {
    late _MockAuthRepository repository;

    AuthCubit build() => AuthCubit(repository: repository);

    setUp(() {
      repository = _MockAuthRepository();

      when(() => repository.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => const Ok<void>(null));
      when(() => repository.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
            displayName: any(named: 'displayName'),
          )).thenAnswer((_) async => const Ok<void>(null));
      when(() => repository.completeProfile(
            displayName: any(named: 'displayName'),
            country: any(named: 'country'),
          )).thenAnswer((_) async => const Ok<void>(null));
    });

    test('a successful login succeeds outright', () async {
      final AuthCubit cubit = build();
      await cubit.login(email: 'you@example.com', password: 'password123');

      expect(cubit.state.succeeded, isTrue);
      expect(cubit.state.needsProfileSetup, isFalse);
      expect(cubit.state.isSubmitting, isFalse);
    });

    test('registration routes to profile setup, not straight into the app',
        () async {
      final AuthCubit cubit = build();
      await cubit.register(
        email: 'new@example.com',
        password: 'password123',
        displayName: 'Ada',
      );

      expect(cubit.state.needsProfileSetup, isTrue);
      expect(
        cubit.state.succeeded,
        isFalse,
        reason: 'the flow is not finished until the profile step is done',
      );
    });

    test('completing the profile finishes the flow', () async {
      final AuthCubit cubit = build();
      await cubit.completeProfile(displayName: 'Ada', country: 'GB');

      expect(cubit.state.succeeded, isTrue);
    });

    test('bad credentials surface an auth failure and do not succeed',
        () async {
      when(() => repository.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer(
        (_) async => const Err<void>(AuthFailure('Wrong password')),
      );

      final AuthCubit cubit = build();
      await cubit.login(email: 'you@example.com', password: 'nope1234');

      expect(cubit.state.succeeded, isFalse);
      expect(cubit.state.failure, isA<AuthFailure>());
      expect(cubit.state.isSubmitting, isFalse);
    });

    test('a duplicate sign-up reports the reason', () async {
      when(() => repository.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
            displayName: any(named: 'displayName'),
          )).thenAnswer(
        (_) async => const Err<void>(ServerFailure('Email already exists')),
      );

      final AuthCubit cubit = build();
      await cubit.register(
        email: 'you@example.com',
        password: 'password123',
        displayName: 'Ada',
      );

      expect(cubit.state.needsProfileSetup, isFalse);
      expect(cubit.state.failure, isA<ServerFailure>());
    });

    test('a retry clears the previous failure', () async {
      when(() => repository.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer(
        (_) async => const Err<void>(AuthFailure('Wrong password')),
      );

      final AuthCubit cubit = build();
      await cubit.login(email: 'you@example.com', password: 'nope1234');
      expect(cubit.state.failure, isNotNull);

      when(() => repository.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => const Ok<void>(null));
      await cubit.login(email: 'you@example.com', password: 'password123');

      expect(cubit.state.failure, isNull);
      expect(cubit.state.succeeded, isTrue);
    });
  });

  group('TokenStore', () {
    late InMemoryTokenStorage storage;

    setUp(() => storage = InMemoryTokenStorage());

    test('starts un-restored so the router can wait rather than guess', () {
      final TokenStore store = TokenStore(storage);

      expect(store.isRestored, isFalse);
      expect(store.hasSession, isFalse);
    });

    test('restores a persisted session', () async {
      await storage.write(const TokenPair(access: 'a', refresh: 'r'));

      final TokenStore store = TokenStore(storage);
      await store.restore();

      expect(store.isRestored, isTrue);
      expect(store.hasSession, isTrue);
      expect(store.accessToken, 'a');
    });

    test('restoring with nothing stored is a clean signed-out state', () async {
      final TokenStore store = TokenStore(storage);
      await store.restore();

      expect(store.isRestored, isTrue);
      expect(store.hasSession, isFalse);
    });

    test('writes through to storage and notifies', () async {
      final TokenStore store = TokenStore(storage);
      int notifications = 0;
      store.addListener(() => notifications++);

      await store.setTokens(access: 'a', refresh: 'r');
      expect((await storage.read())?.access, 'a');
      expect(notifications, 1);

      await store.clear();
      expect(await storage.read(), isNull);
      expect(store.hasSession, isFalse);
      expect(
        notifications,
        2,
        reason: 'the router guard redirects off this notification',
      );
    });
  });
}
