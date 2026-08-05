using Toybox.System as Sys;
using Toybox.Time as Time;
using Toybox.WatchUi as Ui;
using Toybox.Communications as Comm;
using Toybox.Math as Math;

class TaskController {
    var store;
    var relay;
    var queue;
    var view;
    var tasks;
    var projects;
    var selected;
    var mode;
    var projectId;
    var projectName;
    var status;
    var verificationUrl;
    var pendingTask;
    var pendingMutationId;
    var confirmingCompletion;
    var confirmingUnpair;
    var reconciliationRequired;
    var busy;
    var nextCursor;
    var pendingViewMode;
    var pendingProjectId;
    var pendingAppend;

    function initialize() {
        store = new LocalStore();
        relay = new RelayClient(store);
        queue = new OfflineQueue(store);
        tasks = store.getTasks();
        projects = [];
        selected = 0;
        mode = "today";
        projectId = null;
        projectName = null;
        status = store.getRelayToken() == null ? "unpaired" : "cached";
        verificationUrl = store.getVerificationUrl();
        pendingTask = null;
        pendingMutationId = null;
        confirmingCompletion = false;
        confirmingUnpair = false;
        reconciliationRequired = false;
        busy = false;
        nextCursor = null;
        pendingViewMode = null;
        pendingProjectId = null;
        pendingAppend = false;
    }

    function attach(taskView) {
        view = taskView;
    }

    function isPaired() {
        return store.getRelayToken() != null;
    }

    function requestUpdate() {
        if (view != null) {
            Ui.requestUpdate();
        }
    }

    function activeItems() {
        if (mode.equals("projects")) {
            return projects;
        }
        return mode.equals("account") ? [] : tasks;
    }

    function activate() {
        if (busy) {
            return;
        }
        if (!isPaired()) {
            beginOrPollPair();
            return;
        }
        if (reconciliationRequired) {
            refresh();
            return;
        }
        if (mode.equals("account")) {
            if (confirmingUnpair) {
                confirmUnpair();
            } else {
                confirmingUnpair = true;
                status = "confirm_unpair";
                requestUpdate();
            }
            return;
        }
        if (mode.equals("projects")) {
            openSelectedProject();
            return;
        }
        if (confirmingCompletion) {
            confirmSelectedCompletion();
            return;
        }
        if (tasks.size() == 0) {
            refresh();
            return;
        }
        confirmingCompletion = true;
        status = "confirm_complete";
        requestUpdate();
    }

    function beginOrPollPair() {
        var secret = store.getDeviceSecret();
        busy = true;
        status = "pairing";
        requestUpdate();
        if (secret == null) {
            relay.startPair(method(:onPairStarted));
        } else {
            if (verificationUrl != null) {
                Comm.openWebPage(verificationUrl, {"code" => store.getUserCode()}, null);
            }
            relay.pollPair(secret, method(:onPairPolled));
        }
    }

    function onPairStarted(code, response) {
        busy = false;
        if (successfulResponse(code, response) && response["data"] instanceof Dictionary) {
            var data = response["data"];
            store.setPendingPair(data["deviceSecret"], data["userCode"], data["verificationUrl"]);
            verificationUrl = data["verificationUrl"];
            status = "pair_pending";
            Comm.openWebPage(verificationUrl, {"code" => store.getUserCode()}, null);
        } else {
            status = "network_error";
        }
        requestUpdate();
    }

    function onPairPolled(code, response) {
        busy = false;
        if (successfulResponse(code, response) && response["data"] instanceof Dictionary) {
            var data = response["data"];
            if (data["status"] instanceof String && data["status"].equals("paired")) {
                store.setRelayToken(data["relayToken"]);
                store.clearPendingPair();
                status = "paired";
                refresh();
                return;
            }
            status = "pair_pending";
        } else if (invalidPairing(response)) {
            store.clearPendingPair();
            verificationUrl = null;
            status = "pair_expired";
        } else {
            status = "network_error";
        }
        requestUpdate();
    }

