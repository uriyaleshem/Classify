import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs

Item {
    id: root
    anchors.fill: parent

    property string userName: "Admin"
    property int userId: -1
    property var nav: null

    property int activeSectionIndex: 0
    property string searchText: ""
    property bool loading: false
    property string statusText: "Ready"
    property bool statusIsError: false
    property var selectedRow: null
    property int selectedSourceIndex: -1

    property bool editorVisible: false
    property bool confirmVisible: false
    property string editMode: "edit"
    property string editEntity: ""
    property var editRow: null
    property string fileDialogTarget: ""
    property string pendingDeleteEntity: ""
    property var pendingDeleteRow: null

    property var allData: ({
        schools: [], users: [], courses: [], members: [], assignments: [], submissions: [],
        ai_results: [], grades: [], feedback: [], materials: [], messages: [],
        message_reads: [], grade_reads: [], activity: [], system: []
    })
    property var stats: ({})

    readonly property bool compact: width < 1120
    readonly property bool narrow: width < 860
    readonly property int sidebarWidth: narrow ? 0 : 252

    readonly property color bg: "#F6F7FB"
    readonly property color panel: "#FFFFFF"
    readonly property color panel2: "#F8FAFC"
    readonly property color ink: "#0F172A"
    readonly property color muted: "#64748B"
    readonly property color faint: "#94A3B8"
    readonly property color line: "#E2E8F0"
    readonly property color lineSoft: "#EEF2F7"
    readonly property color side: "#111827"
    readonly property color primary: "#2563EB"
    readonly property color primarySoft: "#EFF6FF"
    readonly property color teal: "#0F766E"
    readonly property color tealSoft: "#ECFDF5"
    readonly property color amber: "#D97706"
    readonly property color amberSoft: "#FFFBEB"
    readonly property color red: "#DC2626"
    readonly property color redSoft: "#FEF2F2"
    readonly property color violet: "#7C3AED"

    property var sections: [
        { key: "schools", label: "Schools", short: "SC", id: "school_id", create: true, edit: true, remove: true },
        { key: "users", label: "Users", short: "US", id: "id", create: true, edit: true, remove: true },
        { key: "courses", label: "Courses", short: "CR", id: "course_id", create: true, edit: true, remove: true },
        { key: "members", label: "Members", short: "MB", id: "member_id", create: false, edit: false, remove: false },
        { key: "assignments", label: "Assignments", short: "AS", id: "assignment_id", create: true, edit: true, remove: true },
        { key: "submissions", label: "Submissions", short: "SB", id: "submission_id", create: false, edit: false, remove: false },
        { key: "grades", label: "Grades", short: "GR", id: "grade_id", create: false, edit: false, remove: false },
        { key: "ai_results", label: "AI Results", short: "AI", id: "ai_result_id", create: false, edit: false, remove: false },
        { key: "feedback", label: "Feedback", short: "FB", id: "feedback_id", create: false, edit: false, remove: false },
        { key: "materials", label: "Materials", short: "MT", id: "material_id", create: false, edit: false, remove: true },
        { key: "messages", label: "Messages", short: "MS", id: "message_id", create: false, edit: false, remove: true },
        { key: "message_reads", label: "Message Reads", short: "MR", id: "read_id", create: false, edit: false, remove: false },
        { key: "grade_reads", label: "Grade Reads", short: "RR", id: "read_id", create: false, edit: false, remove: false },
        { key: "activity", label: "Activity", short: "AC", id: "at", create: false, edit: false, remove: false },
        { key: "system", label: "System", short: "SY", id: "metric", create: false, edit: false, remove: false }
    ]

    ListModel {
        id: filteredModel
        dynamicRoles: true
    }

    Timer {
        id: statusTimer
        interval: 3600
        onTriggered: {
            if (!loading) {
                statusText = "Ready"
                statusIsError = false
            }
        }
    }

    function asText(v) {
        if (v === undefined || v === null)
            return ""
        return String(v)
    }

    function safe(v) {
        var t = asText(v).trim()
        return t.length === 0 ? "-" : t
    }

    function shortText(v, maxLen) {
        var t = safe(v)
        if (t.length <= maxLen)
            return t
        return t.substring(0, Math.max(0, maxLen - 3)) + "..."
    }

    function shortDate(v) {
        var t = safe(v)
        if (t === "-")
            return t
        return t.replace("T", " ").substring(0, 16)
    }

    function fileName(v) {
        var t = safe(v)
        if (t === "-")
            return t
        var clean = t.replace(/\\/g, "/")
        var parts = clean.split("/")
        return parts.length > 0 ? parts[parts.length - 1] : t
    }

    function fileNameFromPath(v) {
        var t = asText(v).replace("file:///", "").replace(/\\/g, "/")
        var parts = t.split("/")
        return parts.length > 0 ? parts[parts.length - 1] : t
    }

    function formatBytes(value) {
        var n = Number(value || 0)
        if (n < 1024)
            return n + " B"
        if (n < 1024 * 1024)
            return (n / 1024).toFixed(1) + " KB"
        if (n < 1024 * 1024 * 1024)
            return (n / 1024 / 1024).toFixed(1) + " MB"
        return (n / 1024 / 1024 / 1024).toFixed(1) + " GB"
    }

    function pad2(n) {
        return n < 10 ? "0" + n : "" + n
    }

    function defaultDueDate() {
        var d = new Date()
        d.setDate(d.getDate() + 7)
        return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()) + " 23:59"
    }

    function sectionAt(index) {
        if (index < 0 || index >= sections.length)
            return sections[0]
        return sections[index]
    }

    function currentSection() {
        return sectionAt(activeSectionIndex)
    }

    function rowsForKey(key) {
        return allData && allData[key] ? allData[key] : []
    }

    function currentRows() {
        return rowsForKey(currentSection().key)
    }

    function countFor(key) {
        return rowsForKey(key).length
    }

    function countByValue(rows, field, value) {
        var n = 0
        var wanted = asText(value).toUpperCase()
        for (var i = 0; i < rows.length; i++) {
            if (asText(rows[i][field]).toUpperCase() === wanted)
                n++
        }
        return n
    }

    function rowId(row) {
        if (!row)
            return ""
        var idKey = currentSection().id
        return safe(row[idKey])
    }

    function primaryOf(row) {
        if (!row)
            return ""
        var key = currentSection().key
        if (key === "schools") return safe(row.name)
        if (key === "users") return safe(row.name)
        if (key === "courses") return safe(row.name)
        if (key === "members") return safe(row.student_name)
        if (key === "assignments") return safe(row.title)
        if (key === "submissions") return safe(row.assignment_title)
        if (key === "grades") return safe(row.student_name)
        if (key === "ai_results") return safe(row.engine_name)
        if (key === "feedback") return safe(row.student_name)
        if (key === "materials") return safe(row.title)
        if (key === "messages") return safe(row.subject)
        if (key === "message_reads") return safe(row.message_subject)
        if (key === "grade_reads") return safe(row.assignment_title)
        if (key === "activity") return safe(row.title)
        if (key === "system") return safe(row.metric)
        return rowId(row)
    }

    function secondaryOf(row) {
        if (!row)
            return ""
        var key = currentSection().key
        if (key === "schools") return safe(row.contact_email || row.address)
        if (key === "users") return safe(row.email) + " / " + safe(row.school_name)
        if (key === "courses") return "Teacher: " + safe(row.teacher_name) + " / Code: " + safe(row.class_code)
        if (key === "members") return safe(row.course_name) + " / " + safe(row.student_email)
        if (key === "assignments") return safe(row.course_name) + " / Due: " + shortDate(row.due_date)
        if (key === "submissions") return safe(row.student_name) + " / " + shortDate(row.submitted_at)
        if (key === "grades") return safe(row.course_name) + " / Final: " + safe(row.final_score)
        if (key === "ai_results") return safe(row.assignment_title) + " / Score: " + safe(row.score)
        if (key === "feedback") return safe(row.assignment_title)
        if (key === "materials") return safe(row.course_name) + " / " + fileName(row.file_path)
        if (key === "messages") return safe(row.course_name) + " / " + shortDate(row.created_at)
        if (key === "message_reads") return safe(row.student_name) + " / " + shortDate(row.read_at)
        if (key === "grade_reads") return safe(row.student_name) + " / " + shortDate(row.read_at)
        if (key === "activity") return safe(row.type) + " / " + shortDate(row.at)
        if (key === "system") return safe(row.value) + " " + safe(row.unit)
        return ""
    }

    function statusOf(row) {
        if (!row)
            return ""
        var key = currentSection().key
        if (key === "users") return safe(row.status)
        if (key === "courses") return safe(row.assignments_count) + " tasks"
        if (key === "members") return safe(row.member_status)
        if (key === "assignments") return Number(row.is_closed || 0) ? "Closed" : "Open"
        if (key === "submissions") return safe(row.status)
        if (key === "grades") return row.final_score === null || row.final_score === undefined ? "Draft" : "Final"
        if (key === "ai_results") return safe(row.score)
        if (key === "materials") return safe(row.type)
        if (key === "messages") return safe(row.state)
        if (key === "schools") return safe(row.users_count) + " users"
        if (key === "system") return safe(row.unit)
        return currentSection().short
    }

    function accentOf(row) {
        if (!row)
            return primary
        var status = statusOf(row).toUpperCase()
        var role = asText(row.role).toUpperCase()
        if (status.indexOf("BLOCK") >= 0 || status.indexOf("CLOSED") >= 0 || status.indexOf("FAILED") >= 0)
            return red
        if (status.indexOf("PENDING") >= 0 || status.indexOf("DRAFT") >= 0)
            return amber
        if (status.indexOf("OPEN") >= 0 || status.indexOf("ACTIVE") >= 0 || status.indexOf("FINAL") >= 0)
            return teal
        if (role === "ADMIN")
            return violet
        if (role === "TEACHER")
            return teal
        return primary
    }

    function rowMatches(row, q) {
        if (!q || q.length === 0)
            return true
        var joined = ""
        for (var key in row)
            joined += " " + asText(row[key])
        return joined.toLowerCase().indexOf(q) >= 0
    }

    function makeListRow(row, sourceIndex) {
        var item = {}
        for (var key in row)
            item[key] = row[key]
        item.sourceIndex = sourceIndex
        item.rowIdText = rowId(row)
        item.primaryText = primaryOf(row)
        item.secondaryText = secondaryOf(row)
        item.statusTextValue = statusOf(row)
        item.accentValue = accentOf(row)
        return item
    }

    function rebuildFilter() {
        filteredModel.clear()
        var data = currentRows()
        var q = searchText.toLowerCase().trim()
        for (var i = 0; i < data.length; i++) {
            if (rowMatches(data[i], q))
                filteredModel.append(makeListRow(data[i], i))
        }
        if (selectedRow === null && filteredModel.count > 0)
            selectBySource(filteredModel.get(0).sourceIndex)
    }

    function selectBySource(sourceIndex) {
        var data = currentRows()
        if (sourceIndex < 0 || sourceIndex >= data.length) {
            selectedRow = null
            selectedSourceIndex = -1
            return
        }
        selectedSourceIndex = sourceIndex
        selectedRow = data[sourceIndex]
    }

    function switchSection(index) {
        activeSectionIndex = index
        searchText = ""
        selectedRow = null
        selectedSourceIndex = -1
        rebuildFilter()
    }

    function setStatus(message, isError) {
        statusText = message && message.length > 0 ? message : "Ready"
        statusIsError = isError === true
        statusTimer.restart()
    }

    function refreshAll() {
        if (typeof auth === "undefined")
            return
        loading = true
        statusIsError = false
        statusText = "Refreshing data..."
        auth.get_admin_overview()
    }

    function logout() {
        if (typeof auth !== "undefined" && auth)
            auth.logout()
        if (nav)
            nav.pop()
    }

    function copyPayload(payload) {
        var next = {}
        for (var i = 0; i < sections.length; i++) {
            var key = sections[i].key
            next[key] = payload && payload[key] ? payload[key] : []
        }
        allData = next
        stats = payload && payload.stats ? payload.stats : {}
        selectedRow = null
        selectedSourceIndex = -1
        rebuildFilter()
    }

    function roleOptions() {
        return [
            { label: "Admin", value: "ADMIN" },
            { label: "Manager", value: "MANAGER" },
            { label: "Teacher", value: "TEACHER" },
            { label: "Student", value: "STUDENT" }
        ]
    }

    function statusOptions() {
        return [
            { label: "Active", value: "ACTIVE" },
            { label: "Pending", value: "PENDING" },
            { label: "Blocked", value: "BLOCKED" }
        ]
    }

    function schoolOptions() {
        var out = []
        var rows = rowsForKey("schools")
        for (var i = 0; i < rows.length; i++)
            out.push({ label: safe(rows[i].name) + " (#" + rows[i].school_id + ")", value: Number(rows[i].school_id) })
        return out
    }

    function teacherOptions() {
        var out = []
        var rows = rowsForKey("users")
        for (var i = 0; i < rows.length; i++) {
            var role = asText(rows[i].role).toUpperCase()
            if (role === "TEACHER" || role === "ADMIN")
                out.push({ label: safe(rows[i].name) + " (#" + rows[i].id + ")", value: Number(rows[i].id) })
        }
        return out
    }

    function courseOptions() {
        var out = []
        var rows = rowsForKey("courses")
        for (var i = 0; i < rows.length; i++)
            out.push({ label: safe(rows[i].name) + " (#" + rows[i].course_id + ")", value: Number(rows[i].course_id) })
        return out
    }

    function firstOptionValue(options, fallback) {
        return options.length > 0 ? options[0].value : fallback
    }

    function entityForSectionKey(key) {
        if (key === "schools") return "school"
        if (key === "users") return "user"
        if (key === "courses") return "course"
        if (key === "assignments") return "assignment"
        if (key === "materials") return "material"
        if (key === "messages") return "message"
        return key
    }

    function openCreate(entity) {
        editMode = "create"
        editEntity = entity
        if (entity === "school") {
            editRow = { name: "", address: "", contact_name: "", contact_email: "" }
        } else if (entity === "user") {
            editRow = {
                name: "", email: "", password: "123456", role: "STUDENT", status: "ACTIVE",
                school_id: firstOptionValue(schoolOptions(), 1)
            }
        } else if (entity === "course") {
            editRow = {
                name: "", description: "",
                teacher_id: firstOptionValue(teacherOptions(), userId),
                school_id: firstOptionValue(schoolOptions(), 1)
            }
        } else if (entity === "assignment") {
            editRow = {
                title: "", description: "", due_date: defaultDueDate(),
                course_id: firstOptionValue(courseOptions(), 1),
                ai_enabled: false, is_closed: false,
                attachment_path: "", attachment_name: ""
            }
        }
        editorVisible = true
    }

    function openEdit(entity, row) {
        if (!row)
            return
        editMode = "edit"
        editEntity = entity
        editRow = {}
        for (var key in row)
            editRow[key] = row[key]
        editorVisible = true
    }

    function requestDelete(entity, row) {
        if (!row)
            return
        pendingDeleteEntity = entity
        pendingDeleteRow = row
        confirmVisible = true
    }

    function validateEditor() {
        if (!editRow)
            return false
        if (editEntity === "school" && safe(editRow.name) === "-") {
            setStatus("School name is required.", true)
            return false
        }
        if (editEntity === "user" && (safe(editRow.name) === "-" || safe(editRow.email) === "-")) {
            setStatus("User name and email are required.", true)
            return false
        }
        if (editEntity === "course" && safe(editRow.name) === "-") {
            setStatus("Course name is required.", true)
            return false
        }
        if (editEntity === "assignment" && safe(editRow.title) === "-") {
            setStatus("Assignment title is required.", true)
            return false
        }
        if (editEntity === "assignment" && editMode === "create" && Boolean(editRow.ai_enabled) && safe(editRow.attachment_path) === "-") {
            setStatus("AI assignments need a rubric attachment.", true)
            return false
        }
        return true
    }

    function saveEditor() {
        if (!validateEditor() || typeof auth === "undefined")
            return

        if (editEntity === "school") {
            if (editMode === "create")
                auth.admin_create_school(asText(editRow.name), asText(editRow.address), asText(editRow.contact_name), asText(editRow.contact_email))
            else
                auth.admin_update_school(Number(editRow.school_id), asText(editRow.name), asText(editRow.address), asText(editRow.contact_name), asText(editRow.contact_email))
        } else if (editEntity === "user") {
            if (editMode === "create")
                auth.admin_create_user(asText(editRow.name), asText(editRow.email), asText(editRow.password), asText(editRow.role).toUpperCase(), Number(editRow.school_id || 1), asText(editRow.status).toUpperCase())
            else
                auth.admin_update_user(Number(editRow.id), asText(editRow.name), asText(editRow.email), asText(editRow.role).toUpperCase(), Number(editRow.school_id || 1), asText(editRow.status).toUpperCase())
        } else if (editEntity === "course") {
            if (editMode === "create")
                auth.create_course(asText(editRow.name), asText(editRow.description), Number(editRow.teacher_id || userId), Number(editRow.school_id || 1))
            else
                auth.admin_update_course(Number(editRow.course_id), asText(editRow.name), asText(editRow.description), Number(editRow.teacher_id || userId), Number(editRow.school_id || 1))
        } else if (editEntity === "assignment") {
            if (editMode === "create")
                auth.create_assignment(Number(editRow.course_id || 1), asText(editRow.title), asText(editRow.description), asText(editRow.due_date), Boolean(editRow.ai_enabled), asText(editRow.attachment_path))
            else
                auth.admin_update_assignment(Number(editRow.assignment_id), asText(editRow.title), asText(editRow.description), asText(editRow.due_date), Boolean(editRow.ai_enabled), Boolean(editRow.is_closed))
        }

        editorVisible = false
        loading = true
        setStatus("Saving changes...", false)
    }

    function setEditValue(key, value) {
        if (!editRow)
            editRow = {}
        editRow[key] = value
    }

    function performDelete() {
        if (!pendingDeleteRow || typeof auth === "undefined")
            return
        if (pendingDeleteEntity === "school")
            auth.admin_delete_school(Number(pendingDeleteRow.school_id))
        else if (pendingDeleteEntity === "user")
            auth.admin_delete_user(Number(pendingDeleteRow.id))
        else if (pendingDeleteEntity === "course")
            auth.delete_course(Number(pendingDeleteRow.course_id))
        else if (pendingDeleteEntity === "assignment")
            auth.delete_assignment(Number(pendingDeleteRow.assignment_id))
        else if (pendingDeleteEntity === "material")
            auth.delete_material(Number(pendingDeleteRow.material_id))
        else if (pendingDeleteEntity === "message")
            auth.delete_message(Number(pendingDeleteRow.message_id))

        confirmVisible = false
        loading = true
        setStatus("Deleting record...", false)
    }

    function updateUserStatus(row, statusValue) {
        if (!row || typeof auth === "undefined")
            return
        auth.admin_update_user(Number(row.id), asText(row.name), asText(row.email), asText(row.role).toUpperCase(), Number(row.school_id || 1), statusValue)
        loading = true
        setStatus("Updating user status...", false)
    }

    function fileRefOf(row) {
        if (!row)
            return ""
        if (asText(row.file_path).trim().length > 0)
            return asText(row.file_path)
        if (asText(row.attachment_path).trim().length > 0)
            return asText(row.attachment_path)
        return ""
    }

    function openFilePicker(target) {
        fileDialogTarget = target
        fileDialog.open()
    }

    function detailRows(row) {
        var rows = []
        if (!row)
            return rows
        var skip = { sourceIndex: true, rowIdText: true, primaryText: true, secondaryText: true, statusTextValue: true, accentValue: true }
        for (var key in row) {
            if (skip[key] === true)
                continue
            rows.push({ label: humanize(key), value: valueForDetail(row[key], key) })
        }
        return rows
    }

    function humanize(key) {
        var parts = asText(key).split("_")
        var out = []
        for (var i = 0; i < parts.length; i++) {
            var p = parts[i]
            out.push(p.length > 0 ? p.charAt(0).toUpperCase() + p.slice(1) : p)
        }
        return out.join(" ")
    }

    function valueForDetail(value, key) {
        if (key.indexOf("bytes") >= 0)
            return formatBytes(value)
        if (key.indexOf("_at") >= 0 || key === "created_at" || key === "submitted_at" || key === "due_date")
            return shortDate(value)
        if (typeof value === "boolean")
            return value ? "Yes" : "No"
        if (key === "ai_enabled" || key === "is_closed")
            return Number(value || 0) ? "Yes" : "No"
        return safe(value)
    }

    function statCards() {
        var submissions = countFor("submissions")
        var graded = countFor("grades")
        var withAi = 0
        var submissionRows = rowsForKey("submissions")
        for (var i = 0; i < submissionRows.length; i++) {
            if (Number(submissionRows[i].ai_results_count || 0) > 0)
                withAi++
        }
        var aiCoverage = submissions > 0 ? Math.round((withAi / submissions) * 100) + "%" : "0%"
        var storageBytes = stats && stats.system ? stats.system.storage_size_bytes : 0
        return [
            { label: "Schools", value: countFor("schools"), note: countFor("courses") + " courses", color: primary },
            { label: "Users", value: countFor("users"), note: countByValue(rowsForKey("users"), "role", "TEACHER") + " teachers / " + countByValue(rowsForKey("users"), "role", "STUDENT") + " students", color: teal },
            { label: "Assignments", value: countFor("assignments"), note: countByValue(rowsForKey("assignments"), "is_closed", "1") + " closed", color: amber },
            { label: "Submissions", value: submissions, note: graded + " graded", color: violet },
            { label: "AI Coverage", value: aiCoverage, note: countFor("ai_results") + " AI results", color: primary },
            { label: "Storage", value: formatBytes(storageBytes), note: countFor("materials") + " materials", color: teal }
        ]
    }

    Component.onCompleted: refreshAll()

    Connections {
        target: typeof auth !== "undefined" ? auth : null

        function onAdminOverviewResult(success, message, payload) {
            loading = false
            if (success) {
                copyPayload(payload)
                setStatus("Dashboard updated", false)
            } else {
                setStatus(message, true)
            }
        }

        function onAdminActionResult(success, message, actionName) {
            setStatus(message, !success)
            if (success)
                refreshAll()
            else
                loading = false
        }

        function onCreateCourseResult(success, message, courseId) {
            setStatus(success ? "Course created successfully." : message, !success)
            if (success)
                refreshAll()
            else
                loading = false
        }

        function onCreateAssignmentResult(success, message, courseId, assignmentId) {
            setStatus(success ? "Assignment created successfully." : message, !success)
            if (success)
                refreshAll()
            else
                loading = false
        }

        function onDeleteCourseResult(success, message, courseId) {
            setStatus(message, !success)
            if (success)
                refreshAll()
            else
                loading = false
        }

        function onDeleteAssignmentResult(success, message, assignmentId, courseId) {
            setStatus(message, !success)
            if (success)
                refreshAll()
            else
                loading = false
        }

        function onDeleteMaterialResult(success, message, courseId, materialId) {
            setStatus(message, !success)
            if (success)
                refreshAll()
            else
                loading = false
        }

        function onDeleteMessageResult(success, message, courseId, messageId) {
            setStatus(message, !success)
            if (success)
                refreshAll()
            else
                loading = false
        }

        function onDownloadFileResult(success, message, filePath, savedPath) {
            setStatus(success ? "Downloaded to " + savedPath : message, !success)
        }
    }

    FileDialog {
        id: fileDialog
        title: "Select file"
        fileMode: FileDialog.OpenFile
        nameFilters: ["All files (*)", "Archives (*.zip *.tar *.tgz *.rar *.7z)", "Code files (*.py *.cs *.java *.js *.ts *.cpp *.c *.h)"]
        onAccepted: {
            var path = selectedFile.toString()
            if (root.fileDialogTarget === "assignment_rubric") {
                root.setEditValue("attachment_path", path)
                root.setEditValue("attachment_name", root.fileNameFromPath(path))
                root.setStatus("Rubric selected: " + root.fileNameFromPath(path), false)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: bg
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: sidebarWidth
            Layout.fillHeight: true
            visible: !narrow
            color: side

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        radius: 10
                        color: primary
                        Text {
                            anchors.centerIn: parent
                            text: "C"
                            color: "white"
                            font.pixelSize: 20
                            font.bold: true
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: "Classify"; color: "white"; font.pixelSize: 21; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: "System control"; color: "#CBD5E1"; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#263244" }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: navColumn.height
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: navColumn
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: sections
                            delegate: Rectangle {
                                width: navColumn.width
                                height: 42
                                radius: 10
                                color: activeSectionIndex === index ? "#243145" : "transparent"
                                border.width: activeSectionIndex === index ? 1 : 0
                                border.color: "#334155"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 9

                                    Rectangle {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 26
                                        radius: 8
                                        color: activeSectionIndex === index ? primary : "#1F2937"
                                        Text { anchors.centerIn: parent; text: modelData.short; color: "white"; font.pixelSize: 10; font.bold: true }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        color: activeSectionIndex === index ? "white" : "#CBD5E1"
                                        font.pixelSize: 13
                                        font.bold: activeSectionIndex === index
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: countFor(modelData.key)
                                        color: "#93C5FD"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: switchSection(index)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 158
                    radius: 14
                    color: "#172033"
                    border.color: "#28364C"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4
                        Text { text: "Signed in"; color: "#94A3B8"; font.pixelSize: 11 }
                        Text { text: userName || "Admin"; color: "white"; font.pixelSize: 15; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: "User ID: " + userId; color: "#CBD5E1"; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 9
                            color: statusIsError ? "#3B1D24" : "#1F2937"
                            border.color: statusIsError ? "#7F1D1D" : "#334155"
                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 16
                                text: statusText
                                color: statusIsError ? "#FCA5A5" : "#E2E8F0"
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: 9
                            color: "#F8FAFC"
                            border.color: "#E2E8F0"
                            Text {
                                anchors.centerIn: parent
                                text: "Logout"
                                color: "#0F172A"
                                font.pixelSize: 12
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.logout()
                            }
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
            contentHeight: contentColumn.height + 34
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentColumn
                width: mainFlick.width
                spacing: 16

                Item { Layout.fillWidth: true; Layout.preferredHeight: 22 }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: narrow ? 14 : 26
                    Layout.rightMargin: narrow ? 14 : 26
                    spacing: 14

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Admin Control Center"; color: ink; font.pixelSize: narrow ? 25 : 32; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: "A full operational view across schools, users, classes, assignments, submissions, AI, files and messages."; color: muted; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
                    }

                    Rectangle {
                        Layout.preferredWidth: loading ? 118 : 108
                        Layout.preferredHeight: 40
                        radius: 10
                        color: loading ? "#CBD5E1" : primary
                        Text { anchors.centerIn: parent; text: loading ? "Loading" : "Refresh"; color: "white"; font.pixelSize: 13; font.bold: true }
                        MouseArea { anchors.fill: parent; enabled: !loading; cursorShape: Qt.PointingHandCursor; onClicked: refreshAll() }
                    }

                    Rectangle {
                        Layout.preferredWidth: 94
                        Layout.preferredHeight: 40
                        radius: 10
                        color: panel
                        border.color: line
                        Text { anchors.centerIn: parent; text: "Logout"; color: ink; font.pixelSize: 13; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.logout() }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.leftMargin: narrow ? 14 : 26
                    Layout.rightMargin: narrow ? 14 : 26
                    spacing: 10

                    Repeater {
                        model: statCards()
                        delegate: Rectangle {
                            width: Math.max(178, Math.min(244, (mainFlick.width - (narrow ? 46 : 84)) / (narrow ? 2 : 6)))
                            height: 96
                            radius: 12
                            color: panel
                            border.color: line

                            Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 4; radius: 2; color: modelData.color }
                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text { text: modelData.label; color: muted; font.pixelSize: 11; font.bold: true; width: parent.width; elide: Text.ElideRight }
                                Text { text: modelData.value; color: ink; font.pixelSize: 25; font.bold: true; width: parent.width; elide: Text.ElideRight }
                                Text { text: modelData.note; color: faint; font.pixelSize: 10; width: parent.width; elide: Text.ElideRight }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: narrow ? 14 : 26
                    Layout.rightMargin: narrow ? 14 : 26
                    Layout.preferredHeight: narrow ? 760 : Math.max(620, root.height - 232)
                    radius: 16
                    color: panel
                    border.color: line
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: currentSection().label; color: ink; font.pixelSize: 22; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: filteredModel.count + " visible rows out of " + currentRows().length; color: muted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                            }

                            Rectangle {
                                visible: currentSection().create
                                Layout.preferredWidth: 126
                                Layout.preferredHeight: 38
                                radius: 10
                                color: primarySoft
                                border.color: "#BFDBFE"
                                Text { anchors.centerIn: parent; text: "New " + entityForSectionKey(currentSection().key); color: primary; font.pixelSize: 12; font.bold: true; width: parent.width - 14; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: openCreate(entityForSectionKey(currentSection().key)) }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                radius: 10
                                color: panel2
                                border.color: line

                                Text {
                                    text: "Search this data set"
                                    color: faint
                                    font.pixelSize: 13
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: searchInput.text.length === 0
                                }

                                TextInput {
                                    id: searchInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: ink
                                    selectionColor: "#BFDBFE"
                                    selectedTextColor: ink
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
                                Layout.preferredWidth: 110
                                Layout.preferredHeight: 40
                                radius: 10
                                color: statusIsError ? redSoft : panel2
                                border.color: statusIsError ? "#FECACA" : line
                                Text { anchors.centerIn: parent; text: statusText; color: statusIsError ? red : muted; font.pixelSize: 11; font.bold: true; width: parent.width - 14; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumWidth: narrow ? 0 : 560
                                radius: 12
                                color: "#FCFDFF"
                                border.color: lineSoft
                                clip: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 42
                                        color: panel2
                                        border.color: lineSoft
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 14
                                            anchors.rightMargin: 12
                                            spacing: 10
                                            Text { text: "ID"; color: muted; font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 68; elide: Text.ElideRight }
                                            Text { text: "Record"; color: muted; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                            Text { text: "State"; color: muted; font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 112; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                                            Text { text: "Actions"; color: muted; font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 164; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
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
                                            height: 72
                                            color: selectedSourceIndex === sourceIndex ? primarySoft : (index % 2 === 0 ? "#FFFFFF" : "#FCFDFF")
                                            border.width: selectedSourceIndex === sourceIndex ? 1 : 0
                                            border.color: "#BFDBFE"

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: selectBySource(sourceIndex)
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 14
                                                anchors.rightMargin: 12
                                                spacing: 10
                                                z: 1

                                                Text {
                                                    text: shortText(rowIdText, 10)
                                                    color: muted
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    Layout.preferredWidth: 68
                                                    elide: Text.ElideRight
                                                    verticalAlignment: Text.AlignVCenter
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 3
                                                    Text { text: primaryText; color: ink; font.pixelSize: 14; font.bold: true; Layout.fillWidth: true; maximumLineCount: 1; elide: Text.ElideRight }
                                                    Text { text: secondaryText; color: muted; font.pixelSize: 12; Layout.fillWidth: true; maximumLineCount: 1; elide: Text.ElideRight }
                                                }

                                                Rectangle {
                                                    Layout.preferredWidth: 112
                                                    Layout.preferredHeight: 28
                                                    radius: 8
                                                    color: accentValue === red ? redSoft : (accentValue === amber ? amberSoft : (accentValue === teal ? tealSoft : primarySoft))
                                                    border.color: line
                                                    Text { anchors.centerIn: parent; text: shortText(statusTextValue, 14); color: accentValue; font.pixelSize: 11; font.bold: true; width: parent.width - 12; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                                                }

                                                RowLayout {
                                                    Layout.preferredWidth: 164
                                                    spacing: 6
                                                    Rectangle {
                                                        Layout.preferredWidth: 72
                                                        Layout.preferredHeight: 32
                                                        radius: 8
                                                        color: panel2
                                                        border.color: line
                                                        Text { anchors.centerIn: parent; text: "Details"; color: ink; font.pixelSize: 12; font.bold: true }
                                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: selectBySource(sourceIndex) }
                                                    }
                                                    Rectangle {
                                                        visible: currentSection().edit
                                                        Layout.preferredWidth: 72
                                                        Layout.preferredHeight: 32
                                                        radius: 8
                                                        color: primary
                                                        Text { anchors.centerIn: parent; text: "Edit"; color: "white"; font.pixelSize: 12; font.bold: true }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                selectBySource(sourceIndex)
                                                                openEdit(entityForSectionKey(currentSection().key), selectedRow)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            visible: filteredModel.count === 0
                                            anchors.centerIn: parent
                                            width: Math.min(parent.width - 40, 360)
                                            height: 118
                                            radius: 12
                                            color: "#FFFFFF"
                                            border.color: line
                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 7
                                                Text { text: "No rows found"; color: ink; font.pixelSize: 18; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                                                Text { text: "Try another search or refresh the dashboard."; color: muted; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: compact ? 330 : 410
                                Layout.fillHeight: true
                                visible: !narrow
                                radius: 12
                                color: panel
                                border.color: line
                                clip: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 12

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text { text: selectedRow ? primaryOf(selectedRow) : "Select a record"; color: ink; font.pixelSize: 19; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                            Text { text: selectedRow ? currentSection().label.toUpperCase() : "Details and actions"; color: faint; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                        }
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        visible: selectedRow !== null

                                        Rectangle {
                                            visible: currentSection().edit
                                            width: 76
                                            height: 34
                                            radius: 9
                                            color: primary
                                            Text { anchors.centerIn: parent; text: "Edit"; color: "white"; font.pixelSize: 12; font.bold: true }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: openEdit(entityForSectionKey(currentSection().key), selectedRow) }
                                        }

                                        Rectangle {
                                            visible: currentSection().remove
                                            width: 82
                                            height: 34
                                            radius: 9
                                            color: redSoft
                                            border.color: "#FECACA"
                                            Text { anchors.centerIn: parent; text: "Delete"; color: red; font.pixelSize: 12; font.bold: true }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: requestDelete(entityForSectionKey(currentSection().key), selectedRow) }
                                        }

                                        Rectangle {
                                            visible: fileRefOf(selectedRow).length > 0
                                            width: 98
                                            height: 34
                                            radius: 9
                                            color: tealSoft
                                            border.color: "#A7F3D0"
                                            Text { anchors.centerIn: parent; text: "Download"; color: teal; font.pixelSize: 12; font.bold: true }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: auth.download_file(fileRefOf(selectedRow)) }
                                        }
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        visible: selectedRow !== null && currentSection().key === "users"

                                        Rectangle {
                                            width: 82
                                            height: 32
                                            radius: 9
                                            color: tealSoft
                                            border.color: "#A7F3D0"
                                            Text { anchors.centerIn: parent; text: "Activate"; color: teal; font.pixelSize: 11; font.bold: true }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: updateUserStatus(selectedRow, "ACTIVE") }
                                        }
                                        Rectangle {
                                            width: 82
                                            height: 32
                                            radius: 9
                                            color: amberSoft
                                            border.color: "#FDE68A"
                                            Text { anchors.centerIn: parent; text: "Pending"; color: amber; font.pixelSize: 11; font.bold: true }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: updateUserStatus(selectedRow, "PENDING") }
                                        }
                                        Rectangle {
                                            width: 82
                                            height: 32
                                            radius: 9
                                            color: redSoft
                                            border.color: "#FECACA"
                                            Text { anchors.centerIn: parent; text: "Block"; color: red; font.pixelSize: 11; font.bold: true }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: updateUserStatus(selectedRow, "BLOCKED") }
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: lineSoft }

                                    Flickable {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        contentWidth: width
                                        contentHeight: detailColumn.height
                                        boundsBehavior: Flickable.StopAtBounds

                                        ColumnLayout {
                                            id: detailColumn
                                            width: parent.width
                                            spacing: 9

                                            Repeater {
                                                model: detailRows(selectedRow)
                                                delegate: Rectangle {
                                                    Layout.fillWidth: true
                                                    radius: 10
                                                    color: panel2
                                                    border.color: lineSoft
                                                    Layout.preferredHeight: Math.max(54, detailValue.implicitHeight + 30)

                                                    ColumnLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 10
                                                        spacing: 3
                                                        Text { text: modelData.label; color: faint; font.pixelSize: 10; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                                        Text { id: detailValue; text: modelData.value; color: ink; font.pixelSize: 12; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true; maximumLineCount: 5; elide: Text.ElideRight }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true; Layout.preferredHeight: 18 }
            }
        }
    }

    Rectangle {
        visible: editorVisible
        anchors.fill: parent
        color: "#99111827"
        z: 50

        MouseArea { anchors.fill: parent }

        Rectangle {
            width: Math.min(root.width - 36, 700)
            height: Math.min(root.height - 48, 720)
            anchors.centerIn: parent
            radius: 16
            color: panel
            border.color: line
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: (editMode === "create" ? "Create " : "Edit ") + editEntity; color: ink; font.pixelSize: 23; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: "Changes here affect production data. Review the fields before saving."; color: muted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 9
                        color: panel2
                        border.color: line
                        Text { anchors.centerIn: parent; text: "X"; color: muted; font.pixelSize: 15; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: editorVisible = false }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: editContent.implicitHeight
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
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 10
                        color: panel2
                        border.color: line
                        Text { anchors.centerIn: parent; text: "Cancel"; color: muted; font.pixelSize: 14; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: editorVisible = false }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 10
                        color: primary
                        Text { anchors.centerIn: parent; text: "Save changes"; color: "white"; font.pixelSize: 14; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: saveEditor() }
                    }
                }
            }
        }
    }

    Component {
        id: fieldBox
        Rectangle {
            id: fieldRoot
            property string label: ""
            property string value: ""
            property string keyName: ""
            property bool multiline: false

            Layout.fillWidth: true
            height: multiline ? 122 : 66
            radius: 10
            color: panel2
            border.color: line

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4
                Text { text: fieldRoot.label; color: faint; font.pixelSize: 10; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }

                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: fieldRoot.multiline ? textAreaField : textInputField
                }
            }

            Component {
                id: textInputField
                TextField {
                    text: fieldRoot.value
                    color: ink
                    selectByMouse: true
                    font.pixelSize: 14
                    background: Rectangle { color: "transparent" }
                    onTextEdited: setEditValue(fieldRoot.keyName, text)
                }
            }

            Component {
                id: textAreaField
                TextArea {
                    text: fieldRoot.value
                    color: ink
                    selectByMouse: true
                    wrapMode: TextArea.Wrap
                    font.pixelSize: 14
                    background: Rectangle { color: "transparent" }
                    onTextChanged: setEditValue(fieldRoot.keyName, text)
                }
            }
        }
    }

    Component {
        id: choiceBox
        Rectangle {
            id: choiceRoot
            property string label: ""
            property string keyName: ""
            property var options: []
            property var value: ""

            Layout.fillWidth: true
            height: 68
            radius: 10
            color: panel2
            border.color: line

            function findIndex(v) {
                for (var i = 0; i < options.length; i++) {
                    if (asText(options[i].value) === asText(v))
                        return i
                }
                return options.length > 0 ? 0 : -1
            }

            onOptionsChanged: combo.currentIndex = findIndex(value)
            onValueChanged: combo.currentIndex = findIndex(value)
            Component.onCompleted: combo.currentIndex = findIndex(value)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4
                Text { text: choiceRoot.label; color: faint; font.pixelSize: 10; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                ComboBox {
                    id: combo
                    Layout.fillWidth: true
                    model: choiceRoot.options
                    textRole: "label"
                    font.pixelSize: 14
                    onActivated: {
                        if (index >= 0 && index < choiceRoot.options.length)
                            setEditValue(choiceRoot.keyName, choiceRoot.options[index].value)
                    }
                }
            }
        }
    }

    Component {
        id: boolBox
        Rectangle {
            id: boolRoot
            property string label: ""
            property string keyName: ""
            property bool checkedValue: false

            Layout.fillWidth: true
            height: 58
            radius: 10
            color: panel2
            border.color: line

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                Text { text: boolRoot.label; color: ink; font.pixelSize: 14; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                Switch {
                    checked: boolRoot.checkedValue
                    onToggled: setEditValue(boolRoot.keyName, checked)
                }
            }
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
            Loader { Layout.fillWidth: true; visible: editMode === "create"; sourceComponent: fieldBox; onLoaded: { item.label = "Initial password"; item.keyName = "password"; item.value = asText(editRow.password) } }
            Loader { Layout.fillWidth: true; sourceComponent: choiceBox; onLoaded: { item.label = "Role"; item.keyName = "role"; item.options = roleOptions(); item.value = asText(editRow.role) } }
            Loader { Layout.fillWidth: true; sourceComponent: choiceBox; onLoaded: { item.label = "Status"; item.keyName = "status"; item.options = statusOptions(); item.value = asText(editRow.status) } }
            Loader { Layout.fillWidth: true; sourceComponent: choiceBox; onLoaded: { item.label = "School"; item.keyName = "school_id"; item.options = schoolOptions(); item.value = Number(editRow.school_id || 1) } }
        }
    }

    Component {
        id: courseEditor
        ColumnLayout {
            spacing: 10
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Course name"; item.keyName = "name"; item.value = asText(editRow.name) } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Description"; item.keyName = "description"; item.value = asText(editRow.description); item.multiline = true } }
            Loader { Layout.fillWidth: true; sourceComponent: choiceBox; onLoaded: { item.label = "Teacher"; item.keyName = "teacher_id"; item.options = teacherOptions(); item.value = Number(editRow.teacher_id || userId) } }
            Loader { Layout.fillWidth: true; sourceComponent: choiceBox; onLoaded: { item.label = "School"; item.keyName = "school_id"; item.options = schoolOptions(); item.value = Number(editRow.school_id || 1) } }
        }
    }

    Component {
        id: assignmentEditor
        ColumnLayout {
            spacing: 10
            Loader { Layout.fillWidth: true; visible: editMode === "create"; sourceComponent: choiceBox; onLoaded: { item.label = "Course"; item.keyName = "course_id"; item.options = courseOptions(); item.value = Number(editRow.course_id || 1) } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Title"; item.keyName = "title"; item.value = asText(editRow.title) } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Description"; item.keyName = "description"; item.value = asText(editRow.description); item.multiline = true } }
            Loader { Layout.fillWidth: true; sourceComponent: fieldBox; onLoaded: { item.label = "Due date"; item.keyName = "due_date"; item.value = asText(editRow.due_date) } }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 68
                visible: editMode === "create"
                radius: 10
                color: panel2
                border.color: line
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text { text: "Rubric attachment"; color: faint; font.pixelSize: 10; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: "Up to 25MB - for multiple files, upload one ZIP"; color: faint; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: safe(editRow.attachment_name || fileNameFromPath(editRow.attachment_path)); color: ink; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                    Rectangle {
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 36
                        radius: 9
                        color: primarySoft
                        border.color: "#BFDBFE"
                        Text { anchors.centerIn: parent; text: "Choose file"; color: primary; font.pixelSize: 12; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: openFilePicker("assignment_rubric") }
                    }
                    Rectangle {
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 36
                        visible: safe(editRow.attachment_path) !== "-"
                        radius: 9
                        color: "#FFFFFF"
                        border.color: line
                        Text { anchors.centerIn: parent; text: "Clear"; color: muted; font.pixelSize: 12; font.bold: true }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                setEditValue("attachment_path", "")
                                setEditValue("attachment_name", "")
                            }
                        }
                    }
                }
            }
            Loader { Layout.fillWidth: true; sourceComponent: boolBox; onLoaded: { item.label = "AI enabled"; item.keyName = "ai_enabled"; item.checkedValue = Boolean(editRow.ai_enabled) } }
            Loader { Layout.fillWidth: true; sourceComponent: boolBox; onLoaded: { item.label = "Closed"; item.keyName = "is_closed"; item.checkedValue = Boolean(editRow.is_closed) } }
        }
    }

    Rectangle {
        visible: confirmVisible
        anchors.fill: parent
        color: "#99111827"
        z: 80

        MouseArea { anchors.fill: parent }

        Rectangle {
            width: Math.min(root.width - 32, 440)
            height: 250
            radius: 16
            color: panel
            border.color: line
            anchors.centerIn: parent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Text { text: "Delete record?"; color: ink; font.pixelSize: 23; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                Text { text: "This can remove related data and cannot be undone from this screen."; color: muted; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    radius: 10
                    color: redSoft
                    border.color: "#FECACA"
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        text: pendingDeleteEntity.toUpperCase() + " / " + (pendingDeleteRow ? primaryOf(pendingDeleteRow) : "")
                        color: red
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 10
                        color: panel2
                        border.color: line
                        Text { anchors.centerIn: parent; text: "Cancel"; color: muted; font.pixelSize: 14; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: confirmVisible = false }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 10
                        color: red
                        Text { anchors.centerIn: parent; text: "Delete"; color: "white"; font.pixelSize: 14; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: performDelete() }
                    }
                }
            }
        }
    }
}
