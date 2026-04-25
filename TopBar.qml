import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: topBar
    
    // Вхідні дані
    property bool showPlayerStatus: false
    property bool showControlCenterStatus: false
    property bool showSystemStatus: false
    property bool showWeatherStatus: false // Можна додати для підсвітки
    property string trackTitle: "Music"
    
    // СИГНАЛИ
    signal togglePlayer()
    signal toggleControlCenter()
    signal toggleSystemMonitor()
    signal toggleWeather() // НОВИЙ СИГНАЛ ДЛЯ ПОГОДИ

    anchors { top: true; left: true; right: true }
    implicitHeight: 38
    color: "#1e1e2e"

    // ЛІВА ЧАСТИНА (Arch Icon + Settings)
    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 20
        spacing: 16

        Text { text: " "; color: "#89b4fa"; font.pixelSize: 18 }

        Rectangle {
            implicitWidth: 32; implicitHeight: 28; radius: 6
            color: topBar.showControlCenterStatus ? "#313244" : (settingsHover.hovered ? "#24242e" : "transparent")
            Text { text: "󰒓"; color: "#cdd6f4"; font.pixelSize: 18; anchors.centerIn: parent }
            HoverHandler { id: settingsHover }
            TapHandler { onTapped: topBar.toggleControlCenter() }
        }

        Rectangle {
            implicitWidth: 32; implicitHeight: 28; radius: 6
            color: topBar.showSystemStatus ? "#313244" : (systemHover.hovered ? "#24242e" : "transparent")
            Text { text: "󰈙"; color: "#cdd6f4"; font.pixelSize: 18; anchors.centerIn: parent }
            HoverHandler { id: systemHover }
            TapHandler { onTapped: topBar.toggleSystemMonitor() }
        }
    }

    // ЦЕНТРАЛЬНА ЧАСТИНА (ГОДИННИК + КЛІК ДЛЯ ПОГОДИ)
    Rectangle {
        anchors.centerIn: parent
        // Робимо зону кліку трохи ширшою за сам текст
        implicitWidth: clockText.width + 30 
        implicitHeight: 28
        radius: 8
        // Підсвічуємо, якщо навели мишкою
        color: clockHover.hovered ? "#24242e" : "transparent"

        Text {
            id: clockText
            anchors.centerIn: parent
            property string currentTime: ""
            text: currentTime
            color: "#cdd6f4"; font.pixelSize: 14; font.bold: true; font.family: "monospace"
            
            Timer { 
                interval: 1000; running: true; repeat: true
                onTriggered: { parent.currentTime = Qt.formatDateTime(new Date(), "hh:mm:ss") } 
            }
            Component.onCompleted: { currentTime = Qt.formatDateTime(new Date(), "hh:mm:ss") }
        }

        HoverHandler { id: clockHover }
        TapHandler { onTapped: topBar.toggleWeather() } // ВИКЛИКАЄМО ПОГОДУ
    }

    // ПРАВА ЧАСТИНА (ПЛЕЄР)
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 12
        implicitWidth: playerBtnRow.width + 24
        implicitHeight: 28
        radius: 8
        color: topBar.showPlayerStatus ? "#313244" : (playerBtnHover.hovered ? "#24242e" : "transparent")
        
        Row {
            id: playerBtnRow
            anchors.centerIn: parent
            spacing: 8
            Text { text: "󰎆"; color: "#f4db9d"; font.pixelSize: 16 }
            Text {
                text: topBar.trackTitle
                color: "#cdd6f4"; font.pixelSize: 13; font.family: "monospace"
                width: Math.min(200, 200) // Обмежуємо ширину, щоб не вилізло за край
                elide: Text.ElideRight
            }
        }
        HoverHandler { id: playerBtnHover }
        TapHandler { onTapped: topBar.togglePlayer() }
    }
}