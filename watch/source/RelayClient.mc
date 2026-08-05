using Toybox.Application as App;
using Toybox.Communications as Comm;
import Toybox.Lang;

class RelayClient {
    var store;
    var callback;

    function initialize(localStore) {
        store = localStore;
        callback = null;
    }

    function relayUrl() {
        return App.Properties.getValue("relayUrl");
    }

    function jsonOptions(method, authenticated) {
        var headers = {
            "Content-Type" => Comm.REQUEST_CONTENT_TYPE_JSON
        };
        if (authenticated) {
            headers["Authorization"] = "Bearer " + store.getRelayToken();
        }
        return {
            :method => method,
            :headers => headers,
            :responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
    }

    function request(path, payload, method, authenticated, done) {
        if (callback != null) {
            return false;
        }
        callback = done;
        Comm.makeWebRequest(relayUrl() + path, payload, jsonOptions(method, authenticated), method(:onResponse));
        return true;
    }

    function startPair(done) {
        return request("/v1/pair/start", {}, Comm.HTTP_REQUEST_METHOD_POST, false, done);
    }

    function pollPair(deviceSecret, done) {
        return request("/v1/pair/status", {"deviceSecret" => deviceSecret}, Comm.HTTP_REQUEST_METHOD_POST, false, done);
    }

    function taskPath(view, projectId, utcOffsetMinutes, cursor) {
        var path = "/v1/tasks?view=" + view;
        if (view.equals("project")) {
            path += "&projectId=" + projectId;
        } else {
            path += "&utcOffsetMinutes=" + utcOffsetMinutes.format("%d");
        }
        if (cursor != null) {
            path += "&cursor=" + cursor;
        }
        return path;
    }

    function fetchTasks(view, projectId, utcOffsetMinutes, cursor, done) {
        var path = taskPath(view, projectId, utcOffsetMinutes, cursor);
        return request(path, null, Comm.HTTP_REQUEST_METHOD_GET, true, done);
    }

    function fetchProjects(cursor, done) {
        var path = "/v1/projects";
        if (cursor != null) {
            path += "?cursor=" + cursor;
        }
        return request(path, null, Comm.HTTP_REQUEST_METHOD_GET, true, done);
    }

    function unpair(done) {
        return request("/v1/unpair", {}, Comm.HTTP_REQUEST_METHOD_POST, true, done);
    }

    function completeTask(task, mutationId, done) {
        return request(
            "/v1/tasks/" + task["id"] + "/complete",
            {"projectId" => task["projectId"], "mutationId" => mutationId},
            Comm.HTTP_REQUEST_METHOD_POST,
            true,
            done
        );
    }

    function replayComplete(mutation, done) {
        return request(
            "/v1/tasks/" + mutation["taskId"] + "/complete",
            {"projectId" => mutation["projectId"], "mutationId" => mutation["mutationId"]},
            Comm.HTTP_REQUEST_METHOD_POST,
            true,
            done
        );
    }

    function onResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
        var done = callback;
        callback = null;
        if (done != null) {
            done.invoke(responseCode, data);
        }
    }
}
