import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/datasources/google_sheets_service.dart';

final googleSheetsServiceProvider = Provider<GoogleSheetsService>((ref) {
  return GoogleSheetsService();
});

class AuthState {
  final GoogleSignInAccount? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    GoogleSignInAccount? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final GoogleSheetsService _sheetsService;

  AuthNotifier(this._sheetsService) : super(const AuthState()) {
    checkCurrentUser();
  }

  Future<void> checkCurrentUser() async {
    state = state.copyWith(isLoading: true);
    try {
      final success = await _sheetsService.signInSilently();
      if (success) {
        state = AuthState(user: _sheetsService.currentUser);
      } else {
        state = const AuthState();
      }
    } catch (e) {
      state = AuthState(error: e.toString());
    }
  }

  Future<bool> signIn() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final account = await _sheetsService.signIn();
      state = AuthState(user: account);
      return account != null;
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _sheetsService.signOut();
      state = const AuthState();
    } catch (e) {
      state = AuthState(error: e.toString());
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final service = ref.watch(googleSheetsServiceProvider);
  return AuthNotifier(service);
});
