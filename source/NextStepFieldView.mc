import Toybox.Activity;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class NextStepFieldView extends WatchUi.DataField {

    hidden var mStepName as String = "";
    hidden var mHrRange as String = "";
    hidden var mDuration as String = "";
    hidden var mColor as Number = 0xFFFFFF;
    hidden var mHasStep as Boolean = false;

    // Rep tracking — we track CURRENT step transitions to count reps,
    // then display the NEXT step's upcoming rep number.
    hidden var mStepTotals as Dictionary = {};
    hidden var mStepCounts as Dictionary = {};
    hidden var mPrevCurrentName as String = "";

    // Fuel flash (visual only — StepField owns vibrate/tone)
    hidden const FUEL_INTERVAL_MS = 600000; // 10 min
    hidden var mLastFuelAlert as Number = 0;
    hidden var mFuelFlashUntil as Number = 0;

    function initialize() {
        DataField.initialize();
    }

    function onTimerStart() as Void {
        fetchStepTotals();
    }

    function onTimerResume() as Void {
        if (mStepTotals.isEmpty()) {
            fetchStepTotals();
        }
    }

    function onTimerReset() as Void {
        mHasStep = false;
        mStepTotals = {};
        mStepCounts = {};
        mPrevCurrentName = "";
        mLastFuelAlert = 0;
        mFuelFlashUntil = 0;
    }

    hidden function fetchStepTotals() as Void {
        var url = Secrets.SPRINGA_URL;
        var secret = Secrets.SPRINGA_SECRET;
        if (url.equals("") || secret.equals("")) { return; }

        Communications.makeWebRequest(
            url + "/api/workout-steps",
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => { "api-secret" => secret },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onStepTotalsReceive)
        );
    }

    function onStepTotalsReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (responseCode != 200 || data == null || !(data instanceof Dictionary)) {
            return;
        }
        mStepTotals = data as Dictionary;
    }

    hidden function toNum(val) as Number {
        if (val instanceof Number) { return val; }
        if (val instanceof Float) { return val.toNumber(); }
        if (val instanceof Long) { return val.toNumber(); }
        if (val instanceof Double) { return val.toNumber(); }
        if (val instanceof String) { return val.toNumber(); }
        return 0;
    }

    hidden function resolveStepName(stepInfo as Activity.WorkoutStepInfo) as String {
        var name = "";
        try {
            if (stepInfo has :notes && stepInfo.notes != null) {
                var n = stepInfo.notes.toString();
                if (n.length() > 0) { name = n.toUpper(); }
            }
        } catch (ex) {}
        if (name.length() == 0) {
            try {
                if (stepInfo has :name && stepInfo.name != null) {
                    var n = stepInfo.name.toString();
                    if (n.length() > 0) { name = n.toUpper(); }
                }
            } catch (ex) {}
        }
        if (name.length() == 0) {
            name = intensityLabel(stepInfo.intensity);
        }
        return name;
    }

    function compute(info as Activity.Info) as Void {
        try {
            // Track current step name changes for rep counting
            if (Activity has :getCurrentWorkoutStep) {
                var currentInfo = Activity.getCurrentWorkoutStep();
                if (currentInfo != null) {
                    var currentName = resolveStepName(currentInfo);
                    if (!currentName.equals(mPrevCurrentName)) {
                        var count = mStepCounts.hasKey(currentName) ? (mStepCounts[currentName] as Number) + 1 : 1;
                        mStepCounts[currentName] = count;
                        mPrevCurrentName = currentName;
                    }
                }
            }

            // Resolve next step info
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

            var rawName = resolveStepName(stepInfo);

            // Next step rep = completed count + 1 (the upcoming one)
            if (mStepTotals.hasKey(rawName)) {
                var completed = mStepCounts.hasKey(rawName) ? (mStepCounts[rawName] as Number) : 0;
                mStepName = rawName + " " + (completed + 1) + "/" + toNum(mStepTotals[rawName]);
            } else {
                mStepName = rawName;
            }

            // HR range
            var step = stepInfo.step;
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

            mColor = intensityColor(stepInfo.intensity, mStepName);

            // Fuel flash tracking (visual only — no vibrate/tone)
            if (info.timerTime != null) {
                var now = toNum(info.timerTime);
                if (now - mLastFuelAlert >= FUEL_INTERVAL_MS) {
                    mLastFuelAlert = now;
                    mFuelFlashUntil = now + 5000;
                }
            }
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

        // Flash "FUEL" for 5 seconds after alert
        var showFuel = false;
        try {
            var ai = Activity.getActivityInfo();
            if (ai != null && ai.timerTime != null && mFuelFlashUntil > 0) {
                showFuel = toNum(ai.timerTime) < mFuelFlashUntil;
            }
        } catch (ex4) {}

        if (showFuel) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2,
                Graphics.FONT_LARGE, "FUEL",
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

    hidden function intensityColor(intensity, name as String) as Number {
        if (name.find("EASY") != null || name.find("DOWNHILL") != null) { return 0x00CCFF; }
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
