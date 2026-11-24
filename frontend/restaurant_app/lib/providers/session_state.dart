import 'package:flutter/foundation.dart';

import '../models/session_user.dart';

class SessionState extends ChangeNotifier {
  SessionUser? user;
  void signIn(SessionUser value) {
    user = value;
    notifyListeners();
  }

  void signOut() {
    user = null;
    notifyListeners();
  }
}

final sessionState = SessionState();
