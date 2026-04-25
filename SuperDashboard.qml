import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: dashWindow
    property bool isVisible: false

    visible: isVisible || mainRect.opacity > 0
    
    WlrLayershell.keyboardFocus: dashWindow.isVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors { top: true; left: true }
    margins { 
        top: 60
        left: (dashWindow.screen.width / 2) - 625 
    }

    implicitWidth: 1250
    implicitHeight: 700
    color: "transparent"

    // ==========================================
    // 🗄️ БАЗА ДАНИХ ТА СТАНИ
    // ==========================================
    property date viewDate: new Date()
    property date activeDateObj: new Date()
    property string activeDateKey: activeDateObj.getFullYear() + "-" + activeDateObj.getMonth() + "-" + activeDateObj.getDate()
    
    property var dayNotes: ({})
    property var dayTodos: ({}) 
    property int forceUpdateTracker: 0

    property var wCurrent: ({"temp": "--", "desc": "Синхронізація...", "hum": "--", "wind": "--", "icon": "󰖙"})
    property var wForecast: []

    QtObject {
        id: theme
        property color crust: "#11111b"
        property color mantle: "#181825"
        property color base: "#1e1e2e"
        property color surface0: "#313244"
        property color surface1: "#45475a"
        property color text: "#cdd6f4"
        property color subtext0: "#a6adc8"
        property color blue: "#89b4fa"
        property color sapphire: "#74c7ec"
        property color lavender: "#b4befe"
        property color mauve: "#cba6f7"
        property color pink: "#f5c2e7"
        property color red: "#f38ba8"
        property color peach: "#fab387"
        property color yellow: "#f9e2af"
        property color green: "#a6e3a1"
    }

    // ==========================================
    // ⚡ ЛОГІКА
    // ==========================================
    
    ListModel { id: currentTodosModel }

    function loadDayData() {
        var savedText = dashWindow.dayNotes[activeDateKey];
        notesArea.text = savedText ? savedText : "";
        
        currentTodosModel.clear();
        var list = dashWindow.dayTodos[activeDateKey] || [];
        for (var i = 0; i < list.length; i++) {
            currentTodosModel.append({"taskText": list[i].text, "isDone": list[i].done});
        }
    }

    function saveTodos() {
        var list = [];
        for (var i = 0; i < currentTodosModel.count; i++) {
            list.push({"text": currentTodosModel.get(i).taskText, "done": currentTodosModel.get(i).isDone});
        }
        dashWindow.dayTodos[activeDateKey] = list;
        dashWindow.forceUpdateTracker += 1;
    }

    function getWeatherIcon(desc) {
        var d = desc.toLowerCase();
        if (d.indexOf("rain") !== -1 || d.indexOf("дождь") !== -1 || d.indexOf("дощ") !== -1) return "󰖗";
        if (d.indexOf("cloud") !== -1 || d.indexOf("облач") !== -1 || d.indexOf("хмар") !== -1) return "󰖐";
        if (d.indexOf("snow") !== -1 || d.indexOf("снег") !== -1 || d.indexOf("сніг") !== -1) return "󰖘";
        if (d.indexOf("storm") !== -1 || d.indexOf("гроз") !== -1) return "󰖓";
        if (d.indexOf("clear") !== -1 || d.indexOf("ясно") !== -1) return "󰖙";
        if (d.indexOf("sun") !== -1 || d.indexOf("солн") !== -1) return "󰖙";
        return "󰖐";
    }

    onActiveDateKeyChanged: loadDayData()

    onIsVisibleChanged: {
        if (isVisible) {
            notesArea.forceActiveFocus();
            col1Anim.restart();
            col2Anim.restart();
            col3Anim.restart();
        }
    }

    Timer {
        interval: 600000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", "https://wttr.in/Kyiv?format=j1&lang=ru", true);
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText);
                        var current = data.current_condition[0];
                        
                        dashWindow.wCurrent = {
                            "temp": current.temp_C,
                            "desc": current.lang_ru[0].value,
                            "hum": current.humidity,
                            "wind": current.windspeedKmph,
                            "icon": getWeatherIcon(current.weatherDesc[0].value)
                        };

                        var fcast = [];
                        for(var i = 1; i <= 2; i++) {
                            var dayData = data.weather[i];
                            fcast.push({
                                "date": dayData.date,
                                "max": dayData.maxtempC,
                                "min": dayData.mintempC,
                                "icon": getWeatherIcon(dayData.hourly[4].weatherDesc[0].value)
                            });
                        }
                        dashWindow.wForecast = fcast;
                        dashWindow.forceUpdateTracker += 1;
                    } catch(e) {}
                }
            }
            xhr.send();
        }
    }

    // ==========================================
    // 🎨 ГОЛОВНИЙ ІНТЕРФЕЙС
    // ==========================================
    
    Rectangle {
        id: mainRect
        anchors.fill: parent
        color: theme.crust
        radius: 30
        border.color: theme.surface0
        border.width: 2
        clip: true

        opacity: dashWindow.isVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        transform: Translate { 
            y: dashWindow.isVisible ? 0 : -40 
            Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 25 
            spacing: 25 

            // ---------------------------------------------------
            // КОЛОНКА 1: ЧАС ТА ПОГОДА
            // ---------------------------------------------------
            Rectangle {
                id: col1
                Layout.preferredWidth: 340 
                Layout.fillHeight: true
                color: "transparent"

                transform: Translate { id: tr1; y: 50 }
                NumberAnimation { id: col1Anim; target: tr1; property: "y"; from: 50; to: 0; duration: 500; easing.type: Easing.OutBack; easing.overshoot: 1.2 }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 20

                    // Блок Часу (без привітання)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 160
                        radius: 24
                        color: theme.mantle
                        border.color: theme.surface0; border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            
                            Text {
                                id: mainClock
                                text: Qt.formatTime(new Date(), "hh:mm")
                                color: theme.text
                                font.pixelSize: 84; font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                                Timer { interval: 1000; running: true; repeat: true; onTriggered: mainClock.text = Qt.formatTime(new Date(), "hh:mm") }
                            }
                            Text {
                                text: Qt.formatDate(new Date(), "dd MMMM, dddd").toUpperCase()
                                color: theme.subtext0
                                font.pixelSize: 13; font.bold: true; font.letterSpacing: 2
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // Поточна погода (Hero Card)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 250 
                        radius: 24
                        color: theme.base
                        border.color: theme.surface0; border.width: 1

                        Rectangle {
                            anchors.fill: parent; radius: 24; opacity: 0.1
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: theme.sapphire }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 25; spacing: 5

                            Text { text: "ПОГОДА ЗАРАЗ"; color: theme.surface1; font.bold: true; font.pixelSize: 12; font.letterSpacing: 2 }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: dashWindow.wCurrent.icon; color: theme.yellow; font.pixelSize: 64 }
                                Item { Layout.fillWidth: true }
                                Column {
                                    Text { text: dashWindow.wCurrent.temp + "°"; color: theme.text; font.pixelSize: 56; font.bold: true }
                                    Text { text: dashWindow.wCurrent.desc; color: theme.subtext0; font.pixelSize: 15; font.bold: true; wrapMode: Text.WordWrap; width: 140 }
                                }
                            }

                            Item { Layout.fillHeight: true } 

                            RowLayout {
                                Layout.fillWidth: true; spacing: 15
                                Rectangle {
                                    Layout.fillWidth: true; height: 50; radius: 16; color: theme.mantle; border.color: theme.surface0; border.width: 1
                                    Row { anchors.centerIn: parent; spacing: 10; Text { text: "󰖐"; color: theme.sapphire; font.pixelSize: 20 } Text { text: dashWindow.wCurrent.wind + " км/г"; color: theme.text; font.bold: true; font.pixelSize: 13 } }
                                }
                                Rectangle {
                                    Layout.fillWidth: true; height: 50; radius: 16; color: theme.mantle; border.color: theme.surface0; border.width: 1
                                    Row { anchors.centerIn: parent; spacing: 10; Text { text: "󰖟"; color: theme.blue; font.pixelSize: 20 } Text { text: dashWindow.wCurrent.hum + "%"; color: theme.text; font.bold: true; font.pixelSize: 13 } }
                                }
                            }
                        }
                    }

                    // Прогноз
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 120
                        spacing: 15

                        Repeater {
                            model: dashWindow.wForecast
                            Rectangle {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                radius: 20; color: theme.mantle; border.color: theme.surface0; border.width: 1
                                Column {
                                    anchors.centerIn: parent; spacing: 8
                                    Text { 
                                        text: Qt.formatDate(new Date(modelData.date), "dd.MM").toUpperCase()
                                        color: theme.subtext0; font.bold: true; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter 
                                    }
                                    Text { text: modelData.icon; color: theme.text; font.pixelSize: 36; anchors.horizontalCenter: parent.horizontalCenter }
                                    Row {
                                        spacing: 10; anchors.horizontalCenter: parent.horizontalCenter
                                        Text { text: modelData.max + "°"; color: theme.red; font.bold: true; font.pixelSize: 14 }
                                        Text { text: modelData.min + "°"; color: theme.blue; font.bold: true; font.pixelSize: 14 }
                                    }
                                }
                            }
                        }
                    }
                    
                    Item { Layout.fillHeight: true }
                }
            }

            Rectangle { Layout.preferredWidth: 2; Layout.fillHeight: true; color: theme.surface0; radius: 1 }

            // ---------------------------------------------------
            // КОЛОНКА 2: КАЛЕНДАР 
            // ---------------------------------------------------
            Rectangle {
                id: col2
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"

                transform: Translate { id: tr2; y: 50 }
                NumberAnimation { id: col2Anim; target: tr2; property: "y"; from: 50; to: 0; duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.2 }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 30

                    // Шапка календаря
                    RowLayout {
                        Layout.fillWidth: true
                        
                        Text {
                            text: Qt.formatDateTime(dashWindow.viewDate, "MMMM yyyy").toUpperCase()
                            color: theme.mauve; font.bold: true; font.pixelSize: 26; font.letterSpacing: 2
                        }

                        Item { Layout.fillWidth: true } 

                        Rectangle {
                            Layout.preferredWidth: 90; Layout.preferredHeight: 36; radius: 18
                            color: btnToday.containsMouse ? theme.mauve : "transparent"
                            border.color: theme.mauve; border.width: 1.5
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text { 
                                anchors.centerIn: parent; text: "СЬОГОДНІ"
                                color: btnToday.containsMouse ? theme.crust : theme.mauve; font.bold: true; font.pixelSize: 11; font.letterSpacing: 1
                            }
                            MouseArea { 
                                id: btnToday; anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    let now = new Date();
                                    dashWindow.viewDate = new Date(now.getFullYear(), now.getMonth(), 1);
                                    dashWindow.activeDateObj = now;
                                    dashWindow.activeDateKey = now.getFullYear() + "-" + now.getMonth() + "-" + now.getDate();
                                }
                            }
                        }

                        Row {
                            spacing: 10
                            Rectangle {
                                width: 40; height: 40; radius: 20
                                color: m1.containsMouse ? theme.surface0 : "transparent"
                                Text { anchors.centerIn: parent; text: "󰁍"; color: theme.subtext0; font.pixelSize: 22 }
                                MouseArea { id: m1; anchors.fill: parent; hoverEnabled: true; onClicked: dashWindow.viewDate = new Date(dashWindow.viewDate.getFullYear(), dashWindow.viewDate.getMonth() - 1, 1) }
                            }
                            Rectangle {
                                width: 40; height: 40; radius: 20
                                color: m2.containsMouse ? theme.surface0 : "transparent"
                                Text { anchors.centerIn: parent; text: "󰁔"; color: theme.subtext0; font.pixelSize: 22 }
                                MouseArea { id: m2; anchors.fill: parent; hoverEnabled: true; onClicked: dashWindow.viewDate = new Date(dashWindow.viewDate.getFullYear(), dashWindow.viewDate.getMonth() + 1, 1) }
                            }
                        }
                    }

                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        width: grid.width
                        spacing: 0
                        Repeater {
                            model: ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "НД"]
                            Text { 
                                width: grid.width / 7
                                text: modelData; color: theme.surface1; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter 
                            }
                        }
                    }

                    MonthGrid {
                        id: grid; 
                        Layout.fillWidth: true; Layout.fillHeight: true
                        month: dashWindow.viewDate.getMonth(); year: dashWindow.viewDate.getFullYear()
                        locale: Qt.locale("uk_UA") 

                        delegate: Item {
                            implicitWidth: grid.width / 7
                            implicitHeight: grid.height / 6
                            
                            Rectangle {
                                id: dayCell
                                width: Math.min(parent.width, parent.height) - 8
                                height: width
                                anchors.centerIn: parent
                                radius: width / 2
                                
                                property string dateKey: model.year + "-" + model.month + "-" + model.day
                                property bool isSelected: dateKey === dashWindow.activeDateKey
                                
                                color: isSelected ? theme.mauve : (dayMouse.pressed ? theme.surface1 : (dayMouse.containsMouse ? theme.surface0 : "transparent"))
                                border.color: model.today ? (isSelected ? theme.mauve : theme.pink) : "transparent"
                                border.width: model.today ? 2 : 0
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                                scale: dayMouse.pressed ? 0.9 : (dayMouse.containsMouse ? 1.1 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                                SequentialAnimation on border.color {
                                    running: model.today && !dayCell.isSelected
                                    loops: Animation.Infinite
                                    ColorAnimation { to: theme.surface1; duration: 1000 }
                                    ColorAnimation { to: theme.pink; duration: 1000 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: model.day
                                    font.bold: model.today || dayCell.isSelected
                                    font.pixelSize: 18
                                    color: dayCell.isSelected ? theme.crust : (model.month === grid.month ? theme.text : theme.surface1)
                                }

                                Row {
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4
                                    
                                    Rectangle {
                                        width: 12; height: 4; radius: 2
                                        color: dayCell.isSelected ? theme.crust : theme.pink
                                        visible: {
                                            var dummy = dashWindow.forceUpdateTracker;
                                            var txt = dashWindow.dayNotes[dayCell.dateKey];
                                            return txt !== undefined && txt.trim() !== "";
                                        }
                                    }
                                    
                                    Rectangle {
                                        width: 4; height: 4; radius: 2
                                        color: dayCell.isSelected ? theme.crust : theme.green
                                        visible: {
                                            var dummy = dashWindow.forceUpdateTracker;
                                            var todos = dashWindow.dayTodos[dayCell.dateKey] || [];
                                            for(var i=0; i<todos.length; i++) { if(!todos[i].done) return true; }
                                            return false;
                                        }
                                    }
                                }

                                MouseArea { 
                                    id: dayMouse; anchors.fill: parent; hoverEnabled: true;
                                    onClicked: {
                                        dashWindow.activeDateObj = new Date(model.year, model.month, model.day);
                                        dashWindow.activeDateKey = dayCell.dateKey;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.preferredWidth: 2; Layout.fillHeight: true; color: theme.surface0; radius: 1 }

            // ---------------------------------------------------
            // КОЛОНКА 3: ЗАВДАННЯ ТА НОТАТКИ
            // ---------------------------------------------------
            Rectangle {
                id: col3
                Layout.preferredWidth: 380 
                Layout.fillHeight: true
                color: "transparent"

                transform: Translate { id: tr3; y: 50 }
                NumberAnimation { id: col3Anim; target: tr3; property: "y"; from: 50; to: 0; duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.2 }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 20

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 50
                        color: theme.surface0; radius: 16
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 15
                            Text { text: "󰃭 ПЛАНИ НА ДЕНЬ"; color: theme.subtext0; font.bold: true; font.pixelSize: 12; font.letterSpacing: 1 }
                            Item { Layout.fillWidth: true }
                            Text { text: Qt.formatDate(dashWindow.activeDateObj, "dd.MM.yyyy"); color: theme.text; font.bold: true; font.pixelSize: 16 }
                        }
                    }

                    // СПИСОК ЗАВДАНЬ (TO-DO)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: theme.mantle
                        radius: 20
                        border.color: theme.surface0; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 15; spacing: 10

                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 45
                                color: theme.base; radius: 12; border.color: theme.surface0; border.width: 1
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 10; spacing: 10
                                    Text { text: ""; color: theme.blue; font.pixelSize: 14 }
                                    TextField {
                                        id: todoInput
                                        Layout.fillWidth: true
                                        color: theme.text; font.pixelSize: 15; font.family: "sans-serif"
                                        placeholderText: "Додати завдання..."
                                        placeholderTextColor: theme.surface1
                                        background: null
                                        onAccepted: {
                                            if(text.trim() !== "") {
                                                currentTodosModel.append({"taskText": text.trim(), "isDone": false});
                                                text = "";
                                                saveTodos();
                                            }
                                        }
                                    }
                                }
                            }

                            ListView {
                                id: todoList
                                Layout.fillWidth: true; Layout.fillHeight: true
                                clip: true; spacing: 8
                                model: currentTodosModel
                                
                                delegate: Rectangle {
                                    width: todoList.width; height: 45; radius: 12
                                    color: itemMouse.containsMouse ? theme.surface0 : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 10; spacing: 12
                                        
                                        Rectangle {
                                            width: 24; height: 24; radius: 8
                                            color: model.isDone ? theme.green : "transparent"
                                            border.color: model.isDone ? theme.green : theme.surface1
                                            border.width: 2
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                            
                                            Text { 
                                                anchors.centerIn: parent; text: ""; color: theme.crust
                                                font.pixelSize: 12; font.bold: true
                                                opacity: model.isDone ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                                scale: model.isDone ? 1 : 0.5
                                                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: model.taskText
                                            color: model.isDone ? theme.surface1 : theme.text
                                            font.pixelSize: 15
                                            font.strikeout: model.isDone
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                        }

                                        Text {
                                            text: ""; color: delArea.containsMouse ? theme.red : theme.surface1; font.pixelSize: 14
                                            opacity: itemMouse.containsMouse ? 1 : 0
                                            Behavior on opacity { NumberAnimation { duration: 150 } }
                                            MouseArea {
                                                id: delArea; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true
                                                onClicked: { currentTodosModel.remove(index); saveTodos(); }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: itemMouse; anchors.fill: parent; hoverEnabled: true
                                        onClicked: {
                                            currentTodosModel.setProperty(index, "isDone", !model.isDone);
                                            saveTodos();
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Немає завдань на цей день\nНасолоджуйся відпочинком! ☕"
                                    color: theme.surface1; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter
                                    visible: currentTodosModel.count === 0
                                }
                            }
                        }
                    }

                    // ТЕКСТОВІ НОТАТКИ
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220
                        color: theme.mantle
                        radius: 20
                        border.color: notesArea.activeFocus ? theme.mauve : theme.surface0
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 15; spacing: 10
                            
                            RowLayout {
                                Text { text: "󰎞 ВІЛЬНІ НОТАТКИ"; color: theme.subtext0; font.bold: true; font.pixelSize: 11; font.letterSpacing: 1 }
                            }

                            ScrollView {
                                Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                                
                                TextArea {
                                    id: notesArea
                                    placeholderText: "Запиши сюди важливі думки, контакти чи ідеї..."
                                    color: theme.text; placeholderTextColor: theme.surface1
                                    font.pixelSize: 15; font.family: "sans-serif"
                                    wrapMode: Text.WordWrap; background: null; selectByMouse: true
                                    
                                    onTextChanged: {
                                        if (dashWindow.isVisible && dashWindow.activeDateKey !== "") {
                                            dashWindow.dayNotes[dashWindow.activeDateKey] = text;
                                            dashWindow.forceUpdateTracker += 1; 
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}