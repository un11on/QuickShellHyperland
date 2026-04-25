import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: dashboard
    property bool isVisible: false
    
    // Центруємо під годинником на барі
    anchors { top: true; horizontalCenter: parent.horizontalCenter }
    margins { top: 50 } // Відступ від бару
    
    implicitWidth: 600
    implicitHeight: 400
    color: "transparent"

    // Дані погоди
    property string temp: "--°C"
    property string desc: "Loading..."
    property string humidity: "0%"
    property string wind: "0km/h"

    Process {
        id: weatherProc
        command: ["/home/union/.config/quickshell/scripts/weather.sh"]
        stdout: Quickshell.lines(line => {
            let parts = line.split("|");
            if (parts.length >= 4) {
                dashboard.temp = parts[0];
                dashboard.desc = parts[1];
                dashboard.humidity = parts[2];
                dashboard.wind = parts[3];
            }
        })
    }

    Timer {
        interval: 900000 // Оновлювати кожні 15 хв
        running: dashboard.isVisible; repeat: true; triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e" // Catppuccin Mocha
        radius: 12
        border.color: "#89b4fa"
        border.width: 2
        opacity: dashboard.isVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            // ВЕРХНЯ ЧАСТИНА: Великий годинник
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                color: "#313244"
                radius: 10
                
                Text {
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(new Date(), "hh:mm:ss AP")
                    color: "#cdd6f4"
                    font.pixelSize: 48
                    font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                }
            }

            // НИЖНЯ ЧАСТИНА: Погода + Календар
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 15

                // БЛОК ПОГОДИ
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#313244"
                    radius: 10
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        Text { text: "󰖙"; font.pixelSize: 64; color: "#f9e2af"; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: dashboard.temp; color: "#cdd6f4"; font.pixelSize: 32; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: dashboard.desc; color: "#a6adc8"; font.pixelSize: 18; anchors.horizontalCenter: parent.horizontalCenter }
                        
                        Row {
                            spacing: 15; anchors.horizontalCenter: parent.horizontalCenter
                            Text { text: " " + dashboard.humidity; color: "#89b4fa"; font.pixelSize: 14 }
                            Text { text: "󰖝 " + dashboard.wind; color: "#a6adc8"; font.pixelSize: 14 }
                        }
                    }
                }

                // БЛОК КАЛЕНДАРЯ
                Rectangle {
                    Layout.preferredWidth: 320
                    Layout.fillHeight: true
                    color: "#313244"
                    radius: 10
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        
                        Text {
                            text: Qt.formatDateTime(new Date(), "MMMM yyyy")
                            color: "#cdd6f4"; font.bold: true; Layout.alignment: Qt.AlignHCenter
                        }

                        DayOfWeekRow {
                            Layout.fillWidth: true
                            delegate: Text {
                                text: model.shortName
                                color: "#89b4fa"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MonthGrid {
                            id: grid
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            month: new Date().getMonth()
                            year: new Date().getFullYear()
                            
                            delegate: Rectangle {
                                implicitWidth: 35; implicitHeight: 35
                                color: model.today ? "#89b4fa" : "transparent"
                                radius: 5
                                Text {
                                    anchors.centerIn: parent
                                    text: model.day
                                    color: model.today ? "#1e1e2e" : (model.month === grid.month ? "#cdd6f4" : "#585b70")
                                    font.bold: model.today
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}