import 'package:stripes_backend_helper/QuestionModel/question.dart';
import 'package:stripes_backend_helper/QuestionModel/response.dart' as repo;
import 'package:stripes_backend_helper/RepositoryBase/QuestionBase/question_repo_base.dart';
import 'package:stripes_backend_helper/RepositoryBase/SubBase/sub_user.dart'
    as local;
import 'package:stripes_backend_helper/RepositoryBase/TestBase/BlueDye/blue_dye_impl.dart'
    as test;

import 'package:stripes_backend_helper/RepositoryBase/TestBase/BlueDye/blue_dye_response.dart';
import 'package:stripes_backend_helper/RepositoryBase/TestBase/BlueDye/bm_test_log.dart';
import 'package:stripes_backend_helper/date_format.dart';
import 'package:stripes_main_config/models/BlueDyeResponse.dart';
import 'package:stripes_main_config/models/BlueDyeResponseLog.dart';
import 'package:stripes_main_config/models/BlueDyeTest.dart';
import 'package:stripes_main_config/models/BlueDyeTestLog.dart';
import 'package:stripes_main_config/models/DetailResponse.dart';
import 'package:stripes_main_config/models/Response.dart';
import 'package:stripes_main_config/models/SubUser.dart';

BlueDyeResp blueDyeFromQuery(BlueDyeResponse blueDye) {
  final List<BlueDyeResponseLog> logs = blueDye.logs!;
  final BlueDyeResponseLog firstBlue = logs.firstWhere((val) => val.isBlue);
  final BlueDyeResponseLog lastBlue = logs.lastWhere((val) => val.isBlue);
  final int numBlue = logs.where((element) => element.isBlue).toList().length;
  final int numBrown = logs.length - numBlue;
  return BlueDyeResp(
      id: blueDye.id,
      startEating: dateFromStamp(blueDye.stamp),
      eatingDuration: Duration(milliseconds: blueDye.finishedEating),
      normalBowelMovements: numBrown,
      blueBowelMovements: numBlue,
      firstBlue: dateFromStamp(firstBlue.response?.stamp ?? 0),
      lastBlue: dateFromStamp(lastBlue.response?.stamp ?? 0));
}

SubUser fromLocal(local.SubUser user) => SubUser(
    id: user.uid,
    name: user.name,
    gender: user.gender,
    birthYear: user.birthYear,
    isControl: user.isControl);

local.SubUser toLocal(SubUser user) => local.SubUser(
    id: user.id,
    name: user.name,
    gender: user.gender,
    birthYear: user.birthYear,
    isControl: user.isControl);

repo.Response responseFromQuery(Response response, QuestionRepo questionRepo) {
  Question question = questionRepo.questions.fromID(response.qid);
  if (response.textResponse != null) {
    return repo.OpenResponse(
      id: response.id,
      question: question as FreeResponse,
      stamp: response.stamp,
      response: response.textResponse!,
    );
  } else if (response.all_selected != null) {
    return repo.AllResponse(
        id: response.id,
        question: question as AllThatApply,
        stamp: response.stamp,
        responses: response.all_selected!);
  } else if (response.selected != null) {
    return repo.MultiResponse(
        id: response.id,
        question: question as MultipleChoice,
        stamp: response.stamp,
        index: response.selected!);
  } else if (response.numeric != null) {
    return repo.NumericResponse(
        id: response.id,
        question: question as Numeric,
        stamp: response.stamp,
        response: response.numeric!);
  }
  return repo.Selected(question: question as Check, stamp: response.stamp);
}

Response responseToQuery(repo.Response response, String subUserId) {
  if (response is repo.OpenResponse) {
    return Response(
        stamp: response.stamp,
        type: response.type,
        qid: response.question.id,
        textResponse: response.response,
        id: response.id,
        subUserId: subUserId);
  }
  if (response is repo.AllResponse) {
    return Response(
        id: response.id,
        stamp: response.stamp,
        type: response.type,
        qid: response.question.id,
        all_selected: response.responses,
        subUserId: subUserId);
  }
  if (response is repo.NumericResponse) {
    return Response(
        id: response.id,
        stamp: response.stamp,
        type: response.type,
        qid: response.question.id,
        numeric: response.response.toInt(),
        subUserId: subUserId);
  }
  if (response is repo.MultiResponse) {
    return Response(
        id: response.id,
        stamp: response.stamp,
        type: response.type,
        qid: response.question.id,
        selected: response.index,
        subUserId: subUserId);
  }
  return Response(
      id: response.id,
      stamp: response.stamp,
      type: response.type,
      qid: response.question.id,
      subUserId: subUserId);
}

DetailResponse detailToQuery(repo.DetailResponse detailResponse, SubUser user) {
  final DetailResponse noChildren = DetailResponse(
    id: detailResponse.id,
    stamp: detailResponse.stamp,
    type: detailResponse.type,
    description: detailResponse.description,
    subUserId: user.id,
  );
  final List<Response> children = detailResponse.responses
      .map((response) => responseToQuery(response, user.id)
          .copyWith(detailResponse: noChildren))
      .toList();
  return noChildren.copyWith(responses: children);
}

repo.DetailResponse detailFromQuery(
    DetailResponse response, QuestionRepo questionRepo) {
  return repo.DetailResponse(
      id: response.id,
      description: response.description ?? "",
      responses: response.responses
              ?.map((val) => responseFromQuery(val, questionRepo))
              .toList() ??
          [],
      stamp: response.stamp,
      detailType: response.type ?? "");
}

BlueDyeTest localTestToQuery(test.BlueDyeTest test, local.SubUser subUser) {
  final BlueDyeTest blueDyeTest = BlueDyeTest(
    id: test.id,
    stamp: dateToStamp(test.startTime),
    finishedEating: test.finishedEating?.inMilliseconds,
    subUser: fromLocal(subUser),
  );
  final List<BlueDyeTestLog> testLogs = test.logs.map((log) {
    final DetailResponse logRes =
        detailToQuery(log.response, fromLocal(subUser));
    return BlueDyeTestLog(
        id: log.id,
        isBlue: log.isBlue,
        response: logRes,
        detailResponseID: logRes.id,
        blueDyeTest: blueDyeTest);
  }).toList();
  return blueDyeTest.copyWith(logs: testLogs);
}

test.BlueDyeTest queryToLocalTest(
    BlueDyeTest blueDyeTest, QuestionRepo questionRepo) {
  final List<BMTestLog> logs = blueDyeTest.logs
          ?.map((log) => BMTestLog(
              id: log.id,
              response: detailFromQuery(log.response!, questionRepo),
              isBlue: log.isBlue))
          .toList() ??
      [];
  return test.BlueDyeTest(
      id: blueDyeTest.id,
      startTime: dateFromStamp(blueDyeTest.stamp),
      finishedEating: blueDyeTest.finishedEating != null
          ? Duration(milliseconds: blueDyeTest.finishedEating!)
          : null,
      logs: logs);
}
