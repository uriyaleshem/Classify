import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects 1.0

Item {
    id: signup
    anchors.fill: parent

    // ====== TUNING ======
    property real intro: 0.0
    property real mx: 0.0
    property real my: 0.0
    property bool loading: false
    property string debugText: ""

    // --- splash control (כדי שיראה טבעי כמו login) ---
    property bool splashDone: true   // כאן אין splash, אבל נשאיר את הלוגיקה
    property bool signedUp: false
    property bool lastMessageIsSuccess: false

    function clearInvalidStates() {
        nameBox.invalid = false
        emailBox.invalid = false
        passBox.invalid = false
        confirmBox.invalid = false
        roleContainer.invalid = false
        schoolIdContainer.invalid = false
    }

    function applyServerValidation(message) {
        clearInvalidStates()

        var msg = (message || "").toLowerCase()

        if (msg.indexOf("full name") !== -1 || msg.indexOf("name") !== -1) {
            nameBox.invalid = true
        }

        if (msg.indexOf("email") !== -1) {
            emailBox.invalid = true
        }

        if (msg.indexOf("passwords do not match") !== -1 || msg.indexOf("passwords don't match") !== -1) {
            passBox.invalid = true
            confirmBox.invalid = true
            return
        }

        if (msg.indexOf("password") !== -1) {
            passBox.invalid = true
        }

        if (msg.indexOf("school id") !== -1 || msg.indexOf("valid school id") !== -1 || msg.indexOf("school with that id") !== -1 || msg.indexOf("school not found") !== -1) {
            schoolIdContainer.invalid = true
        }
    }

    // ====== PARALLAX TRACK ======
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: (m)=> {
            signup.mx = (m.x / signup.width) * 2 - 1
            signup.my = (m.y / signup.height) * 2 - 1
        }
        onExited: {
            mxBack.restart()
            myBack.restart()
        }

        NumberAnimation { id: mxBack; target: signup; property: "mx"; to: 0; duration: 320; easing.type: Easing.OutCubic }
        NumberAnimation { id: myBack; target: signup; property: "my"; to: 0; duration: 320; easing.type: Easing.OutCubic }
    }

    // ====== INTRO (כמו אצלך) ======
    SequentialAnimation {
        id: introAnim
        ParallelAnimation {
            NumberAnimation { target: signup; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: signup; property: "intro"; from: 0; to: 1; duration: 900; easing.type: Easing.OutBack }
        }
    }

    Component.onCompleted: introAnim.start()

    // ====== BACKGROUND ======
    Item {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#FFFFFFFF" }
                GradientStop { position: 1.0; color: "#FFF6F7FB" }
            }
        }

        Repeater {
            model: 90
            Rectangle {
                width: 2; height: 2; radius: 1
                color: "#0A0F172A"
                opacity: 0.10
                x: (index * 97) % signup.width
                y: (index * 173) % signup.height
            }
        }
    }

    // ================== PYTHON CONNECTIONS ==================
    Connections {
        target: (typeof auth !== "undefined") ? auth : null

        function onSignupResult(success, message) {
            signup.loading = false
            netTimeout.stop()

            if (success) {
                signup.debugText = message
                signup.lastMessageIsSuccess = true
                signup.signedUp = true
                // אחרי הרשמה מוצלחת: חוזרים ל-Login בצורה טבעית
                StackView.view.pop()
            } else {
                signup.debugText = message
                signup.lastMessageIsSuccess = false
                signup.applyServerValidation(message)
                shakeAnim.restart()
            }
        }
    }

    Timer {
        id: netTimeout
        interval: 8000
        repeat: false
        onTriggered: {
            signup.loading = false
            signup.debugText = "The server took too long to respond. Please try again."
            signup.lastMessageIsSuccess = false
            signup.clearInvalidStates()
            shakeAnim.restart()
        }
    }

    // ================= MAIN UI =================
    Item {
        id: mainUI
        anchors.fill: parent
        opacity: splashDone ? 1.0 : 0.0
        visible: splashDone
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ================= LEFT =================
            Rectangle {
                id: leftPanel
                Layout.fillHeight: true
                Layout.preferredWidth: 520
                Layout.maximumWidth: signup.width * 0.5

                x: (-80) * (1 - signup.intro)
                opacity: signup.intro

                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#5B5CE2" }
                    GradientStop { position: 1.0; color: "#4F46E5" }
                }



                Rectangle {
                    width: 520; height: 520; radius: width/2
                    color: "#FFFFFF"
                    opacity: 0.11
                    x: -180 + signup.mx * 10
                    y: -120 + signup.my * 10
                }
                Rectangle {
                    width: 420; height: 420; radius: width/2
                    color: "#FFFFFF"
                    opacity: 0.08
                    x: leftPanel.width - width - 180 - signup.mx * 12
                    y: leftPanel.height - height - 140 - signup.my * 12
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 64
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 128
                    spacing: 16

                    y: 14 * (1 - signup.intro)
                    opacity: signup.intro

                    Row {
                        spacing: 10
                        Rectangle {
                            width: 34; height: 34; radius: 10
                            color: "#FFFFFF"; opacity: 0.18
                            Text { anchors.centerIn: parent; text: "◼"; color: "#FFFFFF"; opacity: 0.95; font.pixelSize: 16 }
                        }
                        Text {
                            text: "Classify"
                            color: "#FFFFFF"
                            opacity: 0.95
                            y: -10
                            font.pixelSize: 40
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Item { height: 24; width: 1 }

                    Text {
                        text: "Create\nyour account"
                        color: "#FFFFFF"
                        opacity: 0.98
                        font.pixelSize: 40
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                        lineHeight: 1.12
                    }

                    Text {
                        text: "Join your classroom, submit tasks and\nget AI feedback."
                        color: "#FFFFFF"
                        opacity: 0.82
                        font.pixelSize: 14
                        wrapMode: Text.Wrap
                        lineHeight: 1.35
                    }
                }
            }

            // ================= RIGHT =================
            Item {
                id: rightPanel
                Layout.fillHeight: true
                Layout.fillWidth: true

                Item {
                    id: drift
                    anchors.centerIn: parent
                    width: Math.min(560, parent.width * 0.82)
                    height: 560
                    x: signup.mx * 6
                    y: signup.my * 6

                    Item {
                        id: cardWrap
                        anchors.centerIn: parent
                        width: drift.width
                        implicitHeight: card.implicitHeight

                        y: 26 * (1 - signup.intro)
                        opacity: Math.min(1, signup.intro * 1.25)
                        scale: 0.94 + 0.06 * signup.intro

                        property int shake: 0
                        x: shake

                        SequentialAnimation {
                            id: shakeAnim
                            running: false
                            NumberAnimation { target: cardWrap; property: "shake"; to: -10; duration: 55; easing.type: Easing.InOutSine }
                            NumberAnimation { target: cardWrap; property: "shake"; to:  10; duration: 55; easing.type: Easing.InOutSine }
                            NumberAnimation { target: cardWrap; property: "shake"; to:  -7; duration: 55; easing.type: Easing.InOutSine }
                            NumberAnimation { target: cardWrap; property: "shake"; to:   7; duration: 55; easing.type: Easing.InOutSine }
                            NumberAnimation { target: cardWrap; property: "shake"; to:   0; duration: 70; easing.type: Easing.OutCubic }
                        }

                        DropShadow {
                            anchors.fill: card
                            source: card
                            horizontalOffset: 0
                            verticalOffset: 18
                            radius: 34
                            samples: 44
                            color: "#26000000"
                        }

                        Rectangle {
                            id: card
                            width: cardWrap.width
                            radius: 20
                            color: "#FFFFFF"
                            border.width: 1
                            border.color: "#14000000"
                            implicitHeight: content.implicitHeight + 64

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 1
                                border.color: "#10FFFFFF"
                            }

                            ColumnLayout {
                                id: content
                                width: parent.width - 64
                                x: 32
                                y: 32
                                spacing: 14

                                Text {
                                    text: "Sign up"
                                    color: "#0F172A"
                                    font.pixelSize: 22
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    text: "Create your account and get started."
                                    color: "#64748B"
                                    font.pixelSize: 13
                                }

                                Item { Layout.preferredHeight: 8 }


                                // ===== Name =====
                                Item {
                                    id: nameBox
                                    Layout.fillWidth: true
                                    implicitHeight: 48

                                    property bool focused: nameField.activeFocus
                                    property bool invalid: false

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 14
                                        color: "#F3F4F6"
                                        border.width: 1
                                        border.color: nameBox.invalid ? "#EF4444"
                                                   : nameBox.focused ? "#4F46E5"
                                                   : "#1A0F172A"
                                        Behavior on border.color { ColorAnimation { duration: 160 } }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 14
                                        color: "transparent"
                                        border.width: 2
                                        border.color: "#4F46E5"
                                        opacity: nameBox.focused ? 0.35 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 160 } }
                                    }

                                    TextField {
                                        id: nameField
                                        anchors.fill: parent
                                        placeholderText: "Full Name"
                                        font.pixelSize: 13
                                        leftPadding: 14; rightPadding: 14
                                        topPadding: 12; bottomPadding: 12
                                        background: null
                                        onTextChanged: nameBox.invalid = false
                                    }
                                }
                                // ===== Email =====
                                Item {
                                    id: emailBox
                                    Layout.fillWidth: true
                                    implicitHeight: 48

                                    property bool focused: emailField.activeFocus
                                    property bool invalid: false

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 14
                                        color: "#F3F4F6"
                                        border.width: 1
                                        border.color: emailBox.invalid ? "#EF4444"
                                                   : emailBox.focused ? "#4F46E5"
                                                   : "#1A0F172A"
                                        Behavior on border.color { ColorAnimation { duration: 160 } }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 14
                                        color: "transparent"
                                        border.width: 2
                                        border.color: "#4F46E5"
                                        opacity: emailBox.focused ? 0.35 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 160 } }
                                    }

                                    TextField {
                                        id: emailField
                                        anchors.fill: parent
                                        placeholderText: "Email"
                                        font.pixelSize: 13
                                        leftPadding: 14; rightPadding: 14
                                        topPadding: 12; bottomPadding: 12
                                        background: null
                                        onTextChanged: emailBox.invalid = false
                                    }
                                }

                                // ===== Password =====
                                Item {
                                    id: passBox
                                    Layout.fillWidth: true
                                    implicitHeight: 48

                                    property bool focused: passField.activeFocus
                                    property bool invalid: false

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 14
                                        color: "#F3F4F6"
                                        border.width: 1
                                        border.color: passBox.invalid ? "#EF4444"
                                                   : passBox.focused ? "#4F46E5"
                                                   : "#1A0F172A"
                                        Behavior on border.color { ColorAnimation { duration: 160 } }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 14
                                        color: "transparent"
                                        border.width: 2
                                        border.color: "#4F46E5"
                                        opacity: passBox.focused ? 0.35 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 160 } }
                                    }

                                    TextField {
                                        id: passField
                                        anchors.fill: parent
                                        placeholderText: "Password"
                                        echoMode: TextInput.Password
                                        font.pixelSize: 13
                                        leftPadding: 14; rightPadding: 14
                                        topPadding: 12; bottomPadding: 12
                                        background: null
                                        onTextChanged: passBox.invalid = false
                                    }
                                }

                                // ===== Confirm Password =====
                                Item {
                                    id: confirmBox
                                    Layout.fillWidth: true
                                    implicitHeight: 48

                                    property bool focused: confirmField.activeFocus
                                    property bool invalid: false

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 14
                                        color: "#F3F4F6"
                                        border.width: 1
                                        border.color: confirmBox.invalid ? "#EF4444"
                                                   : confirmBox.focused ? "#4F46E5"
                                                   : "#1A0F172A"
                                        Behavior on border.color { ColorAnimation { duration: 160 } }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 14
                                        color: "transparent"
                                        border.width: 2
                                        border.color: "#4F46E5"
                                        opacity: confirmBox.focused ? 0.35 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 160 } }
                                    }

                                    TextField {
                                        id: confirmField
                                        anchors.fill: parent
                                        placeholderText: "Confirm password"
                                        echoMode: TextInput.Password
                                        font.pixelSize: 13
                                        leftPadding: 14; rightPadding: 14
                                        topPadding: 12; bottomPadding: 12
                                        background: null
                                        onTextChanged: confirmBox.invalid = false
                                    }
                                }

                                // ===== Role =====
                                Item {
                                    id: roleContainer
                                    Layout.fillWidth: true
                                    implicitHeight: 48

                                    property bool focused: roleBox.activeFocus
                                    property bool invalid: false   // אם תרצה להפעיל ולידציה גם לזה

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 14
                                        color: "#F3F4F6"
                                        border.width: 1
                                        border.color: roleContainer.invalid ? "#EF4444"
                                                   : roleContainer.focused ? "#4F46E5"
                                                   : "#1A0F172A"
                                        Behavior on border.color { ColorAnimation { duration: 160 } }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 14
                                        color: "transparent"
                                        border.width: 2
                                        border.color: "#4F46E5"
                                        opacity: roleContainer.focused ? 0.35 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 160 } }
                                    }

                                    ComboBox {
                                        id: roleBox
                                        anchors.fill: parent
                                        model: ["STUDENT", "TEACHER", "MANAGER"]

                                        onCurrentTextChanged: {
                                            if (currentText === "MANAGER") {
                                                if (typeof schoolIdField !== "undefined") schoolIdField.text = ""
                                            }
                                        }

                                        background: null

                                        // הטקסט בפנים (כמו TextField)
                                        contentItem: Text {
                                            text: roleBox.displayText
                                            font.pixelSize: 13
                                            color: "#0F172A"
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight

                                            leftPadding: 14
                                            rightPadding: 40   // מקום לחץ בשביל החץ
                                        }

                                        // חץ מימין
                                        indicator: Text {
                                            text: "▾"
                                            color: "#64748B"
                                            font.pixelSize: 14
                                            anchors.right: parent.right
                                            anchors.rightMargin: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        // תפריט נפתח קצת יותר “שלך” (לא חובה, אבל מוסיף עקביות)
                                        popup: Popup {
                                            y: roleContainer.height + 6
                                            width: roleContainer.width
                                            padding: 6

                                            background: Rectangle {
                                                radius: 12
                                                color: "white"
                                                border.width: 1
                                                border.color: "#1A0F172A"
                                            }

                                            contentItem: ListView {
                                                implicitHeight: Math.min(contentHeight, 220)
                                                model: roleBox.delegateModel
                                                currentIndex: roleBox.highlightedIndex
                                                clip: true
                                            }
                                        }
                                    }
                                }
                                // ===== School ID (Students/Teachers only) =====
                                Item {
                                    id: schoolIdContainer
                                    Layout.fillWidth: true
                                    implicitHeight: 48

                                    // editable only for STUDENT / TEACHER
                                    property bool enabledForRole: (roleBox.currentText === "STUDENT" || roleBox.currentText === "TEACHER")
                                    property bool focused: schoolIdField.activeFocus
                                    property bool invalid: false

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 14
                                        color: "#F3F4F6"
                                        border.width: 1
                                        border.color: schoolIdContainer.invalid ? "#EF4444"
                                                   : schoolIdContainer.focused ? "#4F46E5"
                                                   : "#1A0F172A"
                                        Behavior on border.color { ColorAnimation { duration: 160 } }
                                        opacity: schoolIdContainer.enabledForRole ? 1.0 : 0.65
                                        Behavior on opacity { NumberAnimation { duration: 160 } }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 14
                                        color: "transparent"
                                        border.width: 2
                                        border.color: "#4F46E5"
                                        opacity: (schoolIdContainer.focused && schoolIdContainer.enabledForRole) ? 0.35 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 160 } }
                                    }

                                    TextField {
                                        id: schoolIdField
                                        anchors.fill: parent
                                        placeholderText: schoolIdContainer.enabledForRole ? "School ID" : "School ID (students/teachers only)"
                                        font.pixelSize: 13
                                        leftPadding: 14; rightPadding: 14
                                        topPadding: 12; bottomPadding: 12
                                        background: null

                                        enabled: schoolIdContainer.enabledForRole
                                        readOnly: !schoolIdContainer.enabledForRole

                                        color: "#0F172A"
                                        placeholderTextColor: "#64748B"
                                        onTextChanged: schoolIdContainer.invalid = false

                                        onEnabledChanged: {
                                            if (!enabled) text = ""
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: signup.debugText
                                    color: signup.lastMessageIsSuccess ? "#16A34A" : "#DC2626"
                                    font.pixelSize: 12
                                    wrapMode: Text.Wrap
                                    visible: signup.debugText.length > 0
                                }
                                Item { Layout.preferredHeight: 4 }

                                // ===== Submit button (כמו שלך) =====
                                Item {

                                    Layout.fillWidth: true
                                    implicitHeight: 46

                                    Rectangle {
                                        id: signUpBtn
                                        opacity: signup.loading ? 0.85 : 1.0
                                        anchors.fill: parent
                                        radius: 14
                                        clip: true

                                        property bool hovered: false
                                        property bool pressed: false

                                        color: pressed ? "#3730A3"
                                             : hovered ? "#4338CA"
                                             : "#4F46E5"

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            height: parent.height * 0.45
                                            radius: parent.radius
                                            color: "#12FFFFFF"
                                        }

                                        Rectangle {
                                            id: ripple
                                            width: 12; height: 12
                                            radius: width/2
                                            color: "#FFFFFF"
                                            opacity: 0.0
                                            scale: 1.0
                                            x: rx - width/2
                                            y: ry - height/2
                                        }
                                        property real rx: width/2
                                        property real ry: height/2

                                        function splash(px, py) {
                                            rx = px; ry = py
                                            ripple.width = 14
                                            ripple.height = 14
                                            ripple.opacity = 0.20
                                            ripple.scale = 1.0
                                            rippleAnim.restart()
                                        }

                                        ParallelAnimation {
                                            id: rippleAnim
                                            NumberAnimation { target: ripple; property: "scale"; to: 26; duration: 520; easing.type: Easing.OutCubic }
                                            NumberAnimation { target: ripple; property: "opacity"; to: 0.0; duration: 520; easing.type: Easing.OutCubic }
                                        }

                                        Item {
                                            anchors.fill: parent

                                            Text {
                                                visible: !signup.loading
                                                anchors.centerIn: parent
                                                text: "Create account"
                                                color: "#FFFFFF"
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                            }

                                            Item {
                                                visible: signup.loading
                                                anchors.centerIn: parent
                                                width: 18; height: 18

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 9
                                                    color: "transparent"
                                                    border.width: 2
                                                    border.color: "#55FFFFFF"
                                                }
                                                Rectangle {
                                                    width: 4; height: 4; radius: 2
                                                    color: "#FFFFFF"
                                                    x: parent.width/2 - width/2
                                                    y: -2
                                                }
                                                RotationAnimator on rotation {
                                                    running: signup.loading
                                                    from: 0; to: 360
                                                    duration: 800
                                                    loops: Animation.Infinite
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: !signup.loading
                                            cursorShape: Qt.PointingHandCursor

                                            onEntered:  signUpBtn.hovered = true
                                            onExited:   { signUpBtn.hovered = false; signUpBtn.pressed = false }
                                            onPressed:  { signUpBtn.pressed = true; signUpBtn.splash(mouse.x, mouse.y) }
                                            onReleased: signUpBtn.pressed = false

                                            onClicked: {
                                                var bad = false
                                                var selectedRole = roleBox.currentText
                                                var requiresSchoolId = (selectedRole === "STUDENT" || selectedRole === "TEACHER")
                                                var trimmedSchoolId = schoolIdField.text.trim()

                                                signup.lastMessageIsSuccess = false
                                                signup.clearInvalidStates()

                                                if (emailField.text.trim().length === 0) { emailBox.invalid = true; bad = true }
                                                if (passField.text.trim().length === 0)  { passBox.invalid  = true; bad = true }
                                                if (confirmField.text.trim().length === 0) { confirmBox.invalid = true; bad = true }
                                                if (nameField.text.trim().length === 0) { nameBox.invalid = true; bad = true }

                                                if (requiresSchoolId && trimmedSchoolId.length === 0) {
                                                    schoolIdContainer.invalid = true
                                                    signup.debugText = "Please enter your school ID."
                                                    bad = true
                                                } else if (requiresSchoolId && !/^\d+$/.test(trimmedSchoolId)) {
                                                    schoolIdContainer.invalid = true
                                                    signup.debugText = "School ID must contain numbers only."
                                                    bad = true
                                                }

                                                if (passField.text !== confirmField.text) {
                                                    passBox.invalid = true
                                                    confirmBox.invalid = true
                                                    signup.debugText = "Passwords do not match."
                                                    bad = true
                                                }

                                                if (bad) {
                                                    shakeAnim.restart()
                                                    return
                                                }

                                                signup.debugText = ""
                                                signup.loading = true

                                                if (typeof auth !== "undefined") {
                                                    auth.signup(nameField.text, emailField.text, passField.text, selectedRole, trimmedSchoolId)
                                                    netTimeout.restart()
                                                } else {
                                                    signup.loading = false
                                                    signup.debugText = "Sign up is currently unavailable. Please restart the app and try again."
                                                    signup.lastMessageIsSuccess = false
                                                    shakeAnim.restart()
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: "#12000000" }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "Already have an account?"
                                        color: "#64748B"
                                        font.pixelSize: 12
                                    }
                                    Item { Layout.fillWidth: true }
                                    Button {
                                        id: backBtn
                                        text: "Sign in"
                                        flat: true
                                        background: Rectangle { color: "transparent" }
                                        contentItem: Text {
                                            text: "Sign in"
                                            color: "#4F46E5"
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }
                                        onClicked: {
                                            var sv = signup.StackView.view
                                            if (!sv) return
                                            sv.pop()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Image {
                        id: cornerLogo
                        source: "png/AppLogo.png"
                        z: 20
                        width: 68
                        height: 68
                        x: card.width - width - 10
                        y: -30
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                }
            }
        }
    }
}