    function invalidPairing(response) {
        if (!(response instanceof Dictionary) || response["error"] == null) {
            return false;
        }
        var code = response["error"]["code"];
        return code instanceof String && (
            code.equals("pairing_expired") ||
            code.equals("invalid_pairing") ||
            code.equals("invalid_device_secret")
        );
    }

    function successfulResponse(code, response) {
        return code == 200 && response instanceof Dictionary && response["ok"] == true;
    }

    function refresh() {
        if (!isPaired() || busy) {
            return;
        }
        if (!reconciliationRequired && queue.size() > 0) {
            flushQueue();
            return;
        }
        if (!reconciliationRequired) {
            status = "syncing";
        }
        busy = true;
        nextCursor = null;
        pendingViewMode = mode;
        pendingProjectId = projectId;
        pendingAppend = false;
        requestUpdate();
        if (mode.equals("projects")) {
            relay.fetchProjects(null, method(:onProjects));
        } else {
            var offset = Sys.getClockTime().timeZoneOffset / 60;
            relay.fetchTasks(mode, projectId, offset, null, method(:onTasks));
        }
    }

    function sameRequestContext(requestMode, requestProject) {
        if (!(requestMode instanceof String) || !mode.equals(requestMode)) {
            return false;
        }
        if (projectId == null) {
            return requestProject == null;
        }
        return requestProject instanceof String && projectId.equals(requestProject);
    }

    function loadNextPage() {
        if (busy || nextCursor == null || mode.equals("account")) {
            return;
        }
        busy = true;
        status = "loading_more";
        pendingViewMode = mode;
        pendingProjectId = projectId;
        pendingAppend = true;
        if (mode.equals("projects")) {
            relay.fetchProjects(nextCursor, method(:onProjects));
        } else {
            var offset = Sys.getClockTime().timeZoneOffset / 60;
            relay.fetchTasks(mode, projectId, offset, nextCursor, method(:onTasks));
        }
        requestUpdate();
    }

    function onProjects(code, response) {
        busy = false;
        var append = pendingAppend;
        pendingViewMode = null;
        pendingProjectId = null;
        pendingAppend = false;
        if (!mode.equals("projects")) {
            refresh();
            return;
        }
        if (authorizationExpired(response)) {
            expireAuthorization();
            return;
        }
        if (cursorStale(response)) {
            nextCursor = null;
            refresh();
            return;
        }
        if (successfulResponse(code, response) && response["data"] instanceof Dictionary && response["data"]["projects"] instanceof Array) {
            var data = response["data"];
            var incoming = data["projects"];
            if (append && projects.size() + incoming.size() <= 60) {
                for (var index = 0; index < incoming.size(); index += 1) {
                    projects.add(incoming[index]);
                }
            } else {
                projects = incoming;
                selected = 0;
            }
            nextCursor = data["cursor"] instanceof String ? data["cursor"] : null;
            if (selected >= projects.size()) {
                selected = 0;
            }
            status = "synced";
        } else {
            status = "network_error";
        }
        requestUpdate();
    }

    function onTasks(code, response) {
        busy = false;
        var resumeQueue = false;
        var requestMode = pendingViewMode;
        var requestProject = pendingProjectId;
        var append = pendingAppend;
        pendingViewMode = null;
        pendingProjectId = null;
        pendingAppend = false;
        if (!sameRequestContext(requestMode, requestProject)) {
            refresh();
            return;
        }
        if (authorizationExpired(response)) {
            expireAuthorization();
            return;
        }
        if (cursorStale(response)) {
            nextCursor = null;
            refresh();
            return;
        }
        if (successfulResponse(code, response) && response["data"] instanceof Dictionary && response["data"]["tasks"] instanceof Array) {
            var data = response["data"];
            var incoming = data["tasks"];
            if (append) {
                if (tasks.size() + incoming.size() <= 60) {
                    for (var index = 0; index < incoming.size(); index += 1) {
                        tasks.add(incoming[index]);
                    }
                } else {
                    tasks = incoming;
                    selected = 0;
                }
            } else {
                tasks = incoming;
                if (mode.equals("today")) {
                    store.setTasks(incoming);
                }
            }
            nextCursor = data["cursor"] instanceof String ? data["cursor"] : null;
            if (selected >= tasks.size()) {
                selected = 0;
            }
            status = reconciliationRequired ? "reconciled" : "synced";
            resumeQueue = reconciliationRequired && queue.size() > 0;
            reconciliationRequired = false;
        } else if (reconciliationRequired) {
            status = "completion_uncertain";
        } else if (tasks.size() > 0) {
            status = "offline_cache";
        } else {
            status = "network_error";
        }
        requestUpdate();
        if (resumeQueue) {
            flushQueue();
        }
    }

