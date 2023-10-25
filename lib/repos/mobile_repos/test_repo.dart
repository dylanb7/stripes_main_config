import 'dart:async';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:stripes_backend_helper/RepositoryBase/TestBase/BlueDye/blue_dye_impl.dart'
    as repo;
import 'package:stripes_backend_helper/RepositoryBase/TestBase/base_test_repo.dart';
import 'package:stripes_main_config/models/BlueDyeResponse.dart';
import 'package:stripes_main_config/models/BlueDyeResponseLog.dart';
import 'package:stripes_main_config/models/BlueDyeTestLog.dart';
import 'package:stripes_main_config/models/DetailResponse.dart';
import 'package:stripes_main_config/repos/utils.dart';
import 'package:stripes_main_config/repos/web_repos/stamp_repo.dart';

import '../../models/BlueDyeTest.dart';
import '../../models/Response.dart';

class Test extends TestRepo<repo.BlueDyeTest> {
  BlueDyeTest? current;

  final StreamController<repo.BlueDyeTest?> _controller = StreamController();

  final StreamController<StreamSubscription<BlueDyeTestLog>> logsStream =
      StreamController();

  Test(
      {required super.stampRepo,
      required super.authUser,
      required super.subUser,
      required super.questionRepo}) {
    Amplify.DataStore.observe(BlueDyeTest.classType,
            where: BlueDyeTest.SUBUSER.eq(subUser.uid))
        .listen(onTest);
  }

  onTest(SubscriptionEvent<BlueDyeTest> event) async {
    final BlueDyeTest test = event.item;
    try {
      List<BlueDyeTestLog>? logs = test.logs;
      logs ??= await Amplify.DataStore.query(BlueDyeTestLog.classType,
          where: BlueDyeTestLog.BLUEDYETEST.eq(test.id));

      List<BlueDyeTestLog> completed = [];

      fetchLog(BlueDyeTestLog log) async {
        final DetailResponse logResponse = log.response ??
            (await Amplify.DataStore.query(DetailResponse.classType,
                    where: DetailResponse.ID.eq(log.detailResponseID)))
                .first;
        List<Response> responses = logResponse.responses ??
            await Amplify.DataStore.query(Response.classType,
                where: Response.DETAILRESPONSE.eq(logResponse.id));
        final DetailResponse completeDetail =
            logResponse.copyWith(responses: responses);
        final completeTest = log.copyWith(response: completeDetail);
        completed.add(completeTest);
      }

      await Future.wait(logs.map((log) => fetchLog(log)));

      final BlueDyeTest testWithLogs = test.copyWith(logs: completed);

      current = testWithLogs;
      _emit();
    } catch (e) {
      safePrint(e);
    }
  }

  _emit() {
    _controller
        .add(current != null ? queryToLocalTest(current!, questionRepo) : null);
  }

  @override
  cancel() async {
    if (current == null) return;
    try {
      final BlueDyeTest test = (await Amplify.DataStore.query(
        BlueDyeTest.classType,
        where: BlueDyeTest.SUBUSER.eq(subUser.uid),
      ))
          .first;
      Amplify.DataStore.delete(test);
    } catch (e) {
      safePrint(e);
    }
  }

  @override
  Stream<repo.BlueDyeTest?> get obj => _controller.stream;

  @override
  setValue(repo.BlueDyeTest obj) async {
    final BlueDyeTest edit = localTestToQuery(obj, subUser);
    final List<BlueDyeTestLog> logs = edit.logs!;
    try {
      await cancel();
      await Amplify.DataStore.save(edit,
          where: BlueDyeTest.SUBUSER.eq(subUser.uid));
      for (BlueDyeTestLog log in logs) {
        await Amplify.DataStore.save(log.copyWith(blueDyeTest: edit));
      }
    } catch (e) {
      safePrint(e);
    }
  }

  @override
  submit(DateTime submitTime) {
    if (current == null ||
        current?.logs == null ||
        current?.finishedEating == null) return;

    final int lastBlue =
        current!.logs!.lastIndexWhere((element) => element.isBlue);

    if (lastBlue == -1) return;
    final BlueDyeResponse res = BlueDyeResponse(
      stamp: current!.stamp,
      finishedEating: current!.finishedEating!,
      logs: current!.logs!
          .map((log) => BlueDyeResponseLog(
              isBlue: log.isBlue,
              response: log.response,
              detailResponseID: log.response?.id))
          .toList(),
      subUserId: subUser.uid,
    );
    (stampRepo as Stamps).addRawBlueDye(res);
  }
}
