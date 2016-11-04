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


import QtQuick 2.3
import QtQuick.Controls 1.2
import FileIO 1.0
import QtQuick.Window 2.2
import MuseScore 1.0

MuseScore {
    description : "Simple overview of a score showing populated and empty measures and rehearsal marks.  Allows jumping to a measure in a part and selecting of measures or ranges."
    menuPath : "Plugins.scoreOverView"
	
	
    property var selectedElement : null
    property var selectedPart : null
    property var measureTicks : ([])
    property var timers : ({})
    property var settings : ({})
    property var trackMeasures : ([])

    onRun : {

        init();
    }

    ApplicationWindow {

        id : acWin
        width : 800
        height : 150
        title : "scoreOverView"

        Rectangle {
            anchors.fill : parent
            border.width : 2
            border.color : "#101010"
            Rectangle {
                id : mainBg
                anchors.fill : parent
                anchors.margins : 2

                property var col1Width : 60
                property var col2Width : 75
                color : "#e0e0e0"
                property var column : null
                property var rows : []
                property var rMarks : null
                property var lastMeasureHdr : null

                MouseArea {
                    anchors.fill : parent
                    onClicked : {
                        rSelectionHighlight.width = 0;
                    }
                }
                Item {
                    x : 5
                    Item {
                        id : iMeasures
                        property var rowHeight : 15
                        height : btnToggleMeas.hdrVisible ? rowHeight : 0;

                        Label {
                            id : lblMeasure
                            height : btnToggleMeas.hdrVisible ? iMeasures.rowHeight : 0;
                            width : 60
                            text : "Measures"
                            horizontalAlignment : Text.AlignHCenter
                            Rectangle {
                                anchors.fill : parent
                                color : "#a0a0a0"
                                z : -1
                            }
                        }
                        Item {
                            id : headerRow
                            x : 65
                            width : acWin.width - 85
                            height : btnToggleMeas.hdrVisible ? iMeasures.rowHeight : 0;

                            Repeater {
                                id : rMeasureHdr
                                model : []
                                Label {
                                    id : lblMeasureHdr
                                    width : (acWin.width - 85) / (rMeasureHdr.model.length)
                                    x : rMeasureHdr.model[index] * width
                                    wrapMode : Text.Wrap

                                    text : rMeasureHdr.model[index] + 1
                                    Component.onCompleted : {
                                        mainBg.lastMeasureHdr = lblMeasureHdr;
                                    }
                                }
                            }
                        }
                        Item {
                            id : headerRow2
                            x : 65
                            width : acWin.width - 85
                            height : btnToggleMeas.hdrVisible ? iMeasures.rowHeight : 0;

                            Repeater {
                                id : rMeasureHdr2
                                model : []
                                Label {
                                    id : lblMeasureHdr2
                                    width : (acWin.width - 85) / (rMeasureHdr.model.length)
                                    x : rMeasureHdr2.model[index] * width
                                    text : rMeasureHdr2.model[index] + 1
                                }
                            }
                        }

                    }

                    Item {
                        id : irMarks
                        anchors.top : iMeasures.bottom
                        property var rowHeight : 15
                        height : btnToggleRM.rmVisible ? rowHeight : 0;
                        Label {
                            id : lblRMarks
                            horizontalAlignment : Text.AlignHCenter
                            height : btnToggleRM.rmVisible ? irMarks.rowHeight : 0;
                            width : 60
                            text : "R. Marks"
                            Rectangle {
                                anchors.fill : parent
                                color : "#a0a0a0"
                                z : -1
                            }
                        }

                        Item {
                            id : irehearsalMarks

                            x : 65
                            width : acWin.width - 85
                            height : btnToggleRM.rmVisible ? irMarks.rowHeight : 0;

                            Repeater {
                                id : rrMarks
                                model : []
                                Label {
                                    x : rrMarks.model[index].measure * (acWin.width - 85) / (measureTicks.length - 1)
                                    height : btnToggleRM.rmVisible ? irMarks.rowHeight : 0;
                                    width : (acWin.width - 85) / (measureTicks.length - 1)
                                    text : rrMarks.model[index].text;
                                }
                            }
                            Component.onCompleted : {
                                mainBg.rMarks = rrMarks;
                            }

                        }

                    }
                    Column {
                        id : column1
                        anchors.top : irMarks.bottom
                        property var rowHeight : (acWin.height - iMeasures.height - irMarks.height - 20) / rColumn.model.length
                        property var fontRatio : rowHeight / 20
                        height : acWin.height - iMeasures.height - irMarks.height - 20;
                        width : acWin.width;
                        Item {
                            width : acWin.width;
                            height : acWin.height - iMeasures.height - irMarks.height - 20;
                            Repeater {
                                id : rColumn
                                model : []
                                Item {
                                    height : column1.rowHeight
                                    Label {
                                        id : lblcol1Tags
                                        Rectangle {
                                            anchors.fill : parent
                                            color : "#c0c0c0"
                                            z : -1
                                        }
                                        verticalAlignment : Text.AlignVCenter
                                        y : index * column1.rowHeight
                                        width : 60
                                        height : column1.rowHeight
                                        text : rColumn.model[index].name;
                                        font.pointSize : Math.min(9, 9 * column1.fontRatio)
                                    }
                                    Item {

                                        Row {
                                            x : 65
                                            y : index * column1.rowHeight
                                            height : column1.rowHeight
                                            width : acWin.width - 85
                                            Item {
                                                height : column1.rowHeight
                                                width : acWin.width - 85
                                                Repeater {
                                                    id : rRows
                                                    // property var measures : []

                                                    model : []
                                                    Rectangle {
                                                        id : rMeasure
                                                        color : rRows.model[index].hasNotes ? "#050505" : "#e0e0e0"
                                                        z : -1
                                                        width : (acWin.width - 85) / (measureTicks.length - 1)
                                                        height : column1.rowHeight
                                                        border.color : "DarkGray"
                                                        border.width : 1
                                                        x : index * width

                                                        // Component.onCompleted : rRows.measures[index] = rMeasure;
                                                    }

                                                    Component.onCompleted : {
                                                        mainBg.rows[index] = rRows;
                                                    }
                                                }

                                            }
                                        }
                                    }
                                }
                            }
                            Component.onCompleted : {
                                mainBg.column = rColumn;
                            }
                            Rectangle {
                                id : rSelectionHighlight
                                color : "Blue"
                                opacity : 0.5
                            }

                            MouseArea {
                                anchors.fill : parent
                                property var pressed : {}
                                onPressed : {
                                    rSelectionHighlight.color = "Blue";
                                    var colWidth = (acWin.width - 85) / (measureTicks.length - 1)
									if (mouse.x < 65 || mouse.x > acWin.width - 20) {
                                        return;
                                    }
                                    if (mouse.y < 0 || mouse.y > column1.rowHeight * curScore.parts.length) {
                                        return;
                                    }
                                    var x = mouse.x - 65;
                                    var measure = Math.min(Math.floor(x / colWidth), measureTicks.length - 1);
                                    var part = Math.min(Math.floor(mouse.y / column1.rowHeight), curScore.parts.length - 1)
                                        pressed = {
                                        measure : measure,
                                        part : part
                                    }
                                    rSelectionHighlight.x = 65 + measure * colWidth;
                                    rSelectionHighlight.width = colWidth;
                                    rSelectionHighlight.y = part * column1.rowHeight;
                                    rSelectionHighlight.height = column1.rowHeight;

                                }
                                onPositionChanged : {
                                    var colWidth = (acWin.width - 85) / (measureTicks.length - 1)
                                    if (mouse.x < 65 || mouse.x > 65 + colWidth * (measureTicks.length - 1)) {
                                        return;
                                    }
                                    if (mouse.y < 0 || mouse.y > column1.rowHeight * curScore.parts.length) {
                                        return;
                                    }
                                    var x = mouse.x - 65;
                                    var measure = Math.min(Math.floor(x / colWidth), measureTicks.length - 1);
                                    var part = Math.min(Math.floor(mouse.y / column1.rowHeight), curScore.parts.length - 1);

                                    var startPart = Math.min(pressed.part, part);
                                    var endPart = Math.max(pressed.part, part);
                                    var startMeasure = Math.min(pressed.measure, measure);
                                    var endMeasure = Math.max(pressed.measure, measure);

                                    //Display the highlight
                                    rSelectionHighlight.x = 65 + startMeasure * colWidth;
                                    rSelectionHighlight.width = colWidth * (1 + endMeasure - startMeasure);
                                    rSelectionHighlight.y = startPart * column1.rowHeight;
                                    rSelectionHighlight.height = column1.rowHeight * (1 + endPart - startPart);
                                }
                                onReleased : {
                                    var colWidth = (acWin.width - 85) / (measureTicks.length - 1)
                                    if (mouse.x < 65 || mouse.x > 65 + colWidth * (measureTicks.length - 1)) {
                                        return;
                                    }
                                    if (mouse.y < 0 || mouse.y > column1.rowHeight * curScore.parts.length) {
                                        return;
                                    }
                                    var x = mouse.x - 65;
                                    var measure = Math.min(Math.floor(x / colWidth), measureTicks.length - 1);
                                    var part = Math.min(Math.floor(mouse.y / column1.rowHeight), curScore.parts.length - 1);

                                    if (pressed.measure == measure && pressed.part == part) {
                                        if (mouse.modifiers & Qt.ShiftModifier) {
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
                                    //hide the highlight
                                    rSelectionHighlight.color = "yellow";
                                }
                            }
                        }
                    }
                }

            }
            Button {
                id : btnToggleMeas
                height : iMeasures.rowHeight
                width : 10
                anchors.right : mainBg.right
                text : "-"
                tooltip : "Show / hide measures"
                property var hdrVisible : true
                onClicked : {
					btnToggleMeas.hdrVisible = !btnToggleMeas.hdrVisible;
                    text = text == "-" ? "+" : "-";
                    selectHeader();
                }

            }
            Button {
                id : btnToggleRM
                height : irMarks.rowHeight
                width : 10
                anchors.right : mainBg.right
                y : iMeasures.rowHeight
                text : "-"
                tooltip : "Show / hide rehearsal marks"
				property var rmVisible : true
                onClicked : {
                    text = text == "-" ? "+" : "-";
                    btnToggleRM.rmVisible = !btnToggleRM.rmVisible;
					lblRMarks.visible = btnToggleRM.rmVisible;
                    irehearsalMarks.visible = btnToggleRM.rmVisible;
                }

            }
            Row {
                anchors.left : parent.left
                anchors.bottom : parent.bottom
                anchors.leftMargin : 5
                anchors.bottomMargin : 3
                Button {
                    id : btnToggleAlwaysOnTop

                    height : 15
                    width : 15
                    property var checked : true
                    text : "^"
                    tooltip : "Toggle always on top"
                    onClicked : {
                        checked = !checked
                            if (checked) {
                                acWin.flags |= Qt.WindowStaysOnTopHint;
                            } else {
                                acWin.flags &= ~Qt.WindowStaysOnTopHint;
                            }
                    }
                    Rectangle {
                        anchors.fill : parent
                        color : "White"
                        radius : 6
                        opacity : btnToggleAlwaysOnTop.checked ? 0 : 0.5
                    }
                }
            }
            Label {
                id : lblDur
                anchors.right : parent.right
                anchors.bottom : parent.bottom
                anchors.leftMargin : 5
                anchors.rightMargin : 5
                anchors.bottomMargin : 5
                text : "Dur. " + Math.floor(curScore.duration / 60) + ":" + (curScore.duration % 60)
            }
        }

        onWidthChanged : {
            rSelectionHighlight.width = 0;
            selectHeader();

        }
        onHeightChanged : {
            rSelectionHighlight.width = 0;

        }
        onActiveChanged : {
            if (active) {
                lblDur.text = "Dur. " + formatTime(curScore.duration);
                buildViewModels();
            };
        }
        Component.onCompleted : {
            flags |= Qt.WindowStaysOnTopHint
        }

        onClosing : {
            if (timers.timers) {
                timers.timer.stop()
            };
            winAbout.close();

            settings["winx"] = acWin.x;
            settings["winy"] = acWin.y;
            settings["winh"] = acWin.height;
            settings["winw"] = acWin.width;
            saveSettings();
            Qt.quit();

        }
    }

    Window {
        id : winAbout
        title : "About"
        width : 320
        height : 250
        minimumWidth : 320
        minimumHeight : 250
        maximumWidth : 320
        maximumHeight : 250

        Rectangle {
            anchors.fill : parent
            gradient : Gradient {
                GradientStop {
                    position : 0.0;
                    color : "lightsteelblue"
                }
                GradientStop {
                    position : 1.0;
                    color : "lightskyblue"
                }
            }
        }
        Text {
            id : winAboutTxt
            x : 0
            y : 0
            width : 300
            height : 250
            color : "darkturquoise"
            style : Text.Outline;
            styleColor : "#404040"
            text : "<h1>editGtrChords part of gtrChords</h1><br><br><h4>plugin for MuseScore</h4><br><br><h3>(c) 2016 - stevel05</h3>"
            wrapMode : Text.Wrap
            verticalAlignment : Text.AlignVCenter
            horizontalAlignment : Text.AlignHCenter
        }
        Button {
            anchors.horizontalCenter : parent.horizontalCenter
            y : parent.height - 40
            text : "OK"
            onClicked : winAbout.close();
        }
    }

    //
    //@ functions
    //
    function init() {
        loadSettings();
        acWin.show();
        //Fix for known bug where dropdowns can appear on the wrong screen if the window is opened on a second screen
        acWin.x++;
        acWin.x--;
        //

        getMeasureTicks();

    }

    function buildViewModels() {

        //Refresh the measure ticks
        getMeasureTicks();

        //Clear the rows models before we start
        for (var i = 0; i < mainBg.column.model.length; i++) {
            mainBg.rows[i].model = [];
        }
        //Clear the column models
        mainBg.column.model = [];
        mainBg.rMarks.model = [];
        rMarks = [];

        var m = [];
        var rowsModel = [];
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
            rowsModel[i] = initRm.slice(0);
        }
        mainBg.column.model = m;

        var seg = curScore.firstSegment(Segment.ChordRest);
        var curMeasure =  - 1;
        var hasNotes = false;
        var measureDone = false;
        var rMarks = [];
        while (seg) {
            curMeasure = currentMeasure(seg.tick);

            //Store the measure and text of the rehearsal marks.
            for (var i = 0; i < seg.annotations.length; i++) {
                if (seg.annotations[i].type == Element.REHEARSAL_MARK) {
                    rMarks.push({
                        measure : curMeasure,
                        text : seg.annotations[i].text
                    })
                }
            }
            seg = seg.next;
        }

        var measure = curScore.firstMeasure;
        while (measure) {
            seg = measure.firstSegment;
            while (seg) {
                curMeasure = currentMeasure(seg.tick);
                //For each part, store whether each measure has notes, and on which tracks.  Used for the automated selection in selectPartMeasures.
                for (var i = 0; i < curScore.parts.length; i++) {
                    var partData = curScore.parts[i];
                    hasNotes = rowsModel[i][curMeasure].hasNotes;
                    measureDone = rowsModel[i][curMeasure].done;
                    if (!(measureDone && hasNotes)) {
                        for (var j = partData.startTrack; j < partData.endTrack; j++) {

                            if (seg.elementAt(j) && (seg.elementAt(j).type == Element.CHORD || seg.elementAt(j).type == Element.REST)) {
                                //Drives the selection routines, if a track has more than 1 rest or notes.
                                trackMeasures[j][curMeasure]++;
                                if (trackMeasures[j][curMeasure] > 1) {
                                    measureDone = true;
                                }

                                //Drives the GUI image, shaded if part hasNotes
                                if (seg.elementAt(j).type == Element.CHORD) {
                                    hasNotes = true;
                                }
                            }

                            //Drives the GUI image, shaded if part hasNotes
                            rowsModel[i][curMeasure] = {
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
        // listProperty(trackMeasures[12])

        for (var i = 0; i < rowsModel.length; i++) {
            mainBg.rows[i].model = rowsModel[i];
        }
        mainBg.rMarks.model = rMarks;
        rMeasureHdr.model = [];

        var m = [];
        for (var i = 0; i < measureTicks.length - 1; i++) {
            m.push(i);
        }
        rMeasureHdr.model = m;

        rMeasureHdr2.model = [];
        var m = [];
        m.push(0)
        for (var i = 4; i < measureTicks.length - 1; i += 5) {
            m.push(i);
        }
        rMeasureHdr2.model = m;
		selectHeader();
    }
    function selectHeader() {
        if (!mainBg.lastMeasureHdr) {
            return;
        }
        if (btnToggleMeas.hdrVisible) {
			lblMeasure.visible = true;
            if (mainBg.lastMeasureHdr.lineCount > 1) {
                headerRow.visible = false;
                headerRow2.visible = true;

            } else {
                headerRow.visible = true;
                headerRow2.visible = false;
            }
        } else {
			lblMeasure.visible = false;
            headerRow.visible = false;
			headerRow2.visible = false;
        }
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

        //If the first measure of the last part of the selected area starts on a bar with 1 element (note or rest), and the last measure of the last part of the selected area starts on a bar with 1 elementwe need one less move.

        if (trackMeasures[partObj.startTrack][startMeasure] == 1 && trackMeasures[partObj.startTrack][endMeasure] == 1) {
            moveMeasures--;
        } else {
            //If more than one part is selected and the first measure of the last track has only one element, we need one less move.
            if (startPart !== endPart && trackMeasures[partObj.startTrack][startMeasure] == 1) {
                moveMeasures--;
            }
        }
        //Add to the selection the requisite number of measures.
        for (var i = 0; i < moveMeasures; i++) {
            cmd("select-next-measure");
        }
		
		//If selecting a single measure on one part, ant that measure has one element, we need to do additional work to select it.
		if(startMeasure == endMeasure && startPart == endPart && trackMeasures[partObj.startTrack][startMeasure] == 1){
			if(endPart == curScore.parts.length - 1){
				cmd("select-staff-below");
			}
			else{
				cmd("select-staff-below");
				cmd("select-staff-above");
			}
		}

    }
    function loadSettings() {

        file.source = filePath + "/" + "scoreOverView.ini";
        var found = false;
        if (file.exists()) {
            try {
                settings = JSON.parse(file.read());
                found = true;
            } catch (e) {
                found = false;
            }
        }

        if (found) {
            acWin.x = settings["winx"];
            acWin.y = settings["winy"];
            acWin.height = settings["winh"];
            acWin.width = settings["winw"];
        } else {
            settings["winx"] = acWin.x;
            settings["winy"] = acWin.y;
            settings["winh"] = acWin.height;
            settings["winw"] = acWin.width;
            saveSettings();
        }
    }
    function saveSettings() {
        file.source = filePath + "/" + "scoreOverView.ini";
        file.write(JSON.stringify(settings));
    }

    //
    //Return the length of the measure that the tick is in
    //
    function currentMeasureLength(tick) {
        var curMeas = currentMeasure(tick);
        return measureTicks[curMeas + 1] - measureTicks[curMeas];
    }

    //
    //Utility function to query a javascipt object.
    //
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
        return Qt.createQmlObject("import QtQuick 2.0; Timer {}", acWin);
    }
    FileIO {
        id : file
    }
}
