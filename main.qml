import QtQuick 2.15
import QtQuick.Controls 2.15

ApplicationWindow {
    id: win
    visible: true
    width: 1800
    height: 1080
    minimumWidth: 900
    minimumHeight: 560
    title: "Classify"
    color: "#F6F7FB"
    font.family: "Segoe UI"

    StackView {
        id: stack
        anchors.fill: parent
        initialItem: "data/screens/Login.qml"
    }

    Connections {
        target: (typeof auth !== "undefined") ? auth : null

        function onLoginResult(success, message, role, userId) {
            if (!success) return

            console.log("Logged in:", role, "userId:", userId)
        }
    }
}
