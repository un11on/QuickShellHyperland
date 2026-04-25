import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Io

Item {
    id: root

    property bool showPlayer: false
    property bool showControlCenter: false
    property bool showWeather: false
    property bool showSystemMonitor: false

    property string cpuUsage: "0"
    property string cpuTemp: "0"
    property string ramUsed: "0"
    property string ramTotal: "32"
    property string batLevel: "99"
    property string brightnessLevel: "50"
    property string volumeLevel: "50"
    property string powerProfile: "performance"

    // Демон статистики
    Process {
        id: statsDaemon
        running: true
        command: ["bash", "-c", "while true; do cpu=$(LC_ALL=C top -bn1 | grep 'Cpu(s)' | awk '{print int($2 + $4)}'); temp=$(cat /sys/class/thermal/thermal_zone10/temp 2>/dev/null || cat /sys/class/thermal/thermal_zone8/temp 2>/dev/null || echo 0); temp=$((temp / 1000)); ram=$(LC_ALL=C free -m | awk '/Mem:/ {printf \"%.1f\", $3/1024}'); bat=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n 1); br_now=$(brightnessctl get 2>/dev/null || echo 0); br_max=$(brightnessctl max 2>/dev/null || echo 1); br_pct=$((br_now * 100 / br_max)); profile=$(powerprofilesctl get 2>/dev/null || echo \"\"); vol_pct=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '/Volume:/{v=$2; if (v==\"\" || v==\"N/A\") v=0; printf \"%d\", int(v*100+0.5)}'); printf '{\"cpu\":\"%s\",\"temp\":\"%s\",\"ram\":\"%s\",\"bat\":\"%s\",\"br\":\"%s\",\"vol\":\"%s\",\"profile\":\"%s\"}' \"${cpu:-0}\" \"${temp:-0}\" \"${ram:-0}\" \"${bat:-0}\" \"${br_pct:-0}\" \"${vol_pct:-0}\" \"${profile:-}\" > /tmp/qs_stats.json; sleep 1; done"]
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", "file:///tmp/qs_stats.json", false);
            xhr.send();
            if (xhr.status === 200 || xhr.status === 0) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    root.cpuUsage = data.cpu || "0"; root.cpuTemp = data.temp || "0";
                    root.ramUsed = data.ram || "0"; root.batLevel = data.bat || "0";
                    root.brightnessLevel = data.br || root.brightnessLevel;
                    root.volumeLevel = data.vol || root.volumeLevel;
                    root.powerProfile = data.profile || root.powerProfile;
                } catch(e) {}
            }
        }
    }

    // Процеси
    Process { id: powerPerf; command: ["bash", "-lc", "powerprofilesctl set performance"] }
    Process { id: powerBalanced; command: ["bash", "-lc", "powerprofilesctl set balanced"] }
    Process { id: powerSaver; command: ["bash", "-lc", "powerprofilesctl set power-saver"] }
    Process { id: poweroffProc; command: ["bash", "-lc", "systemctl poweroff"] }
    Process { id: rebootProc;   command: ["bash", "-lc", "systemctl reboot"] }
    Process { id: sleepProc;    command: ["bash", "-lc", "systemctl suspend"] }
    Process { id: wifiLauncher; command: ["nm-connection-editor"] }
    Process { id: btLauncher;   command: ["blueman-manager"] }

    property int manualPlayerIndex: 0
    property var pList: Mpris.players.values
    property var activePlayer: (pList && pList.length > 0) ? pList[manualPlayerIndex % pList.length] : null

    TopBar {
        showPlayerStatus: root.showPlayer; showControlCenterStatus: root.showControlCenter; showSystemStatus: root.showSystemMonitor; trackTitle: root.activePlayer ? root.activePlayer.trackTitle : "Music"
        onTogglePlayer: { root.showPlayer = !root.showPlayer; root.showControlCenter = false; root.showWeather = false; root.showSystemMonitor = false }
        onToggleControlCenter: { root.showControlCenter = !root.showControlCenter; root.showPlayer = false; root.showWeather = false; root.showSystemMonitor = false }
        onToggleSystemMonitor: { root.showSystemMonitor = !root.showSystemMonitor; root.showControlCenter = false; root.showWeather = false; root.showPlayer = false }
        onToggleWeather: { root.showWeather = !root.showWeather; root.showControlCenter = false; root.showPlayer = false; root.showSystemMonitor = false }
    }

    SuperDashboard { isVisible: root.showWeather }

    PanelWindow {
        id: systemMonitorWindow
        visible: root.showSystemMonitor || monitorBg.opacity > 0
        anchors { top: true; left: true }
        margins { top: 48; left: 12 }
        implicitWidth: 520
        implicitHeight: 560
        color: "transparent"

        property var cpuHistory: []
        property int historyMax: 40

        Component.onCompleted: {
            cpuHistory = []
            for (var i = 0; i < historyMax; i++) cpuHistory.push(parseInt(root.cpuUsage) || 0)
        }

        Connections {
            target: root
            function onCpuUsageChanged() {
                cpuHistory.push(parseInt(root.cpuUsage) || 0)
                while (cpuHistory.length > historyMax) cpuHistory.shift()
                cpuGraph.requestPaint()
            }
        }

        Rectangle {
            id: monitorBg
            anchors.fill: parent
            radius: 24
            color: "#0f1720"
            border.color: "#2a2f3e"
            border.width: 1
            opacity: root.showSystemMonitor ? 1 : 0
            visible: root.showSystemMonitor || opacity > 0
            Behavior on opacity { NumberAnimation { duration: 250 } }

            Column {
                anchors.fill: parent; anchors.margins: 26; spacing: 18

                Row {
                    spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                    Text { text: "System Monitor"; color: "#cdd6f4"; font.pixelSize: 18; font.bold: true }
                    Rectangle { width: 6; height: 6; radius: 3; color: root.showSystemMonitor ? "#8caaee" : "#555555" }
                }

                Rectangle {
                    width: parent.width; height: 170; radius: 18
                    color: "#121926"
                    border.color: "#222b3d"
                    border.width: 1
                    Column {
                        anchors.fill: parent; anchors.margins: 16; spacing: 12
                        Text { text: "CPU Performance"; color: "#a6d0ff"; font.pixelSize: 13; font.bold: true }
                        Canvas {
                            id: cpuGraph
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width; height: 96
                            onPaint: {
                                var ctx = getContext("2d"); ctx.reset();
                                ctx.fillStyle = "#0f1720"; ctx.fillRect(0,0,width,height);
                                ctx.strokeStyle = "#22304a"; ctx.lineWidth = 1.5;
                                ctx.beginPath();
                                ctx.moveTo(0, height - 4);
                                ctx.lineTo(width, height - 4);
                                ctx.stroke();

                                if (cpuHistory.length > 1) {
                                    ctx.beginPath();
                                    for (var i = 0; i < cpuHistory.length; i++) {
                                        var x = i * width / (historyMax - 1);
                                        var y = height - 8 - (cpuHistory[i] / 100) * (height - 16);
                                        if (i === 0) ctx.moveTo(x, y);
                                        else ctx.lineTo(x, y);
                                    }
                                    ctx.strokeStyle = "#8caaee";
                                    ctx.lineWidth = 2.5;
                                    ctx.stroke();
                                }
                            }
                        }
                        Row { id: cpuStatsRow; spacing: 18
                            Repeater {
                                model: [
                                    { label: "CPU", value: root.cpuUsage + "%", extra: root.cpuTemp + "°C", color: "#8caaee" },
                                    { label: "RAM", value: Math.round((parseFloat(root.ramUsed)/parseFloat(root.ramTotal || 32))*100) + "%", extra: root.ramUsed + " / " + root.ramTotal + " GB", color: "#f4b8e4" },
                                    { label: "BAT", value: root.batLevel + "%", extra: "Capacity", color: "#a6d189" }
                                ]
                                delegate: Rectangle {
                                    width: (cpuStatsRow.width - 36) / 3; height: 70; radius: 14; color: "#121926"; border.color: "#222b3d"; border.width: 1
                                    Column { anchors.fill: parent; anchors.margins: 12; spacing: 4
                                        Text { text: model.label; color: "#cdd6f4"; font.pixelSize: 11 }
                                        Text { text: model.value; color: model.color; font.pixelSize: 16; font.bold: true }
                                        Text { text: model.extra; color: "#8f9bb3"; font.pixelSize: 10 }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width; height: 136; radius: 18; color: "#121926"; border.color: "#222b3d"; border.width: 1
                    Grid { columns: 2; anchors.fill: parent; anchors.margins: 16; rowSpacing: 12; columnSpacing: 12
                        Rectangle { radius: 14; color: "#141f2f"; border.color: "#222b3d"; border.width: 1
                            Column { anchors.fill: parent; anchors.margins: 12; spacing: 6
                                Text { text: "Network"; color: "#a6d0ff"; font.pixelSize: 11 }
                                Text { text: "Ethernet"; color: "#cdd6f4"; font.pixelSize: 14; font.bold: true }
                                Text { text: "Download: 0.00 MB/s"; color: "#8f9bb3"; font.pixelSize: 10 }
                                Text { text: "Upload: 0.00 MB/s"; color: "#8f9bb3"; font.pixelSize: 10 }
                            }
                        }
                        Rectangle { radius: 14; color: "#141f2f"; border.color: "#222b3d"; border.width: 1
                            Column { anchors.fill: parent; anchors.margins: 12; spacing: 6
                                Text { text: "Display"; color: "#a6d0ff"; font.pixelSize: 11 }
                                Text { text: "1920x1080 @ 60Hz"; color: "#cdd6f4"; font.pixelSize: 14; font.bold: true }
                                Text { text: "Intel HD Graphics"; color: "#8f9bb3"; font.pixelSize: 10 }
                                Text { text: "NixOS 26.05"; color: "#8f9bb3"; font.pixelSize: 10 }
                            }
                        }
                    }
                }
            }
        }
    }

    PlayerMenu {
        isVisible: root.showPlayer; activePlayer: root.activePlayer; pList: root.pList
        onNextPlayerClicked: { root.manualPlayerIndex = (root.manualPlayerIndex + 1) % root.pList.length }
        onPrevPlayerClicked: { root.manualPlayerIndex = (root.manualPlayerIndex - 1 + root.pList.length) % root.pList.length }
    }

    // --- CONTROL CENTER WINDOW ---
    PanelWindow {
        id: controlCenterWindow
        
        // ВАЖЛИВО: Вікно існуватиме тоді, коли воно викликане, АБО поки не закінчилась анімація
        visible: root.showControlCenter || bgRect.opacity > 0 

        // Тільки базові якорі, щоб вікна не ламалися
        anchors { top: true; left: true }
        margins { top: 48; left: 12 }
        
        implicitWidth: 460
        implicitHeight: 640
        color: "transparent"

        Rectangle {
            id: bgRect
            anchors.fill: parent
            opacity: root.showControlCenter ? 1 : 0
            
            // ВАЖЛИВО: Прямокутник існує тоді, коли викликаний, АБО поки не закінчилась анімація
            visible: root.showControlCenter || opacity > 0  
            Behavior on opacity { NumberAnimation { duration: 200 } }
            
            color: "#000000" // Solid black background
            radius: 24
            border.color: "#333333"
            border.width: 2

            Column {
                anchors.fill: parent; anchors.margins: 30; spacing: 30

                // Connectivity Section
                Text { text: "Connectivity"; color: "#ffffff"; font.bold: true; font.pixelSize: 16; anchors.horizontalCenter: parent.horizontalCenter; opacity: root.showControlCenter ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } }
                Row {
                    spacing: 20; anchors.horizontalCenter: parent.horizontalCenter; opacity: root.showControlCenter ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 300; delay: 100; easing.type: Easing.OutCubic } }
                    Rectangle {
                        width: 80; height: 80; radius: 40; color: "#1a1a1a"; border.color: "#8caaee"; border.width: 2
                        scale: 1.0
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        Column {
                            anchors.centerIn: parent; spacing: 4
                            Text { text: "󰤨"; font.pixelSize: 24; color: "#8caaee"; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: "Wi-Fi"; font.pixelSize: 10; color: "#ffffff"; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.scale = 1.1
                            onExited: parent.scale = 1.0
                            onPressed: parent.scale = 0.95
                            onReleased: parent.scale = 1.1
                            onClicked: wifiLauncher.running = true
                        }
                    }
                    Rectangle {
                        width: 80; height: 80; radius: 40; color: "#1a1a1a"; border.color: "#a6d189"; border.width: 2
                        scale: 1.0
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        Column {
                            anchors.centerIn: parent; spacing: 4
                            Text { text: "󰂯"; font.pixelSize: 24; color: "#a6d189"; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: "BT"; font.pixelSize: 10; color: "#ffffff"; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.scale = 1.1
                            onExited: parent.scale = 1.0
                            onPressed: parent.scale = 0.95
                            onReleased: parent.scale = 1.1
                            onClicked: btLauncher.running = true
                        }
                    }
                }

                // System Monitoring
                Text { text: "System"; color: "#ffffff"; font.bold: true; font.pixelSize: 16; anchors.horizontalCenter: parent.horizontalCenter; opacity: root.showControlCenter ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 300; delay: 200; easing.type: Easing.OutCubic } } }
                Grid {
                    columns: 3; spacing: 20; anchors.horizontalCenter: parent.horizontalCenter; opacity: root.showControlCenter ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 300; delay: 300; easing.type: Easing.OutCubic } }
                    Repeater {
                        model: [
                            { label: "CPU", value: root.cpuUsage + "%", color: "#e5c890" },
                            { label: "RAM", value: Math.round((parseFloat(root.ramUsed)/32)*100) + "%", color: "#f4b8e4" },
                            { label: "BAT", value: root.batLevel + "%", color: "#a6d189" }
                        ]
                        Item {
                            width: 70; height: 70
                            property real animatedPercent: 0
                            Behavior on animatedPercent { NumberAnimation { duration: 1000; easing.type: Easing.OutCubic } }
                            Canvas {
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d"); ctx.reset();
                                    ctx.beginPath(); ctx.arc(35, 35, 30, 0, 2*Math.PI); ctx.strokeStyle = "#333333"; ctx.lineWidth = 6; ctx.stroke();
                                    ctx.beginPath(); ctx.arc(35, 35, 30, -Math.PI/2, -Math.PI/2 + (2*Math.PI*parent.animatedPercent)); ctx.strokeStyle = modelData.color; ctx.lineWidth = 6; ctx.lineCap = "round"; ctx.stroke();
                                }
                            }
                            Column { anchors.centerIn: parent; spacing: 1; Text { text: modelData.value; color: modelData.color; font.pixelSize: 14; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter } Text { text: modelData.label; color: "#cccccc"; font.pixelSize: 8; anchors.horizontalCenter: parent.horizontalCenter } }
                            Component.onCompleted: {
                                if (modelData.label === "CPU") animatedPercent = parseInt(root.cpuUsage)/100;
                                else if (modelData.label === "RAM") animatedPercent = parseFloat(root.ramUsed)/32;
                                else animatedPercent = parseInt(root.batLevel)/100;
                            }
                            Connections {
                                target: root
                                function onCpuUsageChanged() { if (modelData.label === "CPU") parent.animatedPercent = parseInt(root.cpuUsage)/100; }
                                function onRamUsedChanged() { if (modelData.label === "RAM") parent.animatedPercent = parseFloat(root.ramUsed)/32; }
                                function onBatLevelChanged() { if (modelData.label === "BAT") parent.animatedPercent = parseInt(root.batLevel)/100; }
                            }
                        }
                    }
                }

                // Controls
                Text { text: "Controls"; color: "#ffffff"; font.bold: true; font.pixelSize: 16; anchors.horizontalCenter: parent.horizontalCenter; opacity: root.showControlCenter ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 300; delay: 400; easing.type: Easing.OutCubic } } }
                Column {
                    spacing: 20; width: parent.width; opacity: root.showControlCenter ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 300; delay: 500; easing.type: Easing.OutCubic } }
                    // Brightness
                    Column { 
                        width: parent.width; spacing: 10
                        Item { width: parent.width; height: 16; Text { text: "Brightness"; color: "#ffffff"; font.bold: true; font.pixelSize: 13; anchors.left: parent.left } Text { text: root.brightnessLevel+"%"; color: "#e5c890"; font.pixelSize: 13; anchors.right: parent.right } }
                        Rectangle { width: parent.width; height: 8; radius: 4; color: "#333333"; Rectangle { width: parent.width * (parseInt(root.brightnessLevel)/100); height: 8; radius: 4; color: "#e5c890"; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } Rectangle { anchors.right: parent.right; anchors.rightMargin: -6; width: 14; height: 14; radius: 7; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter } } }
                    }
                    // Volume
                    Column { 
                        width: parent.width; spacing: 10
                        Item { width: parent.width; height: 16; Text { text: "Volume"; color: "#ffffff"; font.bold: true; font.pixelSize: 13; anchors.left: parent.left } Text { text: root.volumeLevel+"%"; color: "#8caaee"; font.pixelSize: 13; anchors.right: parent.right } }
                        Rectangle { width: parent.width; height: 8; radius: 4; color: "#333333"; Rectangle { width: parent.width * (parseInt(root.volumeLevel)/100); height: 8; radius: 4; color: "#8caaee"; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } Rectangle { anchors.right: parent.right; anchors.rightMargin: -6; width: 14; height: 14; radius: 7; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter } } }
                    }
                }

                // Power Section
                Text { text: "Power"; color: "#ffffff"; font.bold: true; font.pixelSize: 16; anchors.horizontalCenter: parent.horizontalCenter; opacity: root.showControlCenter ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 300; delay: 600; easing.type: Easing.OutCubic } } }
                Row {
                    spacing: 15; anchors.horizontalCenter: parent.horizontalCenter; opacity: root.showControlCenter ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 300; delay: 700; easing.type: Easing.OutCubic } }
                    Repeater {
                        model: [
                            { icon: "⏻", cmd: poweroffProc, color: "#f38ba8" },
                            { icon: "↻", cmd: rebootProc, color: "#a6d189" },
                            { icon: "󰒲", cmd: sleepProc, color: "#89b4fa" }
                        ]
                        Rectangle {
                            width: 60; height: 60; radius: 30; color: "#1a1a1a"; border.color: modelData.color; border.width: 2
                            scale: 1.0
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                            Text { anchors.centerIn: parent; text: modelData.icon; color: modelData.color; font.pixelSize: 24 }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: parent.scale = 1.1
                                onExited: parent.scale = 1.0
                                onPressed: parent.scale = 0.95
                                onReleased: parent.scale = 1.1
                                onClicked: modelData.cmd.running = true
                            }
                        }
                    }
                }

                // Power Profiles
                Row {
                    spacing: 10; anchors.horizontalCenter: parent.horizontalCenter; opacity: root.showControlCenter ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 300; delay: 800; easing.type: Easing.OutCubic } }
                    Repeater {
                        model: [
                            { text: "Perf", cmd: powerPerf, active: root.powerProfile === "performance" },
                            { text: "Bal", cmd: powerBalanced, active: root.powerProfile === "balanced" },
                            { text: "Save", cmd: powerSaver, active: root.powerProfile === "power-saver" }
                        ]
                        Rectangle {
                            width: 70; height: 30; radius: 15; color: modelData.active ? "#f4b8e4" : "#1a1a1a"; border.color: "#333333"; border.width: 1
                            scale: 1.0
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                            Text { anchors.centerIn: parent; text: modelData.text; color: modelData.active ? "#000000" : "#ffffff"; font.bold: true; font.pixelSize: 12 }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: parent.scale = 1.05
                                onExited: parent.scale = 1.0
                                onPressed: parent.scale = 0.95
                                onReleased: parent.scale = 1.05
                                onClicked: modelData.cmd.running = true
                            }
                        }
                    }
                }
            }
        }
    }
}