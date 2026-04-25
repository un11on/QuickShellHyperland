PanelWindow {
    id: weatherPopup
    property bool isVisible: false
    
    // ПРАВИЛЬНЕ ЦЕНТРУВАННЯ
    anchors { 
        top: true 
        // Центруємо відносно екрана автоматично
        horizontalCenter: parent.horizontalCenter 
    }
    
    // Тільки відступ зверху, щоб не перекривати бар
    margins { top: 48 } 

    // Фіксована ширина моноліту
    implicitWidth: 680
    implicitHeight: 300
    color: "transparent"

    // Решта коду (Process, Timer, Rectangle) залишається без змін...