import 'dart:async';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:stripes_backend_helper/RepositoryBase/SubBase/base_sub_repo.dart';
import 'package:stripes_backend_helper/RepositoryBase/SubBase/sub_user.dart'
    as repo;
import 'package:stripes_main_config/models/SubUser.dart';
import 'package:stripes_main_config/repos/utils.dart';

class SubRepo extends SubUserRepo {
  final StreamController<List<repo.SubUser>> subStream = StreamController();

  SubRepo({required super.authUser}) {
    Amplify.DataStore.observeQuery(SubUser.classType).listen(
      (event) {
        final List<repo.SubUser> subs =
            event.items.map((sub) => toLocal(sub)).toList();
        subStream.add(subs);
      },
    );
  }

  @override
  Future<void> addSubUser(repo.SubUser user) async {
    try {
      final SubUser newUser = SubUser(
          name: user.name,
          gender: user.gender,
          birthYear: user.birthYear,
          isControl: user.isControl);
      Amplify.DataStore.save(newUser);
    } catch (e) {
      safePrint(e);
    }
  }

  @override
  Future<void> deleteSubUser(repo.SubUser user) async {
    try {
      Amplify.DataStore.delete(fromLocal(user));
    } catch (e) {
      safePrint(e);
    }
  }

  @override
  Future<void> updateSubUser(repo.SubUser user) async {
    try {
      final SubUser newUser = fromLocal(user);
      Amplify.DataStore.save(newUser, where: SubUser.ID.eq(newUser.id));
    } catch (e) {
      safePrint(e);
    }
  }

  @override
  Stream<List<repo.SubUser>> get users => subStream.stream;
}
