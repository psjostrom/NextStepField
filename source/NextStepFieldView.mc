import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class NextStepFieldView extends WatchUi.DataField {

    hidden var mStepName as String = "";
    hidden var mHrRange as String = "";
    hidden var mDuration as String = "";
    hidden var mColor as Number = 0xFFFFFF;
    hidden var mHasStep as Boolean = false;

    function initialize() {
        DataField.initialize();
    }

    hidden function toNum(val) as Number {
        if (val instanceof Number) { return val; }
        if (val instanceof Float) { return val.toNumber(); }
        if (val instanceof Long) { return val.toNumber(); }
        if (val instanceof Double) { return val.toNumber(); }
        if (val instanceof String) { return val.toNumber(); }
        return 0;
    }

    function compute(info as Activity.Info) as Void {
        try {
            if (!(Activity has :getNextWorkoutStep)) { return; }
            var stepInfo = Activity.getNextWorkoutStep();
            if (stepInfo == null) {
                mHasStep = false;
                mStepName = "";
                mHrRange = "";
                mDuration = "";
                return;
            }
            mHasStep = true;

            // Step name: notes first (Garmin Connect), then name (Intervals.icu), then intensity
            mStepName = "";
            var step = stepInfo.step;
            try {
                if (stepInfo has :notes && stepInfo.notes != null) {
                    var n = stepInfo.notes.toString();
                    if (n.length() > 0) { mStepName = n.toUpper(); }
                }
            } catch (ex2) {}
            if (mStepName.length() == 0) {
                try {
                    if (stepInfo has :name && stepInfo.name != null) {
                        var n = stepInfo.name.toString();
                        if (n.length() > 0) { mStepName = n.toUpper(); }
                    }
                } catch (ex3) {}
            }
            if (mStepName.length() == 0) {
                mStepName = intensityLabel(stepInfo.intensity);
            }

            // HR range
            if (step has :targetType && step has :targetValueLow && step has :targetValueHigh) {
                var tt = toNum(step.targetType);
                if (tt == 1) {
                    var lo = step.targetValueLow;
                    var hi = step.targetValueHigh;
                    if (lo != null && hi != null) {
                        mHrRange = (toNum(lo) - 100) + "-" + (toNum(hi) - 100);
                    } else {
                        mHrRange = "";
                    }
                } else {
                    mHrRange = "";
                }
            } else {
                mHrRange = "";
            }

            // Next step total duration/distance
            if (step has :durationType && step has :durationValue && step.durationValue != null) {
                var dt = toNum(step.durationType);
                var dv = toNum(step.durationValue);
                if (dt == 0 && dv > 0) {
                    mDuration = formatCountdown(dv);
                } else if (dt == 1 && dv > 0) {
                    mDuration = formatDistance(dv.toFloat());
                } else {
                    mDuration = "";
                }
            } else {
                mDuration = "";
            }

            mColor = intensityColor(stepInfo.intensity);
        } catch (ex instanceof Lang.Exception) {
            mHasStep = false;
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        if (!mHasStep) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2,
                Graphics.FONT_TINY, "No next step",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var nameFont = Graphics.FONT_MEDIUM;
        var detailFont = Graphics.FONT_MEDIUM;
        var nameH = dc.getFontHeight(nameFont);
        var detailH = dc.getFontHeight(detailFont);

        var hasDetails = (mHrRange.length() > 0 || mDuration.length() > 0);
        var totalH = hasDetails ? nameH + detailH + 2 : nameH;
        var y = (h - totalH) / 2;

        dc.setColor(mColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, nameFont, mStepName, Graphics.TEXT_JUSTIFY_CENTER);
        y += nameH + 2;

        if (mHrRange.length() > 0 && mDuration.length() > 0) {
            var detail = mHrRange + "  " + mDuration;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, detailFont, detail, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (mHrRange.length() > 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, detailFont, mHrRange, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (mDuration.length() > 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, detailFont, mDuration, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function formatCountdown(seconds as Number) as String {
        var m = seconds / 60;
        var s = seconds % 60;
        return m + ":" + s.format("%02d");
    }

    hidden function formatDistance(meters as Float) as String {
        if (meters >= 1000.0f) {
            return (meters / 1000.0f).format("%.1f") + "km";
        }
        return meters.toNumber() + "m";
    }

    hidden function intensityColor(intensity) as Number {
        var i = toNum(intensity);
        if (i == 2 || i == 3) { return 0x55FF55; }
        if (i == 1 || i == 4) { return 0x00CCFF; }
        return 0xFF6666;
    }

    hidden function intensityLabel(intensity) as String {
        var i = toNum(intensity);
        if (i == 2) { return "WARMUP"; }
        if (i == 3) { return "COOLDOWN"; }
        if (i == 4) { return "RECOVERY"; }
        if (i == 1) { return "REST"; }
        return "RUN";
    }
}
