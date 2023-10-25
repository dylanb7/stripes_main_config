import 'dart:async';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:rxdart/rxdart.dart';

import 'package:stripes_backend_helper/RepositoryBase/StampBase/base_stamp_repo.dart';
import 'package:stripes_backend_helper/RepositoryBase/StampBase/stamp.dart';

import 'package:stripes_backend_helper/RepositoryBase/TestBase/BlueDye/blue_dye_response.dart';

import 'package:stripes_main_config/models/ModelProvider.dart';

import 'package:stripes_backend_helper/QuestionModel/response.dart' as repo;
import 'package:stripes_main_config/repos/utils.dart';

class Stamps extends StampRepo<repo.Response> {
  final StreamController<List<repo.Response>> _controller = StreamController();

  Stamps(
      {required super.authUser,
      required super.currentUser,
      required super.questionRepo}) {
    _controller.add([]);
    final Stream<List<DetailResponse>> detailsStream =
        Amplify.DataStore.observeQuery(DetailResponse.classType,
            where: DetailResponse.SUBUSERID.eq(currentUser.uid).and(
                DetailResponse.STAMP.gt(earliest?.millisecondsSinceEpoch ?? 0)),
            sortBy: [DetailResponse.STAMP.ascending()]).asyncMap(_cleanDetails);
    final Stream<List<Response>> responseStream =
        Amplify.DataStore.observeQuery(Response.classType,
            where: Response.SUBUSERID
                .eq(currentUser.uid)
                .and(Response.STAMP.gt(earliest?.millisecondsSinceEpoch ?? 0))
                .and(Response.DETAILRESPONSE.eq(null)),
            sortBy: [Response.STAMP.ascending()]).asyncMap(_cleanResponses);
    final Stream<List<BlueDyeResponse>> blueDyeReponseStream =
        Amplify.DataStore.observeQuery(BlueDyeResponse.classType,
                where: BlueDyeResponse.SUBUSERID.eq(currentUser.uid).and(
                    BlueDyeResponse.STAMP
                        .gt(earliest?.millisecondsSinceEpoch ?? 0)),
                sortBy: [BlueDyeResponse.STAMP.ascending()])
            .asyncMap(_cleanBlueDye);
    Rx.combineLatest3(
        detailsStream, responseStream, blueDyeReponseStream, _updateState);
  }

  _updateState(List<DetailResponse> detailSnapshot,
      List<Response> responseSnapshot, List<BlueDyeResponse> blueDyeSnapshot) {
    final List<repo.DetailResponse> localDetails = detailSnapshot
        .map((detail) => detailFromQuery(detail, questionRepo))
        .toList();
    final List<repo.Response> localResponses = responseSnapshot
        .map((response) => responseFromQuery(response, questionRepo))
        .toList();
    final List<BlueDyeResp> localBlueDye =
        blueDyeSnapshot.map((dye) => blueDyeFromQuery(dye)).toList();
    final List<repo.Response> newStamps = [
      ...localDetails,
      ...localResponses,
      ...localBlueDye
    ];
    newStamps.sort((a, b) => b.stamp.compareTo(a.stamp));
    _controller.add(newStamps);
  }

  Future<List<DetailResponse>> _cleanDetails(
      QuerySnapshot<DetailResponse> event) async {
    final List<DetailResponse> withResponses = [];
    try {
      for (DetailResponse detailResponse in event.items) {
        final List<Response> childResponses = detailResponse.responses ??
            (await Amplify.DataStore.query(Response.classType,
                where: Response.DETAILRESPONSE.eq(detailResponse.id)));
        final DetailResponse toAdd =
            detailResponse.copyWith(responses: childResponses);
        withResponses.add(toAdd);
      }
    } catch (e) {
      safePrint(e);
    }
    return withResponses;
  }

  Future<List<Response>> _cleanResponses(QuerySnapshot<Response> event) async {
    return event.items;
  }

  Future<List<BlueDyeResponse>> _cleanBlueDye(
      QuerySnapshot<BlueDyeResponse> event) async {
    final List<BlueDyeResponse> withLogs = [];
    try {
      for (BlueDyeResponse response in event.items) {
        final List<BlueDyeResponseLog> logs = response.logs ??
            (await Amplify.DataStore.query(BlueDyeResponseLog.classType,
                where: BlueDyeResponseLog.BLUEDYERESPONSE.eq(response.id)));
        List<BlueDyeResponseLog> withDetail = [];
        for (BlueDyeResponseLog log in logs) {
          final DetailResponse logResonse = log.response ??
              (await Amplify.DataStore.query(DetailResponse.classType,
                      where: DetailResponse.ID.eq(log.detailResponseID)))
                  .first;
          final BlueDyeResponseLog has = log.copyWith(response: logResonse);
          withDetail.add(has);
        }
        final BlueDyeResponse toAdd = response.copyWith(logs: withDetail);
        withLogs.add(toAdd);
      }
    } catch (e) {
      safePrint(e);
    }
    return withLogs;
  }

  Future<void> addRawBlueDye(BlueDyeResponse response) async {
    final List<BlueDyeResponseLog> logs = response.logs ?? [];
    try {
      await Amplify.DataStore.save(response);
      for (BlueDyeResponseLog log in logs) {
        final BlueDyeResponseLog toSave =
            log.copyWith(blueDyeResponse: response);
        await Amplify.DataStore.save(toSave);
      }
    } catch (e) {
      safePrint(e);
    }
  }

  @override
  addStamp(Stamp stamp) async {
    if (stamp is repo.DetailResponse) {
      final DetailResponse detailResponse =
          detailToQuery(stamp, fromLocal(currentUser));
      final List<Response> children = detailResponse.responses!;
      try {
        await Amplify.DataStore.save(detailResponse);
        for (Response child in children) {
          final Response toSave =
              child.copyWith(detailResponse: detailResponse);
          await Amplify.DataStore.save(toSave);
        }
      } catch (e) {
        safePrint(e);
      }
    } else if (stamp is BlueDyeResp) {
      throw UnimplementedError();
    } else if (stamp is repo.Response) {
      final Response response = responseToQuery(stamp, currentUser.uid);
      try {
        await Amplify.DataStore.save(response);
      } catch (e) {
        safePrint(e);
      }
    }
  }

  @override
  removeStamp(Stamp stamp) async {
    try {
      if (stamp is repo.DetailResponse) {
        final DetailResponse toDelete = (await Amplify.DataStore.query(
                DetailResponse.classType,
                where: DetailResponse.ID.eq(stamp.id)))
            .first;
        await Amplify.DataStore.delete(toDelete);
      } else if (stamp is BlueDyeResp) {
        final BlueDyeResponse toDelete = (await Amplify.DataStore.query(
                BlueDyeResponse.classType,
                where: BlueDyeResponse.ID.eq(stamp.id)))
            .first;
        await Amplify.DataStore.delete(toDelete);
      } else if (stamp is repo.Response) {
        final Response toDelete = (await Amplify.DataStore.query(
                Response.classType,
                where: Response.ID.eq(stamp)))
            .first;
        await Amplify.DataStore.delete(toDelete);
      }
    } catch (e) {
      safePrint(e);
    }
  }

  @override
  updateStamp(Stamp stamp) async {
    await removeStamp(stamp);
    await addStamp(stamp);
  }

  @override
  set earliestDate(DateTime dateTime) {
    earliest = dateTime;
  }

  @override
  Stream<List<repo.Response>> get stamps => _controller.stream;
}
