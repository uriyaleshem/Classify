import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects 1.0

Item {
    id: login
    anchors.fill: parent

    // ====== TUNING ======
    property real intro: 0.0
    property real mx: 0.0
    property real my: 0.0
    property bool loading: false
    property string debugText: ""
    property bool keepsign: false
    property bool showpass: false
    // --- splash control ---
    property bool splashDone: false

    // --- login success flag ---
    property bool loggedIn: false

    Component.onCompleted: {
        splashAnim.start()
    }

    function triggerLogin() {
        if (login.loading)
            return
        var bad = false
        if (emailField.text.trim().length === 0) { emailBox.invalid = true; bad = true }
        if (passField.text.trim().length === 0)  { passBox.invalid  = true; bad = true }

        if (bad) {
            shakeAnim.restart()
            return
        }

        login.debugText = ""
        login.loading = true

        if (typeof auth !== "undefined") {
            auth.login(emailField.text, passField.text, keepsign)
            netTimeout.restart()
        } else {
            login.loading = false
            login.debugText = "Login is currently unavailable. Please restart the app and try again."
            shakeAnim.restart()
        }
    }

    // ====== PARALLAX TRACK ======
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: (m)=> {
            login.mx = (m.x / login.width) * 2 - 1
            login.my = (m.y / login.height) * 2 - 1
        }
        onExited: {
            mxBack.restart()
            myBack.restart()
        }

        NumberAnimation { id: mxBack; target: login; property: "mx"; to: 0; duration: 320; easing.type: Easing.OutCubic }
        NumberAnimation { id: myBack; target: login; property: "my"; to: 0; duration: 320; easing.type: Easing.OutCubic }
    }

    // ====== INTRO ======
    SequentialAnimation {
        id: introAnim
        ParallelAnimation {
            NumberAnimation { target: login; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: login; property: "intro"; from: 0; to: 1; duration: 900; easing.type: Easing.OutBack }
        }
    }

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
                x: (index * 97) % login.width
                y: (index * 173) % login.height
            }
        }
    }



    // ================== PYTHON CONNECTIONS ==================
    // 1) תוצאה של Login
    Connections {
        target: (typeof auth !== "undefined") ? auth : null

            function onLoginResult(success, message, role, userId, name, schoolId, schoolName, schoolAddress, schoolContactEmail) {
            login.loading = false
            netTimeout.stop()

            if (success) {
                if (login.StackView.view) {

                    if (role == "STUDENT") {
                        login.StackView.view.push("StudentHome.qml", {
                            userName: name,
                            userId: userId,
                            nav: login.StackView.view
                        })

                    } else if (role == "TEACHER") {
                        login.StackView.view.push("TeacherHome.qml", {
                            userName: name,
                            userId: userId,
                            schoolId: schoolId,
                            nav: login.StackView.view
                        })

                    } else if (role == "MANAGER") {
                        login.StackView.view.push("ManagerHome.qml", {
                            userName: name,
                            userId: userId,
                            schoolId: schoolId,
                            schoolName: schoolName !== "" ? schoolName : "My School",
                            schoolAddress: schoolAddress,
                            schoolContactEmail: schoolContactEmail,
                            nav: login.StackView.view
                        })

                    } else if (role == "ADMIN") {
                        login.StackView.view.push("AdminHome.qml", {
                            userName: name,
                            userId: userId,
                            nav: login.StackView.view
                        })

                    } else {
                        login.debugText = "This account role is not supported yet."
                        shakeAnim.restart()
                    }
                }

            } else {
                login.debugText = message
                shakeAnim.restart()
            }
        }
    }
    // 2) טיימר גיבוי: אם אין תשובה מהשרת, לא להיתקע על loading
    Timer {
        id: netTimeout
        interval: 35000
        repeat: false
        onTriggered: {
            login.loading = false
            login.debugText = "The server took too long to respond. Please try again."
            shakeAnim.restart()
        }
    }

    // ================= MAIN UI (appears only AFTER splash ends) =================
    Item {
        id: mainUI
        anchors.fill: parent
        opacity: splashDone ? 1.0 : 0.0
        visible: splashDone && !login.loggedIn
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ================= LEFT =================
            Rectangle {
                id: leftPanel
                Layout.fillHeight: true
                Layout.preferredWidth: 520
                Layout.maximumWidth: login.width * 0.5

                x: (-80) * (1 - login.intro)
                opacity: login.intro

                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#5B5CE2" }
                    GradientStop { position: 1.0; color: "#4F46E5" }
                }



                Rectangle {
                    id: blob1
                    width: 520; height: 520; radius: width/2
                    color: "#FFFFFF"
                    opacity: 0.11
                    x: -180 + login.mx * 10
                    y: -120 + login.my * 10
                }
                Rectangle {
                    id: blob2
                    width: 420; height: 420; radius: width/2
                    color: "#FFFFFF"
                    opacity: 0.08
                    x: leftPanel.width - width - 180 - login.mx * 12
                    y: leftPanel.height - height - 140 - login.my * 12
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 64
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 128
                    spacing: 16

                    y: 14 * (1 - login.intro)
                    opacity: login.intro

                    Row {
                        spacing: 10
                        Rectangle {
                            width: 34; height: 34; radius: 10
                            color: "#FFFFFF"; opacity: 0.18
                            Text {
                                anchors.centerIn: parent
                                text: "◼"
                                color: "#FFFFFF"
                                opacity: 0.95
                                font.pixelSize: 16
                            }
                        }
                        Text {
                            text: "Classify"
                            color: "#FFFFFF"
                            opacity: 0.95
                            y:-10
                            font.pixelSize: 40
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Item { height: 24; width: 1 }

                    Text {
                        text: "Collaborate\nfrom anywhere"
                        color: "#FFFFFF"
                        opacity: 0.98
                        font.pixelSize: 40
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                        lineHeight: 1.12
                    }

                    Text {
                        text: "Connect with your team, submit and add \ntasks, get AI automated score."
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
                    height: 520
                    x: login.mx * 6
                    y: login.my * 6

                    Item {
                        id: cardWrap
                        anchors.centerIn: parent
                        width: drift.width
                        implicitHeight: card.implicitHeight

                        y: 26 * (1 - login.intro)
                        opacity: Math.min(1, login.intro * 1.25)
                        scale: 0.94 + 0.06 * login.intro

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

                            Rectangle {
                                id: sheen
                                width: parent.width * 0.40
                                height: parent.height
                                radius: parent.radius
                                opacity: 0.0
                                x: -width
                                y: 0
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#00FFFFFF" }
                                    GradientStop { position: 0.5; color: "#18FFFFFF" }
                                    GradientStop { position: 1.0; color: "#00FFFFFF" }
                                }
                                SequentialAnimation on x {
                                    running: true
                                    loops: 1
                                    PauseAnimation { duration: 260 }
                                    ScriptAction { script: sheen.opacity = 1.0 }
                                    NumberAnimation { to: card.width + sheen.width; duration: 900; easing.type: Easing.InOutCubic }
                                    ScriptAction { script: sheen.opacity = 0.0 }
                                }
                            }

                            Item {
                                id: blurLayerHost
                                anchors.fill: parent
                                layer.enabled: true
                                layer.effect: FastBlur { radius: 14 * (1 - login.intro) }
                            }

                            ColumnLayout {
                                id: content
                                width: parent.width - 64
                                x: 32
                                y: 32
                                spacing: 14

                                Text {
                                    text: "Sign in"
                                    color: "#0F172A"
                                    font.pixelSize: 22
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    text: "Welcome back. Let’s continue."
                                    color: "#64748B"
                                    font.pixelSize: 13
                                }

                                Item { Layout.preferredHeight: 8 }

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
                                        color: "#0F172A"
                                        placeholderTextColor: "#64748B"
                                        selectedTextColor: "#FFFFFF"
                                        selectionColor: "#4F46E5"
                                        background: null
                                        onTextChanged: emailBox.invalid = false
                                        Keys.onReturnPressed: login.triggerLogin()
                                        Keys.onEnterPressed: login.triggerLogin()
                                    }
                                }

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
                                        font.pixelSize: 13
                                        leftPadding: 14; rightPadding: 14
                                        topPadding: 12; bottomPadding: 12
                                        color: "#0F172A"
                                        placeholderTextColor: "#64748B"
                                        selectedTextColor: "#FFFFFF"
                                        selectionColor: "#4F46E5"
                                        background: null
                                        onTextChanged: passBox.invalid = false
                                        Keys.onReturnPressed: login.triggerLogin()
                                        Keys.onEnterPressed: login.triggerLogin()

                                        echoMode: login.showpass ? TextInput.Normal : TextInput.Password
                                    }

                                }


                                Item {
                                    id: showPasswordControl
                                    Layout.fillWidth: true
                                    implicitHeight: 20
                                    activeFocusOnTab: true

                                    property bool hovered: false

                                    Row {
                                        id: showPasswordRow
                                        spacing: 8
                                        anchors.left: parent.left
                                        anchors.leftMargin: 2
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            width: 16
                                            height: 16
                                            radius: 5
                                            color: login.showpass ? "#4F46E5" : "#FFFFFF"
                                            border.width: 1
                                            border.color: login.showpass ? "#4F46E5"
                                                        : showPasswordControl.hovered ? "#A5B4FC"
                                                        : "#CBD5E1"

                                            Behavior on color { ColorAnimation { duration: 140 } }
                                            Behavior on border.color { ColorAnimation { duration: 140 } }

                                            Canvas {
                                                id: showPasswordCheck
                                                anchors.fill: parent
                                                visible: login.showpass
                                                onVisibleChanged: if (visible) requestPaint()
                                                onPaint: {
                                                    var ctx = getContext("2d")
                                                    ctx.reset()
                                                    ctx.lineWidth = 2
                                                    ctx.lineCap = "round"
                                                    ctx.lineJoin = "round"
                                                    ctx.strokeStyle = "#FFFFFF"
                                                    ctx.beginPath()
                                                    ctx.moveTo(width * 0.28, height * 0.53)
                                                    ctx.lineTo(width * 0.44, height * 0.68)
                                                    ctx.lineTo(width * 0.74, height * 0.34)
                                                    ctx.stroke()
                                                }
                                            }
                                        }

                                        Text {
                                            text: "Show Password"
                                            color: "#475569"
                                            font.pixelSize: 12
                                            verticalAlignment: Text.AlignVCenter
                                            height: 16
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: showPasswordControl.hovered = true
                                        onExited: showPasswordControl.hovered = false
                                        onClicked: login.showpass = !login.showpass
                                    }

                                    Keys.onSpacePressed: login.showpass = !login.showpass
                                    Keys.onReturnPressed: login.showpass = !login.showpass
                                }



                                Text {
                                    text: login.debugText
                                    color: "red"
                                    font.pixelSize: 12
                                    wrapMode: Text.Wrap
                                    visible: login.debugText.length > 0
                                    Layout.fillWidth: true
                                }

                                Item {
                                    Layout.fillWidth: true
                                    implicitHeight: 46

                                    Rectangle {
                                        id: signInBtn
                                        opacity: login.loading ? 0.85 : 1.0
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
                                                visible: !login.loading
                                                anchors.centerIn: parent
                                                text: "Sign in"
                                                color: "#FFFFFF"
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                            }

                                            Item {
                                                visible: login.loading
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
                                                    running: login.loading
                                                    from: 0; to: 360
                                                    duration: 800
                                                    loops: Animation.Infinite
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: !login.loading
                                            cursorShape: Qt.PointingHandCursor

                                            onEntered:  signInBtn.hovered = true
                                            onExited:   { signInBtn.hovered = false; signInBtn.pressed = false }
                                            onPressed:  {
                                                signInBtn.pressed = true
                                                signInBtn.splash(mouse.x, mouse.y)
                                            }
                                            onReleased: signInBtn.pressed = false

                                            onClicked: login.triggerLogin()
                                        }
                                    }
                                }

                                Button {
                                    id: forgotBtn
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Forgot password?"
                                    flat: true
                                    background: Rectangle { color: "transparent" }
                                    contentItem: Text {
                                        text: forgotBtn.text
                                        color: "#4F46E5"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: "#12000000"
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: "Don't have an account?"
                                        color: "#64748B"
                                        font.pixelSize: 12
                                    }
                                    Item { Layout.fillWidth: true }
                                    Button {
                                        id: createBtn
                                        text: "Create"
                                        flat: true
                                        background: Rectangle { color: "transparent" }
                                        contentItem: Text {
                                            text: "Create"
                                            color: "#4F46E5"
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }
                                        onClicked: {
                                            var sv = login.StackView.view
                                            if (!sv) {
                                                return
                                            }
                                            sv.push(Qt.resolvedUrl("Signup.qml"))
                                        }

                                    }
                                }
                            }
                        }
                    }

                    Image {
                        id: cornerLogo
                        source: "png/AppLogo.png"
                        width: 60
                        height: 60
                        x: 493
                        y: 37
                        fillMode: Image.PreserveAspectFit
                    }
                }
            }
        }
    }

    // ================= OPEN SCREEN OVERLAY =================
    Item {
        id: splash
        anchors.fill: parent
        z: 999
        visible: !login.splashDone && !login.loggedIn

        property real throwUp: 0

        Image {
            id: openScreen
            anchors.fill: parent
            source: "png/OpenScreen.png"
            fillMode: Image.PreserveAspectCrop
            smooth: true

            opacity: 1.0
            scale: 1.0
            transformOrigin: Item.Center
        }

        SequentialAnimation {
            id: splashAnim
            running: false

            PauseAnimation { duration: 16 }
            PauseAnimation { duration: 500 }

            ParallelAnimation {
                NumberAnimation { target: openScreen; property: "y"; to: -splash.throwUp; duration: 420; easing.type: Easing.OutCubic }
                NumberAnimation { target: openScreen; property: "scale"; to: 0.96; duration: 420; easing.type: Easing.OutCubic }
            }

            ParallelAnimation {
                NumberAnimation { target: openScreen; property: "opacity"; to: 0.0; duration: 520; easing.type: Easing.OutCubic }
                NumberAnimation { target: openScreen; property: "scale"; to: 0.92; duration: 520; easing.type: Easing.InOutCubic }
                NumberAnimation { target: openScreen; property: "y"; to: -splash.throwUp - 30; duration: 520; easing.type: Easing.InOutCubic }
            }

            ScriptAction {
                script: {
                    login.splashDone = true
                    introAnim.start()
                }
            }
        }
    }
}
