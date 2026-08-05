using Toybox.Graphics as Gfx;
using Toybox.WatchUi as Ui;

class TaskListView extends Ui.View {
    const CORAL = 0xFD4E5A;
    const KLEIN = 0x5A5CF5;
    const SURFACE = 0x1A1A1A;
    const TEXT = 0xD4D4D4;
    const MUTED = 0x999999;
    const HAIRLINE = 0x333333;
    const DANGER = 0xD9434E;

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
            return controller.projectName instanceof String ? controller.projectName : "Project";
        }
        if (controller.mode.equals("account")) {
            return "Account";
        }
        return "Today";
    }

    function isCompact(dc) {
        return dc.getWidth() <= 180 || dc.getHeight() <= 180;
    }

    function color(compact, rich, fallback) {
        return compact ? fallback : rich;
    }

    function statusLabel() {
        var status = controller.status;
        if (status.equals("synced") || status.equals("paired") || status.equals("reconciled")) {
            return "Synced";
        }
        if (status.equals("cached") || status.equals("offline_cache")) {
            return "Offline cache";
        }
        if (status.equals("syncing") || status.equals("loading_more") || status.equals("syncing_change") || status.equals("completing")) {
            return "Syncing";
        }
        if (status.equals("offline_queued") || (status.length() >= 14 && status.substring(0, 14).equals("offline_queue_"))) {
            return "Changes queued";
        }
        if (status.equals("unpaired")) {
            return "Not paired";
        }
        if (status.equals("pair_pending")) {
            return "Approval pending";
        }
        if (status.equals("pairing")) {
            return "Starting pairing";
        }
        if (status.equals("unpairing")) {
            return "Disconnecting";
        }
        if (status.equals("confirm_complete") || status.equals("confirm_unpair")) {
            return "Confirm action";
        }
        return "Needs attention";
    }

    function statusColor(compact) {
        var status = controller.status;
        if (status.equals("synced") || status.equals("paired") || status.equals("reconciled")) {
            return color(compact, KLEIN, Gfx.COLOR_WHITE);
        }
        if (status.equals("network_error") || status.equals("authorization_expired") || status.equals("completion_uncertain") || status.equals("change_rejected") || status.equals("queue_full") || status.equals("unpair_failed")) {
            return color(compact, DANGER, Gfx.COLOR_WHITE);
        }
        if (status.equals("syncing") || status.equals("loading_more") || status.equals("syncing_change") || status.equals("completing") || status.equals("pairing") || status.equals("unpairing") || status.equals("offline_queued")) {
            return color(compact, CORAL, Gfx.COLOR_WHITE);
        }
        return color(compact, MUTED, Gfx.COLOR_LT_GRAY);
    }

    function fitText(dc, text, font, maxWidth) {
        if (!(text instanceof String)) {
            return "Untitled";
        }
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) {
            return text;
        }
        var end = text.length();
        while (end > 1 && dc.getTextWidthInPixels(text.substring(0, end) + "...", font) > maxWidth) {
            end -= 1;
        }
        return text.substring(0, end) + "...";
    }

    function dueLabel(task) {
        var due = task["dueDate"];
        if (!(due instanceof String) || due.length() < 10) {
            return null;
        }
        if (controller.mode.equals("today")) {
            if (task["isAllDay"] == true || due.length() < 16) {
                return "All day";
            }
            return due.substring(11, 16);
        }
        return "Due  " + due.substring(5, 10);
    }

    function onUpdate(dc) {
        var compact = isCompact(dc);
        var background = color(compact, SURFACE, Gfx.COLOR_BLACK);
        dc.setColor(color(compact, TEXT, Gfx.COLOR_WHITE), background);
        dc.clear();

        if (compact) {
            drawCompact(dc);
            return;
        }

        drawHeader(dc, false);
        if (!controller.isPaired()) {
            drawPairing(dc, false);
            return;
        }
        if (controller.confirmingCompletion) {
            drawCompletionConfirm(dc, false);
            return;
        }
        if (controller.mode.equals("account")) {
            drawAccount(dc, false);
            return;
        }
        if (controller.activeItems().size() == 0) {
            drawEmpty(dc, false);
            return;
        }
        drawItems(dc, false);
    }

    function drawHeader(dc, compact) {
        var width = dc.getWidth();
        var top = compact ? 8 : dc.getHeight() / 12;
        var title = modeTitle();
        var titleFont = compact ? Gfx.FONT_XTINY : Gfx.FONT_SMALL;
        dc.setColor(color(compact, TEXT, Gfx.COLOR_WHITE), Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, top, titleFont, fitText(dc, title, titleFont, width - (compact ? 46 : width / 4)), Gfx.TEXT_JUSTIFY_CENTER);

        var statusY = top + dc.getFontHeight(titleFont) + (compact ? 1 : 2);
        var label = statusLabel();
        dc.setColor(statusColor(compact), Gfx.COLOR_TRANSPARENT);
        if (!compact) {
            var labelWidth = dc.getTextWidthInPixels(label, Gfx.FONT_XTINY);
            dc.fillCircle(width / 2 - labelWidth / 2 - 7, statusY + dc.getFontHeight(Gfx.FONT_XTINY) / 2, 3);
        }
        dc.drawText(width / 2 + (compact ? 0 : 5), statusY, Gfx.FONT_XTINY, label, Gfx.TEXT_JUSTIFY_CENTER);
    }

    function drawItems(dc, compact) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var items = controller.activeItems();
        var visible = 3;
        var margin = width / 7;
        var top = height / 12 + dc.getFontHeight(Gfx.FONT_SMALL) + dc.getFontHeight(Gfx.FONT_XTINY) + 14;
        var footer = 58;
        var rowHeight = (height - top - footer) / visible;
        if (rowHeight > 80) {
            rowHeight = 80;
        }
        if (rowHeight < 38) {
            rowHeight = 38;
        }
        var cardWidth = width - margin * 2;
        var start = controller.selected - 1;
        if (start < 0) {
            start = 0;
        }

        for (var row = 0; row < visible && start + row < items.size(); row += 1) {
            var index = start + row;
            var item = items[index];
            var cardY = top + row * rowHeight;
            var cardHeight = rowHeight - 6;
            var selected = index == controller.selected;
            if (selected) {
                dc.setColor(HAIRLINE, Gfx.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(margin, cardY, cardWidth, cardHeight, 10);
                dc.setColor(CORAL, Gfx.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(margin, cardY + 8, 4, cardHeight - 16, 2);
            } else {
                dc.setColor(HAIRLINE, Gfx.COLOR_TRANSPARENT);
                dc.drawLine(margin + 28, cardY + cardHeight, margin + cardWidth - 8, cardY + cardHeight);
            }

            var circleX = margin + 18;
            var centerY = cardY + cardHeight / 2;
            dc.setColor(selected ? CORAL : MUTED, Gfx.COLOR_TRANSPARENT);
            if (controller.mode.equals("projects")) {
                dc.drawText(circleX, centerY - dc.getFontHeight(Gfx.FONT_XTINY) / 2, Gfx.FONT_XTINY, ">", Gfx.TEXT_JUSTIFY_CENTER);
            } else {
                dc.drawRoundedRectangle(circleX - 6, centerY - 6, 12, 12, 3);
            }

            var label = controller.mode.equals("projects") ? item["name"] : item["title"];
            var due = controller.mode.equals("projects") ? null : dueLabel(item);
            var titleFont = Gfx.FONT_XTINY;
            var titleX = margin + 34;
            var titleWidth = cardWidth - 46;
            var titleY = due == null ? cardY + (cardHeight - dc.getFontHeight(titleFont)) / 2 : cardY + 2;
            dc.setColor(TEXT, Gfx.COLOR_TRANSPARENT);
            dc.drawText(titleX, titleY, titleFont, fitText(dc, label, titleFont, titleWidth), Gfx.TEXT_JUSTIFY_LEFT);
            if (due != null) {
                dc.setColor(MUTED, Gfx.COLOR_TRANSPARENT);
                dc.drawText(titleX, titleY + dc.getFontHeight(titleFont) - 1, Gfx.FONT_XTINY, due, Gfx.TEXT_JUSTIFY_LEFT);
            }
        }

        if (items.size() > visible) {
            var railX = width - margin + 3;
            var railTop = top + 4;
            var railLength = visible * rowHeight - 18;
            var thumbHeight = railLength * visible / items.size();
            if (thumbHeight < 14) {
                thumbHeight = 14;
            }
            var thumbY = railTop + (railLength - thumbHeight) * controller.selected / (items.size() - 1);
            dc.setColor(HAIRLINE, Gfx.COLOR_TRANSPARENT);
            dc.drawLine(railX, railTop, railX, railTop + railLength);
            dc.setColor(CORAL, Gfx.COLOR_TRANSPARENT);
            dc.drawLine(railX, thumbY, railX, thumbY + thumbHeight);
        }

        dc.setColor(MUTED, Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height - 66, Gfx.FONT_XTINY, "MENU", Gfx.TEXT_JUSTIFY_CENTER);
    }

    function drawCompact(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        drawHeader(dc, true);
        var line = dc.getFontHeight(Gfx.FONT_XTINY) + 2;
        var y = 8 + line * 2;
        if (!controller.isPaired()) {
            drawPairing(dc, true);
            return;
        }
        if (controller.confirmingCompletion) {
            drawCompletionConfirm(dc, true);
            return;
        }
        if (controller.mode.equals("account")) {
            drawAccount(dc, true);
            return;
        }
        var items = controller.activeItems();
        if (items.size() == 0) {
            drawEmpty(dc, true);
            return;
        }
        var start = controller.selected - 1;
        if (start < 0) {
            start = 0;
        }
        for (var row = 0; row < 3 && start + row < items.size(); row += 1) {
            var index = start + row;
            var item = items[index];
            var label = controller.mode.equals("projects") ? item["name"] : item["title"];
            dc.setColor(index == controller.selected ? Gfx.COLOR_WHITE : Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
            dc.drawText(8, y + row * line, Gfx.FONT_XTINY, (index == controller.selected ? "> " : "  ") + fitText(dc, label, Gfx.FONT_XTINY, width - 18), Gfx.TEXT_JUSTIFY_LEFT);
        }
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height - line, Gfx.FONT_XTINY, "MENU views", Gfx.TEXT_JUSTIFY_CENTER);
    }

    function drawEmpty(dc, compact) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var center = compact ? height / 2 : height / 2 - 8;
        dc.setColor(color(compact, CORAL, Gfx.COLOR_WHITE), Gfx.COLOR_TRANSPARENT);
        dc.drawCircle(width / 2, center - 18, compact ? 7 : 11);
        dc.setColor(color(compact, TEXT, Gfx.COLOR_WHITE), Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, center, compact ? Gfx.FONT_XTINY : Gfx.FONT_SMALL, controller.mode.equals("projects") ? "No projects" : "All clear", Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(color(compact, MUTED, Gfx.COLOR_LT_GRAY), Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, center + (compact ? 18 : 34), Gfx.FONT_XTINY, "SELECT refresh", Gfx.TEXT_JUSTIFY_CENTER);
    }

    function drawCompletionConfirm(dc, compact) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var task = controller.tasks[controller.selected];
        var center = compact ? height / 2 - 12 : height / 2 - 34;
        dc.setColor(color(compact, CORAL, Gfx.COLOR_WHITE), Gfx.COLOR_TRANSPARENT);
        dc.drawCircle(width / 2, center - (compact ? 16 : 34), compact ? 7 : 12);
        dc.setColor(color(compact, TEXT, Gfx.COLOR_WHITE), Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, center, compact ? Gfx.FONT_XTINY : Gfx.FONT_SMALL, "Complete task?", Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, center + (compact ? 18 : 38), Gfx.FONT_XTINY, fitText(dc, task["title"], Gfx.FONT_XTINY, width - (compact ? 20 : width / 4)), Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(color(compact, MUTED, Gfx.COLOR_LT_GRAY), Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, center + (compact ? 38 : 76), Gfx.FONT_XTINY, "SELECT confirm   ·   BACK cancel", Gfx.TEXT_JUSTIFY_CENTER);
    }

    function drawAccount(dc, compact) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var center = compact ? height / 2 - 10 : height / 2 - 32;
        dc.setColor(color(compact, DANGER, Gfx.COLOR_WHITE), Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, center, compact ? Gfx.FONT_XTINY : Gfx.FONT_SMALL, controller.confirmingUnpair ? "Disconnect?" : "Disconnect TickTick", Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(color(compact, TEXT, Gfx.COLOR_WHITE), Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, center + (compact ? 22 : 42), Gfx.FONT_XTINY, controller.confirmingUnpair ? "Removes this watch only" : "Keep cached tasks until confirmed", Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(color(compact, MUTED, Gfx.COLOR_LT_GRAY), Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, center + (compact ? 42 : 80), Gfx.FONT_XTINY, controller.confirmingUnpair ? "SELECT confirm   ·   BACK cancel" : "SELECT disconnect", Gfx.TEXT_JUSTIFY_CENTER);
        if (controller.confirmingUnpair && controller.queue.size() > 0) {
            dc.setColor(color(compact, DANGER, Gfx.COLOR_WHITE), Gfx.COLOR_TRANSPARENT);
            dc.drawText(width / 2, center + (compact ? 60 : 112), Gfx.FONT_XTINY, controller.queue.size().format("%d") + " queued change(s) will be lost", Gfx.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawPairing(dc, compact) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var code = controller.store.getUserCode();
        var center = compact ? height / 2 - 8 : height / 2 - 42;
        dc.setColor(color(compact, CORAL, Gfx.COLOR_WHITE), Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, center, compact ? Gfx.FONT_XTINY : Gfx.FONT_SMALL, code == null ? "Pair TickTick" : "Approve pairing", Gfx.TEXT_JUSTIFY_CENTER);
        if (code == null) {
            dc.setColor(color(compact, TEXT, Gfx.COLOR_WHITE), Gfx.COLOR_TRANSPARENT);
            dc.drawText(width / 2, center + (compact ? 22 : 44), Gfx.FONT_XTINY, "One-time setup in your browser", Gfx.TEXT_JUSTIFY_CENTER);
            dc.setColor(color(compact, CORAL, Gfx.COLOR_WHITE), Gfx.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(width / 2 - (compact ? 54 : 88), center + (compact ? 44 : 84), compact ? 108 : 176, compact ? 24 : 36, compact ? 6 : 10);
            dc.drawText(width / 2, center + (compact ? 47 : 90), Gfx.FONT_XTINY, "SELECT TO START", Gfx.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(color(compact, TEXT, Gfx.COLOR_WHITE), Gfx.COLOR_TRANSPARENT);
            dc.drawText(width / 2, center + (compact ? 22 : 46), compact ? Gfx.FONT_SMALL : Gfx.FONT_LARGE, code, Gfx.TEXT_JUSTIFY_CENTER);
            dc.setColor(color(compact, MUTED, Gfx.COLOR_LT_GRAY), Gfx.COLOR_TRANSPARENT);
            dc.drawText(width / 2, center + (compact ? 56 : 104), Gfx.FONT_XTINY, "SELECT after approval", Gfx.TEXT_JUSTIFY_CENTER);
        }
    }
}