    function move(delta) {
        var items = activeItems();
        if (items.size() == 0) {
            return;
        }
        if (delta > 0 && selected == items.size() - 1 && nextCursor != null) {
            loadNextPage();
            return;
        }
        selected = (selected + delta + items.size()) % items.size();
        requestUpdate();
    }

    function cycleMode() {
        if (busy || !isPaired() || reconciliationRequired) {
            return;
        }
        confirmingCompletion = false;
        confirmingUnpair = false;
        selected = 0;
        nextCursor = null;
        if (mode.equals("today")) {
            mode = "overdue";
            projectId = null;
            projectName = null;
            tasks = [];
        } else if (mode.equals("overdue")) {
            mode = "projects";
            projectId = null;
            projectName = null;
        } else if (mode.equals("projects")) {
            mode = "account";
            projectId = null;
            projectName = null;
        } else {
            mode = "today";
            projectId = null;
            projectName = null;
            tasks = store.getTasks();
        }
        if (mode.equals("account")) {
            status = "synced";
            requestUpdate();
        } else {
            refresh();
        }
    }

    function openSelectedProject() {
        if (projects.size() == 0) {
            refresh();
            return;
        }
        var project = projects[selected];
        if (project["id"] == null) {
            status = "network_error";
            requestUpdate();
            return;
        }
        mode = "project";
        projectId = project["id"];
        projectName = project["name"];
        selected = 0;
        nextCursor = null;
        tasks = [];
        refresh();
    }

    function goBack() {
        if (confirmingUnpair) {
            confirmingUnpair = false;
            status = "synced";
            requestUpdate();
            return true;
        }
        if (confirmingCompletion) {
            confirmingCompletion = false;
            status = "synced";
            requestUpdate();
            return true;
        }
        if (mode.equals("project")) {
            mode = "projects";
            projectId = null;
            projectName = null;
            selected = 0;
            nextCursor = null;
            refresh();
            return true;
        }
        if (mode.equals("projects") || mode.equals("overdue") || mode.equals("account")) {
            mode = "today";
            projectId = null;
            projectName = null;
            selected = 0;
            nextCursor = null;
            tasks = store.getTasks();
            refresh();
            return true;
        }
        return false;
    }

    function confirmSelectedCompletion() {
        confirmingCompletion = false;
        if (tasks.size() == 0) {
            refresh();
            return;
        }
        var task = tasks[selected];
        var mutationId = createMutationId();
        pendingTask = task;
        pendingMutationId = mutationId;
        if (queue.size() > 0) {
            if (queue.enqueueComplete(pendingTask, pendingMutationId)) {
                removeCompletedTask();
                status = "offline_queued";
            } else {
                status = "queue_full";
            }
            pendingTask = null;
            pendingMutationId = null;
            requestUpdate();
            return;
        }
        status = "completing";
        busy = true;
        requestUpdate();
        relay.completeTask(task, mutationId, method(:onCompleted));
    }

    function createMutationId() {
        return "m-" + Time.now().value().format("%d") + "-" + Sys.getTimer().format("%d") + "-" + Math.rand().format("%d");
    }

    function canQueueCompletion(code, response) {
        if (response == null) {
            return code <= 0;
        }
        if (!(response instanceof Dictionary)) {
            return false;
        }
        if (response["ok"] == true || response["error"] == null) {
            return false;
        }
        var error = response["error"];
        var errorCode = error["code"];
        return errorCode instanceof String && !errorCode.equals("mutation_outcome_unknown") && error["retryable"] == true;
    }

