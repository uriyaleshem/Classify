import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    anchors.fill: parent

    property string userName: "Admin"
    property int userId: -1
    property var nav: null

    property int activeTab: 0
    property string searchText: ""
    property bool loading: false
    property string statusText: "Ready"
    property var selectedRow: null
    property int selectedSourceIndex: -1

    property var schoolsData: []
    property var usersData: []
    property var coursesData: []
    property var assignmentsData: []

    property bool editorVisible: false
    property bool confirmVisible: false
    property string editMode: "view"
    property string editEntity: ""
    property var editRow: null
    property string pendingDeleteEntity: ""
    property var pendingDeleteRow: null

    readonly property bool compact: width < 1050
    readonly property bool narrow: width < 760
    readonly property int sidebarWidth: narrow ? 0 : 244
    readonly property color pageBg: "#F4F7FB"
    readonly property color panelBg: "#FFFFFF"
    readonly property color ink: "#111827"
    readonly property color muted: "#64748B"
    readonly property color faint: "#94A3B8"
    readonly property color line: "#E2E8F0"
    readonly property color softLine: "#EEF2F7"
    readonly property color primary: "#4F46E5"
    readonly property color primary2: "#7C3AED"
    readonly property color primarySoft: "#EEF2FF"
    readonly property color good: "#059669"
    readonly property color goodSoft: "#ECFDF5"
    readonly property color warn: "#D97706"
    readonly property color warnSoft: "#FFFBEB"
    readonly property color bad: "#DC2626"
    readonly property color badSoft: "#FEF2F2"
    readonly property color dark: "#0F172A"

    ListModel { id: filteredModel }

    function asText(v) {
        if (v === undefined || v === null) return ""
        return String(v)
    }

    function safe(v) {
        var t = asText(v).trim()
        return t.length === 0 ? "—" : t
    }

    function shortText(v, maxLen) {
        var t = safe(v)
        if (t === "—") return t
        if (t.length <= maxLen) return t
        return t.substring(0, maxLen - 1) + "…"
    }

    function shortDate(v) {
        var t = safe(v)
        if (t === "—") return t
        return t.replace("T", " ").substring(0, 16)
    }

    function fileName(v) {
        var t = safe(v)
        if (t === "—") return t
        var clean = t.replace(/\\/g, "/")
        var parts = clean.split("/")
        return parts.length > 0 ? parts[parts.length - 1] : t
    }

    function idOf(row) {
        if (!row) return ""
        if (activeTab === 0) return asText(row.school_id)
        if (activeTab === 1) return asText(row.id)
        if (activeTab === 2) return asText(row.course_id)
        return asText(row.assignment_id)
    }

    function titleOf(row) {
        if (!row) return ""
        if (activeTab === 0) return safe(row.name)
        if (activeTab === 1) return safe(row.name)
        if (activeTab === 2) return safe(row.name)
        return safe(row.title)
    }

    function subTitleOf(row) {
        if (!row) return ""
        if (activeTab === 0) return safe(row.contact_email || row.address)
        if (activeTab === 1) return safe(row.email)
        if (activeTab === 2) return "Teacher: " + safe(row.teacher_name) + "  ·  Code: " + safe(row.class_code)
        return "Course: " + safe(row.course_name) + "  ·  Due: " + shortDate(row.due_date)
    }

    function badgeText(row) {
        if (!row) return ""
        if (activeTab === 0) return "School"
        if (activeTab === 1) return safe(row.role)
        if (activeTab === 2) return asText(row.students || 0) + " students"
        return row.is_closed ? "Closed" : "Open"
    }

    function badgeColor(row) {
        if (!row) return primary
        if (activeTab === 1) {
            var r = asText(row.role).toUpperCase()
            if (r === "ADMIN") return primary2
            if (r === "MANAGER") return primary
            if (r === "TEACHER") return good
            return muted
        }
        if (activeTab === 3) return row.is_closed ? bad : good
        return primary
    }

    function countByRole(roleName) {
        var n = 0
        for (var i = 0; i < usersData.length; i++) {
            if (asText(usersData[i].role).toUpperCase() === roleName) n++
        }
        return n
    }

    function countPendingUsers() {
        var n = 0
        for (var i = 0; i < usersData.length; i++) {
            if (asText(usersData[i].status).toUpperCase() === "PENDING") n++
        }
        return n
    }

    function countClosedAssignments() {
        var n = 0
        for (var i = 0; i < assignmentsData.length; i++) {
            if (assignmentsData[i].is_closed) n++
        }
        return n
    }

    function totalSubmissions() {
        var n = 0
        for (var i = 0; i < assignmentsData.length; i++) n += Number(assignmentsData[i].submission_count || 0)
        return n
    }

    function currentArray() {
        if (activeTab === 0) return schoolsData
        if (activeTab === 1) return usersData
        if (activeTab === 2) return coursesData
        return assignmentsData
    }

    function rowMatches(row, q) {
        if (!q || q.length === 0) return true
        var joined = ""
        for (var key in row) joined += " " + asText(row[key])
        return joined.toLowerCase().indexOf(q) >= 0
    }

    function makeListRow(row, sourceIndex) {
        var item = {}
        for (var key in row) item[key] = row[key]
        item.sourceIndex = sourceIndex
        item.rowIdText = idOf(row)
        item.titleText = titleOf(row)
        item.subTitleText = subTitleOf(row)
        item.badgeTextValue = badgeText(row)
        item.badgeColorValue = badgeColor(row)
        return item
    }

    function rebuildFilter() {
        filteredModel.clear()
        var data = currentArray()
        var q = searchText.toLowerCase().trim()
        for (var i = 0; i < data.length; i++) {
            if (rowMatches(data[i], q)) filteredModel.append(makeListRow(data[i], i))
        }
        if (selectedRow === null && filteredModel.count > 0) selectBySource(filteredModel.get(0).sourceIndex)
    }

    function selectBySource(sourceIndex) {
        var data = currentArray()
        if (sourceIndex < 0 || sourceIndex >= data.length) {
            selectedRow = null
            selectedSourceIndex = -1
            return
        }
        selectedSourceIndex = sourceIndex
        selectedRow = data[sourceIndex]
    }

    function switchTab(tab) {
        activeTab = tab
        selectedRow = null
        selectedSourceIndex = -1
        searchText = ""
        rebuildFilter()
    }

    function refreshAll() {
        if (typeof auth === "undefined") return
        loading = true
        statusText = "Loading dashboard..."
        auth.get_admin_overview()
    }

    function copyArrays(schools, users, courses, assignments) {
        schoolsData = schools || []
        usersData = users || []
        coursesData = courses || []
        assignmentsData = assignments || []
        selectedRow = null
        selectedSourceIndex = -1
        rebuildFilter()
    }

    function entityName() {
        if (activeTab === 0) return "school"
        if (activeTab === 1) return "user"
        if (activeTab === 2) return "course"
        return "assignment"
    }

    function entityTitle() {
        if (activeTab === 0) return "Schools"
        if (activeTab === 1) return "Users"
        if (activeTab === 2) return "Courses"
        return "Assignments"
    }

    function openCreate(entity) {
        editMode = "create"
        editEntity = entity
        editRow = {}
        if (entity === "user") {
            editRow = { name: "", email: "", password: "123456", role: "STUDENT", school_id: schoolsData.length > 0 ? schoolsData[0].school_id : 1, status: "ACTIVE" }
        }
        if (entity === "school") editRow = { name: "", address: "", contact_name: "", contact_email: "" }
        editorVisible = true
    }

    function openEdit(entity, row) {
        if (!row) return
        editMode = "edit"
        editEntity = entity
        editRow = {}
        for (var key in row) editRow[key] = row[key]
        editorVisible = true
    }

    function requestDelete(entity, row) {
        if (!row) return
        pendingDeleteEntity = entity
        pendingDeleteRow = row
        confirmVisible = true
    }

    function performDelete() {
        if (!pendingDeleteRow || typeof auth === "undefined") return
        if (pendingDeleteEntity === "school") auth.admin_delete_school(Number(pendingDeleteRow.school_id))
        else if (pendingDeleteEntity === "user") auth.admin_delete_user(Number(pendingDeleteRow.id))
        else if (pendingDeleteEntity === "course") auth.delete_course(Number(pendingDeleteRow.course_id))
        else if (pendingDeleteEntity === "assignment") auth.delete_assignment(Number(pendingDeleteRow.assignment_id))
        confirmVisible = false
        statusText = "Working..."
    }

    function saveEditor() {
        if (!editRow || typeof auth === "undefined") return
        if (editEntity === "school") {
            if (editMode === "create") auth.admin_create_school(asText(editRow.name), asText(editRow.address), asText(editRow.contact_name), asText(editRow.contact_email))
            else auth.admin_update_school(Number(editRow.school_id), asText(editRow.name), asText(editRow.address), asText(editRow.contact_name), asText(editRow.contact_email))
        } else if (editEntity === "user") {
            if (editMode === "create") auth.admin_create_user(asText(editRow.name), asText(editRow.email), asText(editRow.password), asText(editRow.role).toUpperCase(), Number(editRow.school_id || 1), asText(editRow.status).toUpperCase())
            else auth.admin_update_user(Number(editRow.id), asText(editRow.name), asText(editRow.email), asText(editRow.role).toUpperCase(), Number(editRow.school_id || 1), asText(editRow.status).toUpperCase())
        } else if (editEntity === "course") {
            auth.admin_update_course(Number(editRow.course_id), asText(editRow.name), asText(editRow.description), Number(editRow.teacher_id || 0), Number(editRow.school_id || 1))
        } else if (editEntity === "assignment") {
            auth.admin_update_assignment(Number(editRow.assignment_id), asText(editRow.title), asText(editRow.description), asText(editRow.due_date), Boolean(editRow.ai_enabled), Boolean(editRow.is_closed))
        }
        editorVisible = false
        statusText = "Saving..."
    }

    function setEditValue(key, value) {
        if (!editRow) editRow = {}
        editRow[key] = value
    }

    function detailRows(row) {
        if (!row) return []
        if (activeTab === 0) return [
            ["School ID", safe(row.school_id)],
            ["Name", safe(row.name)],
            ["Address", safe(row.address)],
            ["Contact name", safe(row.contact_name)],
            ["Contact email", safe(row.contact_email)]
        ]
        if (activeTab === 1) return [
            ["User ID", safe(row.id)],
            ["Name", safe(row.name)],
            ["Email", safe(row.email)],
            ["Role", safe(row.role)],
            ["Status", safe(row.status)],
            ["School ID", safe(row.school_id)],
            ["Created", shortDate(row.created_at)]
        ]
        if (activeTab === 2) return [
            ["Course ID", safe(row.course_id)],
            ["Name", safe(row.name)],
            ["Description", safe(row.description)],
            ["Class code", safe(row.class_code)],
            ["Teacher", safe(row.teacher_name)],
            ["Teacher ID", safe(row.teacher_id)],
            ["School", safe(row.school_name)],
            ["School ID", safe(row.school_id)],
            ["Active students", safe(row.students)],
            ["Created", shortDate(row.created_at)]
        ]
        return [
            ["Assignment ID", safe(row.assignment_id)],
            ["Title", safe(row.title)],
            ["Description", safe(row.description)],
            ["Course", safe(row.course_name)],
            ["Course ID", safe(row.course_id)],
            ["Teacher", safe(row.teacher_name)],
            ["Due date", shortDate(row.due_date)],
            ["AI enabled", row.ai_enabled ? "Yes" : "No"],
            ["Closed", row.is_closed ? "Yes" : "No"],
            ["Submissions", safe(row.submission_count)],
            ["Attachment file", fileName(row.attachment_path)],
            ["Attachment path", safe(row.attachment_path)],
            ["Created", shortDate(row.created_at)]
        ]
    }

    Component.onCompleted: refreshAll()

    Connections {
        target: typeof auth !== "undefined" ? auth : null
        function onAdminOverviewResult(success, message, schools, users, courses, assignments) {
            loading = false
            statusText = success ? "Dashboard updated" : message
            if (success) copyArrays(schools, users, courses, assignments)
        }
        function onAdminActionResult(success, message, actionName) {
            statusText = message
            if (success) refreshAll()
        }
        function onDeleteCourseResult(success, message, courseId) {
            statusText = message
            if (success) refreshAll()
        }
        function onDeleteAssignmentResult(success, message, assignmentId, courseId) {
            statusText = message
            if (success) refreshAll()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: pageBg
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: sidebarWidth
            Layout.fillHeight: true
            visible: !narrow
            color: dark

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Rectangle {
                        width: 42
                        height: 42
                        radius: 14
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#8B5CF6" }
                            GradientStop { position: 1; color: "#4F46E5" }
                        }
                        Text { anchors.centerIn: parent; text: "C"; color: "white"; font.pixelSize: 20; font.bold: true }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text { text: "Classify"; color: "white"; font.pixelSize: 21; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: "System Admin"; color: "#CBD5E1"; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#233047" }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: ["Schools", "Users", "Courses", "Assignments"]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 46
                            radius: 14
                            color: activeTab === index ? "#334155" : "transparent"
                            border.width: activeTab === index ? 1 : 0
                            border.color: "#475569"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 12
                                spacing: 10
                                Text { text: ["🏫", "👥", "📚", "📝"][index]; font.pixelSize: 16 }
                                Text { text: modelData; color: activeTab === index ? "white" : "#CBD5E1"; font.pixelSize: 14; font.bold: activeTab === index; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: [schoolsData.length, usersData.length, coursesData.length, assignmentsData.length][index]; color: "#A5B4FC"; font.pixelSize: 12; font.bold: true }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: switchTab(index) }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true
                    radius: 18
                    color: "#111C31"
                    border.color: "#233047"
                    height: 118
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 5
                        Text { text: "Signed in as"; color: "#94A3B8"; font.pixelSize: 11 }
                        Text { text: userName || "Admin"; color: "white"; font.pixelSize: 16; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: "User ID: " + userId; color: "#CBD5E1"; font.pixelSize: 12 }
                        Rectangle { Layout.fillWidth: true; height: 34; radius: 12; color: "#1E293B"; border.color: "#334155"
                            Text { anchors.centerIn: parent; text: statusText; color: "#E2E8F0"; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width - 18; horizontalAlignment: Text.AlignHCenter }
                        }
                    }
                }
            }
        }

        Flickable {
            id: mainFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: contentColumn.height + 44
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentColumn
                width: mainFlick.width
                spacing: 18

                Item { Layout.fillWidth: true; height: 22 }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: narrow ? 14 : 26
                    Layout.rightMargin: narrow ? 14 : 26
                    spacing: 14

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Admin Dashboard"; color: ink; font.pixelSize: narrow ? 26 : 34; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: "Full control over schools, users, courses and assignments"; color: muted; font.pixelSize: 14; Layout.fillWidth: true; elide: Text.ElideRight }
                    }

                    Rectangle {
                        width: narrow ? 104 : 132
                        height: 42
                        radius: 14
                        color: loading ? "#CBD5E1" : primary
                        Row { anchors.centerIn: parent; spacing: 8
                            Text { text: loading ? "⏳" : "↻"; color: "white"; font.pixelSize: 15 }
                            Text { text: loading ? "Loading" : "Refresh"; color: "white"; font.pixelSize: 13; font.bold: true }
                        }
                        MouseArea { anchors.fill: parent; enabled: !loading; cursorShape: Qt.PointingHandCursor; onClicked: refreshAll() }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.leftMargin: narrow ? 14 : 26
                    Layout.rightMargin: narrow ? 14 : 26
                    spacing: 12

                    Repeater {
                        model: [
                            { label: "Schools", value: schoolsData.length, note: "active organizations", accent: primary },
                            { label: "Users", value: usersData.length, note: countByRole("STUDENT") + " students · " + countByRole("TEACHER") + " teachers", accent: good },
                            { label: "Courses", value: coursesData.length, note: "classes in system", accent: primary2 },
                            { label: "Assignments", value: assignmentsData.length, note: countClosedAssignments() + " closed · " + totalSubmissions() + " submissions", accent: warn },
                            { label: "Pending users", value: countPendingUsers(), note: "waiting approval", accent: bad }
                        ]
                        delegate: Rectangle {
                            width: Math.max(190, Math.min(260, (mainFlick.width - (narrow ? 48 : 90)) / (narrow ? 2 : 5)))
                            height: 112
                            radius: 22
                            color: panelBg
                            border.color: line
                            Rectangle { width: 5; height: parent.height - 34; radius: 3; color: modelData.accent; anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 34
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5
                                Text { text: modelData.label; color: muted; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight; width: parent.width }
                                Text { text: modelData.value; color: ink; font.pixelSize: 30; font.bold: true; elide: Text.ElideRight; width: parent.width }
                                Text { text: modelData.note; color: faint; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: narrow ? 14 : 26
                    Layout.rightMargin: narrow ? 14 : 26
                    height: narrow ? 760 : Math.max(620, root.height - 260)
                    radius: 26
                    color: panelBg
                    border.color: line
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: narrow ? 12 : 18
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text { text: entityTitle(); color: ink; font.pixelSize: 22; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }

                            Rectangle {
                                visible: activeTab === 0 || activeTab === 1
                                width: narrow ? 112 : 142
                                height: 38
                                radius: 13
                                color: primarySoft
                                border.color: "#C7D2FE"
                                Text { anchors.centerIn: parent; text: activeTab === 0 ? "+ School" : "+ User"; color: primary; font.pixelSize: 13; font.bold: true }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: openCreate(activeTab === 0 ? "school" : "user") }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Rectangle {
                                Layout.fillWidth: true
                                height: 42
                                radius: 14
                                color: "#F8FAFC"
                                border.color: line
                                Text { text: "Search everything..."; color: faint; font.pixelSize: 13; anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter; visible: searchInput.text.length === 0 }
                                TextInput {
                                    id: searchInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: ink
                                    font.pixelSize: 14
                                    clip: true
                                    text: searchText
                                    onTextChanged: {
                                        if (searchText !== text) {
                                            searchText = text
                                            rebuildFilter()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 104
                                height: 42
                                radius: 14
                                color: "#F8FAFC"
                                border.color: line
                                Text { anchors.centerIn: parent; text: filteredModel.count + " rows"; color: muted; font.pixelSize: 13; font.bold: true }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 14

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumWidth: narrow ? 0 : 520
                                radius: 20
                                color: "#FAFBFD"
                                border.color: softLine
                                clip: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 42
                                        color: "#F8FAFC"
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 16
                                            spacing: 10
                                            Text { text: "ID"; color: muted; font.pixelSize: 11; font.bold: true; width: 52 }
                                            Text { text: "Main information"; color: muted; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                                            Text { text: "Status"; color: muted; font.pixelSize: 11; font.bold: true; width: narrow ? 76 : 112; horizontalAlignment: Text.AlignHCenter }
                                            Text { text: "Actions"; color: muted; font.pixelSize: 11; font.bold: true; width: narrow ? 122 : 170; horizontalAlignment: Text.AlignHCenter }
                                        }
                                    }

                                    ListView {
                                        id: listView
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        model: filteredModel
                                        boundsBehavior: Flickable.StopAtBounds
                                        delegate: Rectangle {
                                            width: listView.width
                                            height: narrow ? 82 : 76
                                            color: selectedSourceIndex === sourceIndex ? primarySoft : (index % 2 === 0 ? "#FFFFFF" : "#FCFDFF")
                                            border.color: selectedSourceIndex === sourceIndex ? "#C7D2FE" : softLine
                                            border.width: selectedSourceIndex === sourceIndex ? 1 : 0

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 16
                                                anchors.rightMargin: 12
                                                spacing: 10

                                                Text {
                                                    text: rowIdText
                                                    color: muted
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    width: 52
                                                    elide: Text.ElideRight
                                                    verticalAlignment: Text.AlignVCenter
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 4
                                                    Text { text: titleText; color: ink; font.pixelSize: 14; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 1 }
                                                    Text { text: subTitleText; color: muted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 1 }
                                                }

                                                Rectangle {
                                                    width: narrow ? 76 : 112
                                                    height: 28
                                                    radius: 14
                                                    color: primarySoft
                                                    border.color: line
                                                    Text { anchors.centerIn: parent; text: shortText(badgeTextValue, narrow ? 8 : 16); color: badgeColorValue; font.pixelSize: 11; font.bold: true; elide: Text.ElideRight; width: parent.width - 12; horizontalAlignment: Text.AlignHCenter }
                                                }

                                                RowLayout {
                                                    width: narrow ? 122 : 170
                                                    spacing: 6
                                                    Rectangle {
                                                        Layout.preferredWidth: narrow ? 54 : 76
                                                        height: 32
                                                        radius: 11
                                                        color: "#F1F5F9"
                                                        border.color: line
                                                        Text { anchors.centerIn: parent; text: narrow ? "View" : "Details"; color: ink; font.pixelSize: 12; font.bold: true }
                                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: selectBySource(sourceIndex) }
                                                    }
                                                    Rectangle {
                                                        Layout.preferredWidth: narrow ? 54 : 76
                                                        height: 32
                                                        radius: 11
                                                        color: primary
                                                        Text { anchors.centerIn: parent; text: "Edit"; color: "white"; font.pixelSize: 12; font.bold: true }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                selectBySource(sourceIndex)
                                                                openEdit(entityName(), selectedRow)
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                acceptedButtons: Qt.LeftButton
                                                z: -1
                                                onClicked: selectBySource(sourceIndex)
                                            }
                                        }

                                        Rectangle {
                                            visible: filteredModel.count === 0
                                            anchors.centerIn: parent
                                            width: Math.min(parent.width - 40, 360)
                                            height: 120
                                            radius: 20
                                            color: "#FFFFFF"
                                            border.color: line
                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 8
                                                Text { text: "No rows found"; color: ink; font.pixelSize: 18; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                                                Text { text: "Try another search or refresh the dashboard"; color: muted; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: compact ? 310 : 390
                                Layout.fillHeight: true
                                visible: !narrow
                                radius: 20
                                color: "#FFFFFF"
                                border.color: line
                                clip: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    spacing: 12

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3
                                            Text { text: selectedRow ? titleOf(selectedRow) : "Select a row"; color: ink; font.pixelSize: 19; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                            Text { text: selectedRow ? entityName().toUpperCase() + " DETAILS" : "Nothing selected"; color: faint; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                        }
                                        Rectangle {
                                            visible: selectedRow !== null
                                            width: 52
                                            height: 32
                                            radius: 11
                                            color: primarySoft
                                            Text { anchors.centerIn: parent; text: "Edit"; color: primary; font.pixelSize: 12; font.bold: true }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: openEdit(entityName(), selectedRow) }
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: softLine }

                                    Flickable {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        contentWidth: width
                                        contentHeight: detailsColumn.height
                                        boundsBehavior: Flickable.StopAtBounds

                                        ColumnLayout {
                                            id: detailsColumn
                                            width: parent.width
                                            spacing: 10

                                            Repeater {
                                                model: detailRows(selectedRow)
                                                delegate: Rectangle {
                                                    Layout.fillWidth: true
                                                    radius: 14
                                                    color: "#F8FAFC"
                                                    border.color: softLine
                                                    height: Math.max(58, valueText.implicitHeight + 32)
                                                    ColumnLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 12
                                                        spacing: 3
                                                        Text { text: modelData[0]; color: faint; font.pixelSize: 10; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                                        Text { id: valueText; text: modelData[1]; color: ink; font.pixelSize: 13; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true; maximumLineCount: 4; elide: Text.ElideRight }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        visible: selectedRow !== null
                                        spacing: 8
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 40
                                            radius: 13
                                            color: primary
                                            Text { anchors.centerIn: parent; text: "Edit record"; color: "white"; font.pixelSize: 13; font.bold: true }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: openEdit(entityName(), selectedRow) }
                                        }
                                        Rectangle {
                                            width: 98
                                            height: 40
                                            radius: 13
                                            color: badSoft
                                            border.color: "#FECACA"
                                            Text { anchors.centerIn: parent; text: "Delete"; color: bad; font.pixelSize: 13; font.bold: true }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: requestDelete(entityName(), selectedRow) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true; height: 22 }
            }
        }
    }

    Rectangle {
        visible: narrow && selectedRow !== null
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 76
        color: "#FFFFFF"
        border.color: line
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: titleOf(selectedRow); color: ink; font.pixelSize: 14; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                Text { text: subTitleOf(selectedRow); color: muted; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
            }
            Rectangle { width: 70; height: 40; radius: 13; color: primary; Text { anchors.centerIn: parent; text: "Edit"; color: "white"; font.pixelSize: 13; font.bold: true } MouseArea { anchors.fill: parent; onClicked: openEdit(entityName(), selectedRow) } }
            Rectangle { width: 76; height: 40; radius: 13; color: badSoft; border.color: "#FECACA"; Text { anchors.centerIn: parent; text: "Delete"; color: bad; font.pixelSize: 13; font.bold: true } MouseArea { anchors.fill: parent; onClicked: requestDelete(entityName(), selectedRow) } }
        }
    }

    Rectangle {
        visible: editorVisible
        anchors.fill: parent
        color: "#990F172A"
        z: 50

        MouseArea { anchors.fill: parent }

        Rectangle {
            width: Math.min(root.width - 28, 660)
            height: Math.min(root.height - 40, editContent.implicitHeight + 86)
            anchors.centerIn: parent
            radius: 28
            color: "#FFFFFF"
            border.color: line
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: (editMode === "create" ? "Create " : "Edit ") + editEntity; color: ink; font.pixelSize: 24; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: "Make changes carefully. Admin actions affect the whole system."; color: muted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                    Rectangle { width: 36; height: 36; radius: 12; color: "#F1F5F9"; Text { anchors.centerIn: parent; text: "×"; color: muted; font.pixelSize: 22 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: editorVisible = false } }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: editContent.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: editContent
                        width: parent.width
                        spacing: 10

                        Loader { Layout.fillWidth: true; sourceComponent: editEntity === "school" ? schoolEditor : null }
                        Loader { Layout.fillWidth: true; sourceComponent: editEntity === "user" ? userEditor : null }
                        Loader { Layout.fillWidth: true; sourceComponent: editEntity === "course" ? courseEditor : null }
                        Loader { Layout.fillWidth: true; sourceComponent: editEntity === "assignment" ? assignmentEditor : null }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Rectangle { Layout.fillWidth: true; height: 44; radius: 15; color: "#F8FAFC"; border.color: line; Text { anchors.centerIn: parent; text: "Cancel"; color: muted; font.pixelSize: 14; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: editorVisible = false } }
                    Rectangle { Layout.fillWidth: true; height: 44; radius: 15; color: primary; Text { anchors.centerIn: parent; text: "Save changes"; color: "white"; font.pixelSize: 14; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: saveEditor() } }
                }
            }
        }
    }

    Component {
        id: fieldBox
        Rectangle {
            property string label: ""
            property string value: ""
            property string keyName: ""
            property bool multiline: false
            Layout.fillWidth: true
            height: multiline ? 112 : 66
            radius: 16
            color: "#F8FAFC"
            border.color: line
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4
                Text { text: label; color: faint; font.pixelSize: 10; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                TextInput {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: value
                    color: ink
                    font.pixelSize: 14
                    clip: true
                    wrapMode: multiline ? TextInput.WrapAnywhere : TextInput.NoWrap
                    verticalAlignment: multiline ? TextInput.AlignTop : TextInput.AlignVCenter
                    onTextChanged: setEditValue(keyName, text)
                }
            }
        }
    }

    Component {
        id: boolBox
        Rectangle {
            property string label: ""
            property string keyName: ""
            property bool checked: false
            Layout.fillWidth: true
            height: 54
            radius: 16
            color: "#F8FAFC"
            border.color: line
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                Text { text: label; color: ink; font.pixelSize: 14; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                Rectangle { width: 52; height: 30; radius: 15; color: checked ? good : "#CBD5E1"
                    Rectangle { width: 24; height: 24; radius: 12; color: "white"; anchors.verticalCenter: parent.verticalCenter; x: checked ? 25 : 3 }
                }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { checked = !checked; setEditValue(keyName, checked) } }
        }
    }

    Component {
        id: schoolEditor
        ColumnLayout {
            spacing: 10
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "School name"; item.keyName = "name"; item.value = asText(editRow.name) } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Address"; item.keyName = "address"; item.value = asText(editRow.address) } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Contact name"; item.keyName = "contact_name"; item.value = asText(editRow.contact_name) } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Contact email"; item.keyName = "contact_email"; item.value = asText(editRow.contact_email) } }
        }
    }

    Component {
        id: userEditor
        ColumnLayout {
            spacing: 10
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Full name"; item.keyName = "name"; item.value = asText(editRow.name) } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Email"; item.keyName = "email"; item.value = asText(editRow.email) } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; visible: editMode === "create"; onLoaded: { item.label = "Initial password"; item.keyName = "password"; item.value = asText(editRow.password) } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Role: ADMIN / MANAGER / TEACHER / STUDENT"; item.keyName = "role"; item.value = asText(editRow.role) } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Status: ACTIVE / PENDING / BLOCKED"; item.keyName = "status"; item.value = asText(editRow.status) } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "School ID"; item.keyName = "school_id"; item.value = asText(editRow.school_id) } }
        }
    }

    Component {
        id: courseEditor
        ColumnLayout {
            spacing: 10
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Course name"; item.keyName = "name"; item.value = asText(editRow.name) } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Description"; item.keyName = "description"; item.value = asText(editRow.description); item.multiline = true } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Teacher ID"; item.keyName = "teacher_id"; item.value = asText(editRow.teacher_id) } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "School ID"; item.keyName = "school_id"; item.value = asText(editRow.school_id) } }
        }
    }

    Component {
        id: assignmentEditor
        ColumnLayout {
            spacing: 10
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Title"; item.keyName = "title"; item.value = asText(editRow.title) } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Description"; item.keyName = "description"; item.value = asText(editRow.description); item.multiline = true } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Due date"; item.keyName = "due_date"; item.value = asText(editRow.due_date) } }
            Loader { Layout.fillWidth: true; sourceComponent: boolBox; onLoaded: { item.label = "AI enabled"; item.keyName = "ai_enabled"; item.checked = Boolean(editRow.ai_enabled) } }
            Loader { Layout.fillWidth: true; sourceComponent: boolBox; onLoaded: { item.label = "Closed"; item.keyName = "is_closed"; item.checked = Boolean(editRow.is_closed) } }
        }
    }

    Rectangle {
        visible: confirmVisible
        anchors.fill: parent
        color: "#990F172A"
        z: 80
        MouseArea { anchors.fill: parent }
        Rectangle {
            width: Math.min(root.width - 32, 430)
            height: 246
            radius: 26
            color: "white"
            border.color: line
            anchors.centerIn: parent
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 12
                Text { text: "Delete record?"; color: ink; font.pixelSize: 24; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                Text { text: "This action may remove related data. Make sure this is really what you want to do."; color: muted; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                Rectangle { Layout.fillWidth: true; height: 54; radius: 16; color: badSoft; border.color: "#FECACA"; Text { anchors.centerIn: parent; text: pendingDeleteEntity.toUpperCase() + " · " + (pendingDeleteRow ? titleOf(pendingDeleteRow) : ""); color: bad; font.pixelSize: 13; font.bold: true; width: parent.width - 24; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter } }
                Item { Layout.fillHeight: true }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Rectangle { Layout.fillWidth: true; height: 44; radius: 15; color: "#F8FAFC"; border.color: line; Text { anchors.centerIn: parent; text: "Cancel"; color: muted; font.pixelSize: 14; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: confirmVisible = false } }
                    Rectangle { Layout.fillWidth: true; height: 44; radius: 15; color: bad; Text { anchors.centerIn: parent; text: "Delete"; color: "white"; font.pixelSize: 14; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: performDelete() } }
                }
            }
        }
    }
}
