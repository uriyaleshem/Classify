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
    palette.window: "#F6F7FB"
    palette.windowText: "#0F172A"
    palette.base: "#FFFFFF"
    palette.alternateBase: "#F8FAFC"
    palette.text: "#0F172A"
    palette.button: "#FFFFFF"
    palette.buttonText: "#0F172A"
    palette.placeholderText: "#64748B"
    palette.highlight: "#4F46E5"
    palette.highlightedText: "#FFFFFF"

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
