using Toybox.Graphics as Gfx;
using Toybox.WatchUi as Ui;

class TaskListView extends Ui.View {
    var controller;

    function initialize(taskController) {
        View.initialize();
        controller = taskController;
    }

    function onShow() {
        if (controller.isPaired() && !controller.mode.equals("account")) {
            controller.refresh();
        }
    }

    function modeTitle() {
        if (controller.mode.equals("overdue")) {
            return "Overdue";
        }
        if (controller.mode.equals("projects")) {
            return "Projects";
        }
        if (controller.mode.equals("project")) {
            return "Project";
        }
        if (controller.mode.equals("account")) {
            return "Account";
        }
        return "Today";
    }

    function accentColor(dc) {
        return dc.getWidth() <= 180 ? Gfx.COLOR_WHITE : Gfx.COLOR_ORANGE;
    }

    function onUpdate(dc) {
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var line = dc.getFontHeight(Gfx.FONT_XTINY) + 3;
        var compact = width <= 180;
        var titleFont = compact ? Gfx.FONT_XTINY : Gfx.FONT_SMALL;
        var headerX = compact ? width / 2 - 25 : width / 2;
        var y = compact ? 14 : 8;
        dc.setColor(accentColor(dc), Gfx.COLOR_TRANSPARENT);
        dc.drawText(headerX, y, titleFont, modeTitle(), Gfx.TEXT_JUSTIFY_CENTER);
        y += dc.getFontHeight(titleFont) + 5;

        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(headerX, y, Gfx.FONT_XTINY, controller.status, Gfx.TEXT_JUSTIFY_CENTER);
        y += line + 4;

        if (!controller.isPaired()) {
            drawPairing(dc, width, y, line);
            return;
        }
        if (controller.confirmingCompletion) {
            drawCompletionConfirm(dc, width, y, line);
            return;
        }
        if (controller.mode.equals("account")) {
            drawAccount(dc, width, y, line);
            return;
        }
        if (controller.activeItems().size() == 0) {
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(width / 2, y + line, Gfx.FONT_SMALL, controller.mode.equals("projects") ? "No projects" : "No open tasks", Gfx.TEXT_JUSTIFY_CENTER);
            dc.drawText(width / 2, y + line * 3, Gfx.FONT_XTINY, "Select to refresh", Gfx.TEXT_JUSTIFY_CENTER);
            return;
        }
        drawItems(dc, width, y, line, compact);
    }

    function drawItems(dc, width, y, line, compact) {
        var items = controller.activeItems();
        var visible = compact ? 3 : 4;
        var start = controller.selected - 1;
        if (start < 0) {
            start = 0;
        }
        for (var row = 0; row < visible && start + row < items.size(); row += 1) {
            var index = start + row;
            var item = items[index];
            if (index == controller.selected) {
                dc.setColor(accentColor(dc), Gfx.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            }
            var label = controller.mode.equals("projects") ? item["name"] : item["title"];
            if (label == null) {
                label = "Untitled";
            }
            dc.drawText(10, y + row * line, Gfx.FONT_XTINY, (index == controller.selected ? "> " : "  ") + label, Gfx.TEXT_JUSTIFY_LEFT);
        }
    }

    function drawCompletionConfirm(dc, width, y, line) {
        var task = controller.tasks[controller.selected];
        dc.setColor(accentColor(dc), Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, y, Gfx.FONT_SMALL, "Complete?", Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, y + line * 2, Gfx.FONT_XTINY, task["title"], Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, y + line * 4, Gfx.FONT_XTINY, "Select confirm", Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, y + line * 5, Gfx.FONT_XTINY, "Back cancel", Gfx.TEXT_JUSTIFY_CENTER);
    }

    function drawAccount(dc, width, y, line) {
        dc.setColor(accentColor(dc), Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, y + line, Gfx.FONT_SMALL, controller.confirmingUnpair ? "Unpair?" : "Unpair watch", Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, y + line * 3, Gfx.FONT_XTINY, controller.confirmingUnpair ? "Select confirm" : "Select", Gfx.TEXT_JUSTIFY_CENTER);
        if (controller.confirmingUnpair) {
            dc.drawText(width / 2, y + line * 4, Gfx.FONT_XTINY, "Back cancel", Gfx.TEXT_JUSTIFY_CENTER);
            if (controller.queue.size() > 0) {
                dc.drawText(width / 2, y + line * 5, Gfx.FONT_XTINY, "Drops " + controller.queue.size().format("%d") + " pending", Gfx.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    function drawPairing(dc, width, y, line) {
        var code = controller.store.getUserCode();
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        if (code == null) {
            dc.drawText(width / 2, y + line, Gfx.FONT_SMALL, "Select to pair", Gfx.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(width / 2, y, Gfx.FONT_XTINY, "Pairing page opened", Gfx.TEXT_JUSTIFY_CENTER);
            dc.setColor(accentColor(dc), Gfx.COLOR_TRANSPARENT);
            dc.drawText(width / 2, y + line, Gfx.FONT_LARGE, code, Gfx.TEXT_JUSTIFY_CENTER);
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(width / 2, y + line * 4, Gfx.FONT_XTINY, "Select after approval", Gfx.TEXT_JUSTIFY_CENTER);
        }
    }
}
