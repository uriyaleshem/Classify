import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects 1.0

Item {
    id: root
    anchors.fill: parent

    // injected from Login push(...)
    property string userName: "Manager"
    property int userId: -1
    property int schoolId: 1
    property string schoolName: "My School"
    property string schoolAddress: ""
    property string schoolContactEmail: ""
    property var nav

    // theme
    readonly property color bg: "#F6F7FB"
    readonly property color card: "#FFFFFF"
    readonly property color ink: "#0F172A"
    readonly property color muted: "#64748B"
    readonly property color indigo600: "#4F46E5"
    readonly property color indigo700: "#4338CA"
    readonly property color line: "#E5E7EB"
    readonly property color muted2: "#94A3B8"
    readonly property color good: "#22C55E"
    readonly property color warn: "#F59E0B"
    readonly property color danger: "#EF4444"

    // demo data (replace later)
    property var pendingUsersData: []
    property var usersData: []

    property var classesData: []

    property var assignmentsData: []

    property bool refreshInProgress: false
    property bool refreshFeedbackActive: false
    property int refreshPendingResponses: 0
    property string refreshStatusText: ""

    function startRefreshFeedback(expectedResponses) {
        refreshInProgress = true
        refreshFeedbackActive = true
        refreshPendingResponses = expectedResponses
        refreshStatusText = "Refreshing..."
        refreshToastTimer.stop()
    }

    function finishRefreshFeedbackStep() {
        if (!refreshFeedbackActive)
            return

        refreshPendingResponses = Math.max(0, refreshPendingResponses - 1)
        if (refreshPendingResponses === 0) {
            refreshInProgress = false
            refreshFeedbackActive = false
            refreshStatusText = "Refreshed"
            refreshToastTimer.restart()
        }
    }


    // ---------- hooks you will wire    to server ----------
    function approveUser(uid) { auth.approveUser(uid)
    refreshUsers()}
    function blockUser(uid) { auth.blockUser(uid)
    refreshUsers()  }
    function unblockUser(uid) { auth.unblockUser(uid)
    refreshUsers() }
    function refreshSchool(showFeedback) {
        var shouldShowFeedback = (showFeedback === undefined) ? true : showFeedback
        if (shouldShowFeedback)
            startRefreshFeedback(3)

        auth.getUsers(schoolId)
        auth.get_school_courses(schoolId)
        auth.get_school_assignments(schoolId)
    }
    function refreshUsers() { auth.getUsers(schoolId) }


    Component.onCompleted: {
        refreshSchool(false)
    }



    Connections {
        target: auth
        function ongetCoursesResult(success, message, courses) {
            if (success) {
                classesData = courses
            }
            finishRefreshFeedbackStep()
        }
    }
    Connections {
        target: auth
        function ongetAssignmentsResult(success, message, assignments) {
            if (success) {
                assignmentsData = assignments
            }
            finishRefreshFeedbackStep()
        }
    }

    Connections {
        target: auth
        function onGetUsersResult(success, message, users) {
            if (success) {
                var pending = []
                var active = []
                for (var i = 0; i < users.length; i++) {
                    if (users[i].status === "PENDING") {
                        pending.push(users[i])
                    } else {
                        active.push(users[i])
                    }
                }
                pendingUsersData = pending
                usersData = active
            }
            finishRefreshFeedbackStep()
        }
    }

    // ---------- background ----------
    Rectangle {
        anchors.fill: parent
        color: bg
        Rectangle {
            width: 520; height: 520; radius: 260
            x: -240; y: -240
            color: indigo600; opacity: 0.08
        }
        Rectangle {
            width: 620; height: 620; radius: 310
            x: parent.width - 420; y: parent.height - 460
            color: indigo700; opacity: 0.07
        }
    }

    // ---------- main card ----------
    Rectangle {
        id: shell
        anchors.fill: parent
        anchors.margins: 22
        radius: 24
        color: card
        border.width: 1
        border.color: line

        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 18
            radius: 30
            samples: 40
            color: "#1A000000"
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 18

            // top bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 92
                radius: 20
                color: indigo700
                border.width: 1
                border.color: "#14000000"

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: "#10FFFFFF"
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 18

                    Row {
                        id: topBarLeftGroup
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            width: 48; height: 48; radius: 15
                            color: "#20FFFFFF"
                            border.width: 1
                            border.color: "#30FFFFFF"
                            clip: true

                            Image {
                                anchors.centerIn: parent
                                width: 36
                                height: 36
                                source: "png/AppLogo.png"
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                            }
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Classify"
                                color: "#FFFFFF"
                                opacity: 0.98
                                font.pixelSize: 26
                                font.weight: Font.DemiBold
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(320, Math.max(0, topBarRightGroup.x - (topBarLeftGroup.x + topBarLeftGroup.width) - 24))
                                text: schoolName + " • " + userName
                                color: "#FFFFFF"
                                opacity: 0.95
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Row {
                        id: topBarRightGroup
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Item {
                            width: 24
                            height: 24
                            visible: refreshInProgress
                            opacity: refreshInProgress ? 0.95 : 0

                            Text {
                                id: refreshSpinner
                                anchors.centerIn: parent
                                text: "↻"
                                color: "#FFFFFF"
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }

                            NumberAnimation on opacity {
                                duration: 140
                            }

                            RotationAnimator {
                                target: refreshSpinner
                                from: 0
                                to: 360
                                duration: 850
                                loops: Animation.Infinite
                                running: refreshInProgress
                            }
                        }

                        MyButton { text: refreshInProgress ? "Refreshing..." : "Refresh"; kind: "headerGhost"; onClicked: refreshSchool(true) }
                        MyButton { text: "Logout"; kind: "headerGhost"; onClicked: { if (nav) nav.pop() } }
                    }
                }
            }

            // body: sidebar + content
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                // sidebar
                Rectangle {
                    Layout.preferredWidth: 236
                    Layout.fillHeight: true
                    radius: 20
                    color: "#FBFCFF"
                    border.width: 1
                    border.color: line

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Text { text: "Navigation"; color: muted2; font.pixelSize: 12; font.weight: Font.Medium }

                        MenuItem { title: "Home"; iconText: "🏠"; pageKey: "dash" }
                        MenuItem { title: "Users"; iconText: "👥"; pageKey: "users" }
                        MenuItem { title: "Classes"; iconText: "📚"; pageKey: "classes" }
                        MenuItem { title: "Assignments"; iconText: "📝"; pageKey: "tasks" }
                        MenuItem { title: "School settings"; iconText: "⚙️"; pageKey: "settings" }

                        Item { Layout.fillHeight: true }

                        Rectangle { Layout.fillWidth: true; height: 1; color: line }
                        Text { text: "Logged as: MANAGER"; color: muted; font.pixelSize: 11 }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: line
                        }
                        Text {
                            text: "School ID: " + schoolId
                            color: indigo700
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "Share this ID with\nstudents & teachers"
                            color: muted
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                // content panel
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 20
                    color: card
                    border.width: 1
                    border.color: line

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 16

                        // stats row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            StatCard { title: "Pending approvals"; value: "" + pendingUsersData.length; iconText: "⏳" }
                            StatCard { title: "Total users"; value: "" + (pendingUsersData.length + usersData.length); iconText: "👥" }
                            StatCard { title: "Classes"; value: "" + classesData.length; iconText: "📚" }
                            StatCard { title: "Assignments"; value: "" + assignmentsData.length; iconText: "📝" }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: line }

                        // title row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                Layout.fillWidth: true
                                text: pageTitle
                                color: ink
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            MyButton {
                                visible: currentPage === "users"
                                text: "Refresh users"
                                kind: "ghost"
                                onClicked: refreshUsers()
                            }
                        }

                        Loader {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            sourceComponent: currentPage === "dash" ? dashPage
                                            : currentPage === "users" ? usersPage
                                            : currentPage === "classes" ? classesPage
                                            : currentPage === "tasks" ? tasksPage
                                            : currentPage === "settings" ? settingsPage
                                            : statsPage
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: refreshToast
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 34
        anchors.rightMargin: 38
        width: refreshToastText.implicitWidth + 28
        height: 34
        radius: 12
        color: "#0F172A"
        opacity: refreshStatusText !== "" ? 0.92 : 0.0
        visible: opacity > 0
        z: 20

        Behavior on opacity {
            NumberAnimation { duration: 160 }
        }

        Row {
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: refreshInProgress ? "↻" : "✓"
                color: "#FFFFFF"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Text {
                id: refreshToastText
                text: refreshStatusText
                color: "#FFFFFF"
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }

    Timer {
        id: refreshToastTimer
        interval: 1800
        repeat: false
        onTriggered: refreshStatusText = ""
    }

    // ---------- navigation state ----------
    property string currentPage: "dash"
    property string pageTitle: "Home"

    function goPage(key) {
        currentPage = key
        if (key === "dash") pageTitle = "Home"
        else if (key === "users") pageTitle = "Users"
        else if (key === "classes") pageTitle = "Classes"
        else if (key === "tasks") pageTitle = "Assignments"
        else if (key === "settings") pageTitle = "School settings"
        else pageTitle = "Home"
    }

    // ===================== Reusable =====================

    component MyButton : Item {
        id: b
        property string text: "Button"
        property string kind: "ghost" // ghost | primary | danger | headerGhost
        signal clicked()

        implicitWidth: Math.min(126, Math.max(86, label.implicitWidth + 28))
        implicitHeight: 36

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: kind === "primary" ? indigo600
                 : kind === "danger" ? "#FEF2F2"
                 : kind === "headerGhost" ? "#FFFFFF"
                 : "#FFFFFF"
            opacity: kind === "headerGhost"
                     ? (ma.pressed ? 0.22 : (ma.containsMouse ? 0.20 : 0.16))
                     : (ma.pressed ? 0.90 : (ma.containsMouse ? 0.98 : 1.0))
            border.width: 1
            border.color: kind === "primary" ? "#10FFFFFF"
                        : kind === "danger" ? "#FECACA"
                        : kind === "headerGhost" ? "#10FFFFFF"
                        : line
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: b.text
            color: kind === "primary" ? "#FFFFFF"
                 : kind === "danger" ? danger
                 : kind === "headerGhost" ? "#FFFFFF"
                 : indigo600
            opacity: kind === "headerGhost" ? 0.96 : 1.0
            font.pixelSize: 12
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
    }

    component MenuItem : Item {
        id: mi
        property string title: ""
        property string iconText: ""
        property string pageKey: ""
        implicitHeight: 46
        Layout.fillWidth: true

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: root.currentPage === mi.pageKey ? "#EEF2FF" : "#FFFFFF"
            border.width: 1
            border.color: root.currentPage === mi.pageKey ? "#C7D2FE" : line
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 32; height: 32; radius: 10
                color: root.currentPage === mi.pageKey ? "#DDE7FF" : "#EEF4FF"
                border.width: 1
                border.color: root.currentPage === mi.pageKey ? "#C7D2FE" : "#D6E4FF"

                Text {
                    anchors.centerIn: parent
                    text: mi.iconText
                    color: root.currentPage === mi.pageKey ? indigo700 : "#4F46E5"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: mi.title
                color: root.currentPage === mi.pageKey ? indigo700 : ink
                font.pixelSize: 13
                font.weight: root.currentPage === mi.pageKey ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.goPage(mi.pageKey)
        }
    }

    component StatCard : Rectangle {
        property string title: ""
        property string value: ""
        property string iconText: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 96
        radius: 16
        color: "#FCFCFF"
        border.width: 1
        border.color: line

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 14
            spacing: 10

            Rectangle {
                width: 40; height: 40; radius: 12
                color: "#E0E7FF"
                border.width: 1
                border.color: "#B8C7FF"
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: iconText
                    color: indigo700
                    font.pixelSize: 18
                }
            }

            Column {
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
                Text { text: title; color: muted; font.pixelSize: 12 }
                Text { text: value; color: ink; font.pixelSize: 24; font.weight: Font.DemiBold }
            }
        }
    }

    component Pill : Rectangle {
        property string text: ""
        property color fg: ink
        property color bgc: "#EEF2FF"
        property color bc: "#C7D2FE"

        implicitWidth: t.implicitWidth + 18
        implicitHeight: 26
        radius: 13
        color: bgc
        border.width: 1
        border.color: bc

        Text {
            id: t
            anchors.centerIn: parent
            text: parent.text
            color: parent.fg
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }

    component InputBox : Rectangle {
        id: ib
        property string placeholder: ""
        property string text: ""
        signal textEdited(string t)

        radius: 12
        color: "#FFFFFF"
        border.width: 1
        border.color: line
        implicitHeight: 36

        TextInput {
            id: ti
            anchors.fill: parent
            anchors.margins: 10
            text: ib.text
            color: ink
            font.pixelSize: 12
            selectByMouse: true
            onTextChanged: { ib.text = text; ib.textEdited(text) }
        }

        Text {
            visible: ti.text.length === 0
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: ib.placeholder
            color: "#94A3B8"
            font.pixelSize: 12
        }
    }

    // ===================== Pages =====================

    Component {
        id: dashPage
        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                Text { text: "Quick actions"; color: muted2; font.pixelSize: 12; font.weight: Font.Medium }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 12
                    rowSpacing: 12

                    DashCard { title: "Approve users"; sub: "Review pending signups"; iconText: "⏳"; onClicked: root.goPage("users") }
                    DashCard { title: "Manage users"; sub: "Block / unblock users"; iconText: "👥"; onClicked: root.goPage("users") }
                    DashCard { title: "School settings"; sub: "Name, address, info"; iconText: "⚙️"; onClicked: root.goPage("settings") }
                    DashCard { title: "Classes"; sub: "View classes"; iconText: "📚"; onClicked: root.goPage("classes") }
                    DashCard { title: "Assignments"; sub: "View tasks"; iconText: "📝"; onClicked: root.goPage("tasks") }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: line }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text { text: "Pending approvals"; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold }
                    Item { Layout.fillWidth: true }
                    MyButton { text: "Open"; kind: "ghost"; onClicked: root.goPage("users") }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 16
                    color: card
                    border.width: 1
                    border.color: line

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 12
                        clip: true
                        contentWidth: width
                        contentHeight: col.implicitHeight

                        ColumnLayout {
                            id: col
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: root.pendingUsersData.length
                                delegate: UserRow {
                                    userObj: root.pendingUsersData[index]
                                    pending: true
                                }
                            }

                            Text {
                                visible: root.pendingUsersData.length === 0
                                text: "No pending users 🎉"
                                color: muted
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }

    component DashCard : Rectangle {
        property string title: ""
        property string sub: ""
        property string iconText: ""
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 110
        radius: 16
        color: "#FFFFFF"
        border.width: 1
        border.color: line

        // content (slightly left aligned)
        Column {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 6

            Rectangle {
                width: 44; height: 44; radius: 14
                color: "#E0E7FF"
                border.width: 1
                border.color: "#C7D2FE"
                Text { anchors.centerIn: parent; text: iconText; color: indigo700; font.pixelSize: 18; font.weight: Font.DemiBold }
            }

            Text {
                text: title
                color: ink
                font.pixelSize: 14
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: sub
                color: muted
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignLeft
                width: parent.width
            }
        }
MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    Component {
        id: usersPage
        Item {
            property string tab: "pending" // pending | all
            property string roleSelected: "ALL"

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    TabChip { label: "Pending (" + root.pendingUsersData.length + ")"; active: tab === "pending"; onClicked: tab = "pending" }
                    TabChip { label: "Active users (" + root.usersData.length + ")"; active: tab === "all"; onClicked: tab = "all" }
                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    InputBox { id: searchBox; Layout.fillWidth: true; placeholder: "Search by name/email..." }
                    Row {
                        id: roleFilter
                        spacing: 6

                        Repeater {
                            model: ["ALL", "STUDENT", "TEACHER"]
                            delegate: Rectangle {
                                width: 80; height: 36; radius: 10
                                color: roleSelected === modelData ? "#EEF2FF" : card
                                border.width: 1
                                border.color: roleSelected === modelData ? indigo600 : line

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData === "ALL" ? "All" : modelData === "STUDENT" ? "Student" : "Teacher"
                                    color: roleSelected === modelData ? indigo600 : muted
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: roleSelected = modelData
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: line }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 16
                    color: card
                    border.width: 1
                    border.color: line

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 12
                        clip: true
                        contentWidth: width
                        contentHeight: listCol.implicitHeight

                        ColumnLayout {
                            id: listCol
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: tab === "pending" ? root.pendingUsersData.length : root.usersData.length
                                delegate: UserRow {
                                    userObj: tab === "pending" ? root.pendingUsersData[index] : root.usersData[index]
                                    pending: tab === "pending"

                                    visible: {
                                        var u = userObj
                                        var q = (searchBox.text || "").toLowerCase().trim()
                                        var rf = roleSelected
                                        var ok = true
                                        if (q.length > 0) {
                                            ok = (u.name.toLowerCase().indexOf(q) !== -1) || (u.email.toLowerCase().indexOf(q) !== -1)
                                        }
                                        if (ok && rf !== "ALL") {
                                            ok = (u.role === rf)
                                        }
                                        return ok
                                    }
                                }
                            }

                            Text {
                                visible: (tab === "pending" ? root.pendingUsersData.length : root.usersData.length) === 0
                                text: tab === "pending" ? "No pending users." : "No users."
                                color: muted
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }

    component TabChip : Item {
        property string label: ""
        property bool active: false
        signal clicked()

        implicitHeight: 34
        implicitWidth: Math.max(150, txt.implicitWidth + 26)

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: active ? "#EEF2FF" : "#FFFFFF"
            border.width: 1
            border.color: active ? "#C7D2FE" : line
        }

        Text {
            id: txt
            anchors.centerIn: parent
            text: label
            color: active ? indigo700 : ink
            font.pixelSize: 12
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    // FIXED: actions always inside row, right side fixed width, no overflow
    component UserRow : Rectangle {
        property var userObj: ({})
        property bool pending: false
        property bool compact: width < 760

        Layout.fillWidth: true
        Layout.preferredHeight: compact ? 112 : 76
        radius: 14
        color: card
        border.width: 1
        border.color: line

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: compact ? 8 : 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 40; height: 40; radius: 14
                    color: pending ? "#FEF3C7" : (userObj.status === "BLOCKED" ? "#FEE2E2" : "#E0E7FF")
                    border.width: 1
                    border.color: pending ? "#FCD34D" : (userObj.status === "BLOCKED" ? "#FCA5A5" : "#C7D2FE")
                    Text {
                        anchors.centerIn: parent
                        text: pending ? "⏳" : (userObj.status === "BLOCKED" ? "⛔" : "👤")
                        color: pending ? "#B45309" : (userObj.status === "BLOCKED" ? danger : indigo700)
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: (userObj.name || "") + "  •  " + (userObj.role || "")
                        color: ink
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: userObj.email || ""
                        color: muted
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                // right side: pill + actions (wide) OR pill only (compact)
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: compact ? 0 : 260
                    Layout.minimumWidth: compact ? 0 : 260
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item { Layout.fillWidth: true }

                        MyButton {
                            visible: !compact && pending
                            text: "Approve"
                            kind: "ghost"
                            onClicked: root.approveUser(userObj.id)
                        }

                        MyButton {
                            visible: !compact && (!pending) && (userObj.status !== "BLOCKED")
                            text: "Block"
                            kind: "danger"
                            onClicked: root.blockUser(userObj.id)
                        }

                        MyButton {
                            visible: !compact && (!pending) && (userObj.status === "BLOCKED")
                            text: "Unblock"
                            kind: "ghost"
                            onClicked: root.unblockUser(userObj.id)
                        }

                        Pill {
                            visible: !compact
                            text: pending ? "PENDING" : (userObj.status || "")
                            fg: pending ? warn : (userObj.status === "BLOCKED" ? danger : good)
                            bgc: pending ? "#FFF7ED" : (userObj.status === "BLOCKED" ? "#FEF2F2" : "#ECFDF5")
                            bc: pending ? "#FED7AA" : (userObj.status === "BLOCKED" ? "#FECACA" : "#BBF7D0")
                        }
                    }
                }
}

            // compact actions row (second line)
            RowLayout {
                visible: compact
                Layout.fillWidth: true
                spacing: 8

                Item { Layout.fillWidth: true }

                MyButton {
                    visible: pending
                    text: "Approve"
                    kind: "ghost"
                    onClicked: root.approveUser(userObj.id)
                }

                MyButton {
                    visible: (!pending) && (userObj.status !== "BLOCKED")
                    text: "Block"
                    kind: "danger"
                    onClicked: root.blockUser(userObj.id)
                }

                MyButton {
                    visible: (!pending) && (userObj.status === "BLOCKED")
                    text: "Unblock"
                    kind: "ghost"
                    onClicked: root.unblockUser(userObj.id)
                }

                Pill {
                    text: pending ? "PENDING" : (userObj.status || "")
                    fg: pending ? warn : (userObj.status === "BLOCKED" ? danger : good)
                    bgc: pending ? "#FFF7ED" : (userObj.status === "BLOCKED" ? "#FEF2F2" : "#ECFDF5")
                    bc: pending ? "#FED7AA" : (userObj.status === "BLOCKED" ? "#FECACA" : "#BBF7D0")
                }
            }
        }
    }

    Component {
        id: classesPage
        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 12
                Text { text: "All classes in this school"; color: muted2; font.pixelSize: 12; font.weight: Font.Medium }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 16
                    color: card
                    border.width: 1
                    border.color: line

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 12
                        clip: true
                        contentWidth: width
                        contentHeight: col.implicitHeight

                        ColumnLayout {
                            id: col
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: root.classesData.length
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: (width < 760 ? 98 : 74)
                                    radius: 14
                                    color: card
                                    border.width: 1
                                    border.color: line

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 10

                                        Rectangle {
                                            Layout.alignment: Qt.AlignVCenter
                                            width: 40; height: 40; radius: 14
                                            color: "#E0E7FF"
                                            border.width: 1
                                            border.color: "#C7D2FE"
                                            Text { anchors.centerIn: parent; text: "📚"; color: indigo700; font.pixelSize: 16; font.weight: Font.DemiBold }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            spacing: 2
                                            Text {
                                                Layout.fillWidth: true
                                                text: root.classesData[index].name
                                                color: ink
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: "Teacher: " + root.classesData[index].teacher_name
                                                color: muted
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Item { Layout.fillWidth: true } // ensure pill hugs right edge always

                                        Pill {
                                            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                            text: root.classesData[index].students + " students"
                                            fg: indigo700
                                            bgc: "#EEF2FF"
                                            bc: "#C7D2FE"
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: root.classesData.length === 0
                                text: "No classes."
                                color: muted
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: tasksPage
        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 12
                Text { text: "All assignments"; color: muted2; font.pixelSize: 12; font.weight: Font.Medium }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 16
                    color: card
                    border.width: 1
                    border.color: line

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 12
                        clip: true
                        contentWidth: width
                        contentHeight: col.implicitHeight

                        ColumnLayout {
                            id: col
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: root.assignmentsData.length
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: (width < 760 ? 104 : 74)
                                    radius: 14
                                    color: card
                                    border.width: 1
                                    border.color: line

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 10

                                        Rectangle {
                                            Layout.alignment: Qt.AlignVCenter
                                            width: 40; height: 40; radius: 14
                                            color: "#E0E7FF"
                                            border.width: 1
                                            border.color: "#C7D2FE"
                                            Text { anchors.centerIn: parent; text: "📝"; color: indigo700; font.pixelSize: 16; font.weight: Font.DemiBold }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            spacing: 2
                                            Text {
                                                Layout.fillWidth: true
                                                text: root.assignmentsData[index].title + "  •  " + root.assignmentsData[index].teacher_name
                                                color: ink
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: root.assignmentsData[index].course_name + "  •  Due: " + root.assignmentsData[index].due_date
                                                color: muted
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Item { Layout.fillWidth: true } // ensure pill hugs right edge always

                                        Pill {
                                            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                            text: root.assignmentsData[index].submission_count + " submitted"
                                            fg: "#6366F1"
                                            bgc: "#EEF2FF"
                                            bc: "#C7D2FE"
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: root.assignmentsData.length === 0
                                text: "No assignments."
                                color: muted
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: settingsPage
        Item {
            // local state: track whether save succeeded
            property bool saved: false
            property bool saveInProgress: false
            property bool lastSaveOk: false
            property string saveMsg: ""

            Connections {
                target: auth
                function onSchoolUpdateResult(success, message) {
                    saveInProgress = false
                    lastSaveOk = success
                    saveMsg = message || (success ? "OK" : "ERROR")
                    saved = success
                    console.log("School update result:", success)
                    if (success) {
                        sfName.initialText = sfName.currentText
                        sfAddr.initialText = sfAddr.currentText
                        sfMgrName.initialText = sfMgrName.currentText
                        sfMgrEmail.initialText = sfMgrEmail.currentText

                        root.schoolName = sfName.currentText
                        root.userName = sfMgrName.currentText
                        root.schoolAddress = sfAddr.currentText
                        root.schoolContactEmail = sfMgrEmail.currentText
                    }
                }
            }

ColumnLayout {
                anchors.fill: parent
                spacing: 14

                // ── section header ──────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        width: 40; height: 40; radius: 14
                        color: "#E0E7FF"
                        border.width: 1
                        border.color: "#C7D2FE"
                        Text { anchors.centerIn: parent; text: "⚙️"; font.pixelSize: 18 }
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "School Settings"
                            color: ink
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "Update your school's public information"
                            color: muted
                            font.pixelSize: 12
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // success badge (shown after save)
                    Rectangle {
                        visible: saved
                        implicitWidth: savedLabel.implicitWidth + 22
                        implicitHeight: 30
                        radius: 10
                        color: "#ECFDF5"
                        border.width: 1
                        border.color: "#BBF7D0"
                        Text {
                            id: savedLabel
                            anchors.centerIn: parent
                            text: "✓  Saved"
                            color: good
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // ── divider ─────────────────────────────────────
                Rectangle { Layout.fillWidth: true; height: 1; color: line }

                // ── two-column form card ─────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 360
                    radius: 18
                    color: card
                    border.width: 1
                    border.color: line
                    implicitHeight: formCol.implicitHeight + 32

                    ColumnLayout {
                        id: formCol
                        anchors {
                            left: parent.left; right: parent.right
                            top: parent.top
                            margins: 20
                        }
                        spacing: 0

                        // ── group: School info ───────────────────
                        SettingsGroupHeader { label: "School information"; iconTxt: "🏫" }

                        SettingsField {
                            id: sfName
                            fieldLabel: "School name"
                            hint: "Full official name of the school"
                            initialText: root.schoolName
                            iconTxt: "🏷️"
                        }

                        SettingsField {
                            id: sfAddr
                            fieldLabel: "Address"
                            hint: "Street address, city"
                            initialText: root.schoolAddress
                            iconTxt: "📍"
                        }

                        // ── divider ──────────────────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: line
                            Layout.topMargin: 10
                            Layout.bottomMargin: 6
                        }

                        // ── group: Manager contact ───────────────
                        SettingsGroupHeader { label: "Manager contact"; iconTxt: "👤" }

                        SettingsField {
                            id: sfMgrName
                            fieldLabel: "Manager name"
                            hint: "Full name of the school manager"
                            initialText: root.userName
                            iconTxt: "🪪"
                        }

                        SettingsField {
                            id: sfMgrEmail
                            fieldLabel: "Manager email"
                            hint: "Official contact email"
                            initialText: root.schoolContactEmail
                            iconTxt: "✉️"
                        }

                        // ── action row ───────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 16
                            Layout.bottomMargin: 4
                            spacing: 10

                            Item { Layout.fillWidth: true }

                            // Discard button
                            Item {
                                implicitWidth: discardLabel.implicitWidth + 28
                                implicitHeight: 36

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 14
                                    color: "#FFFFFF"
                                    border.width: 1
                                    border.color: line
                                    opacity: discardMa.pressed ? 0.85 : (discardMa.containsMouse ? 0.97 : 1.0)
                                }
                                Text {
                                    id: discardLabel
                                    anchors.centerIn: parent
                                    text: "Discard"
                                    color: muted
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    id: discardMa
                                    enabled: !saveInProgress
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        sfName.reset()
                                        sfAddr.reset()
                                        sfMgrName.reset()
                                        sfMgrEmail.reset()
                                        saved = false
                                        saveMsg = ""
                                        lastSaveOk = false
                                    }
                                }
                            }

                            // Save button
                            Item {
                                implicitWidth: saveLabel.implicitWidth + 36
                                implicitHeight: 36

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 14
                                    color: indigo600
                                    border.width: 1
                                    border.color: "#10FFFFFF"
                                    opacity: saveMa.pressed ? 0.88 : (saveMa.containsMouse ? 0.95 : 1.0)
                                }
                                Text {
                                    id: saveLabel
                                    anchors.centerIn: parent
                                    text: "Save changes"
                                    color: "#FFFFFF"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    id: saveMa
                                    enabled: !saveInProgress
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        saved = false
                                        saveMsg = ""
                                        lastSaveOk = false
                                        saveInProgress = true

                                        // Optimistically update the header texts (will be committed on success)
                                        root.schoolName = sfName.currentText
                                        root.userName   = sfMgrName.currentText

                                        auth.updateSchool(
                                            root.schoolId,
                                            sfName.currentText,
                                            sfAddr.currentText,
                                            sfMgrName.currentText,
                                            sfMgrEmail.currentText
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                // ── save feedback ────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    visible: saveInProgress || saveMsg.length > 0
                    radius: 14
                    color: saveInProgress ? "#EFF6FF" : (lastSaveOk ? "#ECFDF5" : "#FEF2F2")
                    border.width: 1
                    border.color: saveInProgress ? "#BFDBFE" : (lastSaveOk ? "#BBF7D0" : "#FECACA")
                    implicitHeight: fbRow.implicitHeight + 18

                    RowLayout {
                        id: fbRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        spacing: 10

                        Text {
                            text: saveInProgress ? "⏳" : (lastSaveOk ? "✅" : "⚠️")
                            font.pixelSize: 14
                        }
                        Text {
                            Layout.fillWidth: true
                            text: saveInProgress ? "Saving..." : saveMsg
                            color: saveInProgress ? indigo700 : (lastSaveOk ? good : danger)
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                }

// ── bottom info card ────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 92
                    Layout.maximumHeight: implicitHeight
                    radius: 18
                    color: "#FBFCFF"
                    border.width: 1
                    border.color: line

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 14

                        Rectangle {
                            width: 36; height: 36; radius: 12
                            color: "#EEF2FF"
                            border.width: 1; border.color: "#C7D2FE"
                            Text { anchors.centerIn: parent; text: "ℹ️"; font.pixelSize: 16 }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: "Changes are saved to the server"
                                color: ink
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "Once you click \"Save changes\", the updated details will be sent to the server and reflected across the system."
                                color: muted
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }




            // ── reusable sub-components ──────────────────────────

            component SettingsGroupHeader : RowLayout {
                property string label: ""
                property string iconTxt: ""
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.bottomMargin: 8
                spacing: 8

                Text {
                    text: iconTxt
                    font.pixelSize: 13
                }
                Text {
                    text: label
                    color: indigo700
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }
            }

            component SettingsField : Item {
                id: sf
                property string fieldLabel: ""
                property string hint: ""
                property string initialText: ""
                property string iconTxt: ""
                property string currentText: ti2.text

                function reset() { ti2.text = initialText }

                Layout.fillWidth: true
                implicitHeight: 68

                RowLayout {
                    anchors.fill: parent
                    anchors.bottomMargin: 8
                    spacing: 12

                    // icon badge
                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 22
                        width: 32; height: 32; radius: 10
                        color: "#EEF4FF"
                        border.width: 1; border.color: "#D6E4FF"
                        Text { anchors.centerIn: parent; text: sf.iconTxt; font.pixelSize: 14 }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: sf.fieldLabel
                            color: ink
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 10
                            color: "#FFFFFF"
                            border.width: 1
                            border.color: ti2.activeFocus ? indigo600 : "#E2E8F0"

                            TextInput {
                                id: ti2
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                verticalAlignment: TextInput.AlignVCenter
                                text: sf.initialText
                                color: ink
                                font.pixelSize: 12
                                selectByMouse: true
                                clip: true
                            }

                            // placeholder
                            Text {
                                visible: ti2.text.length === 0
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: sf.hint
                                color: "#94A3B8"
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }



    component StatLine : RowLayout {
        property string label: ""
        property string value: ""
        Layout.fillWidth: true
        spacing: 10
        Text { text: label; color: muted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
        Text { text: value; color: ink; font.pixelSize: 12; font.weight: Font.DemiBold }
    }
}
