//(c) 2016 - Steve Laming
//
// Contact : steve@stevel05.com
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

//
//Canvas version
//

import QtQuick 2.3
import QtQuick.Controls 1.2
import FileIO 1.0
import QtQuick.Window 2.2
import QtQuick.Controls.Styles 1.0
import MuseScore 1.0
import Qt.labs.settings 1.0
import QtQuick.Dialogs 1.2

MuseScore {
    description : "Simple overview of a score showing populated and empty measures time signatures and  rehearsal marks.  Allows jumping to a measure in a part and selecting of measures or ranges."
    menuPath : "Plugins.scoreOverView"

    property var selectedElement : null
    property var selectedPart : null
    property var measureTicks : ([])
    property var timers : ({})
    property var settings : ({})
    property var trackMeasures : ([])

    pluginType : "dock"
    dockArea : "bottom"

    // onRun : {

    // }
    Settings {
        id : settings
        category : "pluginSettings"
        property bool showMeasures : true
        property bool showKeyChanges : true
        property bool showTempo : true
        property bool showTempoMarks : false
        property bool showTimeSig : true
        property bool showRMarks : true
    }

    ScrollView {
        id : mainScrollView
        width : parent.parent ? parent.parent.width - 15 : 1000
        height : parent.parent ? parent.parent.height : 150
        property var pressed : false

        __horizontalScrollBar.onHandlePressedChanged : {
            pressed = !pressed;
            if (pressed) {
                canvasPartNames.visible = true;
            } else {
                canvasPartNames.visible = false;
            }
        }
        __horizontalScrollBar.onValueChanged : {
            canvasPartNames.x = __horizontalScrollBar.value + 5;
        }

        Rectangle {
            id : mainBg

            property var col1Width : 60
            property var col2Width : 75
            color : "#e0e0e0"

            property var column1 : ([])
            property var rows : {
                var r = [];
                r[0] = [];
                return r;
            }
            property var rMarks : ([])
            property var timeSigs : ([])
            property var tempos : ([])
            property var tempoMarks : ([])
            property var keyChanges : ([])
            property var measureHdr : ([])
            property var lastMeasureHdr : null
            property var lblTags : ([])
            property var dataArea : ({
                x : 0,
                y : 0,
                width : 0,
                height : 0
            })
            property var headersVisible : (settings.showMeasures ? 1 : 0) + (settings.showKeyChanges ? 1 : 0) + (settings.showTempo ? 1 : 0) + (settings.showTempoMarks ? 1 : 0) + (settings.showTimeSig ? 1 : 0) + (settings.showRMarks ? 1 : 0)

            x : 0
            y : 0
            width : 85 + (rows[0].length * canvasMain.rowHeight)
            height : canvasMain.itemColumnWidth * (rows.length + headersVisible)
            function setSize() {
                // canvasMain.clearCanvas = true;
                // canvasMain.requestPaint();
                // delay(1000, function () {
                mainBg.width = 85 + ((mainBg.rows[0].length - 1) * canvasMain.rowHeight);
                mainBg.height = canvasMain.itemColumnWidth * (mainBg.rows.length + headersVisible);
                canvasMain.requestPaint();
                // });
            }
            MouseArea {
                id : maRefresh
                anchors.fill : parent
                onClicked : {
                    canvasHighlight.clearHighlight();
                    buildViewModels();
                    scoreInfo.tooltip = "Score " + curScore.name + " : Dur. " + formatTime(curScore.duration);
                }

                MouseArea {
                    anchors.fill : parent
                    propagateComposedEvents : true
                    property var pressed : ({})
                    onClicked : {
                        if (mouse.x < mainBg.dataArea.x || mouse.y < mainBg.dataArea.y) {
                            mouse.accepted = false;
                            return;
                        }
                    }
                    onPressed : {

                        if (mouse.x < mainBg.dataArea.x || mouse.y < mainBg.dataArea.y) {
                            return;
                        }
                        canvasHighlight.selecting = true;
                        var measure = Math.floor((mouse.x - mainBg.dataArea.x) / canvasMain.itemColumnWidth);
                        var part = Math.floor((mouse.y - mainBg.dataArea.y) / canvasMain.rowHeight);
                        pressed = {
                            measure : measure,
                            part : part
                        }
                        canvasHighlight.selectedRect = {
                            x : measure * canvasMain.itemColumnWidth,
                            y : part * canvasMain.rowHeight,
                            width : canvasMain.itemColumnWidth,
                            height : canvasMain.rowHeight
                        }
                        canvasHighlight.requestPaint();

                    }
                    onPositionChanged : {

                        //Scroll content
                        if (mouse.y > mainScrollView.height + mainScrollView.flickableItem.contentY - mainScrollView.__horizontalScrollBar.height && mouse.y < mainScrollView.flickableItem.contentHeight) {
                            mainScrollView.flickableItem.contentY += canvasMain.rowHeight;
                        }

                        if (mouse.y < mainScrollView.flickableItem.contentY) {
                            mainScrollView.flickableItem.contentY = Math.max(mainScrollView.flickableItem.contentY - canvasMain.rowHeight, 0);
                        }

                        if (mouse.x > mainScrollView.width + mainScrollView.flickableItem.contentX - mainScrollView.__verticalScrollBar.width && mouse.x < mainScrollView.flickableItem.contentWidth) {
                            mainScrollView.flickableItem.contentX += canvasMain.itemColumnWidth;
                        }

                        if (mouse.x < mainScrollView.flickableItem.contentX && mainScrollView.flickableItem.contentX > 0) {
                            mainScrollView.flickableItem.contentX = Math.max(mainScrollView.flickableItem.contentX - canvasMain.itemColumnWidth, 0);
                        }

                        if (mouse.x < mainBg.dataArea.x || mouse.y < mainBg.dataArea.y || mouse.x > mainBg.dataArea.x + mainBg.dataArea.width || mouse.y > mainBg.dataArea.y + mainBg.dataArea.height) {
                            return;
                        }

                        var measure = Math.floor((mouse.x - mainBg.dataArea.x) / canvasMain.itemColumnWidth);
                        var part = Math.floor((mouse.y - mainBg.dataArea.y) / canvasMain.rowHeight);

                        var startPart = Math.min(pressed.part, part);
                        var endPart = Math.max(pressed.part, part);
                        var startMeasure = Math.min(pressed.measure, measure);
                        var endMeasure = Math.max(pressed.measure, measure);

                        canvasHighlight.selectedRect = {
                            x : startMeasure * canvasMain.itemColumnWidth,
                            y : startPart * canvasMain.rowHeight,
                            width : (1 + endMeasure - startMeasure) * canvasMain.itemColumnWidth,
                            height : (1 + endPart - startPart) * canvasMain.rowHeight
                        }
                        canvasHighlight.requestPaint();

                    }
                    onReleased : {
                        if (mouse.x < mainBg.dataArea.x || mouse.y < mainBg.dataArea.y || mouse.x > mainBg.dataArea.x + mainBg.dataArea.width || mouse.y > mainBg.dataArea.y + mainBg.dataArea.height) {
                            canvasHighlight.clearHighlight();
                            return;
                        }

                        var measure = Math.floor((mouse.x - mainBg.dataArea.x) / canvasMain.itemColumnWidth);
                        var part = Math.floor((mouse.y - mainBg.dataArea.y) / canvasMain.rowHeight);

                        if (pressed.measure == measure && pressed.part == part) {
                            if (mouse.modifiers & Qt.ControlModifier) {
                                cmd("escape");
                                cmd("escape");
                                delay(150, function () {
                                    locatePartMeasure(part, measure);
                                    selectPartMeasures(part, measure, part, measure);
                                });
                            } else {
                                cmd("escape");
                                cmd("escape");
                                delay(150, function () {
                                    locatePartMeasure(part, measure);
                                });
                            }
                        } else {
                            var startPart = Math.min(pressed.part, part);
                            var endPart = Math.max(pressed.part, part);
                            var startMeasure = Math.min(pressed.measure, measure);
                            var endMeasure = Math.max(pressed.measure, measure);
                            cmd("escape");
                            cmd("escape");
                            delay(150, function () {
                                locatePartMeasure(startPart, startMeasure);
                                selectPartMeasures(startPart, startMeasure, endPart, endMeasure);
                            });
                        }

                        canvasHighlight.selecting = false;
                        canvasHighlight.requestPaint();

                    }
                }
            }
            Canvas {
                anchors.fill : parent
                id : canvasMain
                property var rowHeight : 15
                property var column1Width : 60
                property var itemColumnWidth : 15
                property var textSize : 8.5

                onPaint : {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, canvasMain.width, canvasMain.height);

                    var x = 5;
                    var y = 0;

                    ctx.font = textSize + "pt sans-serif";
                    ctx.textAlign = "center";
                    ctx.textBaseline = "top";
                    ctx.strokeStyle = "DarkGray"

                        var centerTextX = x + (column1Width / 2);

                    var titles = ["Measures", "Key Change", "Tempo", "Tempo M", "Time Sig", "R. Marks"]
                    var show = [settings.showMeasures, settings.showKeyChanges, settings.showTempo, settings.showTempoMarks, settings.showTimeSig, settings.showRMarks]

                    //Column 1

                    //Column Titles
                    var rowCount = 0;
                    for (var i = 0; i < titles.length; i++) {
                        if (show[i]) {
                            y = rowCount * rowHeight;
                            ctx.fillStyle = "DarkGray";
                            ctx.fillRect(x, y, column1Width, rowHeight)
                            ctx.fillStyle = "Black";
                            ctx.fillText(titles[i], centerTextX, y)
                            rowCount++;
                        }
                    }
                    //Instrument Names
                    for (var i = 0; i < mainBg.column1.length; i++) {
                        y = (rowCount + i) * rowHeight;
                        ctx.fillStyle = "LightGray";
                        ctx.fillRect(x, y, column1Width, rowHeight)
                        ctx.fillStyle = "Black";
                        ctx.fillText(mainBg.column1[i].name, centerTextX, y)
                    }

                    //Rows

                    //Measures
                    y = 0;
                    var xOffset = 70 + itemColumnWidth / 2;
                    if (settings.showMeasures) {
                        for (var i = 0; i < mainBg.measureHdr.length; i++) {
                            x = xOffset + mainBg.measureHdr[i] * itemColumnWidth;
                            ctx.fillText(mainBg.measureHdr[i] + 1, x, y)
                        }
                        y += rowHeight;
                    }
                    xOffset = 70;
                    if (settings.showKeyChanges) {
                        for (var i = 0; i < mainBg.keyChanges.length; i++) {
                            x = xOffset + mainBg.keyChanges[i].measure * itemColumnWidth;
                            var tm = textMetrics(mainBg.keyChanges[i].text, ctx.font, mainBg, "Transparent");
                            ctx.fillStyle = "White";
                            ctx.fillRect(x, y, tm.width, tm.height);
                            ctx.strokeRect(x, y, tm.width, tm.height)
                            ctx.fillStyle = "Black";
                            ctx.fillText(mainBg.keyChanges[i].text, x + tm.width / 2, y)
                        }
                        y += rowHeight;
                    }

                    //Tempo Text
                    if (settings.showTempo) {
                        ctx.textAlign = "left";
                        for (var i = 0; i < mainBg.tempos.length; i++) {
                            x = xOffset + mainBg.tempos[i].measure * itemColumnWidth;
                            ctx.fillText(mainBg.tempos[i].text, x, y)
                        }
                        y += rowHeight;
                    }
                    //Tempo Text
                    if (settings.showTempoMarks) {
                        ctx.textAlign = "center";
                        for (var i = 0; i < mainBg.tempoMarks.length; i++) {
                            x = xOffset + mainBg.tempoMarks[i].measure * itemColumnWidth;
                            var tm = textMetrics(mainBg.tempoMarks[i].text, ctx.font, mainBg, "Transparent")
                                ctx.fillStyle = "White";
                            ctx.fillRect(x, y, tm.width, tm.height);
                            ctx.strokeRect(x, y, tm.width, tm.height)
                            ctx.fillStyle = "Black";
                            ctx.fillText(mainBg.tempoMarks[i].text, x + tm.width / 2, y)
                        }
                        y += rowHeight;
                    }
                    //Time Sig
                    if (settings.showTimeSig) {
                        ctx.textAlign = "center";
                        for (var i = 0; i < mainBg.timeSigs.length; i++) {
                            x = xOffset + mainBg.timeSigs[i].measure * itemColumnWidth;
                            var tm = textMetrics(mainBg.timeSigs[i].text, ctx.font, mainBg, "Transparent")
                                ctx.fillStyle = "White";
                            ctx.fillRect(x, y, tm.width, tm.height);
                            ctx.strokeRect(x, y, tm.width, tm.height)
                            ctx.fillStyle = "Black";
                            ctx.fillText(mainBg.timeSigs[i].text, x + tm.width / 2, y)
                        }
                        y += rowHeight;
                    }
                    //Rehearsal Marks
                    if (settings.showRMarks) {
                        ctx.textAlign = "center";
                        for (var i = 0; i < mainBg.rMarks.length; i++) {
                            x = xOffset + mainBg.rMarks[i].measure * itemColumnWidth;
                            var tm = textMetrics(mainBg.rMarks[i].text, ctx.font, mainBg, "Transparent");
                            ctx.fillStyle = "White";
                            x = x + (itemColumnWidth - tm.width) / 2;
                            ctx.fillRect(x, y, tm.width, tm.height);
                            ctx.strokeRect(x, y, tm.width, tm.height)
                            ctx.fillStyle = "Black";
                            ctx.fillText(mainBg.rMarks[i].text, x + tm.width / 2, y)
                        }
                        y += rowHeight;
                    }

                    var dataY = y;
                    //RowData

                    for (var i = 0; i < mainBg.rows.length; i++) {
                        for (var j = 0; j < mainBg.rows[i].length; j++) {
                            x = xOffset + j * itemColumnWidth;
                            if (mainBg.rows[i][j].hasNotes) {
                                ctx.fillRect(x + 1, y + 1, itemColumnWidth - 1, rowHeight - 1);
                            }
                        }
                        y += rowHeight;
                    }

                    // Draw boxes
                    y = dataY;
                    ctx.strokeStyle = "DarkGray"
                        ctx.beginPath()
                        for (var i = 0; i <= mainBg.rows.length; i++) {
                            ctx.moveTo(xOffset, y);
                            ctx.lineTo(parent.width, y)
                            y += rowHeight;
                        }
                        x = xOffset;
                    for (var i = 0; i <= mainBg.rows[0].length; i++) {
                        ctx.moveTo(x, dataY);
                        ctx.lineTo(x, parent.height)
                        x += itemColumnWidth;
                    }

                    ctx.stroke();

                    mainBg.dataArea = {
                        x : xOffset,
                        y : dataY,
                        width : parent.width - xOffset,
                        height : parent.height - dataY
                    };
                    canvasPartNames.requestPaint();
                }
            }
            Canvas {
                anchors.fill : parent
                id : canvasHighlight
                property var selectedRect : ({
                    x : 0,
                    y : 0,
                    width : 0,
                    height : 0
                })
                property var selecting : false;
                function clearHighlight() {
                    selecting = false;
                    selectedRect.width = 0;
                    selectedRect.height = 0;
                    requestPaint();
                }
                onPaint : {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, parent.width, parent.height);
                    if (selecting) {
                        ctx.fillStyle = 'rgba(0,0,255,0.4)';
                    } else {
                        ctx.fillStyle = 'rgba(255,255,0,0.4)';
                    }
                    ctx.fillRect(mainBg.dataArea.x + selectedRect.x, mainBg.dataArea.y + selectedRect.y, selectedRect.width, selectedRect.height);
                }
            }
            Canvas {

                id : canvasPartNames
                x : 5
                y : mainBg.dataArea.y
                width : canvasMain.column1Width
                height : mainBg.dataArea.height
                visible : false
                onPaint : {
                    var ctx = getContext("2d");
                    ctx.font = canvasMain.textSize + "pt sans-serif";
                    ctx.textAlign = "center";
                    ctx.textBaseline = "top";
                    //Instrument Names
                    var x = 0;
                    var y = 0;
                    var centerTextX = (canvasMain.column1Width / 2);
                    for (var i = 0; i < mainBg.column1.length; i++) {
                        y = i * canvasMain.rowHeight;
                        ctx.fillStyle = "rgba(211,211,211,0.8)"; ;
                        ctx.fillRect(x, y, canvasMain.column1Width, canvasMain.rowHeight)
                        ctx.fillStyle = "rgba(0,0,0,0.9)";
                        ctx.fillText(mainBg.column1[i].name, centerTextX, y)
                    }

                }
            }
        }
    }
    Component.onCompleted : init();
    Button {
        id : btnToggleMeas
        height : canvasMain.rowHeight
        width : 10
        anchors.left : mainScrollView.right
        tooltip : "Show / hide measures"
        property var hdrVisible : settings.showMeasures
        text : hdrVisible ? "-" : "+"
        onClicked : {
            hdrVisible = !hdrVisible;
            settings.showMeasures = hdrVisible;
            text = hdrVisible ? "-" : "+";
            mainBg.setSize();
        }
    }
    Button {
        id : btnToggleKC
        height : canvasMain.rowHeight
        width : 10
        anchors.left : mainScrollView.right
        y : 15
        tooltip : "Show / hide key signatures"
        property var kcVisible : settings.showKeyChanges
        text : kcVisible ? "-" : "+"
        onClicked : {
            kcVisible = !kcVisible;
            text : kcVisible ? "-" : "+"
            settings.showKeyChanges = kcVisible;
            mainBg.setSize();
        }

    }
    Button {
        id : btnToggleTO
        height : canvasMain.rowHeight
        width : 10
        anchors.left : mainScrollView.right
        y : 30
        tooltip : "Show / hide tempo text"
        property var toVisible : settings.showTempo
        text : toVisible ? "-" : "+"
        onClicked : {
            toVisible = !toVisible;
            text : toVisible ? "-" : "+"
            settings.showTempo = toVisible;
            mainBg.setSize();
        }

    }
    Button {
        id : btnToggleTM
        height : canvasMain.rowHeight
        width : 10
        anchors.left : mainScrollView.right
        y : 45
        tooltip : "Show / hide tempo marks"
        property var tmVisible : settings.showTempoMarks
        text : tmVisible ? "-" : "+"
        onClicked : {
            tmVisible = !tmVisible;
            text : tmVisible ? "-" : "+"
            settings.showTempoMarks = tmVisible;
            mainBg.setSize();
        }

    }

    Button {
        id : btnToggleTS
        height : canvasMain.rowHeight
        width : 10
        anchors.left : mainScrollView.right
        y : 60
        tooltip : "Show / hide time Sigs"
        property var tsVisible : settings.showTimeSig
        text : tsVisible ? "-" : "+"
        onClicked : {
            tsVisible = !tsVisible;
            text : tsVisible ? "-" : "+"
            settings.showTimeSig = tsVisible;
            mainBg.setSize();
        }

    }
    Button {
        id : btnToggleRM
        height : canvasMain.rowHeight
        width : 10
        anchors.left : mainScrollView.right
        y : 75
        tooltip : "Show / hide rehearsal marks"
        property var rmVisible : settings.showRMarks
        text : rmVisible ? "-" : "+"
        onClicked : {
            rmVisible = !rmVisible;
            text : rmVisible ? "-" : "+"
            settings.showRMarks = rmVisible;
            mainBg.setSize();
        }

    }

    Button {
        id : scoreInfo
        anchors.left : mainScrollView.right
        anchors.bottom : mainScrollView.bottom
        width : 10
        text : "i"
        style : ButtonStyle {
            background : Rectangle {
                anchors.fill : parent
                border.width : 1
                border.color : "#888"
                radius : 4
                color : "#eee"
            }
            label : Label {
                color : "Blue";
                font.pointSize : 12
                text : "i"
            }
        }
        tooltip : "Score " + curScore.name + " : Dur. " + formatTime(curScore.duration)
    }

    //
    //@ functions
    //
    function init() {
        buildViewModels();
    }
    function textMetrics(text, font, oParent, color) {
        var txt = Qt.createQmlObject("import QtQuick 2.3; Text {}", oParent);
        txt.color = color;
        txt.text = text;
        txt.font = font;
        delay(0, txt.destroy)
        return {
            width : txt.width,
            height : txt.height
        }
    }

    function buildViewModels() {

        //Refresh the measure ticks
        getMeasureTicks();

        var m = [];
        var rows = [];
        trackMeasures = [];

        var initTm = [];
        var initRm = [];
        for (var i = 0; i < curScore.nmeasures; i++) {
            initTm.push(0);
            initRm.push({
                hasNotes : false,
                done : false
            });
        }

        for (var i = 0; i < curScore.ntracks; i++) {
            trackMeasures[i] = initTm.slice(0);
        }

        //Update the column model with data we need later.
        for (var i = 0; i < curScore.parts.length; i++) {
            m.push({
                name : curScore.parts[i].shortName,
                startTrack : curScore.parts[i].startTrack,
                endTrack : curScore.parts[i].endTrack
            })
            //Initialize as 2d arrays
            rows[i] = initRm.slice(0);
        }
        mainBg.column1 = m;

        var curMeasure =  - 1;
        var hasNotes = false;
        var measureDone = false;
        var rMarks = [];
        var timeSigs = [];
        var keyChanges = [];
        var tempos = [];
        var tempoMarks = [];

        var measure = curScore.firstMeasure;
        while (measure) {
            var seg = measure.firstSegment;
            while (seg) {
                curMeasure = currentMeasure(seg.tick);
                if (seg.segmentType == Segment.TimeSig) {
                    timeSigs.push({
                        measure : curMeasure,
                        text : seg.elementAt(0).numerator + "/" + seg.elementAt(0).denominator
                    });
                }

                //Store the measure and text of the rehearsal marks.
                if (seg.annotations.length < 1000) {
                    for (var i = 0; i < seg.annotations.length; i++) {
                        if (seg.annotations[i].type == Element.REHEARSAL_MARK) {
                            rMarks.push({
                                measure : curMeasure,
                                text : seg.annotations[i].text.replace(/<[^>]*>?/g, "")
                            })
                        }
                        //Tempos
                        if (seg.annotations[i].type == Element.TEMPO_TEXT) {
                            var text = "";
                            var parts = seg.annotations[i].text.split("=");
                            switch (true) {
                            case parts[0].indexOf("Quarter") > -1:
                                text += "4";
                                break;
                            case parts[0].indexOf("Half") > -1:
                                text += "2";
                                break;

                            case parts[0].indexOf("8th") > -1:
                                text += "8";
                                break;
                            }
                            if (parts[0].indexOf("Dot") > -1) {
                                text += ".";
                            }
                            text += " = " + parts[1]
                            tempoMarks.push({
                                measure : curMeasure,
                                text : text
                            })
                        }
                        //Tempos
                        if (seg.annotations[i].type == Element.STAFF_TEXT && seg.annotations[i].textStyleType == 16) {
                            tempos.push({
                                measure : curMeasure,
                                text : seg.annotations[i].text
                            })
                        }
                    }
                } else {
                    console.log("Could not read annotations @ measure", curMeasure + 1,"Tick",seg.tick,"Annotation length = ", seg.annotations.length);
                }
                //Cannot yet get key signatures.
                if (seg.segmentType == Segment.KeySig) {
                    keyChanges.push({
                        measure : curMeasure,
                        text : "KS"
                    })
                }

                //For each part, store whether each measure has notes, and on which tracks.  Used for the automated selection in selectPartMeasures.
                for (var i = 0; i < curScore.parts.length; i++) {
                    var partData = curScore.parts[i];
                    hasNotes = rows[i][curMeasure].hasNotes;
                    measureDone = rows[i][curMeasure].done;
                    if (!(measureDone && hasNotes)) {
                        for (var j = partData.startTrack; j < partData.endTrack; j++) {

                            if (seg.elementAt(j) && (seg.elementAt(j).type == Element.CHORD || seg.elementAt(j).type == Element.REST)) {
                                //Drives the selection routines, if a track has more than 1 rest or note.
                                trackMeasures[j][curMeasure]++;
                                if (trackMeasures[j][curMeasure] > 1 && curMeasure + 1 != curScore.nmeasures) {
                                    measureDone = true;
                                }

                                //Drives the GUI image, shaded if part hasNotes
                                if (seg.elementAt(j).type == Element.CHORD) {
                                    hasNotes = true;
                                }
                            }

                            //Drives the GUI image, shaded if part hasNotes
                            rows[i][curMeasure] = {
                                hasNotes : hasNotes,
                                done : measureDone
                            };
                            if (measureDone && hasNotes) {
                                break;
                            }

                        }
                    }
                }
                seg = seg.next;
                //finished with this measure
                if (seg.tick >= measure.lastSegment.tick) {
                    break;
                }
            }
            measure = measure.nextMeasure;
        }
        mainBg.rows = [];
        for (var i = 0; i < rows.length; i++) {
            mainBg.rows[i] = rows[i];
        }
        mainBg.rMarks = rMarks;
        mainBg.timeSigs = timeSigs;
        mainBg.tempos = tempos;
        mainBg.tempoMarks = tempoMarks;
        mainBg.keyChanges = keyChanges;
        mainBg.measureHdr = [];

        if (measureTicks.length < 99) {
            for (var i = 0; i < measureTicks.length - 1; i++) {
                mainBg.measureHdr.push(i);
            }
        } else {
            mainBg.measureHdr.push(0)
            for (var i = 4; i < measureTicks.length - 1; i += 5) {
                mainBg.measureHdr.push(i);
            }
        }
        mainBg.setSize();
    }

    //Move the cursor to the specified tick in the score.
    function positionCursor(cursor, targetTick) {
        cursor.rewind(0);
        while (cursor.tick < targetTick) {
            cursor.next();
        }
    }

    //
    //Build an index of the first tick of each measure.
    //
    function getMeasureTicks() {
        measureTicks = [];
        measureTicks.push(0);
        var cur = curScore.newCursor();
        cur.rewind(0);
        while (cur.nextMeasure()) {
            measureTicks.push(cur.segment.tick);
        }
        //
        //Add the last tick of the score
        //
        measureTicks.push(curScore.lastSegment.tick);

    }
    //
    //Return the measure the tick is in
    //
    function currentMeasure(tick) {
        //
        //measureTicks also holds the last tick of the score so we shouldn' t compare against that.
        //
        for (var i = measureTicks.length - 2; i >= 0; i--) {
            if (tick >= measureTicks[i])
                return i;
        }
        return -1;
    }
    //
    //Move the scores selection to the first element in the part / measure
    //
    function locatePartMeasure(part, measure) {
        if (measure > curScore.nmeasures / 2) {
            cmd("first-element");
            cmd("next-chord");
            cmd("select-end-score");

            cmd("prev-chord");

            cmd("prev-measure");
            cmd("next-measure");
            cmd("next-measure");

            var i = curScore.nmeasures - 1;
            while (measure < i) {
                cmd("prev-measure");
                i--;
            }
        } else {
            cmd("first-element");
            cmd("next-measure");
            cmd("prev-measure");
            var i = 0;
            while (i < measure) {
                cmd("next-measure");
                i++;
            }
        }

        //next track command actually does next staff or voice, so we need to know how many voices and staves are in each part at this measure.
        var staff = 0;

        for (var i = 0; i < part; i++) {
            var partObj = curScore.parts[i];
            var tracks = 0;
            for (var j = partObj.startTrack; j < partObj.endTrack; j++) {
                tracks += trackMeasures[j][measure] > 0 ? 1 : 0;
            }
            staff += tracks;
        }

        for (var i = 0; i < staff; i++) {
            cmd("next-track");
        }

    }

    //
    //Select a range from the existing selection position.
    //
    function selectPartMeasures(startPart, startMeasure, endPart, endMeasure) {

        //Select the parts first, select-staff-below ignores voices, so can we.
        for (var i = startPart; i <= endPart; i++) {
            var part = curScore.parts[i];

            //Move down a stave for each 4 tracks. ignore the 1st stave in the startPart
            var j = i == startPart ? 1 : 0
                for (j; j < ((part.endTrack - part.startTrack) / 4); j++) {
                    cmd("select-staff-below");
                }
        }

        var partObj = curScore.parts[endPart];
        var added = false;

        var moveMeasures = 1 + endMeasure - startMeasure;

        var startMeasureCount = combineTrackMeasures(partObj, startMeasure);
        var endMeasureCount = combineTrackMeasures(partObj, endMeasure);

        //If the first measure of the last part of the selected area starts on a bar with 1 element (note or rest), and the last measure of the last part of the selected area starts on a bar with 1 element we need one less move.

        if (startMeasureCount == 1 && endMeasureCount == 1) {
            moveMeasures--;
        } else {
            //If more than one part is selected and the first measure of the last track has only one element, we need one less move.
            if (startPart !== endPart && startMeasureCount == 1) {
                moveMeasures--;
            }
        }
        //Add to the selection the requisite number of measures.
        for (var i = 0; i < moveMeasures; i++) {
            cmd("select-next-measure");
        }

        //If selecting a single measure on one part, and that measure has one element, we need to do additional work to select it.
        if (startMeasure == endMeasure && startPart == endPart && startMeasureCount == 1) {
            if (endPart == curScore.parts.length - 1) {
                cmd("select-staff-below");
            } else {
                cmd("select-staff-below");
                cmd("select-staff-above");
            }
        }

        //If selecting the last measure and the last part has more than one element.
        if (startMeasure == endMeasure && endMeasure == curScore.nmeasures - 1 && endMeasureCount > 1) {
            for (var i = 0; i < endMeasureCount; i++) {
                cmd("select-next-chord")
            }
        }

    }

    function combineTrackMeasures(partObj, measure) {
        var count = 0;
        //if a part has more than one stave, we only want to count the last stave, that's where the selection will be.
        for (var i = partObj.endTrack - 4; i < partObj.endTrack; i++) {
            count = Math.max(trackMeasures[i][measure], count);
        }
        return count;
    }

    //
    //Return the length of the measure that the tick is in
    //
    function currentMeasureLength(tick) {
        var curMeas = currentMeasure(tick);
        return measureTicks[curMeas + 1] - measureTicks[curMeas];
    }

    // Utility function to query a javascipt object.

    function listProperty(item, title, iterations, level) {
        level = level == undefined ? 0 : level;
        iterations = iterations == undefined ? 1 : iterations;
        var tabs = "                                                                                                 ".substring(0, level * 4);
        if (level == 0) {
            console.log("----------------LP-------------------" + title + ":" + item);
        }
        for (var p in item) {
            console.log(tabs + p + ":" + item[p]);
            if (iterations > level && typeof item[p] === 'object') {
                listProperty(item[p], "", iterations, level + 1);
            }
        }
        if (level == 0) {
            console.log("-----------------------------------------------")
        };
    }

    //
    //Display time as hh:mm:ss from a var containing seconds
    //
    function formatTime(secs) {
        var hours = Math.floor(secs / 3600)
            secs -= hours * 3600;
        var minutes = Math.floor(secs / 60)
            secs -= minutes * 60;
        hours = "00" + hours;
        hours = hours.substring(hours.length - 2);
        minutes = "00" + minutes;
        minutes = minutes.substring(minutes.length - 2);
        secs = "00" + secs;
        secs = secs.substring(secs.length - 2);

        return hours + ":" + minutes + ":" + secs;
    }
    //
    //Run a function delayed.  Useful to allow the gui to complete a task before running, or giving a task a chance to complete.
    //
    function delay(delayTime, callfunc) {
        if (!timers.timers) {
            timers.timer = new timer();
        }
        timers.timer.interval = delayTime;
        timers.timer.repeat = false;
        timers.timer.triggered.connect(callfunc);
        timers.timer.start();
    }
    //
    //Define other qt.objects
    //
    function timer() {
        return Qt.createQmlObject("import QtQuick 2.0; Timer {}", parent);
    }
    FileIO {
        id : file
    }
}