    function authorizationExpired(response) {
        if (!(response instanceof Dictionary) || response["ok"] != false || response["error"] == null) {
            return false;
        }
        var code = response["error"]["code"];
        return code instanceof String && (code.equals("authorization_expired") || code.equals("unauthorized"));
    }

    function cursorStale(response) {
        if (!(response instanceof Dictionary) || response["ok"] != false || response["error"] == null) {
            return false;
        }
        var code = response["error"]["code"];
        return code instanceof String && code.equals("cursor_stale");
    }

    function requestRejected(response) {
        if (!(response instanceof Dictionary) || response["ok"] != false || response["error"] == null) {
            return false;
        }
        var code = response["error"]["code"];
        return code instanceof String && code.equals("request_rejected");
    }

    function confirmUnpair() {
        confirmingUnpair = false;
        busy = true;
        status = "unpairing";
        requestUpdate();
        relay.unpair(method(:onUnpaired));
    }

    function onUnpaired(code, response) {
        busy = false;
        if (successfulResponse(code, response)) {
            finishUnpair();
        } else if (authorizationExpired(response)) {
            finishUnpair();
        } else {
            status = "unpair_failed";
            requestUpdate();
        }
    }

    function finishUnpair() {
        store.unpair();
        tasks = [];
        projects = [];
        mode = "today";
        projectId = null;
        projectName = null;
        selected = 0;
        verificationUrl = null;
        reconciliationRequired = false;
        status = "unpaired";
        requestUpdate();
    }

    function expireAuthorization() {
        store.unpair();
        tasks = [];
        projects = [];
        projectName = null;
        status = "authorization_expired";
        busy = false;
        requestUpdate();
    }

    function removeCompletedTask() {
        var completedId = pendingTask["id"];
        tasks.remove(pendingTask);
        nextCursor = null;
        var cachedToday = store.getTasks();
        for (var index = cachedToday.size() - 1; index >= 0; index -= 1) {
            var cachedId = cachedToday[index]["id"];
            if (cachedId instanceof String && completedId instanceof String && cachedId.equals(completedId)) {
                cachedToday.remove(cachedToday[index]);
            }
        }
        store.setTasks(cachedToday);
        if (selected >= tasks.size()) {
            selected = 0;
        }
    }

    function onCompleted(code, response) {
        busy = false;
        var refreshAfterCompletion = false;
        if (authorizationExpired(response)) {
            pendingTask = null;
            pendingMutationId = null;
            expireAuthorization();
            return;
        }
        if (successfulResponse(code, response)) {
            removeCompletedTask();
            status = "synced";
            refreshAfterCompletion = true;
        } else if (requestRejected(response)) {
            status = "change_rejected";
        } else if (canQueueCompletion(code, response) && queue.enqueueComplete(pendingTask, pendingMutationId)) {
            removeCompletedTask();
            status = "offline_queued";
        } else if (canQueueCompletion(code, response)) {
            status = "queue_full";
        } else {
            status = "completion_uncertain";
            reconciliationRequired = true;
        }
        pendingTask = null;
        pendingMutationId = null;
        requestUpdate();
        if (reconciliationRequired) {
            refresh();
        } else if (refreshAfterCompletion) {
            refresh();
        }
    }

    function flushQueue() {
        var mutation = queue.head();
        if (mutation == null) {
            refresh();
            return;
        }
        status = "syncing_change";
        busy = true;
        requestUpdate();
        relay.replayComplete(mutation, method(:onQueueMutation));
    }

    function onQueueMutation(code, response) {
        busy = false;
        if (authorizationExpired(response)) {
            expireAuthorization();
            return;
        }
        if (successfulResponse(code, response)) {
            queue.removeHead();
            flushQueue();
        } else if (requestRejected(response)) {
            queue.removeHead();
            status = "change_rejected";
            reconciliationRequired = true;
            requestUpdate();
            refresh();
        } else if (!canQueueCompletion(code, response)) {
            queue.removeHead();
            status = "completion_uncertain";
            reconciliationRequired = true;
            requestUpdate();
            refresh();
        } else {
            status = "offline_queue_" + queue.size().format("%d");
            requestUpdate();
        }
    }
}
