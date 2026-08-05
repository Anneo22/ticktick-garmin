using Toybox.WatchUi as Ui;

class TaskListDelegate extends Ui.BehaviorDelegate {
    var controller;

    function initialize(taskController) {
        BehaviorDelegate.initialize();
        controller = taskController;
    }

    function onSelect() {
        controller.activate();
        return true;
    }

    function onNextPage() {
        controller.move(1);
        return true;
    }

    function onPreviousPage() {
        controller.move(-1);
        return true;
    }

    function onMenu() {
        controller.cycleMode();
        return true;
    }

    function onBack() {
        return controller.goBack();
    }
}
