import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: playerWindow
    
    property bool isVisible: false
    visible: isVisible || mainContainer.opacity > 0 

    WlrLayershell.keyboardFocus: isVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property var activePlayer: null 
    property var pList: []        
    signal nextPlayerClicked()
    signal prevPlayerClicked()
    
    // Дефолтні дані
    property var m: ({
        "title": "Not Playing",
        "artist": "Select a track",
        "status": "Stopped",
        "percent": 0,
        "volume": 0,
        "artUrl": "",
        "textColor": "#cba6f7",
        "deviceName": "Speaker",
        "deviceIcon": "󰓃"
    }) 

    property bool isPlaying: m.status === "Playing"
    property color trackColor: (m.textColor && m.textColor.length > 3) ? m.textColor : theme.mauve

    // ФІКС 1: Блокування оновлень інтерфейсу при взаємодії (щоб не "відскакувало" назад)
    property bool isInteracting: false
    Timer {
        id: interactionCooldown
        interval: 2000 // 2 секунди ігноруємо скрипт після твого кліку
        onTriggered: playerWindow.isInteracting = false
    }

    anchors { top: true; right: true }
    margins { top: 60; right: 20 }
    
    // ФІКС 2: Збільшено висоту вікна до 880, щоб ніколи нічого не обрізало знизу
    implicitWidth: 460
    implicitHeight: 880
    color: "transparent"

    QtObject {
        id: theme
        property color crust: "#11111b"
        property color mantle: "#181825"
        property color base: "#1e1e2e"
        property color surface0: "#313244"
        property color surface1: "#45475a"
        property color text: "#cdd6f4"
        property color subtext0: "#a6adc8"
        property color mauve: "#cba6f7"
        property color pink: "#f5c2e7"
    }

    Process { id: mediaScript; command: ["/home/union/.config/quickshell/scripts/media.sh"] }
    Process { id: mediaCmd }
    
    function runCmd(args) {
        mediaCmd.command = args;
        mediaCmd.running = true;
    }

    // Головний таймер опитування
    Timer {
        interval: 1000; running: playerWindow.isVisible; repeat: true; triggeredOnStart: true
        onTriggered: {
            mediaScript.running = true;
            
            // Якщо ми щойно тиснули паузу або звук — ігноруємо старі дані від bash скрипта
            if (playerWindow.isInteracting) return; 

            var xhr = new XMLHttpRequest();
            xhr.open("GET", "file:///tmp/qs_media.json", false);
            xhr.send();
            if (xhr.status === 200 || xhr.status === 0) {
                try { playerWindow.m = JSON.parse(xhr.responseText); } catch(e) {}
            }
        }
    }

    Rectangle {
        id: mainContainer
        anchors.fill: parent
        color: theme.crust
        radius: 36
        border.color: theme.surface0
        border.width: 1
        clip: true

        opacity: playerWindow.isVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        transform: Translate { 
            y: playerWindow.isVisible ? 0 : -40 
            Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        }

        // Фонове світіння
        Rectangle {
            anchors.fill: parent
            opacity: playerWindow.isPlaying ? 0.15 : 0.05
            Behavior on opacity { NumberAnimation { duration: 1000 } }
            gradient: Gradient {
                GradientStop { position: 0.0; color: playerWindow.trackColor }
                GradientStop { position: 0.6; color: "transparent" }
            }
            Behavior on gradient { ColorAnimation { duration: 1000 } }
        }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 25; spacing: 20

            // ==========================================
            // 1. ШАПКА (ІДЕАЛЬНО ВІДЦЕНТРОВАНА)
            // ==========================================
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 45
                color: theme.mantle; radius: 22; border.color: theme.surface0; border.width: 1

                Item {
                    anchors.fill: parent; anchors.margins: 15
                    
                    Text { 
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "󰅁"; font.pixelSize: 20; color: btnPrevP.containsMouse ? theme.text : theme.subtext0
                        Behavior on color { ColorAnimation { duration: 150 } }
                        MouseArea { id: btnPrevP; anchors.fill: parent; anchors.margins: -10; hoverEnabled: true; onClicked: playerWindow.prevPlayerClicked() } 
                    }
                    
                    // ФІКС 3: Абсолютне центрування тексту!
                    Text { 
                        anchors.centerIn: parent
                        text: playerWindow.activePlayer ? playerWindow.activePlayer.name.toUpperCase() : "MEDIA CENTER"
                        color: playerWindow.trackColor; font.bold: true; font.pixelSize: 13; font.letterSpacing: 2
                        Behavior on color { ColorAnimation { duration: 800 } }
                    }

                    Text { 
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "󰅂"; font.pixelSize: 20; color: btnNextP.containsMouse ? theme.text : theme.subtext0
                        Behavior on color { ColorAnimation { duration: 150 } }
                        MouseArea { id: btnNextP; anchors.fill: parent; anchors.margins: -10; hoverEnabled: true; onClicked: playerWindow.nextPlayerClicked() } 
                    }
                }
            }

            // ==========================================
            // 2. ВІНІЛ, ТОНАРМ ТА "КАВА"
            // ==========================================
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 320 // Трохи збільшили простір під вініл
                Layout.topMargin: 10

                // Візуалізатор (Кава)
                Item {
                    anchors.centerIn: parent
                    width: 270; height: 270
                    visible: playerWindow.isPlaying 

                    Repeater {
                        model: 4 
                        Rectangle {
                            anchors.centerIn: parent
                            width: 260; height: 260; radius: 130
                            color: playerWindow.trackColor
                            border.color: playerWindow.trackColor; border.width: 2
                            
                            NumberAnimation on scale {
                                from: 1.0; to: 1.6 + (index * 0.1)
                                duration: 3000; loops: Animation.Infinite; running: playerWindow.isPlaying
                            }
                            NumberAnimation on opacity {
                                from: 0.3 - (index * 0.05); to: 0.0
                                duration: 3000; loops: Animation.Infinite; running: playerWindow.isPlaying
                            }
                            Behavior on color { ColorAnimation { duration: 800 } }
                        }
                    }
                }

                Item {
                    id: vinylWrapper
                    width: 260; height: 260
                    anchors.centerIn: parent

                    Item {
                        anchors.fill: parent
                        
                        RotationAnimation on rotation {
                            loops: Animation.Infinite; from: 0; to: 360; duration: 8000 
                            running: playerWindow.isPlaying
                        }

                        Image {
                            id: trackArt
                            anchors.fill: parent
                            source: playerWindow.m.artUrl ? "file://" + playerWindow.m.artUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: false 
                        }

                        Rectangle {
                            id: circleMask
                            anchors.fill: parent
                            radius: width / 2
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: trackArt
                            maskSource: circleMask
                        }

                        Rectangle {
                            anchors.fill: parent; radius: width / 2; color: theme.surface0
                            visible: !playerWindow.m.artUrl
                            Text { anchors.centerIn: parent; text: "󰎆"; font.pixelSize: 80; color: theme.surface1 }
                        }

                        Rectangle { anchors.fill: parent; radius: width/2; color: "transparent"; border.color: "#0a0a0f"; border.width: 14 }
                        Rectangle { anchors.centerIn: parent; width: 210; height: 210; radius: 105; color: "transparent"; border.color: "#8011111a"; border.width: 2 }
                        Rectangle { anchors.centerIn: parent; width: 160; height: 160; radius: 80; color: "transparent"; border.color: "#8011111a"; border.width: 2 }

                        Rectangle {
                            anchors.centerIn: parent; width: 76; height: 76; radius: 38
                            color: playerWindow.trackColor; border.color: theme.mantle; border.width: 4
                            Behavior on color { ColorAnimation { duration: 800 } }
                            Rectangle { anchors.centerIn: parent; width: 14; height: 14; radius: 7; color: theme.crust }
                        }
                    }

                    // Відблиск
                    Rectangle {
                        anchors.fill: parent; radius: width / 2
                        color: "transparent"
                        rotation: 45
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#26ffffff" }
                            GradientStop { position: 0.4; color: "transparent" }
                            GradientStop { position: 0.6; color: "transparent" }
                            GradientStop { position: 1.0; color: "#66000000" }
                        }
                    }
                }

                // Розумний тонарм
                Item {
                    id: tonearm
                    width: 40; height: 200
                    anchors.top: parent.top; anchors.topMargin: -10
                    anchors.right: parent.right; anchors.rightMargin: 40
                    transformOrigin: Item.Top 
                    
                    rotation: playerWindow.isPlaying ? (25 + ((playerWindow.m.percent || 0) / 100) * 25) : 0
                    Behavior on rotation { SpringAnimation { spring: 1.5; damping: 0.25 } } 

                    Rectangle { width: 38; height: 38; radius: 19; color: theme.surface1; anchors.horizontalCenter: parent.horizontalCenter; border.color: theme.crust; border.width: 4; z: 5 }
                    Rectangle { width: 6; height: 170; color: "#a6adc8"; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 15; z: 4 }
                    Rectangle { 
                        width: 18; height: 45; radius: 4; color: playerWindow.trackColor
                        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: -12
                        rotation: 25; z: 4
                        Behavior on color { ColorAnimation { duration: 800 } }
                    }
                }
            }

            // ==========================================
            // 3. ІНФОРМАЦІЯ ПРО ТРЕК + МІНІ-ЕКВАЛАЙЗЕР
            // ==========================================
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 15
                spacing: 15

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text { 
                        text: playerWindow.m.title || "Not Playing"
                        color: theme.text; font.bold: true; font.pixelSize: 26
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Text { 
                        text: playerWindow.m.artist || "Waiting for media..."
                        color: theme.subtext0; font.pixelSize: 16; font.bold: true
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                }

                Row {
                    spacing: 4; Layout.alignment: Qt.AlignBottom
                    Repeater {
                        model: 5
                        Rectangle {
                            width: 6; radius: 3; color: playerWindow.trackColor
                            height: playerWindow.isPlaying ? (10 + Math.random() * 25) : 4
                            Behavior on height { SpringAnimation { spring: 3; damping: 0.2 } }
                            Behavior on color { ColorAnimation { duration: 800 } }
                        }
                    }
                    Timer { interval: 150; running: playerWindow.isPlaying; repeat: true; onTriggered: parent.children[0].height = parent.children[0].height }
                }
            }

            // ==========================================
            // 4. ПРОГРЕС БАР
            // ==========================================
            ColumnLayout {
                Layout.fillWidth: true; Layout.topMargin: 15; spacing: 8
                
                Rectangle {
                    Layout.fillWidth: true; height: 10; radius: 5; color: theme.mantle
                    border.color: theme.surface0; border.width: 1; clip: true
                    
                    Rectangle { 
                        height: parent.height; radius: 5; color: playerWindow.trackColor
                        width: parent.width * ((playerWindow.m.percent || 0) / 100)
                        Behavior on width { NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
                        Behavior on color { ColorAnimation { duration: 800 } }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "0%"; color: theme.surface1; font.pixelSize: 11; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: "100%"; color: theme.surface1; font.pixelSize: 11; font.bold: true }
                }
            }

            // ==========================================
            // 5. КЕРУВАННЯ
            // ==========================================
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 110
                Layout.topMargin: 10
                color: theme.base; radius: 28; border.color: theme.surface0; border.width: 1

                RowLayout {
                    anchors.fill: parent; anchors.margins: 20
                    Item { Layout.fillWidth: true } 

                    Rectangle {
                        width: 50; height: 50; radius: 25; color: btnPrev.containsMouse ? theme.surface0 : "transparent"
                        Text { anchors.centerIn: parent; text: "󰒮"; font.pixelSize: 32; color: theme.text }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        scale: btnPrev.pressed ? 0.9 : 1.0; Behavior on scale { SpringAnimation { spring: 3; damping: 0.2 } }
                        MouseArea { 
                            id: btnPrev; anchors.fill: parent; hoverEnabled: true; 
                            onClicked: {
                                playerWindow.isInteracting = true; interactionCooldown.restart();
                                runCmd(["playerctl", "previous"]) 
                            }
                        }
                    }

                    Item { Layout.preferredWidth: 25 } 

                    // КНОПКА PLAY/PAUSE З МИТТЄВОЮ РЕАКЦІЄЮ
                    Rectangle {
                        width: 80; height: 80; radius: 40
                        color: playerWindow.trackColor
                        Behavior on color { ColorAnimation { duration: 800 } }
                        scale: btnPlay.pressed ? 0.9 : (btnPlay.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { SpringAnimation { spring: 3; damping: 0.2 } }

                        Rectangle { anchors.centerIn: parent; width: parent.width; height: parent.height; radius: parent.radius; color: parent.color; opacity: 0.4; scale: 1.15; z: -1 }

                        Text { 
                            anchors.centerIn: parent
                            text: playerWindow.isPlaying ? "󰏤" : "󰐊"
                            font.pixelSize: 46; color: theme.crust
                            anchors.horizontalCenterOffset: playerWindow.isPlaying ? 0 : 3 
                        }
                        MouseArea { 
                            id: btnPlay; anchors.fill: parent; hoverEnabled: true; 
                            onClicked: {
                                // 1. Блокуємо оновлення від bash
                                playerWindow.isInteracting = true;
                                interactionCooldown.restart();
                                // 2. Відправляємо команду в систему
                                runCmd(["playerctl", "play-pause"]);
                                // 3. Миттєво перемальовуємо UI (Оптимістичне оновлення)
                                var newM = JSON.parse(JSON.stringify(playerWindow.m));
                                newM.status = playerWindow.isPlaying ? "Paused" : "Playing";
                                playerWindow.m = newM;
                            }
                        }
                    }

                    Item { Layout.preferredWidth: 25 }

                    Rectangle {
                        width: 50; height: 50; radius: 25; color: btnNext.containsMouse ? theme.surface0 : "transparent"
                        Text { anchors.centerIn: parent; text: "󰒭"; font.pixelSize: 32; color: theme.text }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        scale: btnNext.pressed ? 0.9 : 1.0; Behavior on scale { SpringAnimation { spring: 3; damping: 0.2 } }
                        MouseArea { 
                            id: btnNext; anchors.fill: parent; hoverEnabled: true; 
                            onClicked: {
                                playerWindow.isInteracting = true; interactionCooldown.restart();
                                runCmd(["playerctl", "next"]) 
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            Item { Layout.fillHeight: true } // Гнучкий простір, щоб відштовхнути гучність у самий низ

            // ==========================================
            // 6. ГУЧНІСТЬ ТА АУДІОПРИСТРІЙ (Більше не обрізається!)
            // ==========================================
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 75
                color: theme.mantle; radius: 20; border.color: theme.surface0; border.width: 1

                RowLayout {
                    anchors.fill: parent; anchors.margins: 15; spacing: 15

                    Rectangle {
                        Layout.preferredWidth: 44; Layout.preferredHeight: 44; radius: 14; color: theme.surface0
                        Text { anchors.centerIn: parent; text: playerWindow.m.deviceIcon || "󰋋"; color: playerWindow.trackColor; font.pixelSize: 24; Behavior on color { ColorAnimation { duration: 800 } } }
                    }

                    // ФІКС 4: Жорстко обмежена ширина тексту, щоб не стискало повзунок
                    Item {
                        Layout.preferredWidth: 120; Layout.fillHeight: true
                        Column {
                            anchors.verticalCenter: parent.verticalCenter; width: parent.width; spacing: 3
                            Text { 
                                text: playerWindow.m.deviceName || "Speaker"
                                color: theme.text; font.pixelSize: 13; font.bold: true
                                width: parent.width; elide: Text.ElideRight // Зайвий текст стає "..."
                            }
                            Text { text: playerWindow.m.volume + "%"; color: theme.subtext0; font.pixelSize: 12; font.bold: true }
                        }
                    }

                    // ПОВЗУНОК ГУЧНОСТІ З ПЕРЕТЯГУВАННЯМ (Drag)
                    Rectangle {
                        Layout.fillWidth: true; height: 14; radius: 7; color: theme.crust
                        border.color: theme.surface0; border.width: 1
                        
                        Rectangle {
                            height: parent.height; radius: 7; color: playerWindow.trackColor
                            width: parent.width * (parseInt(playerWindow.m.volume || 0) / 100)
                            Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: 800 } }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            preventStealing: true // Щоб вікно не забирало фокус
                            
                            function updateVolume(mouse) {
                                let val = Math.round((mouse.x / width) * 100);
                                if (val < 0) val = 0;
                                if (val > 100) val = 100;
                                
                                // 1. Блокуємо bash-скрипт
                                playerWindow.isInteracting = true;
                                interactionCooldown.restart();
                                
                                // 2. Застосовуємо гучність у систему
                                runCmd(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", val + "%"]);
                                
                                // 3. Миттєво оновлюємо UI та цифри
                                var newM = JSON.parse(JSON.stringify(playerWindow.m));
                                newM.volume = val;
                                playerWindow.m = newM;
                            }

                            onClicked: (mouse) => updateVolume(mouse)
                            onPositionChanged: (mouse) => { if (pressed) updateVolume(mouse); } // Працює при перетягуванні!
                        }
                    }
                }
            }
        }
    }
}