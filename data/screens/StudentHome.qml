import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs

Item {
    id: root
    anchors.fill: parent
    clip: true

    property string userName: "Student"
    property string role: "STUDENT"
    property int userId: -1
    property var nav

    property string currentPage: "dashboard"
    property int selectedClassId: 1
    property int selectedAssignmentId: 101
    property int selectedMaterialId: 1
    property int selectedMessageId: 1

    property string assignmentFilterClass: "All classes"
    property string assignmentDisplayMode: "All assignments"
    property string materialFilterClass: "All classes"
    property string gradesFilterClass: "All classes"
    property string messageFilterClass: "All classes"
    property string gradeMode: "new"
    property string messageMode: "new"
    property string classSearchText: ""
    property string assignmentSearchText: ""
    property string materialSearchText: ""
    property string gradeSearchText: ""
    property string messageSearchText: ""
    property bool detailOverlayVisible: false
    property string detailMode: ""

    property string joinCodeText: ""
    property string statusText: ""
    property bool statusError: false
    property string pendingSubmissionFilePath: ""
    property string pendingSubmissionFileName: ""
    property string pendingSubmissionText: ""
    property string lastDownloadedPath: ""
    property string busyText: ""
    property bool busyActive: false

    signal backendActionRequested(string actionName, string payloadText)

    readonly property color bg: "#F4F7FB"
    readonly property color card: "#FFFFFF"
    readonly property color cardSoft: "#F8FBFF"
    readonly property color soft: "#F7F9FC"
    readonly property color ink: "#0F172A"
    readonly property color muted: "#64748B"
    readonly property color muted2: "#94A3B8"
    readonly property color line: "#E2E8F0"
    readonly property color lineSoft: "#EDF2F7"
    readonly property color indigo600: "#4F46E5"
    readonly property color indigo700: "#4338CA"
    readonly property color indigoSoft: "#EEF2FF"
    readonly property color blue: "#2563EB"
    readonly property color blueSoft: "#DBEAFE"
    readonly property color emerald: "#059669"
    readonly property color emeraldSoft: "#D1FAE5"
    readonly property color amber: "#D97706"
    readonly property color amberSoft: "#FEF3C7"
    readonly property color rose: "#E11D48"
    readonly property color roseSoft: "#FFE4E6"
    readonly property color violetSoft: "#EDE9FE"

    Timer {
        id: statusTimer
        interval: 3800
        onTriggered: statusText = ""
    }

    FileDialog {
        id: uploadDialog
        title: "Choose submission file"
        nameFilters: ["Allowed files (*.pdf *.doc *.docx *.txt *.py)", "All files (*)"]
        onAccepted: {
            pendingSubmissionFilePath = selectedFile.toString()
            pendingSubmissionFileName = fileNameFromPath(pendingSubmissionFilePath)
            setStatus("File selected: " + pendingSubmissionFileName, false)
        }
    }

    ListModel {
        id: classesModel
    }

    ListModel {
        id: assignmentsModel
    }

    ListModel {
        id: materialsModel
    }

    ListModel {
        id: messagesModel
    }

    Component.onCompleted: { normalizeSelections(); loadStudentDashboard() }
    onUserIdChanged: loadStudentDashboard()

    function backendPayloadToText(payload) {
        if (payload === undefined || payload === null)
            return ""
        if (typeof payload === "string")
            return payload
        return JSON.stringify(payload)
    }

    function backendStub(actionName, payload) {
        var payloadText = backendPayloadToText(payload)
        backendActionRequested(actionName, payloadText)
    }

    function setStatus(messageText, isError) {
        statusText = messageText
        statusError = isError === true
        statusTimer.restart()
    }

    function beginBusy(messageText) {
        busyText = messageText && messageText.length > 0 ? messageText : "Please wait..."
        busyActive = true
    }

    function endBusy() {
        busyActive = false
        busyText = ""
    }

    function fileNameFromPath(pathText) {
        if (!pathText || pathText.length === 0)
            return ""
        var normalized = ("" + pathText).replace("file:///", "")
        normalized = normalized.split("\\").join("/")
        var parts = normalized.split("/")
        return parts.length > 0 ? parts[parts.length - 1] : normalized
    }

    function formatDateTimePretty(value) {
        if (!value || ("" + value).trim().length === 0)
            return "No due date"
        var txt = (("" + value).replace("T", " ")).trim()
        var parts = txt.split(" ")
        var datePart = parts.length > 0 ? parts[0] : ""
        var timePart = parts.length >= 2 && parts[1].length > 0 ? parts[1] : "00:00"
        var dateParts = datePart.split("-")
        if (dateParts.length === 3)
            return dateParts[2] + "/" + dateParts[1] + "/" + dateParts[0] + "  " + timePart.slice(0, 5)
        return txt
    }

    function isAssignmentOpen(dueTextValue) {
        if (!dueTextValue || dueTextValue.length === 0)
            return true
        var raw = (("" + dueTextValue).replace("T", " ")).trim()
        if (raw.indexOf(" ") < 0)
            raw += " 00:00"
        var parsed = new Date(raw.replace(" ", "T"))
        if (isNaN(parsed.getTime()))
            return true
        return parsed.getTime() >= new Date().getTime()
    }

    function hasStudentSubmission(assignmentObj) {
        if (!assignmentObj)
            return false
        if (assignmentObj.submitted === true)
            return true
        if (Number(assignmentObj.submissionId) >= 0)
            return true
        if (((assignmentObj.submittedAt || "") + "").trim().length > 0)
            return true
        if (((assignmentObj.submissionPath || "") + "").trim().length > 0)
            return true
        if (((assignmentObj.submissionFileName || "") + "").trim().length > 0)
            return true
        if (Number(assignmentObj.finalGrade) >= 0)
            return true
        return false
    }

    function isAssignmentClosedValue(value) {
        return value === true || value === 1 || value === "1" || value === "true"
    }

    function isAssignmentAvailableForSubmission(assignmentObj) {
        if (!assignmentObj)
            return false
        if (hasStudentSubmission(assignmentObj))
            return false
        if (!shouldShowAssignmentInMainList(assignmentObj))
            return false
        return true
    }

    function shouldShowAssignmentInMainList(assignmentObj) {
        if (!assignmentObj)
            return false
        return !isAssignmentClosedValue(assignmentObj.isClosed) && isAssignmentOpen(assignmentObj.dueText)
    }

    function firstVisibleAssignmentId() {
        for (var i = 0; i < assignmentsModel.count; i++) {
            var a = assignmentsModel.get(i)
            if (shouldShowAssignmentInMainList(a))
                return a.assignmentId
        }
        return assignmentsModel.count > 0 ? assignmentsModel.get(0).assignmentId : -1
    }

    function classIndexById(classId) {
        for (var i = 0; i < classesModel.count; i++)
            if (classesModel.get(i).classId === classId)
                return i
        return -1
    }

    function assignmentIndexById(assignmentId) {
        for (var i = 0; i < assignmentsModel.count; i++)
            if (assignmentsModel.get(i).assignmentId === assignmentId)
                return i
        return -1
    }

    function materialIndexById(materialId) {
        for (var i = 0; i < materialsModel.count; i++)
            if (materialsModel.get(i).materialId === materialId)
                return i
        return -1
    }

    function messageIndexById(messageId) {
        for (var i = 0; i < messagesModel.count; i++)
            if (messagesModel.get(i).messageId === messageId)
                return i
        return -1
    }

    function classNameById(classId) {
        var idx = classIndexById(classId)
        return idx >= 0 ? classesModel.get(idx).name : "Unknown class"
    }

    function classAccentById(classId) {
        var idx = classIndexById(classId)
        return idx >= 0 ? classesModel.get(idx).accent : indigo600
    }

    function classAccentSoftById(classId) {
        var idx = classIndexById(classId)
        return idx >= 0 ? classesModel.get(idx).accentSoft : indigoSoft
    }

    function currentClassObject() {
        var idx = classIndexById(selectedClassId)
        return idx >= 0 ? classesModel.get(idx) : null
    }

    function currentAssignmentObject() {
        var idx = assignmentIndexById(selectedAssignmentId)
        return idx >= 0 ? assignmentsModel.get(idx) : null
    }

    function currentMaterialObject() {
        var idx = materialIndexById(selectedMaterialId)
        return idx >= 0 ? materialsModel.get(idx) : null
    }

    function currentMessageObject() {
        var idx = messageIndexById(selectedMessageId)
        return idx >= 0 ? messagesModel.get(idx) : null
    }


    function materialDetailText(materialObj) {
        if (!materialObj)
            return ""
        var viewText = ((materialObj.viewText || "") + "").trim()
        var description = ((materialObj.description || "") + "").trim()
        if (viewText.length === 0)
            return description
        if (description.length === 0)
            return viewText
        if (viewText === description)
            return viewText
        if (viewText.indexOf(description) >= 0)
            return viewText
        if (description.indexOf(viewText) >= 0)
            return description
        return viewText + "

" + description
    }

    function normalizeSelections() {
        if (classesModel.count > 0 && classIndexById(selectedClassId) < 0)
            selectedClassId = classesModel.get(0).classId
        if (assignmentsModel.count > 0) {
            var firstVisibleId = firstVisibleAssignmentId()
            if (assignmentIndexById(selectedAssignmentId) < 0 || !shouldShowAssignmentInMainList(currentAssignmentObject()))
                selectedAssignmentId = firstVisibleId
        }
        if (materialsModel.count > 0 && materialIndexById(selectedMaterialId) < 0)
            selectedMaterialId = materialsModel.get(0).materialId
        if (messagesModel.count > 0 && messageIndexById(selectedMessageId) < 0)
            selectedMessageId = messagesModel.get(0).messageId
    }

    function filterAccepts(filterText, classId) {
        return filterText === "All classes" || classNameById(classId) === filterText
    }

    function matchesSearch(value, searchText) {
        var needle = (searchText || "").trim().toLowerCase()
        if (needle.length === 0)
            return true
        return ((value || "") + "").toLowerCase().indexOf(needle) >= 0
    }

    function openCount() {
        var total = 0
        for (var i = 0; i < assignmentsModel.count; i++) {
            var a = assignmentsModel.get(i)
            if (isAssignmentAvailableForSubmission(a))
                total += 1
        }
        return total
    }

    function submittedCount() {
        var total = 0
        for (var i = 0; i < assignmentsModel.count; i++)
            if (hasStudentSubmission(assignmentsModel.get(i)))
                total += 1
        return total
    }

    function gradedCount() {
        var total = 0
        for (var i = 0; i < assignmentsModel.count; i++)
            if (assignmentsModel.get(i).finalGrade >= 0)
                total += 1
        return total
    }

    function unreadMessagesCount() {
        var total = 0
        for (var i = 0; i < messagesModel.count; i++)
            if (!messagesModel.get(i).read)
                total += 1
        return total
    }

    function unreadGradesCount() {
        var total = 0
        for (var i = 0; i < assignmentsModel.count; i++) {
            var a = assignmentsModel.get(i)
            if (a.finalGrade >= 0 && !a.gradeRead)
                total += 1
        }
        return total
    }

    function averageGradeText() {
        var total = 0
        var count = 0
        for (var i = 0; i < assignmentsModel.count; i++) {
            var grade = assignmentsModel.get(i).finalGrade
            if (grade >= 0) {
                total += grade
                count += 1
            }
        }
        return count === 0 ? "—" : Math.round(total / count).toString()
    }

    function nextDueText() {
        var nextTs = -1
        var nextLabel = "No pending due dates"
        for (var i = 0; i < assignmentsModel.count; i++) {
            var a = assignmentsModel.get(i)
            if (!isAssignmentAvailableForSubmission(a))
                continue
            var raw = (("" + a.dueText).replace("T", " ")).trim()
            if (raw.indexOf(" ") < 0)
                raw += " 00:00"
            var parsed = new Date(raw.replace(" ", "T"))
            if (isNaN(parsed.getTime()))
                continue
            if (nextTs < 0 || parsed.getTime() < nextTs) {
                nextTs = parsed.getTime()
                nextLabel = a.title + " · " + formatDateTimePretty(a.dueText)
            }
        }
        return nextLabel
    }

    function joinClassByCode() {
        var codeValue = ("" + joinCodeText).trim().toUpperCase()
        if (codeValue.length === 0) {
            setStatus("Enter a class code first", true)
            return
        }
        beginBusy("Joining class...")
        if (typeof auth !== "undefined" && auth)
            auth.join_course_by_code(userId, codeValue)
        backendStub("join_class", { userId: userId, classCode: codeValue })
    }

    function leaveClass(classId) {
        var idx = classIndexById(classId)
        if (idx < 0)
            return
        beginBusy("Leaving class...")
        if (typeof auth !== "undefined" && auth)
            auth.leave_course(userId, classId)
        backendStub("leave_class", { userId: userId, classId: classId })
    }

    function openAssignment(assignmentId) {
        selectedAssignmentId = assignmentId
        currentPage = "assignments"
        detailMode = "assignment"
        detailOverlayVisible = true
        backendStub("open_assignment", { userId: userId, assignmentId: assignmentId })
    }

    function openMaterial(materialId) {
        selectedMaterialId = materialId
        currentPage = "materials"
        detailMode = "material"
        detailOverlayVisible = true
        backendStub("view_material", { userId: userId, materialId: materialId })
    }

    function openMessage(messageId) {
        selectedMessageId = messageId
        markMessageRead(messageId)
        currentPage = "messages"
        detailMode = "message"
        detailOverlayVisible = true
        backendStub("open_message", { userId: userId, messageId: messageId })
    }

    function openGrade(assignmentId) {
        var idx = assignmentIndexById(assignmentId)
        if (idx < 0)
            return
        assignmentsModel.setProperty(idx, "gradeRead", true)
        var submissionId = assignmentsModel.get(idx).submissionId || -1
        if (submissionId >= 0 && typeof auth !== "undefined" && auth)
            auth.mark_grade_read(userId, submissionId)
        selectedAssignmentId = assignmentId
        currentPage = "grades"
        detailMode = "grade"
        detailOverlayVisible = true
        backendStub("open_grade", { userId: userId, assignmentId: assignmentId, submissionId: submissionId })
    }

    function openSubmission(assignmentId) {
        selectedAssignmentId = assignmentId
        currentPage = "assignments"
        detailMode = "submission"
        detailOverlayVisible = true
        backendStub("open_submission", { userId: userId, assignmentId: assignmentId })
    }

    function clearSubmissionSelection() {
        pendingSubmissionFilePath = ""
        pendingSubmissionFileName = ""
    }

    function validateSubmissionFile() {
        if (!pendingSubmissionFileName || pendingSubmissionFileName.length === 0)
            return ""
        var lower = pendingSubmissionFileName.toLowerCase()
        var allowed = lower.endsWith(".pdf") || lower.endsWith(".doc") || lower.endsWith(".docx") || lower.endsWith(".txt") || lower.endsWith(".py")
        if (!allowed)
            return "Only PDF, DOC, DOCX, TXT or PY files are allowed"
        return ""
    }

    function validateSubmissionInput() {
        var hasFile = pendingSubmissionFileName && pendingSubmissionFileName.length > 0
        var hasText = pendingSubmissionText && pendingSubmissionText.trim().length > 0
        if (!hasFile && !hasText)
            return "Add submission text or choose a file before submitting"
        return validateSubmissionFile()
    }

    function submitSelectedAssignment() {
        var a = currentAssignmentObject()
        if (!a) {
            setStatus("Choose an assignment first", true)
            return
        }
        var validationError = validateSubmissionInput()
        if (validationError.length > 0) {
            setStatus(validationError, true)
            return
        }
        beginBusy("Uploading submission...")
        if (typeof auth !== "undefined" && auth) {
            if (pendingSubmissionFilePath && pendingSubmissionFilePath.length > 0)
                auth.upload_submission(a.assignmentId, userId, pendingSubmissionFilePath)
            else
                auth.upload_submission_text(a.assignmentId, userId, pendingSubmissionText)
        }
        backendStub("submit_assignment", {
            userId: userId,
            assignmentId: a.assignmentId,
            classId: a.classId,
            fileName: pendingSubmissionFileName,
            filePath: pendingSubmissionFilePath,
            submissionText: pendingSubmissionText
        })
    }

    function deleteSubmission(assignmentId) {
        var idx = assignmentIndexById(assignmentId)
        if (idx < 0)
            return
        beginBusy("Removing submission...")
        if (typeof auth !== "undefined" && auth)
            auth.delete_student_submission(assignmentId, userId)
        backendStub("delete_submission", { userId: userId, assignmentId: assignmentId })
    }

    function markMessageRead(messageId) {
        var idx = messageIndexById(messageId)
        if (idx < 0)
            return
        if (!messagesModel.get(idx).read) {
            messagesModel.setProperty(idx, "read", true)
            if (typeof auth !== "undefined" && auth)
                auth.mark_message_read(userId, messageId)
            backendStub("mark_message_read", { userId: userId, messageId: messageId })
        }
    }

    function markAllMessagesRead() {
        for (var i = 0; i < messagesModel.count; i++)
            messagesModel.setProperty(i, "read", true)
        if (typeof auth !== "undefined" && auth)
            auth.mark_all_messages_read(userId)
        backendStub("mark_all_messages_read", { userId: userId })
        setStatus("All messages marked as read", false)
    }

    function downloadServerFile(filePath, labelText) {
        if (!filePath || filePath.length === 0) {
            setStatus(labelText + " is not available for download", true)
            return
        }
        lastDownloadedPath = filePath
        beginBusy("Downloading " + labelText + "...")
        if (typeof auth !== "undefined" && auth)
            auth.download_file(filePath)
        backendStub("download_file", { userId: userId, path: filePath })
        setStatus("Download requested: " + labelText, false)
    }

    function refreshData() {
        var pageBeforeRefresh = currentPage
        loadStudentDashboard()
        backendStub("refresh_student_dashboard", { userId: userId, page: pageBeforeRefresh })
        setStatus("Refreshing data...", false)
    }

    function logout() {
        backendStub("logout", { userId: userId, userName: userName, role: role })
        if (nav)
            nav.pop()
    }

    function assignmentDisplayOptions() {
        return ["All assignments", "Not submitted", "Submitted"]
    }

    function assignmentVisibleForMode(submittedValue) {
        if (assignmentDisplayMode === "Not submitted")
            return !submittedValue
        if (assignmentDisplayMode === "Submitted")
            return submittedValue
        return true
    }

    function classOpenAssignmentCount(classId) {
        var total = 0
        for (var i = 0; i < assignmentsModel.count; i++) {
            var a = assignmentsModel.get(i)
            if (a.classId === classId && isAssignmentAvailableForSubmission(a))
                total += 1
        }
        return total
    }

    function classSubmittedCount(classId) {
        var total = 0
        for (var i = 0; i < assignmentsModel.count; i++) {
            var a = assignmentsModel.get(i)
            if (a.classId === classId && a.submitted)
                total += 1
        }
        return total
    }

    function classUnreadMessageCount(classId) {
        var total = 0
        for (var i = 0; i < messagesModel.count; i++) {
            var m = messagesModel.get(i)
            if (m.classId === classId && !m.read)
                total += 1
        }
        return total
    }

    function classNameOptions() {
        var arr = ["All classes"]
        for (var i = 0; i < classesModel.count; i++)
            arr.push(classesModel.get(i).name)
        return arr
    }

    function visibleClassesCount() {
        var total = 0
        for (var i = 0; i < classesModel.count; i++) {
            var c = classesModel.get(i)
            if (matchesSearch(c.name + " " + c.teacherName + " " + c.code + " " + c.description, root.classSearchText))
                total += 1
        }
        return total
    }

    function visibleUpcomingCount() {
        var total = 0
        for (var i = 0; i < assignmentsModel.count; i++) {
            var a = assignmentsModel.get(i)
            if (isAssignmentAvailableForSubmission(a))
                total += 1
        }
        return total
    }

    function visibleAssignmentsCount() {
        var total = 0
        for (var i = 0; i < assignmentsModel.count; i++) {
            var a = assignmentsModel.get(i)
            if (shouldShowAssignmentInMainList(a) && filterAccepts(root.assignmentFilterClass, a.classId) && assignmentVisibleForMode(hasStudentSubmission(a)) && matchesSearch(a.title + " " + a.description + " " + classNameById(a.classId), root.assignmentSearchText))
                total += 1
        }
        return total
    }

    function visibleSubmittedAssignmentsCount() {
        var total = 0
        for (var i = 0; i < assignmentsModel.count; i++) {
            var a = assignmentsModel.get(i)
            if (a.submitted && filterAccepts(root.assignmentFilterClass, a.classId))
                total += 1
        }
        return total
    }

    function visibleMaterialsCount() {
        var total = 0
        for (var i = 0; i < materialsModel.count; i++) {
            var m = materialsModel.get(i)
            if (filterAccepts(root.materialFilterClass, m.classId) && matchesSearch(m.title + " " + m.description + " " + m.type, root.materialSearchText))
                total += 1
        }
        return total
    }

    function visibleGradesCount() {
        var total = 0
        for (var i = 0; i < assignmentsModel.count; i++) {
            var a = assignmentsModel.get(i)
            if (a.finalGrade >= 0 && filterAccepts(root.gradesFilterClass, a.classId) && (root.gradeMode === "all" || (root.gradeMode === "new" && !a.gradeRead) || (root.gradeMode === "history" && a.gradeRead)) && matchesSearch(a.title + " " + classNameById(a.classId), root.gradeSearchText))
                total += 1
        }
        return total
    }

    function visibleMessagesCount() {
        var total = 0
        for (var i = 0; i < messagesModel.count; i++) {
            var m = messagesModel.get(i)
            if (filterAccepts(root.messageFilterClass, m.classId) && (root.messageMode === "all" || (root.messageMode === "new" && !m.read) || (root.messageMode === "history" && m.read)) && matchesSearch(m.subject + " " + m.fromText + " " + m.body, root.messageSearchText))
                total += 1
        }
        return total
    }

    // --- Added: backend integration helpers ---
    function clearModel(model) {
        while (model.count > 0)
            model.remove(0)
    }

    function refillModel(model, rows) {
        clearModel(model)
        if (!rows)
            return
        for (var i = 0; i < rows.length; i++)
            model.append(rows[i])
    }

    function loadStudentDashboard() {
        if (typeof auth === "undefined" || !auth || userId < 0)
            return
        beginBusy("Loading student data...")
        clearModel(classesModel)
        clearModel(assignmentsModel)
        clearModel(materialsModel)
        clearModel(messagesModel)
        auth.get_student_dashboard(userId)
    }

    Rectangle {
        anchors.fill: parent
        color: bg

        Rectangle { width: 540; height: 540; radius: 270; x: -240; y: -210; color: indigo600; opacity: 0.05 }
        Rectangle { width: 680; height: 680; radius: 340; x: parent.width - 500; y: parent.height - 500; color: blue; opacity: 0.05 }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 92
                radius: 24
                gradient: Gradient {
                    GradientStop { position: 0.0; color: indigo600 }
                    GradientStop { position: 1.0; color: indigo700 }
                }
                border.width: 1
                border.color: "#2FFFFFFF"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    Rectangle {
                        width: 54; height: 54; radius: 17
                        color: "#20FFFFFF"
                        border.width: 1
                        border.color: "#30FFFFFF"
                        clip: true

                        Image {
                            anchors.centerIn: parent
                            width: 40
                            height: 40
                            source: "png/AppLogo.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 12

                        Text {
                            text: "Classify"
                            color: "#FFFFFF"
                            opacity: 0.98
                            font.pixelSize: 26
                            font.weight: Font.DemiBold
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: "Welcome back, " + root.userName + " 👋"
                            color: "#FFFFFF"
                            opacity: 0.95
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 10
                        HeaderButton { text: "Refresh"; onClicked: root.refreshData() }
                        HeaderButton { text: "Logout"; onClicked: root.logout() }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                Rectangle {
                    Layout.preferredWidth: 324
                    Layout.fillHeight: true
                    radius: 24
                    color: card
                    border.width: 1
                    border.color: line

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        Text { text: "Student menu"; color: ink; font.pixelSize: 18; font.weight: Font.DemiBold }

                        Item { Layout.fillWidth: true; implicitHeight: 6 }
                        NavItem { title: "Dashboard"; iconText: "🏠"; pageKey: "dashboard" }
                        NavItem { title: "My classes"; iconText: "🏫"; pageKey: "classes" }
                        NavItem { title: "Assignments"; iconText: "📝"; pageKey: "assignments" }
                        NavItem { title: "Study materials"; iconText: "📚"; pageKey: "materials" }
                        NavItem { title: "Grades"; iconText: "📈"; pageKey: "grades" }
                        NavItem { title: "Messages"; iconText: "✉️"; pageKey: "messages" }
                        NavItem { title: "Join a class"; iconText: "➕"; pageKey: "join" }

                        Item { Layout.fillHeight: true }

                        Rectangle {
                            Layout.fillWidth: true
                            radius: 18
                            color: cardSoft
                            border.width: 1
                            border.color: line
                            implicitHeight: 122

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 6
                                Text { text: "Up next"; color: ink; font.pixelSize: 14; font.weight: Font.DemiBold }
                                Text { text: nextDueText(); color: muted; font.pixelSize: 12; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                                Badge { textValue: "Average grade: " + averageGradeText(); bgColor: violetSoft; fgColor: indigo700 }
                            }
                        }
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    sourceComponent:
                        currentPage === "dashboard" ? dashboardPage :
                        currentPage === "classes" ? classesPage :
                        currentPage === "assignments" ? assignmentsPage :
                        currentPage === "materials" ? materialsPage :
                        currentPage === "grades" ? gradesPage :
                        currentPage === "messages" ? messagesPage :
                        joinPage
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: statusText.length > 0 ? 46 : 0
                visible: statusText.length > 0
                radius: 14
                color: statusError ? roseSoft : emeraldSoft
                border.width: 1
                border.color: statusError ? "#FBCFE8" : "#A7F3D0"

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    text: statusText
                    color: statusError ? rose : emerald
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
        }
    }

    // --- Added: backend signal handlers ---
    Connections {
        target: typeof auth !== "undefined" ? auth : null

        function onStudentDashboardResult(success, message, studentIdResult, classesRows, assignmentsRows, materialsRows, messagesRows) {
            if (studentIdResult !== userId)
                return
            endBusy()
            if (!success) {
                clearModel(classesModel)
                clearModel(assignmentsModel)
                clearModel(materialsModel)
                clearModel(messagesModel)
                normalizeSelections()
                setStatus(message, true)
                return
            }
            refillModel(classesModel, classesRows)
            refillModel(assignmentsModel, assignmentsRows)
            refillModel(materialsModel, materialsRows)
            refillModel(messagesModel, messagesRows)
            normalizeSelections()
        }

        function onJoinCourseResult(success, message, studentIdResult, classCode) {
            if (studentIdResult !== userId)
                return
            if (success) {
                joinCodeText = ""
                loadStudentDashboard()
                setStatus("You joined the class successfully.", false)
            } else {
                endBusy()
                setStatus(message, true)
            }
        }

        function onLeaveCourseResult(success, message, studentIdResult, courseIdResult) {
            if (studentIdResult !== userId)
                return
            if (success) {
                loadStudentDashboard()
                setStatus("You left the class successfully.", false)
            } else {
                endBusy()
                setStatus(message, true)
            }
        }

        function onUploadSubmissionResult(success, message, assignmentIdResult, submissionIdResult) {
            if (success) {
                clearSubmissionSelection()
                pendingSubmissionText = ""
                detailMode = "submission"
                loadStudentDashboard()
                setStatus("Submission uploaded", false)
            } else {
                endBusy()
                if (message === "ASSIGNMENT_CLOSED")
                    setStatus("This assignment is closed and can no longer be submitted", true)
                else
                    setStatus(message, true)
            }
        }

        function onDeleteSubmissionResult(success, message, assignmentIdResult, studentIdResult) {
            if (studentIdResult !== userId)
                return
            if (success) {
                loadStudentDashboard()
                setStatus("Submission removed", false)
            } else {
                endBusy()
                setStatus(message, true)
            }
        }

        function onDownloadFileResult(success, message, filePath, savedPath) {
            endBusy()
            if (success)
                setStatus("File downloaded to: " + savedPath, false)
            else
                setStatus(message, true)
        }
    }

    component HeaderButton : Item {
        id: hb
        property alias text: label.text
        signal clicked
        implicitWidth: 100
        implicitHeight: 36

        Rectangle { anchors.fill: parent; radius: 12; color: "#FFFFFF"; opacity: ma.pressed ? 0.22 : (ma.containsMouse ? 0.20 : 0.16); border.width: 1; border.color: "#10FFFFFF" }
        Text { id: label; anchors.centerIn: parent; color: "#FFFFFF"; font.pixelSize: 13; font.weight: Font.DemiBold }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: hb.clicked() }
    }

    component NavItem : Item {
        property string title: ""
        property string iconText: ""
        property string pageKey: ""
        readonly property bool active: root.currentPage === pageKey
        Layout.fillWidth: true
        implicitHeight: 52

        Rectangle { anchors.fill: parent; radius: 14; color: active ? indigoSoft : "transparent"; border.width: 1; border.color: active ? "#C7D2FE" : "transparent" }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10
            Rectangle { width: 30; height: 30; radius: 10; color: active ? "#FFFFFF" : soft; border.width: 1; border.color: lineSoft; Text { anchors.centerIn: parent; text: iconText; font.pixelSize: 13 } }
            Text { Layout.fillWidth: true; text: title; color: active ? indigo700 : ink; font.pixelSize: 13; font.weight: active ? Font.DemiBold : Font.Medium; elide: Text.ElideRight }
        }
        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.currentPage = pageKey }
    }

    component StatCard : Rectangle {
        property string title: ""
        property string value: ""
        property string iconText: ""
        property color accentBg: indigoSoft
        property color accentText: indigo700
        Layout.fillWidth: true
        Layout.preferredHeight: 96
        radius: 18
        color: card
        border.width: 1
        border.color: line

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            Rectangle { width: 46; height: 46; radius: 15; color: accentBg; border.width: 1; border.color: lineSoft; Text { anchors.centerIn: parent; text: iconText; color: accentText; font.pixelSize: 18 } }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: title; color: muted; font.pixelSize: 12 }
                Text { text: value; color: ink; font.pixelSize: 24; font.weight: Font.DemiBold }
            }
        }
    }

    component SectionFrame : Rectangle {
        Layout.fillWidth: true
        radius: 22
        clip: true
        color: card
        border.width: 1
        border.color: line
    }

    component SearchField : Item {
        property string label: "Search"
        property alias text: searchField.text
        property string placeholder: "Search..."
        implicitHeight: 78
        Layout.fillWidth: true
        ColumnLayout {
            anchors.fill: parent
            spacing: 7
            Text { text: label; color: muted; font.pixelSize: 12; font.weight: Font.Medium }
            TextField {
                id: searchField
                Layout.fillWidth: true
                implicitHeight: 46
                placeholderText: placeholder
                leftPadding: 38
                topPadding: 15
                bottomPadding: 7
                color: ink
                selectByMouse: true
                selectedTextColor: "#FFFFFF"
                selectionColor: indigo600
                background: Rectangle { radius: 14; color: "#F8FAFC"; border.width: 1; border.color: searchField.activeFocus ? indigo600 : line }
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; text: "🔎"; color: muted2; font.pixelSize: 14 }
            }
        }
    }

    component Badge : Rectangle {
        property string textValue: ""
        property color bgColor: blueSoft
        property color fgColor: blue
        implicitWidth: Math.max(84, badgeText.implicitWidth + 18)
        implicitHeight: 28
        radius: 10
        color: bgColor
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.05)
        Text { id: badgeText; anchors.centerIn: parent; text: textValue; color: fgColor; font.pixelSize: 12; font.weight: Font.DemiBold }
    }

    component ActionButton : Item {
        id: ab
        property alias text: btnLabel.text
        property string kind: "primary"
        property bool enabledState: true
        signal clicked
        implicitWidth: Math.max(108, btnLabel.implicitWidth + 28)
        implicitHeight: 40
        enabled: enabledState
        opacity: enabled ? 1.0 : 0.55

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: kind === "ghost" ? "#FFFFFF" : indigo600
            border.width: 1
            border.color: kind === "ghost" ? line : indigo600
            opacity: btnMouse.pressed ? 0.88 : 1.0
        }
        Text { id: btnLabel; anchors.centerIn: parent; color: kind === "ghost" ? ink : "#FFFFFF"; font.pixelSize: 12; font.weight: Font.DemiBold }
        MouseArea { id: btnMouse; anchors.fill: parent; hoverEnabled: true; enabled: ab.enabled; cursorShape: Qt.PointingHandCursor; onClicked: ab.clicked() }
    }



    component CardActionButton : Item {
        id: cab
        property alias text: cabLabel.text
        property color fillColor: indigo600
        property color borderColor: fillColor
        property color textColor: "#FFFFFF"
        property bool enabledState: true
        signal clicked
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        implicitWidth: Math.max(132, cabLabel.implicitWidth + 28)
        implicitHeight: 42
        enabled: enabledState
        opacity: enabled ? 1.0 : 0.55

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: cab.fillColor
            border.width: 1
            border.color: cab.borderColor
            opacity: cabMouse.pressed ? 0.9 : 1.0
        }

        Text {
            id: cabLabel
            anchors.centerIn: parent
            color: cab.textColor
            font.pixelSize: 12
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        MouseArea {
            id: cabMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: cab.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: cab.clicked()
        }
    }

    component StyledCombo : Item {
        property string label: ""
        property alias model: combo.model
        property alias currentText: combo.currentText
        property alias currentIndex: combo.currentIndex
        implicitHeight: 78
        Layout.fillWidth: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 7
            Text { text: label; color: muted; font.pixelSize: 12; font.weight: Font.Medium }
            ComboBox {
                id: combo
                Layout.fillWidth: true
                implicitHeight: 46
                font.pixelSize: 12
                model: []
                leftPadding: 14
                rightPadding: 36
                contentItem: Text {
                    text: combo.displayText
                    color: ink
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 0
                    rightPadding: 0
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
                indicator: Canvas {
                    x: combo.width - width - 14
                    y: combo.topPadding + (combo.availableHeight - height) / 2
                    width: 12
                    height: 8
                    contextType: "2d"
                    onPaint: {
                        context.reset()
                        context.moveTo(0, 0)
                        context.lineTo(width, 0)
                        context.lineTo(width / 2, height)
                        context.closePath()
                        context.fillStyle = "#475569"
                        context.fill()
                    }
                }
                delegate: ItemDelegate {
                    width: combo.width - 8
                    contentItem: Text {
                        text: modelData
                        color: ink
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 10
                        color: highlighted ? "#EEF2FF" : (combo.currentIndex === index ? "#F8FAFF" : "transparent")
                        border.width: combo.currentIndex === index ? 1 : 0
                        border.color: "#C7D2FE"
                    }
                }
                background: Rectangle {
                    radius: 14
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#FFFFFF" }
                        GradientStop { position: 1.0; color: "#F8FAFC" }
                    }
                    border.width: 1
                    border.color: combo.activeFocus ? indigo600 : "#D7E0EC"
                }
                popup: Popup {
                    y: combo.height + 6
                    width: combo.width
                    implicitHeight: Math.min(contentItem.implicitHeight + 10, 220)
                    padding: 5
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: combo.popup.visible ? combo.delegateModel : null
                        spacing: 4
                        ScrollIndicator.vertical: ScrollIndicator { }
                    }
                    background: Rectangle {
                        radius: 16
                        color: "#FFFFFF"
                        border.width: 1
                        border.color: "#D7E0EC"
                    }
                }
            }
        }
    }

    component PageHeader : Rectangle {
        property string title: ""
        property string subtitle: ""
        property string iconText: ""
        Layout.fillWidth: true
        implicitHeight: 100
        radius: 18
        color: cardSoft
        border.width: 1
        border.color: line

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            Rectangle { width: 46; height: 46; radius: 15; color: indigoSoft; border.width: 1; border.color: "#D9E0FF"; Text { anchors.centerIn: parent; text: iconText; font.pixelSize: 18 } }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                Text { text: title; color: ink; font.pixelSize: 20; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignLeft; Layout.fillWidth: true }
                Text { text: subtitle; visible: subtitle.length > 0; color: muted; font.pixelSize: 12; wrapMode: Text.WrapAnywhere; horizontalAlignment: Text.AlignLeft; Layout.fillWidth: true }
            }
        }
    }

    component EmptyState : Item {
        property string title: ""
        property string subtitle: ""
        implicitHeight: 190
        Layout.fillWidth: true

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: soft
            border.width: 1
            border.color: line
        }

        Column {
            anchors.centerIn: parent
            spacing: 8
            Text { text: "✨"; font.pixelSize: 28; horizontalAlignment: Text.AlignHCenter; width: 240 }
            Text { text: title; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; width: 300 }
            Text { text: subtitle; visible: subtitle.length > 0; color: muted; font.pixelSize: 12; wrapMode: Text.WrapAnywhere; horizontalAlignment: Text.AlignHCenter; width: 300 }
        }
    }

    Component {
        id: dashboardPage
        Item {
            ColumnLayout {
                id: dashboardColumn
                anchors.fill: parent
                spacing: 16

                PageHeader {
                    title: "Overview"
                    subtitle: ""
                    iconText: "🏠"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    StatCard { title: "My classes"; value: classesModel.count.toString(); iconText: "🏫"; accentBg: blueSoft; accentText: blue }
                    StatCard { title: "Open tasks"; value: openCount().toString(); iconText: "📝"; accentBg: amberSoft; accentText: amber }
                    StatCard { title: "Unread grades"; value: unreadGradesCount().toString(); iconText: "📈"; accentBg: emeraldSoft; accentText: emerald }
                    StatCard { title: "Unread messages"; value: unreadMessagesCount().toString(); iconText: "✉️"; accentBg: violetSoft; accentText: indigo700 }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 16

                    SectionFrame {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "My classes"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }
                                Item { Layout.fillWidth: true }
                                ActionButton { text: "Join class"; kind: "ghost"; onClicked: currentPage = "join" }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 18
                                color: soft
                                border.width: 1
                                border.color: line

                                ListView {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    clip: true
                                    spacing: 10
                                    model: classesModel
                                    visible: classesModel.count > 0
                                    ScrollIndicator.vertical: ScrollIndicator { }
                                    delegate: Rectangle {
                                        width: ListView.view.width
                                        height: 98
                                        radius: 18
                                        color: accentSoft
                                        border.width: 1
                                        border.color: Qt.darker(accentSoft, 1.08)

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12
                                            Rectangle { width: 48; height: 48; radius: 16; color: "#FFFFFF"; border.width: 1; border.color: Qt.rgba(0,0,0,0.06); Text { anchors.centerIn: parent; text: iconText; font.pixelSize: 20 } }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 3
                                                Text { text: name; color: ink; font.pixelSize: 14; font.weight: Font.DemiBold }
                                                Text { text: teacherName + " · Code " + code; color: muted; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                                                Text { text: description; color: muted2; font.pixelSize: 11; wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideRight; Layout.fillWidth: true }
                                            }
                                            ActionButton { text: "Open"; kind: "ghost"; onClicked: { selectedClassId = classId; currentPage = "classes" } }
                                        }
                                    }
                                }

                                EmptyState {
                                    anchors.centerIn: parent
                                    visible: classesModel.count === 0
                                    title: "No classes yet"
                                    subtitle: "When you join a class, it will appear here."
                                }
                            }
                        }
                    }

                    SectionFrame {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Next things to do"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }
                                Item { Layout.fillWidth: true }
                                Badge { textValue: "Average grade: " + averageGradeText(); bgColor: violetSoft; fgColor: indigo700 }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 18
                                color: soft
                                border.width: 1
                                border.color: line

                                ListView {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    clip: true
                                    spacing: 0
                                    model: assignmentsModel
                                    visible: visibleUpcomingCount() > 0
                                    ScrollIndicator.vertical: ScrollIndicator { }
                                    delegate: Item {
                                        property bool shown: root.isAssignmentAvailableForSubmission({
                                            "submitted": submitted,
                                            "submissionId": submissionId,
                                            "finalGrade": finalGrade,
                                            "submittedAt": submittedAt,
                                            "isClosed": isClosed,
                                            "dueText": dueText
                                        })
                                        width: ListView.view.width
                                        height: shown ? 98 : 0
                                        visible: shown

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            height: 88
                                            radius: 18
                                            color: "#FFFFFF"
                                            border.width: 1
                                            border.color: line

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 10
                                                Badge {
                                                    textValue: "Open"
                                                    bgColor: amberSoft
                                                    fgColor: amber
                                                }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    Text { text: title; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold }
                                                    Text { text: classNameById(classId) + " · Due " + formatDateTimePretty(dueText); color: muted; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                                                    Text { text: description; color: muted2; font.pixelSize: 11; wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideRight; Layout.fillWidth: true }
                                                }
                                                ActionButton { text: "Open"; kind: "ghost"; onClicked: openAssignment(assignmentId) }
                                            }
                                        }
                                    }
                                }

                                EmptyState {
                                    anchors.centerIn: parent
                                    visible: visibleUpcomingCount() === 0
                                    title: "No upcoming assignments"
                                    subtitle: "Tasks you still need to submit will appear here."
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: classesPage
        Flickable {
            contentWidth: width
            contentHeight: classesColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator { }

            ColumnLayout {
                id: classesColumn
                width: parent.width
                spacing: 16

                PageHeader {
                    title: "My classes"
                    subtitle: ""
                    iconText: "🏫"
                }
                SearchField { label: "Find class"; placeholder: "Search by class, teacher or code"; text: root.classSearchText; onTextChanged: root.classSearchText = text }

                EmptyState {
                    visible: visibleClassesCount() === 0
                    title: classesModel.count === 0 ? "No classes yet" : "No classes match your search"
                    subtitle: classesModel.count === 0 ? "Join a class to start seeing your courses here." : "Try a different search word."
                }

                Repeater {
                    model: classesModel
                    delegate: SectionFrame {
                        visible: matchesSearch(name + " " + teacherName + " " + code + " " + description, root.classSearchText)
                        implicitHeight: visible ? 248 : 0

                        Rectangle {
                            anchors.fill: parent
                            radius: 22
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: accentSoft }
                                GradientStop { position: 0.65; color: "#FFFFFF" }
                                GradientStop { position: 1.0; color: "#F8FAFC" }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Rectangle { width: 54; height: 54; radius: 18; color: "#FFFFFF"; border.width: 1; border.color: line; Text { anchors.centerIn: parent; text: iconText; font.pixelSize: 21 } }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3
                                    Text { text: name; color: ink; font.pixelSize: 18; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { text: teacherName + " · Code " + code; color: muted; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { text: description; color: muted; font.pixelSize: 12; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true; maximumLineCount: 2 }
                                }
                                Badge { textValue: studentsCount + " students"; bgColor: accentSoft; fgColor: accent }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                MiniInfo { label: "Open tasks"; value: classOpenAssignmentCount(classId).toString(); tint: accentSoft; tintText: accent }
                                MiniInfo { label: "Submitted"; value: classSubmittedCount(classId).toString(); tint: accentSoft; tintText: accent }
                                MiniInfo { label: "Unread messages"; value: classUnreadMessageCount(classId).toString(); tint: accentSoft; tintText: accent }
                                MiniInfo { label: "Materials"; value: materialCount(classId).toString(); tint: accentSoft; tintText: accent }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 72
                                radius: 18
                                color: "#FFFFFF"
                                border.width: 1
                                border.color: line
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12
                                    CardActionButton {
                                        text: "Open assignments"
                                        fillColor: accent
                                        borderColor: accent
                                        onClicked: {
                                            selectedClassId = classId
                                            assignmentFilterClass = classNameById(classId)
                                            assignmentDisplayMode = "All assignments"
                                            currentPage = "assignments"
                                            backendStub("open_class_assignments", { userId: userId, classId: classId, className: name })
                                        }
                                    }
                                    CardActionButton {
                                        text: "Study materials"
                                        fillColor: "#FFFFFF"
                                        borderColor: accent
                                        textColor: accent
                                        onClicked: {
                                            selectedClassId = classId
                                            materialFilterClass = classNameById(classId)
                                            currentPage = "materials"
                                            backendStub("open_class_materials", { userId: userId, classId: classId, className: name })
                                        }
                                    }
                                    CardActionButton {
                                        text: "Leave class"
                                        fillColor: rose
                                        borderColor: rose
                                        onClicked: leaveClass(classId)
                                    }
                                }

                            }
                        }
                    }
                }
            }
        }
    }

    component MiniInfo : Rectangle {
        property string label: ""
        property string value: ""
        property string tint: blueSoft
        property string tintText: blue
        Layout.fillWidth: true
        implicitHeight: 66
        radius: 16
        color: "#FFFFFF"
        border.width: 1
        border.color: line

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: tint
            opacity: 0.22
        }

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 3

            Text {
                text: value
                color: ink
                font.pixelSize: 18
                font.weight: Font.Bold
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Text {
                text: label
                color: muted
                font.pixelSize: 11
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 2
            }
        }
    }

    function myCount(classId) {
        var total = 0
        for (var i = 0; i < assignmentsModel.count; i++)
            if (assignmentsModel.get(i).classId === classId)
                total += 1
        return total
    }

    function materialCount(classId) {
        var total = 0
        for (var i = 0; i < materialsModel.count; i++)
            if (materialsModel.get(i).classId === classId)
                total += 1
        return total
    }

    Component {
        id: assignmentsPage
        Item {
            ColumnLayout {
                id: assignmentsColumn
                anchors.fill: parent
                spacing: 16

                PageHeader {
                    title: "Assignments"
                    subtitle: ""
                    iconText: "📝"
                }
                SearchField { label: "Find assignment"; placeholder: "Search by title, class or instructions"; text: root.assignmentSearchText; onTextChanged: root.assignmentSearchText = text }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    StyledCombo {
                        Layout.preferredWidth: 260
                        label: "Filter by class"
                        model: classNameOptions()
                        currentIndex: Math.max(0, classNameOptions().indexOf(root.assignmentFilterClass))
                        onCurrentTextChanged: root.assignmentFilterClass = currentText
                    }
                    StyledCombo {
                        Layout.preferredWidth: 220
                        label: "Show"
                        model: assignmentDisplayOptions()
                        currentIndex: Math.max(0, assignmentDisplayOptions().indexOf(root.assignmentDisplayMode))
                        onCurrentTextChanged: root.assignmentDisplayMode = currentText
                    }
                    Item { Layout.fillWidth: true }
                    Badge { textValue: submittedCount().toString() + " submissions"; bgColor: blueSoft; fgColor: blue }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 16

                    SectionFrame {
                        Layout.preferredWidth: 420
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            Text { text: "Assignment list"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 18
                                color: soft
                                border.width: 1
                                border.color: line
                                ListView {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    clip: true
                                    spacing: 0
                                    model: assignmentsModel
                                    visible: visibleAssignmentsCount() > 0
                                    ScrollIndicator.vertical: ScrollIndicator { }
                                    delegate: Item {
                                        property bool shown: shouldShowAssignmentInMainList(model) && filterAccepts(root.assignmentFilterClass, classId) && assignmentVisibleForMode(hasStudentSubmission(model)) && matchesSearch(title + " " + description + " " + classNameById(classId), root.assignmentSearchText)
                                        width: ListView.view.width
                                        height: shown ? 110 : 0
                                        visible: shown

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            height: 100
                                            radius: 18
                                            color: selectedAssignmentId === assignmentId ? indigoSoft : "#FFFFFF"
                                            border.width: 1
                                            border.color: selectedAssignmentId === assignmentId ? "#C7D2FE" : line

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 12
                                                Rectangle { width: 48; height: 48; radius: 15; color: classAccentSoftById(classId); border.width: 1; border.color: line; Text { anchors.centerIn: parent; text: hasStudentSubmission(model) ? (finalGrade >= 0 ? "✅" : "📤") : "📝"; font.pixelSize: 18 } }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    Text { text: title; color: ink; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                                    Text { text: classNameById(classId) + " · Due " + formatDateTimePretty(dueText); color: muted; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                                                    Text { text: description; color: muted2; font.pixelSize: 11; wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideRight; Layout.fillWidth: true }
                                                }
                                                ActionButton { text: "Open"; kind: "ghost"; onClicked: openAssignment(assignmentId) }
                                            }
                                        }
                                    }
                                }

                                EmptyState {
                                    anchors.centerIn: parent
                                    visible: currentPage === "assignments" && visibleAssignmentsCount() === 0
                                    title: "No assignments available"
                                    subtitle: "Assignments for the selected class will appear here when your teacher adds them."
                                }

                            }
                        }
                    }

                    SectionFrame {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            Text { text: currentAssignmentObject() ? currentAssignmentObject().title : "Assignment details"; color: ink; font.pixelSize: 20; font.weight: Font.DemiBold }
                            RowLayout {
                                Layout.fillWidth: true
                                Badge { visible: currentAssignmentObject() !== null; textValue: currentAssignmentObject() ? classNameById(currentAssignmentObject().classId) : ""; bgColor: currentAssignmentObject() ? classAccentSoftById(currentAssignmentObject().classId) : indigoSoft; fgColor: currentAssignmentObject() ? classAccentById(currentAssignmentObject().classId) : indigo700 }
                                Badge { visible: currentAssignmentObject() !== null; textValue: currentAssignmentObject() && hasStudentSubmission(currentAssignmentObject()) ? "Submitted" : "Not submitted"; bgColor: currentAssignmentObject() && hasStudentSubmission(currentAssignmentObject()) ? blueSoft : amberSoft; fgColor: currentAssignmentObject() && hasStudentSubmission(currentAssignmentObject()) ? blue : amber }
                                Item { Layout.fillWidth: true }
                                Text { text: currentAssignmentObject() ? "Due: " + formatDateTimePretty(currentAssignmentObject().dueText) : ""; color: muted; font.pixelSize: 12 }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                radius: 16
                                color: soft
                                border.width: 1
                                border.color: line
                                implicitHeight: 110
                                Text {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    text: currentAssignmentObject() ? currentAssignmentObject().instructions : "Select an assignment to view the instructions."
                                    color: ink
                                    font.pixelSize: 12
                                    wrapMode: Text.WrapAnywhere
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                ActionButton { text: "Download task file"; kind: "ghost"; enabledState: currentAssignmentObject() && currentAssignmentObject().attachmentPath.length > 0; onClicked: downloadServerFile(currentAssignmentObject().attachmentPath, currentAssignmentObject().attachmentName) }
                                Item { Layout.fillWidth: true }
                                Text { text: currentAssignmentObject() && currentAssignmentObject().attachmentName.length > 0 ? currentAssignmentObject().attachmentName : "No attachment"; color: muted; font.pixelSize: 12; elide: Text.ElideRight }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 18
                                color: cardSoft
                                border.width: 1
                                border.color: line
                                implicitHeight: 378

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 10
                                    Text { text: "Submit this assignment"; color: ink; font.pixelSize: 15; font.weight: Font.DemiBold }
                                    Text { text: "You can submit text, attach a file, or both. At least one of them is required."; color: muted; font.pixelSize: 12; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 132
                                        radius: 14
                                        color: "#FFFFFF"
                                        border.width: 1
                                        border.color: line
                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 8
                                            Text { text: "Submission text"; color: muted; font.pixelSize: 11; font.weight: Font.Medium }
                                            TextArea {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                text: root.pendingSubmissionText
                                                placeholderText: "Write a short answer or note for this submission"
                                                wrapMode: TextEdit.WrapAnywhere
                                                selectByMouse: true
                                                color: ink
                                                font.pixelSize: 12
                                                clip: true
                                                background: Rectangle { color: "transparent" }
                                                onTextChanged: root.pendingSubmissionText = text
                                            }
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 60
                                        radius: 14
                                        color: "#FFFFFF"
                                        border.width: 1
                                        border.color: line
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10
                                            Text { Layout.fillWidth: true; text: pendingSubmissionFileName.length > 0 ? pendingSubmissionFileName : "No file selected"; color: pendingSubmissionFileName.length > 0 ? ink : muted2; font.pixelSize: 12; elide: Text.ElideRight }
                                            ActionButton { Layout.preferredWidth: 112; Layout.topMargin: -2; text: "Browse"; kind: "ghost"; onClicked: uploadDialog.open() }
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 52
                                        radius: 14
                                        color: soft
                                        border.width: 1
                                        border.color: line
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10
                                            Text { Layout.fillWidth: true; text: currentAssignmentObject() && currentAssignmentObject().submissionFileName.length > 0 ? "Current submission: " + currentAssignmentObject().submissionFileName : "No submission uploaded yet"; color: muted; font.pixelSize: 12; elide: Text.ElideRight }
                                            Text { text: currentAssignmentObject() && currentAssignmentObject().submittedAt.length > 0 ? formatDateTimePretty(currentAssignmentObject().submittedAt) : ""; color: muted2; font.pixelSize: 11 }
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 4
                                        spacing: 10
                                        ActionButton { text: currentAssignmentObject() && hasStudentSubmission(currentAssignmentObject()) ? "Replace submission" : "Submit assignment"; onClicked: submitSelectedAssignment() }
                                        ActionButton { text: "Delete submission"; kind: "ghost"; enabledState: currentAssignmentObject() && hasStudentSubmission(currentAssignmentObject()); onClicked: deleteSubmission(currentAssignmentObject().assignmentId) }
                                        ActionButton { text: "Clear"; kind: "ghost"; enabledState: pendingSubmissionFileName.length > 0 || pendingSubmissionText.length > 0; onClicked: { clearSubmissionSelection(); pendingSubmissionText = "" } }
                                    }
                                }
                            }
                        }
                    }
                }

                SectionFrame {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        Text { text: "All my submissions"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 18
                            color: soft
                            border.width: 1
                            border.color: line
                            ListView {
                                anchors.fill: parent
                                anchors.margins: 10
                                clip: true
                                spacing: 0
                                model: assignmentsModel
                                visible: visibleSubmittedAssignmentsCount() > 0
                                ScrollIndicator.vertical: ScrollIndicator { }
                                delegate: Item {
                                    property bool shown: submitted && filterAccepts(root.assignmentFilterClass, classId)
                                    width: ListView.view.width
                                    height: shown ? 94 : 0
                                    visible: shown

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        height: 84
                                        radius: 16
                                        color: "#FFFFFF"
                                        border.width: 1
                                        border.color: line
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12
                                            Badge { textValue: classNameById(classId); bgColor: classAccentSoftById(classId); fgColor: classAccentById(classId) }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text { text: title; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold }
                                                Text { text: submissionFileName + (submittedAt.length > 0 ? " · " + formatDateTimePretty(submittedAt) : ""); color: muted; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                                            }
                                            ActionButton { text: "Open"; kind: "ghost"; onClicked: openSubmission(assignmentId) }
                                        }
                                    }
                                }
                            }

                            EmptyState {
                                anchors.centerIn: parent
                                visible: visibleSubmittedAssignmentsCount() === 0
                                title: "No submissions yet"
                                subtitle: "Once you submit an assignment, it will appear here."
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: materialsPage
        Item {
            ColumnLayout {
                id: materialsColumn
                anchors.fill: parent
                spacing: 16

                PageHeader {
                    title: "Study materials"
                    subtitle: ""
                    iconText: "📚"
                }
                SearchField { label: "Find material"; placeholder: "Search by title, type or description"; text: root.materialSearchText; onTextChanged: root.materialSearchText = text }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    StyledCombo {
                        Layout.preferredWidth: 260
                        label: "Filter by class"
                        model: classNameOptions()
                        currentIndex: Math.max(0, classNameOptions().indexOf(root.materialFilterClass))
                        onCurrentTextChanged: root.materialFilterClass = currentText
                    }
                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 16

                    SectionFrame {
                        Layout.preferredWidth: 420
                        Layout.fillHeight: true
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            Text { text: "Material list"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 18
                                color: soft
                                border.width: 1
                                border.color: line
                                ListView {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    clip: true
                                    spacing: 0
                                    model: materialsModel
                                    visible: visibleMaterialsCount() > 0
                                    ScrollIndicator.vertical: ScrollIndicator { }
                                    delegate: Item {
                                        property bool shown: filterAccepts(root.materialFilterClass, classId) && matchesSearch(title + " " + description + " " + type, root.materialSearchText)
                                        width: ListView.view.width
                                        height: shown ? 104 : 0
                                        visible: shown

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            height: 94
                                            radius: 18
                                            color: selectedMaterialId === materialId ? indigoSoft : "#FFFFFF"
                                            border.width: 1
                                            border.color: selectedMaterialId === materialId ? "#C7D2FE" : line
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 12
                                                Rectangle { width: 46; height: 46; radius: 14; color: classAccentSoftById(classId); border.width: 1; border.color: line; Text { anchors.centerIn: parent; text: type === "Slides" ? "🖥️" : "📄"; font.pixelSize: 18 } }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 3
                                                    Text { text: title; color: ink; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                                    Text { text: classNameById(classId) + " · " + whenText; color: muted; font.pixelSize: 12 }
                                                    Text { text: description; color: muted2; font.pixelSize: 11; wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideRight; Layout.fillWidth: true }
                                                }
                                                ActionButton { text: "Open"; kind: "ghost"; onClicked: openMaterial(materialId) }
                                            }
                                        }
                                    }
                                }

                                EmptyState {
                                    anchors.centerIn: parent
                                    visible: visibleMaterialsCount() === 0
                                    title: "No study materials available"
                                    subtitle: "Materials for the selected class will appear here when your teacher adds them."
                                }
                            }
                        }
                    }

                    SectionFrame {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            Text { text: currentMaterialObject() ? currentMaterialObject().title : "Material details"; color: ink; font.pixelSize: 20; font.weight: Font.DemiBold }
                            RowLayout {
                                Layout.fillWidth: true
                                Badge { visible: currentMaterialObject() !== null; textValue: currentMaterialObject() ? classNameById(currentMaterialObject().classId) : ""; bgColor: currentMaterialObject() ? classAccentSoftById(currentMaterialObject().classId) : indigoSoft; fgColor: currentMaterialObject() ? classAccentById(currentMaterialObject().classId) : indigo700 }
                                Item { Layout.fillWidth: true }
                                Text { text: currentMaterialObject() ? currentMaterialObject().byText + " · " + currentMaterialObject().whenText : ""; color: muted; font.pixelSize: 12 }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                radius: 16
                                color: soft
                                border.width: 1
                                border.color: line
                                implicitHeight: 220
                                Text {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    text: currentMaterialObject() ? materialDetailText(currentMaterialObject()) : "Select a material to read more about it."
                                    color: ink
                                    font.pixelSize: 12
                                    wrapMode: Text.WrapAnywhere
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                ActionButton { text: "Download file"; kind: "ghost"; enabledState: currentMaterialObject() && currentMaterialObject().filePath.length > 0; onClicked: downloadServerFile(currentMaterialObject().filePath, currentMaterialObject().title) }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: gradesPage
        Item {
            ColumnLayout {
                id: gradesColumn
                anchors.fill: parent
                spacing: 16

                PageHeader {
                    title: "Grades"
                    subtitle: ""
                    iconText: "📈"
                }
                SearchField { label: "Find grade"; placeholder: "Search by assignment title or class"; text: root.gradeSearchText; onTextChanged: root.gradeSearchText = text }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    StyledCombo {
                        Layout.preferredWidth: 240
                        label: "Filter by class"
                        model: classNameOptions()
                        currentIndex: Math.max(0, classNameOptions().indexOf(root.gradesFilterClass))
                        onCurrentTextChanged: root.gradesFilterClass = currentText
                    }
                    StyledCombo {
                        Layout.preferredWidth: 180
                        label: "Show"
                        model: ["New grades", "Grade history", "All grades"]
                        currentIndex: root.gradeMode === "new" ? 0 : (root.gradeMode === "history" ? 1 : 2)
                        onCurrentIndexChanged: root.gradeMode = currentIndex === 0 ? "new" : (currentIndex === 1 ? "history" : "all")
                    }
                    Item { Layout.fillWidth: true }
                    Badge { textValue: gradedCount().toString() + " graded tasks"; bgColor: emeraldSoft; fgColor: emerald }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 560
                    spacing: 16

                    SectionFrame {
                        Layout.preferredWidth: 460
                        Layout.fillHeight: true
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            Text { text: root.gradeMode === "new" ? "New grades" : (root.gradeMode === "history" ? "Grade history" : "All grades"); color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 18
                                color: soft
                                border.width: 1
                                border.color: line
                                ListView {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    clip: true
                                    spacing: 10
                                    model: assignmentsModel
                                    visible: visibleGradesCount() > 0
                                    ScrollIndicator.vertical: ScrollIndicator { }
                                    delegate: Rectangle {
                                        property bool shown: finalGrade >= 0 && filterAccepts(root.gradesFilterClass, classId) && (root.gradeMode === "all" || (root.gradeMode === "new" && !gradeRead) || (root.gradeMode === "history" && gradeRead)) && matchesSearch(title + " " + classNameById(classId), root.gradeSearchText)
                                        visible: shown
                                        width: ListView.view.width
                                        height: shown ? 102 : 0
                                        radius: 18
                                        color: selectedAssignmentId === assignmentId ? indigoSoft : "#FFFFFF"
                                        border.width: 1
                                        border.color: selectedAssignmentId === assignmentId ? "#C7D2FE" : line
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12
                                            Rectangle {
                                                width: 52; height: 52; radius: 16
                                                color: !gradeRead ? amberSoft : emeraldSoft
                                                border.width: 1; border.color: line
                                                Text { anchors.centerIn: parent; text: finalGrade >= 90 ? "🌟" : "📄"; font.pixelSize: 19 }
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 3
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8
                                                    Text { text: title; color: ink; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                                    Rectangle { visible: !gradeRead; width: 10; height: 10; radius: 5; color: amber }
                                                }
                                                Text { text: classNameById(classId) + " · Final grade " + finalGrade; color: muted; font.pixelSize: 12 }
                                                Text { text: teacherFeedback.length > 0 ? teacherFeedback : "Teacher feedback is available inside."; color: muted2; font.pixelSize: 11; wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideRight; Layout.fillWidth: true }
                                            }
                                            ActionButton { text: "Open"; kind: "ghost"; onClicked: openGrade(assignmentId) }
                                        }
                                    }
                                }

                                EmptyState {
                                    anchors.centerIn: parent
                                    visible: visibleGradesCount() === 0
                                    title: "No grades available"
                                    subtitle: "Grades for the selected class will appear here once they are published."
                                }
                            }
                        }
                    }

                    SectionFrame {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            Text { text: currentAssignmentObject() && currentAssignmentObject().finalGrade >= 0 ? currentAssignmentObject().title : "Grade details"; color: ink; font.pixelSize: 20; font.weight: Font.DemiBold }
                            RowLayout {
                                Layout.fillWidth: true
                                Badge { visible: currentAssignmentObject() && currentAssignmentObject().finalGrade >= 0; textValue: currentAssignmentObject() ? classNameById(currentAssignmentObject().classId) : ""; bgColor: currentAssignmentObject() ? classAccentSoftById(currentAssignmentObject().classId) : indigoSoft; fgColor: currentAssignmentObject() ? classAccentById(currentAssignmentObject().classId) : indigo700 }
                                Item { Layout.fillWidth: true }
                                Text { text: currentAssignmentObject() && currentAssignmentObject().submittedAt.length > 0 ? "Submitted: " + currentAssignmentObject().submittedAt : ""; color: muted; font.pixelSize: 12 }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 132
                                radius: 20
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#EEF8FF" }
                                    GradientStop { position: 1.0; color: "#FFFFFF" }
                                }
                                border.width: 1
                                border.color: "#D8E6FF"
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 6
                                    Text { text: "Final grade"; color: muted; font.pixelSize: 12 }
                                    Text { text: currentAssignmentObject() && currentAssignmentObject().finalGrade >= 0 ? currentAssignmentObject().finalGrade.toString() : "--"; color: ink; font.pixelSize: 42; font.weight: Font.Bold }
                                    Text { text: currentAssignmentObject() && currentAssignmentObject().finalGrade >= 0 ? "This is the grade visible to the student." : "Select a grade from the list to view the teacher feedback."; color: muted; font.pixelSize: 12; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 18
                                color: soft
                                border.width: 1
                                border.color: line
                                Flickable {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    contentWidth: width
                                    contentHeight: feedbackText.implicitHeight
                                    clip: true
                                    ScrollIndicator.vertical: ScrollIndicator { }
                                    Text {
                                        id: feedbackText
                                        width: parent.width
                                        text: currentAssignmentObject() && currentAssignmentObject().teacherFeedback.length > 0 ? currentAssignmentObject().teacherFeedback : "Teacher feedback will appear here."
                                        color: ink
                                        font.pixelSize: 12
                                        wrapMode: Text.WrapAnywhere
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                ActionButton { text: "Open full view"; onClicked: currentAssignmentObject() && currentAssignmentObject().finalGrade >= 0 ? openGrade(currentAssignmentObject().assignmentId) : null }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: messagesPage
        Item {
            ColumnLayout {
                id: messagesColumn
                anchors.fill: parent
                spacing: 16

                PageHeader {
                    title: "Messages"
                    subtitle: ""
                    iconText: "✉️"
                }
                SearchField { label: "Find message"; placeholder: "Search by subject, sender or content"; text: root.messageSearchText; onTextChanged: root.messageSearchText = text }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    StyledCombo {
                        Layout.preferredWidth: 240
                        label: "Filter by class"
                        model: classNameOptions()
                        currentIndex: Math.max(0, classNameOptions().indexOf(root.messageFilterClass))
                        onCurrentTextChanged: root.messageFilterClass = currentText
                    }
                    StyledCombo {
                        Layout.preferredWidth: 190
                        label: "Show"
                        model: ["New messages", "Earlier messages", "All messages"]
                        currentIndex: root.messageMode === "new" ? 0 : (root.messageMode === "history" ? 1 : 2)
                        onCurrentIndexChanged: root.messageMode = currentIndex === 0 ? "new" : (currentIndex === 1 ? "history" : "all")
                    }
                    Item { Layout.fillWidth: true }
                    ActionButton { text: "Mark all as read"; kind: "ghost"; onClicked: markAllMessagesRead() }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 16

                    SectionFrame {
                        Layout.preferredWidth: 450
                        Layout.fillHeight: true
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            Text { text: "Inbox"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 18
                                color: soft
                                border.width: 1
                                border.color: line
                                ListView {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    clip: true
                                    spacing: 10
                                    model: messagesModel
                                    visible: visibleMessagesCount() > 0
                                    ScrollIndicator.vertical: ScrollIndicator { }
                                    delegate: Rectangle {
                                        property bool shown: filterAccepts(root.messageFilterClass, classId) && (root.messageMode === "all" || (root.messageMode === "new" && !read) || (root.messageMode === "history" && read)) && matchesSearch(subject + " " + fromText + " " + body, root.messageSearchText)
                                        visible: shown
                                        width: ListView.view.width
                                        height: shown ? 104 : 0
                                        radius: 18
                                        color: selectedMessageId === messageId ? indigoSoft : "#FFFFFF"
                                        border.width: 1
                                        border.color: selectedMessageId === messageId ? "#C7D2FE" : line
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12
                                            Rectangle { width: 46; height: 46; radius: 15; color: read ? soft : blueSoft; border.width: 1; border.color: line; Text { anchors.centerIn: parent; text: read ? "📨" : "✉️"; font.pixelSize: 17 }
                                                Rectangle { visible: !read; width: 12; height: 12; radius: 6; color: indigo600; anchors.right: parent.right; anchors.top: parent.top; anchors.rightMargin: 0; anchors.topMargin: 0 } }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 3
                                                Text { text: subject; color: ink; font.pixelSize: 14; font.weight: read ? Font.Medium : Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                                Text { text: fromText + " · " + classNameById(classId); color: muted; font.pixelSize: 12 }
                                                Text { text: body; color: muted2; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                                            }
                                            ActionButton { text: "Open"; kind: "ghost"; onClicked: openMessage(messageId) }
                                        }
                                    }
                                }

                                EmptyState {
                                    anchors.centerIn: parent
                                    visible: visibleMessagesCount() === 0
                                    title: "No messages available"
                                    subtitle: "Messages for the selected class will appear here."
                                }
                            }
                        }
                    }

                    SectionFrame {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            Text { text: currentMessageObject() ? currentMessageObject().subject : "Message details"; color: ink; font.pixelSize: 20; font.weight: Font.DemiBold }
                            RowLayout {
                                Layout.fillWidth: true
                                Badge { visible: currentMessageObject() !== null; textValue: currentMessageObject() ? classNameById(currentMessageObject().classId) : ""; bgColor: currentMessageObject() ? classAccentSoftById(currentMessageObject().classId) : indigoSoft; fgColor: currentMessageObject() ? classAccentById(currentMessageObject().classId) : indigo700 }
                                Item { Layout.fillWidth: true }
                                Text { text: currentMessageObject() ? currentMessageObject().fromText + " · " + currentMessageObject().whenText : ""; color: muted; font.pixelSize: 12 }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 16
                                color: cardSoft
                                border.width: 1
                                border.color: line
                                Text {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    text: currentMessageObject() ? currentMessageObject().body : "Open a message to read it here."
                                    color: ink
                                    font.pixelSize: 12
                                    wrapMode: Text.WrapAnywhere
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: joinPage
        Flickable {
            contentWidth: width
            contentHeight: joinColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator { }

            ColumnLayout {
                id: joinColumn
                width: parent.width
                spacing: 16

                PageHeader {
                    title: "Join a new class"
                    subtitle: ""
                    iconText: "➕"
                }

                SectionFrame {
                    implicitHeight: 250
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        Text { text: "Enter class code"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Text { text: "Paste the class code you received from your teacher."; color: muted; font.pixelSize: 12; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                        StyledTextField { id: joinField; label: "Class code"; text: root.joinCodeText; placeholder: "Type the code"; onTextChanged: root.joinCodeText = text }
                        RowLayout {
                            Layout.fillWidth: true
                            ActionButton { text: "Join class"; onClicked: joinClassByCode() }
                            ActionButton { text: "Clear"; kind: "ghost"; onClicked: joinCodeText = "" }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.busyActive
        z: 20000
        color: "#660F172A"

        MouseArea {
            anchors.fill: parent
            enabled: root.busyActive
        }

        Rectangle {
            width: 280
            height: 116
            radius: 18
            color: card
            border.width: 1
            border.color: line
            anchors.centerIn: parent

            Column {
                anchors.centerIn: parent
                spacing: 10

                BusyIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                    running: root.busyActive
                    width: 40
                    height: 40
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.busyText.length > 0 ? root.busyText : "Please wait..."
                    color: ink
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: detailOverlayVisible
        z: 999
        color: "#7A0F172A"

        MouseArea {
            anchors.fill: parent
            onClicked: detailOverlayVisible = false
        }

        Rectangle {
            width: Math.min(parent.width - 40, 1040)
            height: Math.min(parent.height - 36, 760)
            anchors.centerIn: parent
            radius: 26
            color: "#FFFFFF"
            border.width: 1
            border.color: line
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text {
                        Layout.fillWidth: true
                        text: detailMode === "assignment" ? "Assignment details" :
                              detailMode === "submission" ? "Submission details" :
                              detailMode === "material" ? "Study material" :
                              detailMode === "message" ? "Message" :
                              detailMode === "grade" ? "Grade details" : "Details"
                        color: ink
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                    }
                    ActionButton { text: "Close"; kind: "ghost"; onClicked: detailOverlayVisible = false }
                }

                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: detailMode === "assignment" ? assignmentOverlayContent :
                                     detailMode === "submission" ? submissionOverlayContent :
                                     detailMode === "material" ? materialOverlayContent :
                                     detailMode === "message" ? messageOverlayContent :
                                     gradeOverlayContent
                }
            }
        }
    }

    Component {
        id: assignmentOverlayContent
        Flickable {
            contentWidth: width
            contentHeight: assignmentOverlayColumn.implicitHeight
            clip: true
            ScrollIndicator.vertical: ScrollIndicator { }
            ColumnLayout {
                id: assignmentOverlayColumn
                width: parent.width
                spacing: 14
                Text { text: currentAssignmentObject() ? currentAssignmentObject().title : ""; color: ink; font.pixelSize: 20; font.weight: Font.DemiBold }
                RowLayout {
                    Layout.fillWidth: true
                    Badge { visible: currentAssignmentObject() !== null; textValue: currentAssignmentObject() ? classNameById(currentAssignmentObject().classId) : ""; bgColor: currentAssignmentObject() ? classAccentSoftById(currentAssignmentObject().classId) : indigoSoft; fgColor: currentAssignmentObject() ? classAccentById(currentAssignmentObject().classId) : indigo700 }
                    Badge { visible: currentAssignmentObject() !== null; textValue: currentAssignmentObject() && hasStudentSubmission(currentAssignmentObject()) ? "Submitted" : "Not submitted"; bgColor: currentAssignmentObject() && hasStudentSubmission(currentAssignmentObject()) ? blueSoft : amberSoft; fgColor: currentAssignmentObject() && hasStudentSubmission(currentAssignmentObject()) ? blue : amber }
                    Item { Layout.fillWidth: true }
                    Text { text: currentAssignmentObject() ? "Due: " + formatDateTimePretty(currentAssignmentObject().dueText) : ""; color: muted; font.pixelSize: 12 }
                }
                Rectangle {
                    Layout.fillWidth: true
                    radius: 18
                    color: "#F8FAFC"
                    border.width: 1
                    border.color: line
                    implicitHeight: 190
                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 14
                        contentWidth: width
                        contentHeight: assignmentInstructions.implicitHeight
                        clip: true
                        ScrollIndicator.vertical: ScrollIndicator { }
                        Text {
                            id: assignmentInstructions
                            width: parent.width
                            text: currentAssignmentObject() ? currentAssignmentObject().instructions : ""
                            color: ink
                            font.pixelSize: 12
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    radius: 16
                    color: cardSoft
                    border.width: 1
                    border.color: line
                    implicitHeight: 66
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12
                        Text { Layout.fillWidth: true; text: currentAssignmentObject() && currentAssignmentObject().attachmentName.length > 0 ? currentAssignmentObject().attachmentName : "No task attachment"; color: muted; font.pixelSize: 12; elide: Text.ElideRight }
                        ActionButton { text: "Download task file"; kind: "ghost"; enabledState: currentAssignmentObject() && currentAssignmentObject().attachmentPath.length > 0; onClicked: downloadServerFile(currentAssignmentObject().attachmentPath, currentAssignmentObject().attachmentName) }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    radius: 20
                    color: "#F8FBFF"
                    border.width: 1
                    border.color: "#D9E7FF"
                    implicitHeight: 404
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10
                        Text { text: "Submit this assignment"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Text { text: "You can submit text, attach a file, or both. At least one of them is required."; color: muted; font.pixelSize: 12; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 132
                            radius: 14
                            color: "#FFFFFF"
                            border.width: 1
                            border.color: line
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8
                                Text { text: "Submission text"; color: muted; font.pixelSize: 11; font.weight: Font.Medium }
                                TextArea {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    text: root.pendingSubmissionText
                                    placeholderText: "Write a short answer or note for this submission"
                                    wrapMode: TextEdit.WrapAnywhere
                                    selectByMouse: true
                                    color: ink
                                    font.pixelSize: 12
                                    clip: true
                                    background: Rectangle { color: "transparent" }
                                    onTextChanged: root.pendingSubmissionText = text
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 60
                            radius: 14
                            color: "#FFFFFF"
                            border.width: 1
                            border.color: line
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10
                                Text { Layout.fillWidth: true; text: pendingSubmissionFileName.length > 0 ? pendingSubmissionFileName : "No file selected"; color: pendingSubmissionFileName.length > 0 ? ink : muted2; font.pixelSize: 12; elide: Text.ElideRight }
                                ActionButton { Layout.preferredWidth: 112; Layout.topMargin: -2; text: "Browse"; kind: "ghost"; onClicked: uploadDialog.open() }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 52
                            radius: 14
                            color: soft
                            border.width: 1
                            border.color: line
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10
                                Text { Layout.fillWidth: true; text: currentAssignmentObject() && currentAssignmentObject().submissionFileName.length > 0 ? "Current submission: " + currentAssignmentObject().submissionFileName : "No submission uploaded yet"; color: muted; font.pixelSize: 12; elide: Text.ElideRight }
                                Text { text: currentAssignmentObject() && currentAssignmentObject().submittedAt.length > 0 ? currentAssignmentObject().submittedAt : ""; color: muted2; font.pixelSize: 11 }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            ActionButton { text: currentAssignmentObject() && hasStudentSubmission(currentAssignmentObject()) ? "Replace submission" : "Submit assignment"; onClicked: submitSelectedAssignment() }
                            ActionButton { text: "Delete submission"; kind: "ghost"; enabledState: currentAssignmentObject() && hasStudentSubmission(currentAssignmentObject()); onClicked: deleteSubmission(currentAssignmentObject().assignmentId) }
                            ActionButton { text: "Clear"; kind: "ghost"; enabledState: pendingSubmissionFileName.length > 0 || pendingSubmissionText.length > 0; onClicked: { clearSubmissionSelection(); pendingSubmissionText = "" } }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: submissionOverlayContent
        Flickable {
            contentWidth: width
            contentHeight: submissionOverlayColumn.implicitHeight
            clip: true
            ScrollIndicator.vertical: ScrollIndicator { }
            ColumnLayout {
                id: submissionOverlayColumn
                width: parent.width
                spacing: 14
                Text { text: currentAssignmentObject() ? currentAssignmentObject().title : ""; color: ink; font.pixelSize: 20; font.weight: Font.DemiBold }
                Badge { visible: currentAssignmentObject() !== null; textValue: currentAssignmentObject() ? classNameById(currentAssignmentObject().classId) : ""; bgColor: currentAssignmentObject() ? classAccentSoftById(currentAssignmentObject().classId) : indigoSoft; fgColor: currentAssignmentObject() ? classAccentById(currentAssignmentObject().classId) : indigo700 }
                Rectangle {
                    Layout.fillWidth: true
                    radius: 18
                    color: "#F8FAFC"
                    border.width: 1
                    border.color: line
                    implicitHeight: 210
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10
                        Text { text: "Submission summary"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }
                        KeyValueRow { label: "Submitted file"; value: currentAssignmentObject() ? (currentAssignmentObject().submissionFileName.length > 0 ? currentAssignmentObject().submissionFileName : "No file") : "" }
                        KeyValueRow { label: "Submitted at"; value: currentAssignmentObject() ? (currentAssignmentObject().submittedAt.length > 0 ? currentAssignmentObject().submittedAt : "-") : "" }
                        KeyValueRow { label: "Due date"; value: currentAssignmentObject() ? formatDateTimePretty(currentAssignmentObject().dueText) : "" }
                        KeyValueRow { label: "Status"; value: currentAssignmentObject() && hasStudentSubmission(currentAssignmentObject()) ? "Submitted" : "Not submitted" }
                        KeyValueRow { label: "Text"; value: currentAssignmentObject() && currentAssignmentObject().submissionText.length > 0 ? currentAssignmentObject().submissionText : "No submission text" }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    radius: 18
                    color: cardSoft
                    border.width: 1
                    border.color: line
                    implicitHeight: 150
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8
                        Text { text: "Actions"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Text { text: "Download the file you submitted, replace it, or remove the submission entirely."; color: muted; font.pixelSize: 12; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                        RowLayout {
                            Layout.fillWidth: true
                            ActionButton { text: "Download my file"; kind: "ghost"; enabledState: currentAssignmentObject() && currentAssignmentObject().submissionPath.length > 0; onClicked: downloadServerFile(currentAssignmentObject().submissionPath, currentAssignmentObject().submissionFileName) }
                            ActionButton { text: "Replace submission"; onClicked: { detailMode = "assignment"; } }
                            ActionButton { text: "Delete submission"; kind: "ghost"; enabledState: currentAssignmentObject() && hasStudentSubmission(currentAssignmentObject()); onClicked: deleteSubmission(currentAssignmentObject().assignmentId) }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: materialOverlayContent
        Flickable {
            contentWidth: width
            contentHeight: materialOverlayColumn.implicitHeight
            clip: true
            ScrollIndicator.vertical: ScrollIndicator { }
            ColumnLayout {
                id: materialOverlayColumn
                width: parent.width
                spacing: 14
                Text { text: currentMaterialObject() ? currentMaterialObject().title : ""; color: ink; font.pixelSize: 20; font.weight: Font.DemiBold }
                RowLayout {
                    Layout.fillWidth: true
                    Badge { visible: currentMaterialObject() !== null; textValue: currentMaterialObject() ? classNameById(currentMaterialObject().classId) : ""; bgColor: currentMaterialObject() ? classAccentSoftById(currentMaterialObject().classId) : indigoSoft; fgColor: currentMaterialObject() ? classAccentById(currentMaterialObject().classId) : indigo700 }
                    Item { Layout.fillWidth: true }
                    Text { text: currentMaterialObject() ? currentMaterialObject().byText + " · " + currentMaterialObject().whenText : ""; color: muted; font.pixelSize: 12 }
                }
                Rectangle {
                    Layout.fillWidth: true
                    radius: 18
                    color: "#F8FAFC"
                    border.width: 1
                    border.color: line
                    implicitHeight: 240
                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 14
                        contentWidth: width
                        contentHeight: materialOverlayText.implicitHeight
                        clip: true
                        ScrollIndicator.vertical: ScrollIndicator { }
                        Text {
                            id: materialOverlayText
                            width: parent.width
                            text: materialDetailText(currentMaterialObject())
                            color: ink
                            font.pixelSize: 12
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    ActionButton { text: "Download file"; kind: "ghost"; enabledState: currentMaterialObject() && currentMaterialObject().filePath.length > 0; onClicked: downloadServerFile(currentMaterialObject().filePath, currentMaterialObject().title) }
                }
            }
        }
    }

    Component {
        id: messageOverlayContent
        Flickable {
            contentWidth: width
            contentHeight: messageOverlayColumn.implicitHeight
            clip: true
            ScrollIndicator.vertical: ScrollIndicator { }
            ColumnLayout {
                id: messageOverlayColumn
                width: parent.width
                spacing: 14
                Text { text: currentMessageObject() ? currentMessageObject().subject : ""; color: ink; font.pixelSize: 20; font.weight: Font.DemiBold }
                RowLayout {
                    Layout.fillWidth: true
                    Badge { visible: currentMessageObject() !== null; textValue: currentMessageObject() ? classNameById(currentMessageObject().classId) : ""; bgColor: currentMessageObject() ? classAccentSoftById(currentMessageObject().classId) : indigoSoft; fgColor: currentMessageObject() ? classAccentById(currentMessageObject().classId) : indigo700 }
                    Item { Layout.fillWidth: true }
                    Text { text: currentMessageObject() ? currentMessageObject().fromText + " · " + currentMessageObject().whenText : ""; color: muted; font.pixelSize: 12 }
                }
                Rectangle {
                    Layout.fillWidth: true
                    radius: 18
                    color: "#F8FAFC"
                    border.width: 1
                    border.color: line
                    implicitHeight: 320
                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 14
                        contentWidth: width
                        contentHeight: messageOverlayText.implicitHeight
                        clip: true
                        ScrollIndicator.vertical: ScrollIndicator { }
                        Text {
                            id: messageOverlayText
                            width: parent.width
                            text: currentMessageObject() ? currentMessageObject().body : ""
                            color: ink
                            font.pixelSize: 12
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }
        }
    }

    Component {
        id: gradeOverlayContent
        Flickable {
            contentWidth: width
            contentHeight: gradeOverlayColumn.implicitHeight
            clip: true
            ScrollIndicator.vertical: ScrollIndicator { }
            ColumnLayout {
                id: gradeOverlayColumn
                width: parent.width
                spacing: 14
                Text { text: currentAssignmentObject() ? currentAssignmentObject().title : ""; color: ink; font.pixelSize: 20; font.weight: Font.DemiBold }
                RowLayout {
                    Layout.fillWidth: true
                    Badge { visible: currentAssignmentObject() !== null; textValue: currentAssignmentObject() ? classNameById(currentAssignmentObject().classId) : ""; bgColor: currentAssignmentObject() ? classAccentSoftById(currentAssignmentObject().classId) : indigoSoft; fgColor: currentAssignmentObject() ? classAccentById(currentAssignmentObject().classId) : indigo700 }
                    Item { Layout.fillWidth: true }
                    Text { text: currentAssignmentObject() && currentAssignmentObject().submittedAt.length > 0 ? "Submitted: " + currentAssignmentObject().submittedAt : ""; color: muted; font.pixelSize: 12 }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 142
                    radius: 20
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#EEF8FF" }
                        GradientStop { position: 1.0; color: "#FFFFFF" }
                    }
                    border.width: 1
                    border.color: "#D8E6FF"
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 4
                        Text { text: "Final grade"; color: muted; font.pixelSize: 12 }
                        Text { text: currentAssignmentObject() && currentAssignmentObject().finalGrade >= 0 ? currentAssignmentObject().finalGrade.toString() : "--"; color: ink; font.pixelSize: 46; font.weight: Font.Bold }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    radius: 18
                    color: "#F8FAFC"
                    border.width: 1
                    border.color: line
                    implicitHeight: 260
                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 14
                        contentWidth: width
                        contentHeight: gradeOverlayText.implicitHeight
                        clip: true
                        ScrollIndicator.vertical: ScrollIndicator { }
                        Text {
                            id: gradeOverlayText
                            width: parent.width
                            text: currentAssignmentObject() ? currentAssignmentObject().teacherFeedback : ""
                            color: ink
                            font.pixelSize: 12
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }
        }
    }

    component KeyValueRow : RowLayout {
        property string label: ""
        property string value: ""
        Layout.fillWidth: true
        spacing: 10
        Text { text: label; color: muted; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.preferredWidth: 110 }
        Text { text: value; color: ink; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere }
    }

    component StyledTextField : Item {
        property string label: ""
        property alias text: field.text
        property string placeholder: ""
        implicitHeight: 76
        Layout.fillWidth: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 6
            Text { text: label; color: muted; font.pixelSize: 12; font.weight: Font.Medium }
            TextField {
                id: field
                Layout.fillWidth: true
                placeholderText: placeholder
                selectByMouse: true
                implicitHeight: 42
                color: ink
                selectedTextColor: "#FFFFFF"
                selectionColor: indigo600
                background: Rectangle { radius: 12; color: "#F8FAFC"; border.width: 1; border.color: field.activeFocus ? indigo600 : line }
            }
        }
    }
}
