import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects 1.0
import QtQuick.Dialogs

Item {
    id: root
    anchors.fill: parent

    property string userName: "Teacher"
    property string role: "TEACHER"
    property int userId: -1
    property int schoolId: 1
    property var nav

    property string currentPage: "dashboard"
    property int nextClassId: 4
    property int nextAssignmentId: 302
    property int nextStudentId: 7
    property int nextMaterialId: 5
    property int nextGradeId: 5
    property int nextSubmissionId: 3
    property int nextMessageId: 1

    property int messageTargetClassId: 1
    property string messageSubject: ""
    property string messageBody: ""

    property int createAssignmentClassId: 1
    property string createAssignmentTitle: ""
    property string createAssignmentDescription: ""
    property string createAssignmentDue: ""
    property bool createAssignmentAi: true

    property int materialsTargetClassId: 1
    property string materialTitle: ""
    property string materialType: "NO FILE"
    property string materialBy: "Teacher upload"
    property string materialDescription: ""
    property int selectedMaterialId: -1
    property string selectedMaterialTitle: ""
    property string selectedMaterialMeta: ""
    property string selectedMaterialDescription: ""
    property string selectedMaterialPath: ""

    property string newClassName: ""
    property string newClassDescription: ""

    property int studentsClassId: 1
    property int submissionsClassId: 1
    property int submissionsAssignmentId: 102
    property int selectedSubmissionId: -1
    property string reviewTeacherNote: ""
    property string reviewFinalGrade: ""
    property string assignmentAttachmentName: ""
    property string assignmentAttachmentPath: ""
    property string materialFileName: ""
    property string materialFilePath: ""
    property string selectedSubmissionPreview: ""
    property string selectedSubmissionFileName: ""
    property string fileDialogTarget: ""

    property int gradesClassId: 1
    property int gradesAssignmentId: 102
    property int selectedGradeId: -1
    property string gradeEditValue: ""
    property var schoolUsersData: []
    property string backendStatusText: ""
    property bool backendStatusIsError: false
    property string busyText: ""
    property bool busyActive: false
    property string lastDownloadedPath: ""
    property string classSearchText: ""
    property string assignmentSearchText: ""
    property string studentSearchText: ""
    property string materialSearchText: ""
    property string messageSearchText: ""
    property string submissionSearchText: ""
    property int dueYear: new Date().getFullYear()
    property int dueMonth: new Date().getMonth() + 1
    property int dueDay: new Date().getDate()
    property int dueHour: 23
    property int dueMinute: 59

    onUserIdChanged: if (userId > 0) refreshTeacherData()
    onSchoolIdChanged: if (userId > 0) refreshTeacherData()
    onStudentsClassIdChanged: {
        resetScrollViewPosition(studentsActiveScroll)
        resetScrollViewPosition(studentsPendingScroll)
        refreshClassData(studentsClassId)
    }
    onSubmissionsClassIdChanged: {
        submissionsAssignmentId = -1
        submissionSearchText = ""
        selectedSubmissionId = -1
        reviewTeacherNote = ""
        reviewFinalGrade = ""
        resetScrollViewPosition(submissionsListScroll)
        refreshClassData(submissionsClassId)
    }
    onGradesClassIdChanged: refreshClassData(gradesClassId)
    onSubmissionsAssignmentIdChanged: {
        resetScrollViewPosition(submissionsListScroll)
        if (submissionsAssignmentId > 0)
            auth.get_submissions_for_assignment(submissionsAssignmentId)
    }
    onGradesAssignmentIdChanged: if (gradesAssignmentId > 0) auth.get_submissions_for_assignment(gradesAssignmentId)

    signal backendActionRequested(string actionName, string payloadText)

    function backendValueToText(value) {
        if (value === undefined)
            return "undefined"
        if (value === null)
            return "null"
        if (typeof value === "string")
            return value
        if (typeof value === "number" || typeof value === "boolean")
            return value.toString()
        return "" + value
    }

    function hasHebrewText(value) {
        return /[\u0590-\u05FF]/.test(value ? value.toString() : "")
    }

    function rtlWrappedText(value) {
        var text = value ? value.toString() : ""
        if (!hasHebrewText(text))
            return text
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].trim().length > 0)
                lines[i] = "\u202B" + lines[i] + "\u202C"
        }
        return lines.join("\n")
    }

    function backendPayloadToText(payload) {
        if (payload === undefined)
            return ""
        if (payload === null)
            return "null"
        if (typeof payload === "string")
            return payload
        if (typeof payload === "number" || typeof payload === "boolean")
            return payload.toString()

        var parts = []
        for (var key in payload)
            parts.push(key + ": " + backendValueToText(payload[key]))
        return "{ " + parts.join(", ") + " }"
    }

    function backendStub(actionName, payload) {
        var payloadText = backendPayloadToText(payload)
        backendActionRequested(actionName, payloadText)
    }


    function setStatus(messageText, isError) {
        backendStatusText = messageText
        backendStatusIsError = isError === true
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

    function clearAssignmentAttachment() {
        assignmentAttachmentName = ""
        assignmentAttachmentPath = ""
    }

    function clearMaterialAttachment() {
        materialFileName = ""
        materialFilePath = ""
        materialType = "NO FILE"
    }

    function resetScrollViewPosition(view) {
        if (!view)
            return

        function applyReset() {
            if (view.contentItem) {
                view.contentItem.contentY = 0
                view.contentItem.contentX = 0
            }
        }

        applyReset()
        Qt.callLater(applyReset)
    }

    function refreshCurrentPageData() {
        var pageBeforeRefresh = currentPage
        refreshTeacherData()
        if (pageBeforeRefresh === "assignments" && createAssignmentClassId > 0)
            refreshClassData(createAssignmentClassId)
        else if (pageBeforeRefresh === "students" && studentsClassId > 0)
            refreshClassData(studentsClassId)
        else if (pageBeforeRefresh === "materials" && materialsTargetClassId > 0)
            refreshClassData(materialsTargetClassId)
        else if (pageBeforeRefresh === "submissions" && submissionsClassId > 0)
            refreshClassData(submissionsClassId)
        else if (pageBeforeRefresh === "grades" && gradesClassId > 0)
            refreshClassData(gradesClassId)
        else if (pageBeforeRefresh === "messages" && messageTargetClassId > 0)
            refreshClassData(messageTargetClassId)
    }

    function downloadServerFile(filePath, labelText) {
        if (!filePath || filePath.length === 0) {
            setStatus(labelText + " is not available for download", true)
            return
        }
        lastDownloadedPath = filePath
        beginBusy("Downloading " + labelText + "...")
        auth.download_file(filePath)
    }

    function clearListModel(model) {
        while (model.count > 0)
            model.remove(model.count - 1)
    }

    function removeRowsByField(model, fieldName, fieldValue) {
        for (var i = model.count - 1; i >= 0; i--) {
            var row = model.get(i)
            if (row[fieldName] === fieldValue)
                model.remove(i)
        }
    }

    function removeRowsByAssignment(assignmentId) {
        removeRowsByField(submissionsModel, "assignmentId", assignmentId)
        removeRowsByField(gradesModel, "assignmentId", assignmentId)
    }

    function assignmentClassId(assignmentId) {
        for (var i = 0; i < assignmentsModel.count; i++) {
            var a = assignmentsModel.get(i)
            if (a.assignmentId === assignmentId)
                return a.classId
        }
        return -1
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
            return ""
        var txt = (("" + value).replace("T", " ")).trim()
        var parts = txt.split(" ")
        var datePart = parts.length > 0 ? parts[0] : ""
        var timePart = parts.length >= 2 && parts[1].length > 0 ? parts[1] : "00:00"
        var dateParts = datePart.split("-")
        if (dateParts.length === 3)
            return dateParts[2] + "/" + dateParts[1] + "/" + dateParts[0] + "  " + timePart.slice(0, 5)
        return txt
    }

    function formatBytes(sizeBytes) {
        var size = Number(sizeBytes)
        if (!isFinite(size) || size <= 0)
            return "0 B"
        var units = ["B", "KB", "MB", "GB"]
        var unitIndex = 0
        while (size >= 1024 && unitIndex < units.length - 1) {
            size /= 1024
            unitIndex += 1
        }
        return (unitIndex === 0 ? Math.round(size).toString() : size.toFixed(1)) + " " + units[unitIndex]
    }

    function inferMaterialTypeFromPath(pathText) {
        var name = fileNameFromPath(pathText).toLowerCase()
        if (name.endsWith(".pdf"))
            return "PDF"
        if (name.endsWith(".ppt") || name.endsWith(".pptx") || name.endsWith(".key"))
            return "Slides"
        if (name.endsWith(".doc") || name.endsWith(".docx") || name.endsWith(".rtf") || name.endsWith(".txt"))
            return "DOCX"
        if (name.endsWith(".jpg") || name.endsWith(".jpeg") || name.endsWith(".png") || name.endsWith(".gif") || name.endsWith(".webp"))
            return "Image"
        if (name.endsWith(".mp4") || name.endsWith(".mov") || name.endsWith(".avi"))
            return "Video"
        return "FILE"
    }

    function pad2(value) {
        return value < 10 ? ("0" + value) : ("" + value)
    }

    function refreshCreateAssignmentDue() {
        createAssignmentDue = dueYear + "-" + pad2(dueMonth) + "-" + pad2(dueDay) + " " + pad2(dueHour) + ":" + pad2(dueMinute)
    }

    function selectedCreateAssignmentDueDate() {
        return new Date(dueYear, dueMonth - 1, dueDay, dueHour, dueMinute, 0, 0)
    }

    function isCreateAssignmentDueValid() {
        var due = selectedCreateAssignmentDueDate()
        return !isNaN(due.getTime()) && due.getTime() > new Date().getTime()
    }

    function matchesSearch(haystack, needle) {
        if (!needle || needle.trim().length === 0)
            return true
        return ("" + haystack).toLowerCase().indexOf(needle.trim().toLowerCase()) >= 0
    }

    function normalizeGradeInput(value) {
        var txt = ("" + value).replace(/[^0-9]/g, "")
        if (txt.length === 0)
            return ""
        var num = parseInt(txt, 10)
        if (isNaN(num))
            return ""
        if (num < 0)
            num = 0
        if (num > 100)
            num = 100
        return num.toString()
    }

    function isValidGradeValue(value) {
        if (("" + value).trim().length === 0)
            return false
        var num = parseInt(value, 10)
        return !isNaN(num) && num >= 0 && num <= 100
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

    function refreshTeacherData() {
        if (userId <= 0)
            return

        clearListModel(classesModel)
        clearListModel(assignmentsModel)
        clearListModel(studentsModel)
        clearListModel(pendingStudentsModel)
        clearListModel(materialsModel)
        clearListModel(gradesModel)
        clearListModel(submissionsModel)
        clearListModel(messageLogModel)

        auth.get_teacher_courses(userId)
        if (schoolId > 0)
            auth.getUsers(schoolId)
    }

    function refreshClassData(classId) {
        if (classId <= 0)
            return
        auth.get_course_assignments(classId)
        auth.get_course_students(classId)
        auth.get_course_materials(classId)
        auth.get_course_messages(classId)
    }

    readonly property color bg: "#F6F7FB"
    readonly property color card: "#FFFFFF"
    readonly property color soft: "#FBFCFF"
    readonly property color ink: "#0F172A"
    readonly property color muted: "#64748B"
    readonly property color muted2: "#94A3B8"
    readonly property color line: "#E5E7EB"
    readonly property color indigo600: "#4F46E5"
    readonly property color indigo700: "#4338CA"
    readonly property color green: "#16A34A"
    readonly property color greenSoft: "#DCFCE7"
    readonly property color red: "#DC2626"
    readonly property color redSoft: "#FEE2E2"
    readonly property color amber: "#D97706"
    readonly property color amberSoft: "#FEF3C7"
    readonly property color blue: "#2563EB"
    readonly property color blueSoft: "#DBEAFE"
    readonly property color violetSoft: "#EDE9FE"

    ListModel {
        id: classesModel
    }

    ListModel {
        id: assignmentsModel
    }

    ListModel {
        id: studentsModel
    }

    ListModel {
        id: pendingStudentsModel
    }

    ListModel {
        id: materialsModel

    }

    ListModel {
        id: gradesModel

    }

    ListModel {
        id: submissionsModel

        }

    ListModel {
        id: messageLogModel
    }

    function openPage(pageKey) {
        currentPage = pageKey
    }

    function classNameById(classId) {
        for (var i = 0; i < classesModel.count; i++) {
            var c = classesModel.get(i)
            if (c.classId === classId)
                return c.name
        }
        return "Unknown class"
    }

    function classIndexById(classId) {
        for (var i = 0; i < classesModel.count; i++)
            if (classesModel.get(i).classId === classId)
                return i
        return -1
    }

    function countAssignmentsByClass(classId) {
        var count = 0
        for (var i = 0; i < assignmentsModel.count; i++)
            if (assignmentsModel.get(i).classId === classId)
                count++
        return count
    }

    function countOpenAssignmentsByClass(classId) {
        var count = 0
        for (var i = 0; i < assignmentsModel.count; i++) {
            var a = assignmentsModel.get(i)
            if (a.classId === classId && a.status === "Open")
                count++
        }
        return count
    }

    function countMaterialsByClass(classId) {
        var count = 0
        for (var i = 0; i < materialsModel.count; i++)
            if (materialsModel.get(i).classId === classId)
                count++
        return count
    }

    function countStudentsByClass(classId) {
        var count = 0
        for (var i = 0; i < studentsModel.count; i++)
            if (studentsModel.get(i).classId === classId)
                count++
        return count
    }

    function totalStudentsAll() {
        var sum = 0
        for (var i = 0; i < classesModel.count; i++)
            sum += classesModel.get(i).students
        return sum
    }

    function countOpenAssignments() {
        var count = 0
        for (var i = 0; i < assignmentsModel.count; i++)
            if (assignmentsModel.get(i).status === "Open")
                count++
        return count
    }

    function averageAcrossClasses() {
        var sum = 0
        var count = 0
        for (var i = 0; i < gradesModel.count; i++) {
            var g = gradesModel.get(i)
            if (g.finalGrade !== undefined && g.finalGrade !== null && !isNaN(g.finalGrade)) {
                sum += Number(g.finalGrade)
                count += 1
            }
        }
        return count > 0 ? Math.round(sum / count) : 0
    }
    function countUnreviewedGrades() {
    var count = 0
    for (var i = 0; i < gradesModel.count; i++) {
        if (!gradesModel.get(i).reviewed)
            count++
    }
    return count
    }

    function countAiEnabledAssignments() {
        var count = 0
        for (var i = 0; i < assignmentsModel.count; i++) {
            if (assignmentsModel.get(i).aiEnabled)
                count++
        }
        return count
    }

    function topClassByAverage() {
        if (classesModel.count === 0)
            return null

        var best = classesModel.get(0)
        for (var i = 1; i < classesModel.count; i++) {
            var c = classesModel.get(i)
            if (c.average > best.average)
                best = c
        }
        return best
    }

    function busiestClassByOpenAssignments() {
        if (classesModel.count === 0)
            return null

        var busiest = classesModel.get(0)
        for (var i = 1; i < classesModel.count; i++) {
            var c = classesModel.get(i)
            if (c.openAssignments > busiest.openAssignments)
                busiest = c
        }
        return busiest
    }

    function statusColor(status) {
        return status === "Closed" || status === "Inactive" ? red : green
    }

    function statusBg(status) {
        return status === "Closed" || status === "Inactive" ? redSoft : greenSoft
    }

    function studentRowsForClass(classId) {
        var rows = []
        for (var i = 0; i < studentsModel.count; i++) {
            var s = studentsModel.get(i)
            if (classId <= 0 || s.classId === classId)
                rows.push({
                    studentId: s.studentId,
                    classId: s.classId,
                    className: classNameById(s.classId),
                    name: s.name,
                    status: s.status,
                    grade: s.grade,
                    lastSubmission: s.lastSubmission
                })
        }
        return rows
    }

    function assignmentRowsForClass(classId) {
        var rows = []
        for (var i = 0; i < assignmentsModel.count; i++) {
            var a = assignmentsModel.get(i)
            if (classId <= 0 || a.classId === classId)
                rows.push({
                    assignmentId: a.assignmentId,
                    classId: a.classId,
                    className: classNameById(a.classId),
                    title: a.title,
                    description: a.description,
                    dueText: a.dueText,
                    status: a.status,
                    submissions: a.submissions,
                    totalStudents: a.totalStudents,
                    aiEnabled: a.aiEnabled,
                    materialCount: a.materialCount
                })
        }
        return rows
    }

    function materialRowsForClass(classId) {
        var rows = []
        for (var i = 0; i < materialsModel.count; i++) {
            var m = materialsModel.get(i)
            if (classId <= 0 || m.classId === classId)
                rows.push({ materialId: m.materialId, classId: m.classId, className: classNameById(m.classId), type: m.type, title: m.title, by: m.by, whenText: formatDateTimePretty(m.whenText) })
        }
        return rows
    }

    function assignmentOptionsForClass(classId) {
        var rows = []
        for (var i = 0; i < assignmentsModel.count; i++) {
            var a = assignmentsModel.get(i)
            if (classId <= 0 || a.classId === classId)
                rows.push({ assignmentId: a.assignmentId, name: a.title })
        }
        return rows
    }

    function firstAssignmentIdForClass(classId) {
        for (var i = 0; i < assignmentsModel.count; i++)
            if (classId <= 0 || assignmentsModel.get(i).classId === classId)
                return assignmentsModel.get(i).assignmentId
        return -1
    }

    function assignmentIndexForClassAndId(classId, assignmentId) {
        var rows = assignmentOptionsForClass(classId)
        if (!rows || rows.length === 0 || assignmentId <= 0)
            return -1
        for (var i = 0; i < rows.length; i++)
            if (rows[i].assignmentId === assignmentId)
                return i
        return -1
    }

    function gradeRowsForSelection(classId, assignmentId) {
        var rows = []
        for (var i = 0; i < gradesModel.count; i++) {
            var g = gradesModel.get(i)
            if ((classId <= 0 || g.classId === classId) && (assignmentId <= 0 || g.assignmentId === assignmentId))
                rows.push({ gradeId: g.gradeId, classId: g.classId, className: classNameById(g.classId), assignmentId: g.assignmentId, student: g.student, finalGrade: g.finalGrade, aiGrade: g.aiGrade, reviewed: g.reviewed })
        }
        return rows
    }

    function submissionRowsForSelection(classId, assignmentId) {
        var rows = []
        for (var i = 0; i < submissionsModel.count; i++) {
            var s = submissionsModel.get(i)
            if ((classId <= 0 || s.classId === classId) && (assignmentId <= 0 || s.assignmentId === assignmentId))
                rows.push({ submissionId: s.submissionId, classId: s.classId, className: classNameById(s.classId), assignmentId: s.assignmentId, student: s.student, submittedAt: s.submittedAt, aiGrade: s.aiGrade, finalGrade: s.finalGrade, aiEnabled: s.aiEnabled, teacherEdited: s.teacherEdited, aiText: s.aiText, teacherText: s.teacherText, fileName: s.fileName })
        }
        return rows
    }

    function messageRows() {
        var rows = []
        for (var i = messageLogModel.count - 1; i >= 0; i--) {
            var m = messageLogModel.get(i)
            rows.push({ messageId: m.messageId, classId: m.classId, className: classNameById(m.classId), subject: m.subject, body: m.body, state: m.state, createdAt: m.createdAt, createdAtPretty: formatDateTimePretty(m.createdAt) })
        }
        return rows
    }

    function firstSubmissionIdForClass(classId) {
        for (var i = 0; i < submissionsModel.count; i++)
            if (submissionsModel.get(i).classId === classId)
                return submissionsModel.get(i).submissionId
        return -1
    }

    function assignmentAiEnabled(assignmentId) {
        for (var i = 0; i < assignmentsModel.count; i++) {
            var a = assignmentsModel.get(i)
            if (a.assignmentId === assignmentId)
                return a.aiEnabled === true
        }
        return true
    }

    function submissionById(submissionId) {
        for (var i = 0; i < submissionsModel.count; i++) {
            var s = submissionsModel.get(i)
            if (s.submissionId === submissionId)
                return s
        }
        return null
    }

    function gradeById(gradeId) {
        for (var i = 0; i < gradesModel.count; i++) {
            var g = gradesModel.get(i)
            if (g.gradeId === gradeId)
                return g
        }
        return null
    }

    function submissionIndexById(submissionId) {
        for (var i = 0; i < submissionsModel.count; i++)
            if (submissionsModel.get(i).submissionId === submissionId)
                return i
        return -1
    }

    function gradeIndexById(gradeId) {
        for (var i = 0; i < gradesModel.count; i++)
            if (gradesModel.get(i).gradeId === gradeId)
                return i
        return -1
    }

    function saveMessage(state) {
        if (messageSubject.trim().length === 0 || messageBody.trim().length === 0) {
            setStatus("Please enter both a subject and a message.", true)
            return
        }

        backendStub("saveMessage", {
            state: state,
            classId: messageTargetClassId,
            subject: messageSubject,
            body: messageBody
        })

        auth.save_course_message(messageTargetClassId, userId, messageSubject, messageBody, state)
    }

    function addClass() {
        if (newClassName.trim().length === 0) {
            setStatus("Please enter a class name.", true)
            return
        }

        backendStub("createClass", {
            name: newClassName,
            description: newClassDescription
        })

        auth.create_course(newClassName, newClassDescription, userId, schoolId)
    }

    function deleteClass(classId, className) {
        backendStub("deleteClass", { classId: classId, className: className })
        auth.delete_course(classId)
    }

    function addAssignment() {
        if (createAssignmentTitle.trim().length === 0 || createAssignmentDue.trim().length === 0) {
            setStatus("Please fill in assignment title and due date", true)
            return
        }

        if (assignmentAttachmentPath.length > 0 && assignmentAttachmentName.length === 0) {
            setStatus("Selected file is not valid. Maximum size is 25MB", true)
            return
        }

        if (!isCreateAssignmentDueValid()) {
            setStatus("Due date must be in the future", true)
            return
        }

        backendStub("createAssignment", {
            classId: createAssignmentClassId,
            title: createAssignmentTitle,
            description: createAssignmentDescription,
            dueText: createAssignmentDue,
            aiEnabled: createAssignmentAi,
            attachmentName: assignmentAttachmentName,
            attachmentPath: assignmentAttachmentPath
        })

        beginBusy("Uploading assignment...")
        auth.create_assignment(createAssignmentClassId,
                               createAssignmentTitle,
                               createAssignmentDescription,
                               createAssignmentDue,
                               createAssignmentAi,
                               assignmentAttachmentPath)
    }

    function addMaterial() {
        if (materialTitle.trim().length === 0) {
            setStatus("Please enter a title for the material.", true)
            return
        }

        if (materialFilePath.length > 0 && materialFileName.length === 0) {
            setStatus("Selected file is not valid. Maximum size is 25MB", true)
            return
        }

        var uploadType = materialFilePath.length > 0 ? materialType : "NO FILE"

        backendStub("uploadMaterial", {
            classId: materialsTargetClassId,
            title: materialTitle,
            type: uploadType,
            by: materialBy,
            description: materialDescription,
            fileName: materialFileName,
            filePath: materialFilePath
        })

        beginBusy("Uploading material...")
        auth.create_material(materialsTargetClassId,
                             materialTitle,
                             materialDescription,
                             uploadType,
                             userId,
                             materialFilePath)
    }

    function toggleAssignmentStatus(assignmentId) {
        for (var i = 0; i < assignmentsModel.count; i++) {
            var a = assignmentsModel.get(i)
            if (a.assignmentId === assignmentId) {
                var shouldClose = (a.status === "Open")
                if (!shouldClose && a.manualClosed !== true) {
                    setStatus("This assignment is already closed because the due time passed", true)
                    return
                }
                backendStub("toggleAssignmentStatus", { assignmentId: assignmentId, isClosed: shouldClose })
                auth.set_assignment_closed(assignmentId, shouldClose)
                return
            }
        }
    }

    function deleteAssignment(assignmentId) {
        backendStub("deleteAssignment", { assignmentId: assignmentId })
        auth.delete_assignment(assignmentId)
    }

    function deleteMaterial(materialId) {
        backendStub("deleteMaterial", { materialId: materialId })
        auth.delete_material(materialId)
    }

    function deleteMessage(messageId) {
        backendStub("deleteMessage", { messageId: messageId })
        auth.delete_message(messageId)
    }

    function toggleStudentStatus(studentId) {
        var studentRow = null
        for (var i = 0; i < studentsModel.count; i++) {
            var row = studentsModel.get(i)
            if (row.studentId === studentId && row.classId === root.studentsClassId) {
                studentRow = row
                break
            }
        }
        if (!studentRow) {
            setStatus("Student not found", true)
            return
        }

        var newStatus = studentRow.status === "Active" ? "INACTIVE" : "ACTIVE"
        backendStub("toggleStudentStatus", { studentId: studentId, memberStatus: newStatus })
        auth.update_course_member_status(root.studentsClassId, studentId, newStatus)
    }

    function selectSubmission(submissionId) {
        backendStub("selectSubmission", { submissionId: submissionId })

        selectedSubmissionId = submissionId
        var s = submissionById(submissionId)
        if (s) {
            reviewTeacherNote = s.teacherText
            reviewFinalGrade = s.finalGrade.toString()
        }
    }

    function saveSubmissionReview() {
        var idx = submissionIndexById(selectedSubmissionId)
        if (idx < 0 || reviewFinalGrade.trim().length === 0) {
            setStatus("Please choose a submission and enter a final grade", true)
            return
        }

        if (!isValidGradeValue(reviewFinalGrade)) {
            setStatus("Final grade must be between 0 and 100", true)
            return
        }

        backendStub("saveSubmissionReview", {
            submissionId: selectedSubmissionId,
            teacherNote: reviewTeacherNote,
            finalGrade: reviewFinalGrade
        })

        auth.update_submission_review(selectedSubmissionId, reviewFinalGrade, reviewTeacherNote, userId)
    }

    function selectGrade(gradeId) {
        backendStub("selectGrade", { gradeId: gradeId })

        selectedGradeId = gradeId
        var g = gradeById(gradeId)
        gradeEditValue = g ? g.finalGrade.toString() : ""
    }

    function saveGradeEdit() {
        var idx = gradeIndexById(selectedGradeId)
        if (idx < 0 || gradeEditValue.trim().length === 0) {
            setStatus("Please choose a grade and enter a new value", true)
            return
        }

        if (!isValidGradeValue(gradeEditValue)) {
            setStatus("Final grade must be between 0 and 100", true)
            return
        }

        var gradeRow = gradesModel.get(idx)
        var targetSubmissionId = -1
        for (var i = 0; i < submissionsModel.count; i++) {
            var sub = submissionsModel.get(i)
            if (sub.assignmentId === gradeRow.assignmentId && sub.student === gradeRow.student) {
                targetSubmissionId = sub.submissionId
                break
            }
        }

        backendStub("saveGradeEdit", {
            gradeId: selectedGradeId,
            value: gradeEditValue,
            submissionId: targetSubmissionId
        })

        if (targetSubmissionId > 0)
            auth.update_submission_review(targetSubmissionId, gradeEditValue, submissionById(targetSubmissionId).teacherText, userId)
    }

    function materialById(materialId) {
        for (var i = 0; i < materialsModel.count; i++) {
            var m = materialsModel.get(i)
            if (m.materialId === materialId)
                return m
        }
        return null
    }

    function openMaterialViewer(materialId) {
        var m = materialById(materialId)
        if (!m) {
            setStatus("Material not found", true)
            return
        }

        backendStub("downloadMaterial", { materialId: materialId })
        downloadServerFile(m.filePath !== undefined ? m.filePath : "", m.title)
    }


    function countPendingStudentsByClass(classId) {
        var count = 0
        for (var i = 0; i < pendingStudentsModel.count; i++)
            if (pendingStudentsModel.get(i).classId === classId)
                count++
        return count
    }

    function pendingRowsForClass(classId) {
        var rows = []
        for (var i = 0; i < pendingStudentsModel.count; i++) {
            var p = pendingStudentsModel.get(i)
            if (classId <= 0 || p.classId === classId)
                rows.push({ requestId: p.requestId, studentId: p.studentId, classId: p.classId, className: classNameById(p.classId), name: p.name, requestedAt: p.requestedAt })
        }
        return rows
    }

    function approvePendingStudent(requestId) {
        backendStub("approvePendingStudent", { requestId: requestId })

        for (var i = 0; i < pendingStudentsModel.count; i++) {
            var p = pendingStudentsModel.get(i)
            if (p.requestId === requestId) {
                auth.update_course_member_status(p.classId, p.studentId, "ACTIVE")
                return
            }
        }
    }

    function rejectPendingStudent(requestId) {
        backendStub("rejectPendingStudent", { requestId: requestId })

        for (var i = 0; i < pendingStudentsModel.count; i++) {
            var p = pendingStudentsModel.get(i)
            if (p.requestId === requestId) {
                auth.delete_course_member(p.classId, p.studentId)
                return
            }
        }
    }

    function openFilePicker(target) {
        backendStub("openFilePicker", { target: target })
        fileDialogTarget = target
        fileDialog.open()
    }

    function openSubmissionViewer() {
        var s = submissionById(selectedSubmissionId)
        if (!s) {
            setStatus("Submission not found", true)
            return
        }

        backendStub("downloadSubmission", { submissionId: selectedSubmissionId, fileName: s.fileName })
        downloadServerFile(s.filePath, s.fileName)
    }

    function logout() {
        backendStub("logout", { userId: userId, userName: userName, role: role })
        if (typeof auth !== "undefined" && auth)
            auth.logout()
        if (nav)
            nav.pop()
    }

    Component.onCompleted: {
        clearListModel(classesModel)
        clearListModel(assignmentsModel)
        clearListModel(studentsModel)
        clearListModel(pendingStudentsModel)
        clearListModel(materialsModel)
        clearListModel(gradesModel)
        clearListModel(submissionsModel)
        refreshCreateAssignmentDue()
        refreshTeacherData()
    }

    Timer {
        id: statusTimer
        interval: 4500
        repeat: false
        onTriggered: root.backendStatusText = ""
    }

    Rectangle {
        anchors.fill: parent
        color: bg

        Rectangle { width: 520; height: 520; radius: 260; x: -220; y: -230; color: indigo600; opacity: 0.08 }
        Rectangle { width: 620; height: 620; radius: 310; x: parent.width - 440; y: parent.height - 470; color: indigo700; opacity: 0.07 }
    }


    Connections {
        target: auth

        function onTeacherCoursesResult(success, message, courses) {
            if (!success) {
                setStatus(message, true)
                return
            }

            clearListModel(classesModel)
            clearListModel(assignmentsModel)
            clearListModel(studentsModel)
            clearListModel(materialsModel)
            clearListModel(gradesModel)
            clearListModel(submissionsModel)
            clearListModel(messageLogModel)

            for (var i = 0; i < courses.length; i++) {
                var c = courses[i]
                var courseId = Number(c.course_id)
                if (!isFinite(courseId) || courseId <= 0)
                    continue

                classesModel.append({
                    classId: courseId,
                    classCode: c.class_code ? c.class_code : "",
                    name: c.name ? c.name : "Untitled class",
                    description: c.description ? c.description : "",
                    students: 0,
                    pendingStudents: 0,
                    assignments: 0,
                    openAssignments: 0,
                    materials: 0,
                    average: 0,
                    lastActivity: c.created_at ? c.created_at : ""
                })
            }

            if (classesModel.count > 0) {
                var firstClassId = classesModel.get(0).classId
                messageTargetClassId = firstClassId
                createAssignmentClassId = firstClassId
                materialsTargetClassId = firstClassId
                studentsClassId = firstClassId
                submissionsClassId = firstClassId
                gradesClassId = firstClassId

                for (var ci = 0; ci < classesModel.count; ci++)
                    refreshClassData(classesModel.get(ci).classId)
            } else {
                messageTargetClassId = -1
                createAssignmentClassId = -1
                materialsTargetClassId = -1
                studentsClassId = -1
                submissionsClassId = -1
                submissionsAssignmentId = -1
                gradesClassId = -1
                gradesAssignmentId = -1
            }
        }
    }

    Connections {
        target: auth

        function onCourseAssignmentsResult(success, message, courseId, assignments) {
            if (!success) {
                setStatus(message, true)
                return
            }

            removeRowsByField(assignmentsModel, "classId", courseId)
            for (var i = 0; i < assignments.length; i++) {
                var a = assignments[i]
                assignmentsModel.append({
                    assignmentId: a.assignment_id,
                    classId: courseId,
                    title: a.title,
                    description: a.description ? a.description : "",
                    dueText: a.due_date ? a.due_date : "",
                    manualClosed: a.is_closed ? true : false,
                    status: (a.is_closed || !isAssignmentOpen(a.due_date)) ? "Closed" : "Open",
                    submissions: 0,
                    totalStudents: countStudentsByClass(courseId),
                    aiEnabled: !!a.ai_enabled,
                    materialCount: 0,
                    attachmentPath: a.attachment_path ? a.attachment_path : ""
                })
                auth.get_submissions_for_assignment(a.assignment_id)
            }

            var classIndex = classIndexById(courseId)
            if (classIndex >= 0) {
                classesModel.setProperty(classIndex, "assignments", countAssignmentsByClass(courseId))
                classesModel.setProperty(classIndex, "openAssignments", countOpenAssignmentsByClass(courseId))
            }

            if (submissionsClassId === courseId && assignmentIndexForClassAndId(courseId, submissionsAssignmentId) < 0)
                submissionsAssignmentId = -1
            if (gradesClassId === courseId)
                gradesAssignmentId = firstAssignmentIdForClass(courseId)
        }
    }

    Connections {
        target: auth

        function onCourseStudentsResult(success, message, courseId, students) {
            if (!success) {
                setStatus(message, true)
                return
            }

            var previousStudentState = {}
            for (var pi = 0; pi < studentsModel.count; pi++) {
                var prev = studentsModel.get(pi)
                if (prev.classId === courseId)
                    previousStudentState[prev.studentId] = { grade: prev.grade, lastSubmission: prev.lastSubmission }
            }

            removeRowsByField(studentsModel, "classId", courseId)
            removeRowsByField(pendingStudentsModel, "classId", courseId)
            for (var i = 0; i < students.length; i++) {
                var s = students[i]
                var statusValue = s.member_status ? String(s.member_status).trim().toUpperCase() : "ACTIVE"
                if (statusValue === "PENDING") {
                    pendingStudentsModel.append({
                        requestId: s.id,
                        studentId: s.id,
                        classId: courseId,
                        name: s.name,
                        requestedAt: s.joined_at ? formatDateTimePretty(s.joined_at) : "Waiting approval"
                    })
                    continue
                }

                if (statusValue !== "ACTIVE" && statusValue !== "INACTIVE")
                    continue

                var prevState = previousStudentState[s.id]
                studentsModel.append({
                    studentId: s.id,
                    classId: courseId,
                    name: s.name,
                    status: statusValue === "INACTIVE" ? "Inactive" : "Active",
                    grade: prevState ? prevState.grade : 0,
                    lastSubmission: prevState ? prevState.lastSubmission : ""
                })
            }

            var classIndex = classIndexById(courseId)
            if (classIndex >= 0) {
                classesModel.setProperty(classIndex, "students", countStudentsByClass(courseId))
                classesModel.setProperty(classIndex, "pendingStudents", countPendingStudentsByClass(courseId))
            }

            for (var ai = 0; ai < assignmentsModel.count; ai++) {
                var assignmentRow = assignmentsModel.get(ai)
                if (assignmentRow.classId === courseId)
                    assignmentsModel.setProperty(ai, "totalStudents", countStudentsByClass(courseId))
            }
        }
    }

    Connections {
        target: auth

        function onSubmissionsResult(success, message, assignmentId, submissions) {
            if (!success) {
                setStatus(message, true)
                return
            }

            var classId = assignmentClassId(assignmentId)
            removeRowsByAssignment(assignmentId)

            for (var i = 0; i < submissions.length; i++) {
                var s = submissions[i]
                var aiGradeValue = (s.ai_score === null || s.ai_score === undefined) ? 0 : Math.round(s.ai_score)
                var finalGradeValue = (s.final_score === null || s.final_score === undefined) ? aiGradeValue : Math.round(s.final_score)
                submissionsModel.append({
                    submissionId: s.submission_id,
                    classId: classId,
                    assignmentId: assignmentId,
                    student: s.student_name,
                    submittedAt: s.submitted_at,
                    aiGrade: aiGradeValue,
                    finalGrade: finalGradeValue,
                    aiEnabled: assignmentAiEnabled(assignmentId),
                    teacherEdited: s.final_score !== null && s.final_score !== undefined,
                    aiText: s.ai_feedback ? s.ai_feedback : "",
                    teacherText: s.teacher_feedback ? s.teacher_feedback : "",
                    fileName: fileNameFromPath(s.file_path),
                    filePath: s.file_path
                })
                gradesModel.append({
                    gradeId: s.submission_id,
                    classId: classId,
                    assignmentId: assignmentId,
                    student: s.student_name,
                    finalGrade: finalGradeValue,
                    aiGrade: aiGradeValue,
                    reviewed: s.final_score !== null && s.final_score !== undefined
                })
            }

            for (var ai = 0; ai < assignmentsModel.count; ai++) {
                var assignmentRow = assignmentsModel.get(ai)
                if (assignmentRow.assignmentId === assignmentId) {
                    assignmentsModel.setProperty(ai, "submissions", submissions.length)
                    break
                }
            }

            for (var si = 0; si < studentsModel.count; si++) {
                var studentRow = studentsModel.get(si)
                if (studentRow.classId !== classId)
                    continue
                var total = 0
                var count = 0
                var lastSubmitted = ""
                for (var gi = 0; gi < gradesModel.count; gi++) {
                    var g = gradesModel.get(gi)
                    if (g.classId === classId && g.student === studentRow.name) {
                        total += g.finalGrade
                        count += 1
                    }
                }
                for (var subi = 0; subi < submissionsModel.count; subi++) {
                    var sub = submissionsModel.get(subi)
                    if (sub.classId === classId && sub.student === studentRow.name)
                        lastSubmitted = sub.submittedAt
                }
                studentsModel.setProperty(si, "grade", count > 0 ? Math.round(total / count) : 0)
                studentsModel.setProperty(si, "lastSubmission", lastSubmitted)
            }

            var classTotal = 0
            var classCount = 0
            for (var gi2 = 0; gi2 < gradesModel.count; gi2++) {
                var gradeRow = gradesModel.get(gi2)
                if (gradeRow.classId === classId) {
                    classTotal += gradeRow.finalGrade
                    classCount += 1
                }
            }
            var classIndex = classIndexById(classId)
            if (classIndex >= 0)
                classesModel.setProperty(classIndex, "average", classCount > 0 ? Math.round(classTotal / classCount) : 0)
        }
    }

    Connections {
        target: auth

        function onCreateCourseResult(success, message, courseId) {
            if (success)
                setStatus("Your class was created successfully.", false)
            else
                setStatus(message, true)
            if (success) {
                newClassName = ""
                newClassDescription = ""
                refreshTeacherData()
            }
        }
    }

    Connections {
        target: auth

        function onCreateAssignmentResult(success, message, courseId, assignmentId) {
            endBusy()
            if (success)
                setStatus("Your assignment was created successfully.", false)
            else
                setStatus(message, true)
            if (success) {
                createAssignmentTitle = ""
                createAssignmentDescription = ""
                createAssignmentDue = ""
                createAssignmentAi = true
                assignmentAttachmentName = ""
                assignmentAttachmentPath = ""
                refreshClassData(courseId)
            }
        }
    }

    Connections {
        target: auth

        function onUpdateSubmissionReviewResult(success, message, submissionId) {
            if (!success)
                setStatus(message, true)
            if (!success)
                return

            var idx = submissionIndexById(submissionId)
            if (idx >= 0) {
                submissionsModel.setProperty(idx, "teacherText", reviewTeacherNote)
                submissionsModel.setProperty(idx, "finalGrade", parseInt(reviewFinalGrade))
                submissionsModel.setProperty(idx, "teacherEdited", true)
                var sub = submissionsModel.get(idx)
                for (var i = 0; i < gradesModel.count; i++) {
                    var g = gradesModel.get(i)
                    if (g.assignmentId === sub.assignmentId && g.student === sub.student) {
                        gradesModel.setProperty(i, "finalGrade", parseInt(reviewFinalGrade))
                        gradesModel.setProperty(i, "reviewed", true)
                    }
                }
                auth.get_submissions_for_assignment(sub.assignmentId)
                auth.get_course_students(sub.classId)
            }
        }
    }

    Connections {
        target: auth

        function onGetUsersResult(success, message, users) {
            if (!success)
                return
            schoolUsersData = users
        }
    }

    Connections {
        target: auth

        function onCourseMaterialsResult(success, message, courseId, materials) {
            if (!success) {
                setStatus(message, true)
                return
            }

            removeRowsByField(materialsModel, "classId", courseId)
            for (var i = 0; i < materials.length; i++) {
                var m = materials[i]
                materialsModel.append({
                    materialId: m.material_id,
                    classId: courseId,
                    type: m.file_path ? (m.type ? m.type : inferMaterialTypeFromPath(m.file_path)) : "NO FILE",
                    title: m.title,
                    by: m.created_by_name ? m.created_by_name : materialBy,
                    description: m.description ? m.description : "",
                    fileName: fileNameFromPath(m.file_path ? m.file_path : ""),
                    filePath: m.file_path ? m.file_path : "",
                    whenText: m.created_at ? formatDateTimePretty(m.created_at) : ""
                })
            }

            var classIndex = classIndexById(courseId)
            if (classIndex >= 0)
                classesModel.setProperty(classIndex, "materials", countMaterialsByClass(courseId))
        }
    }

    Connections {
        target: auth

        function onCreateMaterialResult(success, message, courseId, materialId) {
            endBusy()
            if (success)
                setStatus("The material was uploaded successfully.", false)
            else
                setStatus(message, true)
            if (!success)
                return

            materialTitle = ""
            materialDescription = ""
            materialFileName = ""
            materialFilePath = ""
            materialType = "NO FILE"
            auth.get_course_materials(courseId)
        }
    }

    Connections {
        target: auth

        function onCourseMessagesResult(success, message, courseId, messages) {
            if (!success) {
                setStatus(message, true)
                return
            }

            removeRowsByField(messageLogModel, "classId", courseId)
            for (var i = messages.length - 1; i >= 0; i--) {
                var m = messages[i]
                messageLogModel.append({
                    messageId: m.message_id,
                    classId: courseId,
                    subject: m.subject,
                    body: m.body,
                    state: m.state,
                    createdAt: m.created_at
                })
            }
        }
    }

    Connections {
        target: auth

        function onSaveCourseMessageResult(success, message, courseId, messageId) {
            if (!success)
                setStatus(message, true)
            if (!success)
                return

            messageSubject = ""
            messageBody = ""
            auth.get_course_messages(courseId)
        }
    }

    Connections {
        target: auth

        function onUpdateCourseMemberStatusResult(success, message, courseId, studentId, memberStatus) {
            if (!success)
                setStatus(message, true)
            if (!success)
                return
            auth.get_course_students(courseId)
        }
    }

    Connections {
        target: auth

        function onDeleteCourseMemberResult(success, message, courseId, studentId) {
            if (!success)
                setStatus(message, true)
            if (!success)
                return
            auth.get_course_students(courseId)
        }
    }

    Connections {
        target: auth

        function onDeleteCourseResult(success, message, courseId) {
            if (!success) {
                setStatus(message, true)
                return
            }
            if (root.studentsClassId === courseId)
                root.studentsClassId = classesModel.count > 0 ? classesModel.get(0).classId : -1
            if (root.submissionsClassId === courseId)
                root.submissionsClassId = classesModel.count > 0 ? classesModel.get(0).classId : -1
            if (root.gradesClassId === courseId)
                root.gradesClassId = classesModel.count > 0 ? classesModel.get(0).classId : -1
            setStatus("The class was deleted successfully.", false)
            refreshTeacherData()
        }
    }

    Connections {
        target: auth

        function onSetAssignmentClosedResult(success, message, assignmentId, isClosed) {
            if (!success) {
                if (message === "ASSIGNMENT_ALREADY_PAST_DUE")
                    setStatus("This assignment cannot be reopened because its due time already passed", true)
                else
                    setStatus(message, true)
                return
            }
            for (var i = 0; i < assignmentsModel.count; i++) {
                var a = assignmentsModel.get(i)
                if (a.assignmentId === assignmentId) {
                    assignmentsModel.setProperty(i, "manualClosed", isClosed)
                    assignmentsModel.setProperty(i, "status", (isClosed || !isAssignmentOpen(a.dueText)) ? "Closed" : "Open")
                    var classIndex = classIndexById(a.classId)
                    if (classIndex >= 0)
                        classesModel.setProperty(classIndex, "openAssignments", countOpenAssignmentsByClass(a.classId))
                    setStatus(isClosed ? "Assignment closed" : "Assignment reopened", false)
                    return
                }
            }
        }
    }

    Connections {
        target: auth

        function onDeleteAssignmentResult(success, message, assignmentId, courseId) {
            if (!success) {
                setStatus(message, true)
                return
            }
            removeRowsByAssignment(assignmentId)
            for (var i = assignmentsModel.count - 1; i >= 0; i--) {
                if (assignmentsModel.get(i).assignmentId === assignmentId)
                    assignmentsModel.remove(i)
            }
            if (courseId > 0) {
                var classIndex = classIndexById(courseId)
                if (classIndex >= 0) {
                    classesModel.setProperty(classIndex, "assignments", countAssignmentsByClass(courseId))
                    classesModel.setProperty(classIndex, "openAssignments", countOpenAssignmentsByClass(courseId))
                }
                if (root.submissionsClassId === courseId)
                    root.submissionsAssignmentId = -1
                if (root.gradesClassId === courseId)
                    root.gradesAssignmentId = firstAssignmentIdForClass(courseId)
            }
            setStatus("The assignment was deleted successfully.", false)
        }
    }

    Connections {
        target: auth

        function onDeleteMaterialResult(success, message, materialId, courseId) {
            if (!success) {
                setStatus(message, true)
                return
            }
            for (var i = materialsModel.count - 1; i >= 0; i--) {
                if (materialsModel.get(i).materialId === materialId)
                    materialsModel.remove(i)
            }
            if (courseId > 0) {
                var classIndex = classIndexById(courseId)
                if (classIndex >= 0)
                    classesModel.setProperty(classIndex, "materials", countMaterialsByClass(courseId))
            }
            setStatus("The material was deleted successfully.", false)
        }
    }

    Connections {
        target: auth

        function onDeleteMessageResult(success, message, messageId, courseId) {
            if (!success) {
                setStatus(message, true)
                return
            }
            for (var i = messageLogModel.count - 1; i >= 0; i--) {
                if (messageLogModel.get(i).messageId === messageId)
                    messageLogModel.remove(i)
            }
            setStatus("The message was deleted successfully.", false)
        }
    }

    Connections {
        target: auth

        function onLocalFileValidationResult(success, target, filePath, message, sizeBytes) {
            if (!success) {
                if (target === "assignment") {
                    root.assignmentAttachmentPath = ""
                    root.assignmentAttachmentName = ""
                } else if (target === "material") {
                    root.materialFilePath = ""
                    root.materialFileName = ""
                }
                setStatus(message, true)
                return
            }

            var cleanName = root.fileNameFromPath(filePath)
            if (target === "assignment") {
                root.assignmentAttachmentPath = filePath
                root.assignmentAttachmentName = cleanName
            } else if (target === "material") {
                root.materialFilePath = filePath
                root.materialFileName = cleanName
                root.materialType = inferMaterialTypeFromPath(filePath)
                if (root.materialTitle.trim().length === 0)
                    root.materialTitle = cleanName
            }
            setStatus("File selected: " + cleanName + " (" + formatBytes(sizeBytes) + ")", false)
        }
    }

    Connections {
        target: auth

        function onDownloadFileResult(success, message, filePath, savedPath) {
            endBusy()
            if (success) {
                root.lastDownloadedPath = savedPath
                setStatus("The download finished successfully.", false)
            } else {
                setStatus("Download failed: " + message, true)
            }
        }
    }

    Dialog {
        id: messageDialog
        modal: true
        width: Math.min(Math.max(root.width * 0.52, 500), root.width - 120)
        height: Math.min(Math.max(root.height * 0.46, 320), root.height - 140)
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        title: "Message details"

        background: Rectangle { radius: 18; color: card; border.width: 1; border.color: line }

        contentItem: ColumnLayout {
            spacing: 12
            Text { text: root.selectedMaterialTitle; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }
            Text { text: root.selectedMaterialMeta; color: muted; font.pixelSize: 11; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
            TextArea {
                Layout.fillWidth: true
                Layout.fillHeight: true
                readOnly: true
                wrapMode: TextEdit.WrapAnywhere
                text: root.selectedMaterialDescription
                background: Rectangle { radius: 14; color: "#F8FAFC"; border.width: 1; border.color: line }
            }
            RowLayout { Layout.fillWidth: true; Item { Layout.fillWidth: true } ActionButton { text: "Close"; onClicked: messageDialog.close() } }
        }
    }

    FileDialog {
        id: fileDialog
        title: "Select file"
        fileMode: FileDialog.OpenFile
        nameFilters: ["All files (*)", "Archives (*.zip *.tar *.tgz *.rar *.7z)", "Code files (*.py *.cs *.java *.js *.ts *.cpp *.c *.h)"]
        onAccepted: {
            var path = selectedFile.toString()
            var cleanName = root.fileNameFromPath(path)
            root.backendStub("fileSelected", { target: root.fileDialogTarget, fileName: cleanName, filePath: path })
            auth.validate_local_file(path, root.fileDialogTarget)
        }
    }

    Dialog {
        id: submissionDialog
        modal: true
        width: Math.min(Math.max(root.width * 0.64, 560), root.width - 80)
        height: Math.min(Math.max(root.height * 0.72, 420), root.height - 80)
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        title: "Submission Viewer"

        background: Rectangle {
            radius: 18
            color: card
            border.width: 1
            border.color: line
        }

        contentItem: ColumnLayout {
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 56
                radius: 14
                color: "#F8FAFC"
                border.width: 1
                border.color: line

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    Text { text: root.selectedSubmissionFileName; color: ink; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Item { Layout.fillWidth: true }
                    Badge { textValue: "Preview"; bgColor: blueSoft; fgColor: blue }
                }
            }

            TextArea {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.selectedSubmissionPreview
                readOnly: true
                wrapMode: TextEdit.WrapAnywhere
                selectByMouse: true
                background: Rectangle {
                    radius: 14
                    color: "#F8FAFC"
                    border.width: 1
                    border.color: line
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ActionButton { text: "Close"; onClicked: submissionDialog.close() }
            }
        }
    }

    Dialog {
        id: materialDialog
        modal: true
        width: Math.min(Math.max(root.width * 0.58, 520), root.width - 100)
        height: Math.min(Math.max(root.height * 0.58, 360), root.height - 100)
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        title: "Material Viewer"

        background: Rectangle {
            radius: 18
            color: card
            border.width: 1
            border.color: line
        }

        contentItem: ColumnLayout {
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 82
                radius: 14
                color: "#F8FAFC"
                border.width: 1
                border.color: line

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4
                    Text { text: root.selectedMaterialTitle; color: ink; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Text { text: root.selectedMaterialMeta; color: muted; font.pixelSize: 11; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                }
            }

            TextArea {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.selectedMaterialDescription
                readOnly: true
                wrapMode: TextEdit.WrapAnywhere
                selectByMouse: true
                background: Rectangle {
                    radius: 14
                    color: "#F8FAFC"
                    border.width: 1
                    border.color: line
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ActionButton { text: "Download"; onClicked: root.downloadServerFile(root.selectedMaterialPath, root.selectedMaterialTitle) }
                ActionButton { text: "Close"; kind: "ghost"; onClicked: materialDialog.close() }
                Item { Layout.fillWidth: true }
            }
        }
    }

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

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 92
                radius: 20
                color: indigo700
                border.width: 1
                border.color: "#14000000"

                Rectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"; border.width: 1; border.color: "#10FFFFFF" }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    Rectangle {
                        width: 54; height: 54; radius: 17
                        color: "#20FFFFFF"
                        border.width: 1
                        border.color: "#30FFFFFF"
                        Layout.alignment: Qt.AlignVCenter
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
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "Classify"
                            color: "#FFFFFF"
                            opacity: 0.98
                            font.pixelSize: 26
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: "Welcome back, " + userName + " 👋"
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
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 8
                        HeaderButton { text: "Refresh"; onClicked: root.refreshCurrentPageData() }
                        HeaderButton { text: "Logout"; onClicked: root.logout() }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: Math.max(220, Math.min(252, shell.width * 0.19))
                    Layout.maximumWidth: 252
                    Layout.minimumWidth: 220
                    Layout.fillHeight: true
                    radius: 20
                    color: soft
                    border.width: 1
                    border.color: line

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Text { text: "Quick actions"; color: muted2; font.pixelSize: 12; font.weight: Font.Medium }

                        NavItem { title: "Dashboard"; iconText: "🏠"; pageKey: "dashboard" }
                        NavItem { title: "Create Class"; iconText: "➕"; pageKey: "newClass" }
                        NavItem { title: "All Classes"; iconText: "🏫"; pageKey: "classes" }
                        NavItem { title: "Assignments"; iconText: "📝"; pageKey: "assignments" }
                        NavItem { title: "Students"; iconText: "👥"; pageKey: "students" }
                        NavItem { title: "Materials"; iconText: "📂"; pageKey: "materials" }
                        NavItem { title: "Submission Review"; iconText: "🤖"; pageKey: "submissions" }
                        NavItem { title: "Messages"; iconText: "📣"; pageKey: "messages" }
                        NavItem { title: "Reports"; iconText: "📈"; pageKey: "reports" }

                        Item { Layout.fillHeight: true }

                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        StatCard { title: "Active classes"; value: classesModel.count.toString(); iconText: "🏫"; accentBg: violetSoft; accentText: indigo700 }
                        StatCard { title: "Total students"; value: totalStudentsAll().toString(); iconText: "👨‍🎓"; accentBg: blueSoft; accentText: blue }
                        StatCard { title: "Open assignments"; value: countOpenAssignments().toString(); iconText: "🟢"; accentBg: greenSoft; accentText: green }
                        StatCard { title: "Average grade"; value: averageAcrossClasses().toString(); iconText: "⭐"; accentBg: amberSoft; accentText: amber }
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        sourceComponent:
                            currentPage === "dashboard" ? dashboardPage :
                            currentPage === "newClass" ? newClassPage :
                            currentPage === "classes" ? classesPage :
                            currentPage === "assignments" ? assignmentsPage :
                            currentPage === "students" ? studentsPage :
                            currentPage === "materials" ? materialsPage :
                            currentPage === "submissions" || currentPage === "grades" ? submissionsPage :
                            currentPage === "messages" ? messagesPage :
                            reportsPage
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.backendStatusText.length > 0
                        implicitHeight: visible ? 30 : 0
                        radius: 12
                        color: root.backendStatusIsError ? "#FEF2F2" : "#F0FDF4"
                        border.width: visible ? 1 : 0
                        border.color: root.backendStatusIsError ? "#FCA5A5" : "#86EFAC"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            anchors.topMargin: 6
                            anchors.bottomMargin: 8
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: root.backendStatusText
                                color: root.backendStatusIsError ? red : green
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            Item {
                                width: 20
                                height: 20
                                Layout.alignment: Qt.AlignVCenter

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.backendStatusText = ""
                                    cursorShape: Qt.PointingHandCursor
                                }

                                Text {
                                    anchors.centerIn: parent
                                    y: -1
                                    text: "✕"
                                    color: muted
                                    font.pixelSize: 11
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
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
                    width: 224
                    text: root.busyText.length > 0 ? root.busyText : "Please wait..."
                    color: ink
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }

    component HeaderButton : Item {
        id: hb
        property alias text: label.text
        signal clicked
        implicitWidth: 92
        implicitHeight: 34

        Rectangle { anchors.fill: parent; radius: 12; color: "#FFFFFF"; opacity: ma.pressed ? 0.22 : (ma.containsMouse ? 0.20 : 0.16); border.width: 1; border.color: "#10FFFFFF" }
        Text { id: label; anchors.centerIn: parent; color: "#FFFFFF"; font.pixelSize: 13; font.weight: Font.DemiBold }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: hb.clicked() }
    }

    component NavItem : Item {
        id: ni
        property string title: ""
        property string iconText: ""
        property string pageKey: ""
        implicitHeight: 46
        Layout.fillWidth: true
        readonly property bool active: root.currentPage === pageKey

        Rectangle { anchors.fill: parent; radius: 14; color: active ? "#EEF2FF" : "transparent"; border.width: 1; border.color: active ? "#C7D2FE" : "transparent" }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Rectangle {
                width: 28; height: 28; radius: 9
                color: active ? "#FFFFFF" : "#F3F4F6"
                border.width: 1
                border.color: active ? "#D9E0FF" : "#ECEFF3"
                Text { anchors.centerIn: parent; text: iconText; font.pixelSize: 13 }
            }

            Text { Layout.fillWidth: true; text: title; color: active ? indigo700 : ink; font.pixelSize: 13; font.weight: active ? Font.DemiBold : Font.Medium; elide: Text.ElideRight }
        }

        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openPage(pageKey) }
    }

    component StatCard : Rectangle {
        property string title: ""
        property string value: ""
        property string iconText: ""
        property color accentBg: "#EEF2FF"
        property color accentText: indigo700
        property string helperText: "Read-only"
        Layout.fillWidth: true
        Layout.preferredHeight: 104
        radius: 18
        color: card
        border.width: 1
        border.color: line

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 10
            anchors.rightMargin: 10
            radius: 9
            color: "#F8FAFC"
            border.width: 1
            border.color: "#E8ECF4"
            implicitWidth: helperBadgeText.implicitWidth + 14
            implicitHeight: 22

            Text {
                id: helperBadgeText
                anchors.centerIn: parent
                text: helperText
                color: muted2
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.rightMargin: 18
            spacing: 12
            Rectangle { width: 44; height: 44; radius: 14; color: accentBg; border.width: 1; border.color: "#E8ECF4"; Text { anchors.centerIn: parent; text: iconText; color: accentText; font.pixelSize: 18 } }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: title; color: muted; font.pixelSize: 12 }
                Text { text: value; color: ink; font.pixelSize: 24; font.weight: Font.DemiBold }
            }
        }
    }

    component SectionFrame : Rectangle {
        Layout.fillWidth: true
        radius: 20
        color: card
        border.width: 1
        border.color: line
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
        signal clicked
        implicitWidth: Math.max(110, btnLabel.implicitWidth + 28)
        implicitHeight: 40

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: kind === "ghost" ? "#FFFFFF" : indigo600
            border.width: 1
            border.color: kind === "ghost" ? line : indigo600
            opacity: btnMouse.pressed ? 0.85 : 1.0
        }

        Text { id: btnLabel; anchors.centerIn: parent; color: kind === "ghost" ? ink : "#FFFFFF"; font.pixelSize: 12; font.weight: Font.DemiBold }
        MouseArea { id: btnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ab.clicked() }
    }

    component InputField : Item {
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

    component AreaField : Item {
        property string label: ""
        property alias text: field.text
        property string placeholder: ""
        implicitHeight: 190
        Layout.fillWidth: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 6
            Text { text: label; color: muted; font.pixelSize: 12; font.weight: Font.Medium }
            TextArea {
                id: field
                Layout.fillWidth: true
                Layout.fillHeight: true
                wrapMode: TextEdit.WrapAnywhere
                selectByMouse: true
                placeholderText: placeholder
                color: ink
                selectedTextColor: "#FFFFFF"
                selectionColor: indigo600
                background: Rectangle { radius: 12; color: "#F8FAFC"; border.width: 1; border.color: field.activeFocus ? indigo600 : line }
            }
        }
    }

    component LabeledCombo : Item {
        id: lc
        property string label: ""
        property var model: []
        property string textRole: ""
        property int currentIndex: 0
        readonly property string currentText: itemText(currentIndex)
        signal chosen(int index)
        implicitHeight: 76
        Layout.fillWidth: true

        function itemText(idx) {
            if (!model || idx < 0)
                return ""
            var item = model.get !== undefined ? model.get(idx) : model[idx]
            if (item === undefined || item === null)
                return ""
            if (textRole && item[textRole] !== undefined)
                return item[textRole]
            return item.toString !== undefined ? item.toString() : ""
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 6

            Text { text: lc.label; color: muted; font.pixelSize: 12; font.weight: Font.Medium }

            Rectangle {
                id: comboBoxFrame
                Layout.fillWidth: true
                implicitHeight: 42
                radius: 12
                color: "#F8FAFC"
                border.width: 1
                border.color: comboPopup.opened ? indigo600 : line

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: lc.currentIndex >= 0 ? lc.currentText : "Select"
                        color: ink
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    Text { text: "▾"; color: muted; font.pixelSize: 14; font.weight: Font.DemiBold }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: comboPopup.opened ? comboPopup.close() : comboPopup.open()
                }
            }
        }

        Popup {
            id: comboPopup
            y: comboBoxFrame.height + 6
            width: comboBoxFrame.width
            z: 10000
            padding: 6
            modal: false
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            background: Rectangle {
                radius: 14
                color: "#FFFFFF"
                border.width: 1
                border.color: line
            }

            contentItem: ListView {
                implicitHeight: Math.min(contentHeight, 220)
                clip: true
                model: lc.model
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: StyledScrollBar {}

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 38
                    radius: 10
                    color: index === lc.currentIndex ? "#EEF2FF" : (itemMouse.containsMouse ? "#F8FAFC" : "#FFFFFF")

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        text: lc.itemText(index)
                        color: ink
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            lc.chosen(index)
                            comboPopup.close()
                        }
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
        implicitHeight: 96
        radius: 18
        color: soft
        border.width: 1
        border.color: line

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            Rectangle { width: 44; height: 44; radius: 14; color: "#EEF2FF"; border.width: 1; border.color: "#D9E0FF"; Text { anchors.centerIn: parent; text: iconText; font.pixelSize: 18 } }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: title; color: ink; font.pixelSize: 20; font.weight: Font.DemiBold }
                Text { text: subtitle; color: muted; font.pixelSize: 12; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
            }
        }
    }

    component RightMetric : Item {
        property string topText: ""
        property string bottomText: ""
        property color topColor: ink
        property color bottomColor: muted
        property int metricWidth: 120
        width: metricWidth
        implicitHeight: 46

        Column {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 2

            Text { width: parent.width; text: topText; horizontalAlignment: Text.AlignRight; color: topColor; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Text { width: parent.width; text: bottomText; horizontalAlignment: Text.AlignRight; color: bottomColor; font.pixelSize: 11; elide: Text.ElideRight }
        }
    }

    Component {
        id: dashboardPage
        Flickable {
            contentWidth: width
            contentHeight: dashCol.implicitHeight
            clip: true

            ColumnLayout {
                id: dashCol
                width: parent.width
                spacing: 14

                PageHeader { title: "Overview"; iconText: "🏠" }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    SectionFrame {
                        Layout.fillWidth: true
                        implicitHeight: 380

                        Item {
                            anchors.fill: parent
                            anchors.margins: 14

                            Text {
                                id: classSnapshotTitle
                                text: "Class snapshot"
                                color: ink
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                anchors.top: parent.top
                                anchors.left: parent.left
                            }

                            Flickable {
                                id: classSnapshotFlick
                                anchors.top: classSnapshotTitle.bottom
                                anchors.topMargin: 10
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                clip: true
                                contentWidth: width
                                contentHeight: classSnapshotList.height
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: StyledScrollBar { policy: ScrollBar.AsNeeded }

                                Column {
                                    id: classSnapshotList
                                    width: classSnapshotFlick.width
                                    spacing: 10

                                    Repeater {
                                        model: classesModel
                                        delegate: Rectangle {
                                            width: classSnapshotList.width
                                            implicitHeight: 72
                                            radius: 14
                                            color: "#F8FAFC"
                                            border.width: 1
                                            border.color: line

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 12

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    Text { text: name; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                                    Text { text: classCode && classCode.length > 0 ? ("Class code: " + classCode) : description; color: muted; font.pixelSize: 11; elide: Text.ElideRight }
                                                    Text { visible: classCode && classCode.length > 0 && description.length > 0; text: description; color: muted2; font.pixelSize: 11; wrapMode: Text.WrapAnywhere; maximumLineCount: 1; elide: Text.ElideRight }
                                                }

                                                RowLayout {
                                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                    spacing: 8
                                                    Badge { textValue: countStudentsByClass(classId) + " students"; bgColor: blueSoft; fgColor: blue }
                                                    Badge { textValue: countOpenAssignmentsByClass(classId) + " open tasks"; bgColor: greenSoft; fgColor: green }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    SectionFrame {
                        Layout.fillWidth: true
                        implicitHeight: 380

                        Item {
                            anchors.fill: parent
                            anchors.margins: 14

                            Text {
                                id: teacherPulseTitle
                                text: "Teacher pulse"
                                color: ink
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                anchors.top: parent.top
                                anchors.left: parent.left
                            }



                            Rectangle {
                                id: pulseApprovalCard
                                anchors.top: teacherPulseSubtitle.bottom
                                anchors.topMargin: 14
                                anchors.left: parent.left
                                width: Math.floor((parent.width - 10) / 2)
                                height: 78
                                radius: 12
                                color: "#F8FAFC"
                                border.width: 1
                                border.color: line

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 4

                                    Text {
                                        text: "Awaiting approval"
                                        color: muted
                                        font.pixelSize: 11
                                    }

                                    Row {
                                        height: 30
                                        spacing: 6

                                        Text {
                                            text: pendingStudentsModel.count.toString()
                                            color: ink
                                            font.pixelSize: 24
                                            font.weight: Font.Bold
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: pendingStudentsModel.count === 1 ? "student" : "students"
                                            color: blue
                                            font.pixelSize: 11
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: pulseReviewCard
                                anchors.top: teacherPulseSubtitle.bottom
                                anchors.topMargin: 14
                                anchors.right: parent.right
                                width: Math.floor((parent.width - 10) / 2)
                                height: 78
                                radius: 12
                                color: "#F8FAFC"
                                border.width: 1
                                border.color: line

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 4

                                    Text {
                                        text: "Need review"
                                        color: muted
                                        font.pixelSize: 11
                                    }

                                    Row {
                                        height: 30
                                        spacing: 6

                                        Text {
                                            text: countUnreviewedGrades().toString()
                                            color: ink
                                            font.pixelSize: 24
                                            font.weight: Font.Bold
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: countUnreviewedGrades() === 1 ? "submission" : "submissions"
                                            color: amber
                                            font.pixelSize: 11
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: pulseInsightsCard
                                anchors.top: pulseApprovalCard.bottom
                                anchors.topMargin: 10
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 148
                                radius: 12
                                color: "#F8FAFC"
                                border.width: 1
                                border.color: line

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 14

                                    Item {
                                        width: parent.width
                                        height: 44

                                        Text {
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            text: "Top class by average"
                                            color: muted
                                            font.pixelSize: 12
                                        }

                                        Text {
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            text: topClassByAverage() ? (topClassByAverage().average + " avg") : "-"
                                            color: green
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            text: topClassByAverage() ? topClassByAverage().name : "No classes yet"
                                            color: ink
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 1
                                        color: line
                                    }

                                    Item {
                                        width: parent.width
                                        height: 44

                                        Text {
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            text: "Most open workload"
                                            color: muted
                                            font.pixelSize: 12
                                        }

                                        Text {
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            text: busiestClassByOpenAssignments() ? (busiestClassByOpenAssignments().openAssignments + " open") : "-"
                                            color: blue
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            text: busiestClassByOpenAssignments() ? busiestClassByOpenAssignments().name : "No classes yet"
                                            color: ink
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: pulseAiCard
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                width: Math.floor((parent.width - 10) / 2)
                                height: 52
                                radius: 12
                                color: "#F8FAFC"
                                border.width: 1
                                border.color: line

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "AI assignments"
                                    color: muted
                                    font.pixelSize: 12
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: countAiEnabledAssignments().toString()
                                    color: indigo700
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                            }

                            Rectangle {
                                id: pulseMaterialsCard
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                width: Math.floor((parent.width - 10) / 2)
                                height: 52
                                radius: 12
                                color: "#F8FAFC"
                                border.width: 1
                                border.color: line

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Materials"
                                    color: muted
                                    font.pixelSize: 12
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: materialsModel.count.toString()
                                    color: ink
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: newClassPage
        Flickable {
            contentWidth: width
            contentHeight: newClassCol.implicitHeight
            clip: true

            ColumnLayout {
                id: newClassCol
                width: parent.width
                spacing: 14

                PageHeader { title: "Create class"; iconText: "➕" }

                SectionFrame {
                    Layout.fillWidth: true
                    implicitHeight: 350
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        InputField { id: classNameInput; label: "Class name"; placeholder: "Example: Grade 12 - Advanced Python"; text: root.newClassName; onTextChanged: root.newClassName = text }
                        InputField { id: classDescriptionInput; label: "Description"; placeholder: "Example: Final project, API work, data analysis"; text: root.newClassDescription; onTextChanged: root.newClassDescription = text }
                        Item { Layout.fillHeight: true }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            ActionButton { text: "Create class"; onClicked: root.addClass() }
                            ActionButton { text: "Clear"; kind: "ghost"; onClicked: { root.newClassName = ""; root.newClassDescription = "" } }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: classesPage
        Flickable {
            id: classesPageFlick
            contentWidth: width
            contentHeight: classesCol.implicitHeight
            clip: true

            ColumnLayout {
                id: classesCol
                width: parent.width
                spacing: 14

                PageHeader { title: "Classes"; iconText: "🏫" }

                SearchField {
                    Layout.fillWidth: true
                    placeholderText: "Search classes by name, description or code"
                    text: root.classSearchText
                    onTextChanged: root.classSearchText = text
                }

                SectionFrame {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(470, classesPageFlick.height - 120)

                    Flickable {
                        id: classesListFlick
                        anchors.fill: parent
                        anchors.margins: 16
                        clip: true
                        contentWidth: width
                        contentHeight: classesListColumn.height
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: StyledScrollBar { policy: ScrollBar.AsNeeded }

                        Column {
                            id: classesListColumn
                            width: classesListFlick.width
                            spacing: 12

                            Repeater {
                                model: classesModel
                                delegate: Rectangle {
                                    readonly property bool matchesSearchRow: root.matchesSearch(name + " " + description + " " + (classCode ? classCode : ""), root.classSearchText)
                                    width: classesListColumn.width
                                    visible: matchesSearchRow
                                    implicitHeight: matchesSearchRow ? 142 : 0
                                    radius: 16
                                    color: "#F8FAFC"
                                    border.width: matchesSearchRow ? 1 : 0
                                    border.color: line

                                    Column {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        anchors.leftMargin: 14
                                        anchors.topMargin: 14
                                        anchors.bottomMargin: 14
                                        width: parent.width - 260
                                        spacing: 5

                                        Text {
                                            width: parent.width
                                            text: name
                                            color: ink
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: parent.width
                                            text: classCode && classCode.length > 0 ? ("Class code: " + classCode) : ""
                                            visible: text.length > 0
                                            color: blue
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: parent.width
                                            text: description
                                            color: muted
                                            font.pixelSize: 11
                                            wrapMode: Text.WrapAnywhere
                                            maximumLineCount: classCode && classCode.length > 0 ? 1 : 2
                                            elide: Text.ElideRight
                                        }
                                        Item { width: 1; height: 4 }
                                        Text {
                                            width: parent.width
                                            text: "Last activity: " + formatDateTimePretty(lastActivity)
                                            color: muted2
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Column {
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.rightMargin: 14
                                        anchors.topMargin: 12
                                        width: 180
                                        spacing: 8

                                        Row {
                                            width: parent.width
                                            spacing: 6
                                            layoutDirection: Qt.RightToLeft
                                            Badge { textValue: students + " students"; bgColor: blueSoft; fgColor: blue }
                                            Badge { textValue: materials + " materials"; bgColor: violetSoft; fgColor: indigo700 }
                                        }
                                        Row {
                                            width: parent.width
                                            spacing: 6
                                            layoutDirection: Qt.RightToLeft
                                            Badge { textValue: assignments + " tasks"; bgColor: greenSoft; fgColor: green }
                                            Badge { textValue: "Avg " + average; bgColor: amberSoft; fgColor: amber }
                                        }

                                        ActionButton {
                                            width: parent.width
                                            text: "Delete class"
                                            kind: "ghost"
                                            onClicked: root.deleteClass(classId, name)
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

    Component {
        id: assignmentsPage
        Flickable {
            contentWidth: width
            contentHeight: assignCol.implicitHeight
            clip: true

            ColumnLayout {
                id: assignCol
                width: parent.width
                spacing: 14

                PageHeader { title: "Assignments"; iconText: "📝" }

                SectionFrame {
                    visible: classesModel.count === 0
                    Layout.fillWidth: true
                    implicitHeight: visible ? 92 : 0
                    ColumnLayout { anchors.centerIn: parent; spacing: 4
                        Text { text: "No classes available yet"; color: ink; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text { text: "Create your first class to start adding assignments."; color: muted; font.pixelSize: 11 }
                    }
                }

                SectionFrame {
                    Layout.fillWidth: true
                    implicitHeight: 760

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        Text { text: "Create assignment"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }

                        LabeledCombo {
                            label: "Class"
                            model: classesModel
                            currentIndex: Math.max(0, classIndexById(root.createAssignmentClassId))
                            textRole: "name"
                            onChosen: if (index >= 0) root.createAssignmentClassId = classesModel.get(index).classId
                        }

                        InputField { label: "Assignment title"; placeholder: "Example: Functions quiz"; text: root.createAssignmentTitle; onTextChanged: root.createAssignmentTitle = text }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: "Due date & time"; color: muted; font.pixelSize: 11; font.weight: Font.Medium }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 170
                                radius: 18
                                color: "#F8FAFC"
                                border.width: 1
                                border.color: line

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 12

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 3
                                        columnSpacing: 10
                                        rowSpacing: 10

                                        DateTimeSpin { label: "Year"; from: 2024; to: 2035; value: root.dueYear; Layout.fillWidth: true; onValueModified: { root.dueYear = value; root.refreshCreateAssignmentDue() } }
                                        DateTimeSpin { label: "Month"; from: 1; to: 12; value: root.dueMonth; Layout.fillWidth: true; onValueModified: { root.dueMonth = value; root.refreshCreateAssignmentDue() } }
                                        DateTimeSpin { label: "Day"; from: 1; to: 31; value: root.dueDay; Layout.fillWidth: true; onValueModified: { root.dueDay = value; root.refreshCreateAssignmentDue() } }
                                        DateTimeSpin { label: "Hour"; from: 0; to: 23; value: root.dueHour; Layout.fillWidth: true; onValueModified: { root.dueHour = value; root.refreshCreateAssignmentDue() } }
                                        DateTimeSpin { label: "Minute"; from: 0; to: 59; value: root.dueMinute; Layout.fillWidth: true; onValueModified: { root.dueMinute = value; root.refreshCreateAssignmentDue() } }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            radius: 14
                                            color: "#EEF2FF"
                                            border.width: 1
                                            border.color: "#C7D2FE"

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 8
                                                Text { text: "🕒"; font.pixelSize: 14 }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Text { text: "Selected due time"; color: muted; font.pixelSize: 10; font.weight: Font.Medium }
                                                    Text { text: root.createAssignmentDue; color: indigo700; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        AreaField { label: "Instructions"; placeholder: "Write the instructions for the class"; text: root.createAssignmentDescription; onTextChanged: root.createAssignmentDescription = text; implicitHeight: 140 }

                        Text { text: "File limit: up to 25MB - For multiple files, upload one ZIP"; color: muted; font.pixelSize: 11 }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 54
                            radius: 14
                            color: "#F8FAFC"
                            border.width: 1
                            border.color: line

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8
                                Text { Layout.fillWidth: true; text: root.assignmentAttachmentName.length > 0 ? root.assignmentAttachmentName : "No instruction file selected"; color: root.assignmentAttachmentName.length > 0 ? ink : muted2; font.pixelSize: 12; elide: Text.ElideRight }
                                ActionButton { text: "Browse"; kind: "ghost"; onClicked: root.openFilePicker("assignment") }
                                ActionButton { text: "Remove"; kind: "ghost"; enabled: root.assignmentAttachmentName.length > 0; onClicked: root.clearAssignmentAttachment() }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                implicitWidth: 196
                                implicitHeight: 46
                                radius: 14
                                color: "#F8FAFC"
                                border.width: 1
                                border.color: line

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    spacing: 4

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 38
                                        radius: 11
                                        color: root.createAssignmentAi ? indigo600 : "transparent"
                                        border.width: root.createAssignmentAi ? 0 : 1
                                        border.color: root.createAssignmentAi ? "transparent" : line
                                        Text { anchors.centerIn: parent; text: "AI ON"; color: root.createAssignmentAi ? "white" : muted; font.pixelSize: 12; font.weight: Font.DemiBold }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.createAssignmentAi = true }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 38
                                        radius: 11
                                        color: root.createAssignmentAi ? "transparent" : "#FEE2E2"
                                        border.width: root.createAssignmentAi ? 1 : 0
                                        border.color: root.createAssignmentAi ? line : "transparent"
                                        Text { anchors.centerIn: parent; text: "AI OFF"; color: root.createAssignmentAi ? muted : red; font.pixelSize: 12; font.weight: Font.DemiBold }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.createAssignmentAi = false }
                                    }
                                }
                            }

                            ActionButton {
                                text: "Publish"
                                opacity: root.isCreateAssignmentDueValid() ? 1.0 : 0.55
                                onClicked: root.addAssignment()
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                SectionFrame {
                    Layout.fillWidth: true
                    implicitHeight: 520

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10
                        Text { text: "Active assignments"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }
                        SearchField {
                            Layout.fillWidth: true
                            placeholderText: "Search assignments by title or description"
                            text: root.assignmentSearchText
                            onTextChanged: root.assignmentSearchText = text
                        }

                        ScrollView {
                            id: activeAssignmentsScroll
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            ScrollBar.vertical: StyledScrollBar {}

                            Column {
                                width: (activeAssignmentsScroll.availableWidth > 0 ? activeAssignmentsScroll.availableWidth : activeAssignmentsScroll.width)
                                spacing: 10

                                Rectangle {
                                    width: parent.width
                                    visible: assignmentOptionsForClass(root.createAssignmentClassId).length === 0
                                    height: visible ? 84 : 0
                                    radius: 14
                                    color: "#F8FAFC"
                                    border.width: visible ? 1 : 0
                                    border.color: line

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text { text: "No assignments yet for this class"; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold }
                                        Text { text: "Create the first assignment from the card above."; color: muted; font.pixelSize: 11 }
                                    }
                                }

                                Repeater {
                                    model: assignmentsModel
                                    delegate: Rectangle {
                                        readonly property bool matchesClass: classId === root.createAssignmentClassId
                                        readonly property bool matchesSearchRow: root.matchesSearch(title + " " + description + " " + dueText, root.assignmentSearchText)
                                        width: parent.width
                                        visible: matchesClass && matchesSearchRow
                                        height: visible ? 124 : 0
                                        radius: 15
                                        color: "#F8FAFC"
                                        border.width: visible ? 1 : 0
                                        border.color: line

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 4
                                                Text { text: title; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                                Text { text: classNameById(classId) + " • Due " + formatDateTimePretty(dueText); color: muted; font.pixelSize: 11; elide: Text.ElideRight }
                                                Text { text: description; color: muted2; font.pixelSize: 11; wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideRight; Layout.fillWidth: true }
                                            }

                                            ColumnLayout {
                                                width: Math.min(210, parent.width * 0.34)
                                                spacing: 6
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 6
                                                    Badge { textValue: status; bgColor: status === "Open" ? greenSoft : amberSoft; fgColor: status === "Open" ? green : amber }
                                                    Badge { textValue: submissions + "/" + totalStudents + " turned in"; bgColor: blueSoft; fgColor: blue }
                                                }
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 6
                                                    Badge { textValue: aiEnabled ? "AI on" : "AI off"; bgColor: aiEnabled ? violetSoft : redSoft; fgColor: aiEnabled ? indigo700 : red }
                                                    ActionButton { text: status === "Open" ? "Close" : "Reopen"; kind: "ghost"; onClicked: root.toggleAssignmentStatus(assignmentId) }
                                                    ActionButton { text: "Delete"; kind: "ghost"; onClicked: root.deleteAssignment(assignmentId) }
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
        }
    }

    Component {
        id: studentsPage
        Flickable {
            contentWidth: width
            contentHeight: studentsCol.implicitHeight
            clip: true

            ColumnLayout {
                id: studentsCol
                width: parent.width
                spacing: 14

                PageHeader { title: "Class roster"; iconText: "👥" }

                SectionFrame {
                    visible: classesModel.count === 0
                    Layout.fillWidth: true
                    implicitHeight: visible ? 92 : 0
                    ColumnLayout { anchors.centerIn: parent; spacing: 4
                        Text { text: "No classes available yet"; color: ink; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text { text: "Create a class first, then students will appear here."; color: muted; font.pixelSize: 11 }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    SectionFrame {
                        Layout.fillWidth: true
                        implicitHeight: 590

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            LabeledCombo {
                                label: "Class"
                                model: classesModel
                                currentIndex: Math.max(0, classIndexById(root.studentsClassId))
                                textRole: "name"
                                onChosen: if (index >= 0) root.studentsClassId = classesModel.get(index).classId
                            }

                            Text { text: "Active and inactive students"; color: ink; font.pixelSize: 15; font.weight: Font.DemiBold }
                            SearchField {
                                Layout.fillWidth: true
                                placeholderText: "Search students by name, status or grade"
                                text: root.studentSearchText
                                onTextChanged: root.studentSearchText = text
                            }

                            ScrollView {
                                id: studentsActiveScroll
                                LayoutMirroring.enabled: false
                                ScrollBar.vertical: StyledScrollBar { }
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                Column {
                                    width: (studentsActiveScroll.availableWidth > 0 ? studentsActiveScroll.availableWidth : studentsActiveScroll.width)
                                    spacing: 10

                                    Rectangle {
                                        width: parent.width
                                        visible: countStudentsByClass(root.studentsClassId) === 0
                                        height: visible ? 84 : 0
                                        radius: 14
                                        color: "#F8FAFC"
                                        border.width: visible ? 1 : 0
                                        border.color: line

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text { text: "No students in this class"; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter }
                                            Text { text: "Choose another class or add students later."; color: muted; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
                                        }
                                    }

                                    Repeater {
                                        model: studentsModel
                                        delegate: Rectangle {
                                            readonly property bool matchesClass: classId === root.studentsClassId
                                            readonly property bool matchesSearchRow: root.matchesSearch(name + " " + status + " " + grade + " " + lastSubmission, root.studentSearchText)
                                            width: parent.width
                                            visible: matchesClass && matchesSearchRow
                                            height: visible ? 68 : 0
                                            radius: 14
                                            color: "#F8FAFC"
                                            border.width: matchesClass ? 1 : 0
                                            border.color: line

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 12

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    Text { Layout.fillWidth: true; text: name; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; horizontalAlignment: Text.AlignLeft }
                                                    Text { Layout.fillWidth: true; text: lastSubmission && lastSubmission.length > 0 ? formatDateTimePretty(lastSubmission) : "No submissions yet"; color: muted; font.pixelSize: 11; elide: Text.ElideRight; horizontalAlignment: Text.AlignLeft }
                                                }

                                                RowLayout {
                                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                    spacing: 8
                                                    Badge { textValue: status; bgColor: status === "Active" ? greenSoft : redSoft; fgColor: status === "Active" ? green : red }
                                                    Badge { textValue: "Avg " + grade; bgColor: blueSoft; fgColor: blue }
                                                    ActionButton { text: status === "Active" ? "Deactivate" : "Activate"; kind: "ghost"; onClicked: root.toggleStudentStatus(studentId) }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    SectionFrame {
                        Layout.fillWidth: true
                        implicitHeight: 590

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10
                            Text { text: "Pending approvals"; color: ink; font.pixelSize: 15; font.weight: Font.DemiBold }

                            ScrollView {
                                id: studentsPendingScroll
                                LayoutMirroring.enabled: false
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                ScrollBar.vertical: StyledScrollBar {}
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                                Column {
                                    width: (studentsPendingScroll.availableWidth > 0 ? studentsPendingScroll.availableWidth : studentsPendingScroll.width)
                                    spacing: 10

                                    Rectangle {
                                        width: parent.width
                                        visible: countPendingStudentsByClass(root.studentsClassId) === 0
                                        height: visible ? 84 : 0
                                        radius: 14
                                        color: "#F8FAFC"
                                        border.width: visible ? 1 : 0
                                        border.color: line

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text { text: "No students are waiting for approval"; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter }
                                            Text { text: "Switch classes or come back later."; color: muted; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
                                        }
                                    }

                                    Repeater {
                                        model: pendingStudentsModel
                                        delegate: Rectangle {
                                            readonly property bool matchesClass: classId === root.studentsClassId
                                            width: parent.width
                                            visible: matchesClass
                                            height: matchesClass ? 70 : 0
                                            radius: 14
                                            color: "#F8FAFC"
                                            border.width: matchesClass ? 1 : 0
                                            border.color: line

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 10
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 3
                                                    Text { text: name; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold }
                                                    Text { text: "Requested: " + requestedAt; color: muted; font.pixelSize: 11 }
                                                }
                                                Item { Layout.fillWidth: true }
                                                ActionButton { text: "Approve"; onClicked: root.approvePendingStudent(requestId) }
                                                ActionButton { text: "Reject"; kind: "ghost"; onClicked: root.rejectPendingStudent(requestId) }
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
    }

    Component {
        id: materialsPage
        Flickable {
            contentWidth: width
            contentHeight: materialsCol.implicitHeight
            clip: true

            ColumnLayout {
                id: materialsCol
                width: parent.width
                spacing: 14

                PageHeader { title: "Materials"; iconText: "📂" }

                SectionFrame {
                    visible: classesModel.count === 0
                    Layout.fillWidth: true
                    implicitHeight: visible ? 92 : 0
                    ColumnLayout { anchors.centerIn: parent; spacing: 4
                        Text { text: "No classes available yet"; color: ink; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text { text: "Create a class first to upload learning materials."; color: muted; font.pixelSize: 11 }
                    }
                }

                SectionFrame {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(590, root.height * 0.39)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        Text { text: "Upload new material"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }

                        LabeledCombo {
                            label: "Class"
                            model: classesModel
                            currentIndex: Math.max(0, classIndexById(root.materialsTargetClassId))
                            textRole: "name"
                            onChosen: if (index >= 0) root.materialsTargetClassId = classesModel.get(index).classId
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 48
                            radius: 14
                            color: "#F8FAFC"
                            border.width: 1
                            border.color: line
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10
                                Text { text: "Detected type"; color: muted; font.pixelSize: 11; font.weight: Font.Medium }
                                Badge { textValue: root.materialType; bgColor: violetSoft; fgColor: indigo700 }
                                Text { Layout.fillWidth: true; text: root.materialFileName.length > 0 ? "Detected automatically from the selected file" : "Choose a file and the type will be detected automatically"; color: muted2; font.pixelSize: 11; elide: Text.ElideRight }
                            }
                        }

                        InputField { label: "Title"; placeholder: "Example: Lesson summary"; text: root.materialTitle; onTextChanged: root.materialTitle = text }
                        AreaField { label: "Description"; placeholder: "Describe the material for the class"; text: root.materialDescription; onTextChanged: root.materialDescription = text; implicitHeight: 140 }

                        Text { text: "File limit: up to 25MB - For multiple files, upload one ZIP"; color: muted; font.pixelSize: 11 }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 54
                            radius: 14
                            color: "#F8FAFC"
                            border.width: 1
                            border.color: line

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8
                                Text { Layout.fillWidth: true; text: root.materialFileName.length > 0 ? root.materialFileName : "No file selected"; color: root.materialFileName.length > 0 ? ink : muted2; font.pixelSize: 12; elide: Text.ElideRight }
                                ActionButton { text: "Browse"; kind: "ghost"; onClicked: root.openFilePicker("material") }
                                ActionButton { text: "Remove"; kind: "ghost"; enabled: root.materialFileName.length > 0; onClicked: root.clearMaterialAttachment() }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            ActionButton { text: "Upload material"; onClicked: root.addMaterial() }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                SectionFrame {
                    Layout.fillWidth: true
                    implicitHeight: 460

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        Text { text: "Existing materials"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }
                        SearchField {
                            Layout.fillWidth: true
                            placeholderText: "Search materials by title, type or description"
                            text: root.materialSearchText
                            onTextChanged: root.materialSearchText = text
                        }

                        ScrollView {
                            id: existingMaterialsScroll
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            ScrollBar.vertical: StyledScrollBar {}

                            Column {
                                width: (existingMaterialsScroll.availableWidth > 0 ? existingMaterialsScroll.availableWidth : existingMaterialsScroll.width)
                                spacing: 10

                                Rectangle {
                                    width: parent.width
                                    visible: countMaterialsByClass(root.materialsTargetClassId) === 0
                                    height: visible ? 84 : 0
                                    radius: 14
                                    color: "#F8FAFC"
                                    border.width: visible ? 1 : 0
                                    border.color: line

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text { text: "No materials yet for this class"; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter }
                                        Text { text: "Upload the first file from the card above."; color: muted; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
                                    }
                                }

                                Repeater {
                                    model: materialsModel
                                    delegate: Rectangle {
                                        readonly property bool matchesClass: classId === root.materialsTargetClassId
                                        readonly property bool matchesSearchRow: root.matchesSearch(title + " " + type + " " + description + " " + by, root.materialSearchText)
                                        width: parent.width
                                        visible: matchesClass && matchesSearchRow
                                        height: visible ? 94 : 0
                                        radius: 14
                                        color: "#F8FAFC"
                                        border.width: matchesClass ? 1 : 0
                                        border.color: line

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 3
                                                Text { text: title; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                                Text { text: by + " • " + whenText; color: muted; font.pixelSize: 11; elide: Text.ElideRight }
                                            }

                                            RowLayout {
                                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                spacing: 8
                                                Badge { textValue: type; bgColor: violetSoft; fgColor: indigo700 }
                                                ActionButton { text: "Download"; kind: "ghost"; onClicked: root.openMaterialViewer(materialId) }
                                                ActionButton { text: "Delete"; kind: "ghost"; onClicked: root.deleteMaterial(materialId) }
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
    }

    Component {
        id: submissionsPage
        Flickable {
            contentWidth: width
            contentHeight: subCol.implicitHeight
            clip: true

            ColumnLayout {
                id: subCol
                width: parent.width
                spacing: 14

                PageHeader { title: "Submission review"; iconText: "🤖" }

                SectionFrame {
                    visible: classesModel.count === 0
                    Layout.fillWidth: true
                    implicitHeight: visible ? 92 : 0
                    ColumnLayout { anchors.centerIn: parent; spacing: 4
                        Text { text: "No classes available yet"; color: ink; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text { text: "Create a class and assignments to start reviewing submissions."; color: muted; font.pixelSize: 11 }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    SectionFrame {
                        Layout.fillWidth: true
                        implicitHeight: 650

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            LabeledCombo {
                                label: "Class"
                                model: classesModel
                                currentIndex: Math.max(0, classIndexById(root.submissionsClassId))
                                textRole: "name"
                                onChosen: {
                                    if (index >= 0) {
                                        root.submissionsClassId = classesModel.get(index).classId
                                        root.submissionsAssignmentId = -1
                                        root.selectedSubmissionId = -1
                                        root.reviewTeacherNote = ""
                                        root.reviewFinalGrade = ""
                                    }
                                }
                            }

                            LabeledCombo {
                                label: "Assignment"
                                model: assignmentOptionsForClass(root.submissionsClassId)
                                textRole: "name"
                                currentIndex: assignmentIndexForClassAndId(root.submissionsClassId, root.submissionsAssignmentId)
                                onChosen: {
                                    var options = assignmentOptionsForClass(root.submissionsClassId)
                                    if (index >= 0 && index < options.length) {
                                        root.submissionsAssignmentId = options[index].assignmentId
                                        root.selectedSubmissionId = -1
                                        root.reviewTeacherNote = ""
                                        root.reviewFinalGrade = ""
                                    }
                                }
                            }

                            Text { text: "Submissions"; color: ink; font.pixelSize: 15; font.weight: Font.DemiBold }
                            SearchField {
                                Layout.fillWidth: true
                                placeholderText: "Search student submissions"
                                text: root.submissionSearchText
                                onTextChanged: root.submissionSearchText = text
                            }

                            ScrollView {
                                id: submissionsListScroll
                                LayoutMirroring.enabled: false
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                ScrollBar.vertical: StyledScrollBar {}
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                                Column {
                                    width: (submissionsListScroll.availableWidth > 0 ? submissionsListScroll.availableWidth : submissionsListScroll.width)
                                    spacing: 10

                                    Rectangle {
                                        width: parent.width
                                        visible: submissionRowsForSelection(root.submissionsClassId, root.submissionsAssignmentId).length === 0
                                        height: visible ? 92 : 0
                                        radius: 14
                                        color: "#F8FAFC"
                                        border.width: visible ? 1 : 0
                                        border.color: line

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text { text: "No submissions for this assignment"; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter }
                                            Text { text: "Choose another assignment or wait for students to submit."; color: muted; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
                                        }
                                    }

                                    Repeater {
                                        model: submissionsModel
                                        delegate: Rectangle {
                                            readonly property bool matchesSelection: classId === root.submissionsClassId && assignmentId === root.submissionsAssignmentId
                                            readonly property bool matchesSearchRow: root.matchesSearch(student + " " + submittedAt + " " + fileName + " " + aiText + " " + teacherText, root.submissionSearchText)
                                            width: parent.width
                                            visible: matchesSelection && matchesSearchRow
                                            height: visible ? 78 : 0
                                            radius: 14
                                            color: submissionId === root.selectedSubmissionId ? "#EEF2FF" : "#F8FAFC"
                                            border.width: matchesSelection ? 1 : 0
                                            border.color: submissionId === root.selectedSubmissionId ? "#C7D2FE" : line

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 10

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 3
                                                    Text { text: student; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold }
                                                    Text { text: formatDateTimePretty(submittedAt); color: muted; font.pixelSize: 11 }
                                                }

                                                RowLayout {
                                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                    spacing: 6
                                                    Badge { textValue: aiEnabled ? ("AI " + aiGrade) : "AI off"; bgColor: violetSoft; fgColor: indigo700 }
                                                    Badge { textValue: "Final " + finalGrade; bgColor: greenSoft; fgColor: green }
                                                    Badge { textValue: teacherEdited ? "Reviewed" : "Pending"; bgColor: teacherEdited ? blueSoft : amberSoft; fgColor: teacherEdited ? blue : amber }
                                                }
                                            }

                                            MouseArea { anchors.fill: parent; onClicked: root.selectSubmission(submissionId) }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    SectionFrame {
                        Layout.fillWidth: true
                        implicitHeight: 650
                        enabled: root.selectedSubmissionId > 0
                        opacity: enabled ? 1.0 : 0.58

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            Text { text: submissionById(root.selectedSubmissionId) ? (submissionById(root.selectedSubmissionId).student + " review") : "Select a submission to start reviewing"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 78
                                radius: 14
                                color: "#F8FAFC"
                                border.width: 1
                                border.color: line

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 3
                                    Text { text: submissionById(root.selectedSubmissionId) ? submissionById(root.selectedSubmissionId).fileName : "No submission selected"; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold }
                                    Text { text: submissionById(root.selectedSubmissionId) ? ((submissionById(root.selectedSubmissionId).aiEnabled ? ("AI score: " + submissionById(root.selectedSubmissionId).aiGrade) : "AI disabled") + " • Final: " + submissionById(root.selectedSubmissionId).finalGrade) : "Click a student submission on the left to enable this panel."; color: muted; font.pixelSize: 11; wrapMode: Text.WrapAnywhere }
                                }
                            }

                            Rectangle {
                                id: aiFeedbackPanel
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredHeight: 180
                                radius: 14
                                color: "#F8FAFC"
                                border.width: 1
                                border.color: line
                                readonly property var selectedSubmission: root.submissionById(root.selectedSubmissionId)
                                readonly property string feedbackText: aiFeedbackPanel.selectedSubmission ? (aiFeedbackPanel.selectedSubmission.aiText || "No AI feedback yet") : "Select a submission to view AI feedback."
                                readonly property bool feedbackIsRtl: root.hasHebrewText(aiFeedbackPanel.feedbackText)

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 6
                                    Text {
                                        Layout.fillWidth: true
                                        text: "AI feedback"
                                        color: ink
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        horizontalAlignment: aiFeedbackPanel.feedbackIsRtl ? Text.AlignRight : Text.AlignLeft
                                    }
                                    ScrollView {
                                        LayoutMirroring.enabled: aiFeedbackPanel.feedbackIsRtl
                                        LayoutMirroring.childrenInherit: true
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        ScrollBar.vertical: StyledScrollBar {}
                                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                        Text {
                                            width: Math.max(0, (parent.availableWidth > 0 ? parent.availableWidth : parent.width) - 2)
                                            text: root.rtlWrappedText(aiFeedbackPanel.feedbackText)
                                            color: muted
                                            font.pixelSize: 11
                                            textFormat: Text.PlainText
                                            wrapMode: Text.WrapAnywhere
                                            horizontalAlignment: aiFeedbackPanel.feedbackIsRtl ? Text.AlignRight : Text.AlignLeft
                                        }
                                    }
                                }
                            }

                            AreaField { enabled: root.selectedSubmissionId > 0; label: "Teacher feedback"; placeholder: "Write feedback"; text: root.reviewTeacherNote; onTextChanged: root.reviewTeacherNote = text; implicitHeight: 170 }
                            InputField { enabled: root.selectedSubmissionId > 0; label: "Final grade"; placeholder: "0-100"; text: root.reviewFinalGrade; onTextChanged: { var normalized = normalizeGradeInput(text); if (normalized !== text) root.reviewFinalGrade = normalized; else root.reviewFinalGrade = text } }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                ActionButton { enabled: root.selectedSubmissionId > 0; text: "Download submission"; kind: "ghost"; onClicked: root.openSubmissionViewer() }
                                ActionButton { enabled: root.selectedSubmissionId > 0; text: "Save review"; onClicked: root.saveSubmissionReview() }
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: gradesPage
        Flickable {
            contentWidth: width
            contentHeight: gradesCol.implicitHeight
            clip: true

            ColumnLayout {
                id: gradesCol
                width: parent.width
                spacing: 14

                PageHeader { title: "Gradebook"; iconText: "📊" }

                SectionFrame {
                    visible: classesModel.count === 0
                    Layout.fillWidth: true
                    implicitHeight: visible ? 92 : 0
                    ColumnLayout { anchors.centerIn: parent; spacing: 4
                        Text { text: "No classes available yet"; color: ink; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text { text: "Create a class and assignments to see grades here."; color: muted; font.pixelSize: 11 }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    SectionFrame {
                        Layout.fillWidth: true
                        implicitHeight: 540

                        ColumnLayout {
                            id: gradesLeftColumn
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10
                            readonly property var rows: gradeRowsForSelection(root.gradesClassId, root.gradesAssignmentId)

                            LabeledCombo {
                                label: "Class"
                                model: classesModel
                                currentIndex: Math.max(0, classIndexById(root.gradesClassId))
                                textRole: "name"
                                onChosen: {
                                    if (index >= 0) {
                                        root.gradesClassId = classesModel.get(index).classId
                                        root.gradesAssignmentId = firstAssignmentIdForClass(root.gradesClassId)
                                        root.selectedGradeId = -1
                                        root.gradeEditValue = ""
                                    }
                                }
                            }

                            LabeledCombo {
                                label: "Assignment"
                                model: assignmentOptionsForClass(root.gradesClassId)
                                textRole: "name"
                                currentIndex: assignmentIndexForClassAndId(root.gradesClassId, root.gradesAssignmentId)
                                onChosen: {
                                    var options = assignmentOptionsForClass(root.gradesClassId)
                                    if (index >= 0 && index < options.length) {
                                        root.gradesAssignmentId = options[index].assignmentId
                                        root.selectedGradeId = -1
                                        root.gradeEditValue = ""
                                    }
                                }
                            }

                            Text { text: "Grades list"; color: ink; font.pixelSize: 15; font.weight: Font.DemiBold }

                            ScrollView {
                                id: gradesListScroll
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                Column {
                                    width: (gradesListScroll.availableWidth > 0 ? gradesListScroll.availableWidth : gradesListScroll.width)
                                    spacing: 10

                                    Rectangle {
                                        width: parent.width
                                        visible: gradesLeftColumn.rows.length === 0
                                        height: visible ? 92 : 0
                                        radius: 14
                                        color: "#F8FAFC"
                                        border.width: visible ? 1 : 0
                                        border.color: line

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text { text: "No grades for this assignment"; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter }
                                            Text { text: "Choose another assignment or wait for submissions to be reviewed."; color: muted; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
                                        }
                                    }

                                    Repeater {
                                        model: gradesLeftColumn.rows
                                        delegate: Rectangle {
                                            width: parent.width
                                            height: 68
                                            radius: 14
                                            color: modelData.gradeId === root.selectedGradeId ? "#EEF2FF" : "#F8FAFC"
                                            border.width: 1
                                            border.color: modelData.gradeId === root.selectedGradeId ? "#C7D2FE" : line

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 10

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 3
                                                    Text { text: modelData.student; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                                    Text { text: "Assignment #" + modelData.assignmentId; color: muted; font.pixelSize: 11; elide: Text.ElideRight }
                                                }

                                                RowLayout {
                                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                    spacing: 6
                                                    Badge { textValue: "AI " + modelData.aiGrade; bgColor: violetSoft; fgColor: indigo700 }
                                                    Badge { textValue: "Final " + modelData.finalGrade; bgColor: greenSoft; fgColor: green }
                                                    Badge { textValue: modelData.reviewed ? "Reviewed" : "Pending"; bgColor: modelData.reviewed ? blueSoft : amberSoft; fgColor: modelData.reviewed ? blue : amber }
                                                }
                                            }

                                            MouseArea { anchors.fill: parent; onClicked: root.selectGrade(modelData.gradeId) }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    SectionFrame {
                        Layout.fillWidth: true
                        implicitHeight: 540

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            Text {
                                Layout.fillWidth: true
                                text: gradeById(root.selectedGradeId) ? (gradeById(root.selectedGradeId).student + " grade") : "Select a grade"
                                color: ink
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 86
                                radius: 14
                                color: "#F8FAFC"
                                border.width: 1
                                border.color: line

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 4
                                    Text {
                                        Layout.fillWidth: true
                                        text: gradeById(root.selectedGradeId) ? ("Assignment #" + gradeById(root.selectedGradeId).assignmentId) : "Assignment -"
                                        color: ink
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: gradeById(root.selectedGradeId) ? ("Student: " + gradeById(root.selectedGradeId).student) : "Student -"
                                        color: muted
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: gradeById(root.selectedGradeId) ? ("AI grade: " + gradeById(root.selectedGradeId).aiGrade) : "AI grade -"
                                        color: muted
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            InputField { label: "Edit final grade"; text: root.gradeEditValue; onTextChanged: { var normalized = normalizeGradeInput(text); if (normalized !== text) root.gradeEditValue = normalized; else root.gradeEditValue = text } }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                ActionButton { text: "Save grade"; onClicked: root.saveGradeEdit() }
                                ActionButton { text: "Reset"; kind: "ghost"; onClicked: root.selectGrade(root.selectedGradeId) }
                                Item { Layout.fillWidth: true }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 14
                                color: gradeById(root.selectedGradeId) ? "#F8FAFC" : "#FBFCFF"
                                border.width: 1
                                border.color: line

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 6
                                    Text { text: "Grade details"; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold }
                                    Text {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WrapAnywhere
                                        text: gradeById(root.selectedGradeId)
                                              ? ("Review status: " + (gradeById(root.selectedGradeId).reviewed ? "Reviewed" : "Pending") + "\nFinal grade: " + gradeById(root.selectedGradeId).finalGrade + "\nAI grade: " + gradeById(root.selectedGradeId).aiGrade)
                                              : "Choose a grade from the left to activate this panel."
                                        color: gradeById(root.selectedGradeId) ? muted : muted2
                                        font.pixelSize: 12
                                    }
                                    Item { Layout.fillHeight: true }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: messagesPage
        Flickable {
            contentWidth: width
            contentHeight: msgCol.implicitHeight
            clip: true

            ColumnLayout {
                id: msgCol
                width: parent.width
                spacing: 14

                PageHeader { title: "Messages"; iconText: "📣" }

                SectionFrame {
                    visible: classesModel.count === 0
                    Layout.fillWidth: true
                    implicitHeight: visible ? 92 : 0
                    ColumnLayout { anchors.centerIn: parent; spacing: 4
                        Text { text: "No classes available yet"; color: ink; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text { text: "Create a class first to send messages."; color: muted; font.pixelSize: 11 }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    SectionFrame {
                        Layout.fillWidth: true
                        implicitHeight: 540
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            LabeledCombo {
                                label: "Send to class"
                                model: classesModel
                                currentIndex: Math.max(0, classIndexById(root.messageTargetClassId))
                                textRole: "name"
                                onChosen: if (index >= 0) root.messageTargetClassId = classesModel.get(index).classId
                            }
                            InputField { label: "Subject"; placeholder: "Example: Reminder for tomorrow"; text: root.messageSubject; onTextChanged: root.messageSubject = text }
                            AreaField { label: "Message body"; placeholder: "Write your message here"; text: root.messageBody; onTextChanged: root.messageBody = text }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                ActionButton { text: "Send"; onClicked: root.saveMessage("Sent") }
                                ActionButton { text: "Save draft"; kind: "ghost"; onClicked: root.saveMessage("Draft") }
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }

                    SectionFrame {
                        Layout.fillWidth: true
                        implicitHeight: 540
                        Item {
                            anchors.fill: parent
                            anchors.margins: 16

                            Text {
                                id: recentMessagesTitle
                                text: "Recent messages"
                                color: ink
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                anchors.top: parent.top
                                anchors.left: parent.left
                            }

                            SearchField {
                                id: messagesSearchField
                                anchors.top: recentMessagesTitle.bottom
                                anchors.topMargin: 10
                                anchors.left: parent.left
                                anchors.right: parent.right
                                placeholderText: "Search messages by subject or text"
                                text: root.messageSearchText
                                onTextChanged: root.messageSearchText = text
                            }

                            Flickable {
                                id: recentMessagesFlick
                                anchors.top: messagesSearchField.bottom
                                anchors.topMargin: 12
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                clip: true
                                contentWidth: width
                                contentHeight: recentMessagesColumn.height
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: StyledScrollBar { policy: ScrollBar.AsNeeded }

                                Column {
                                    id: recentMessagesColumn
                                    width: Math.max(0, recentMessagesFlick.width - 12)
                                    spacing: 12

                                    Rectangle {
                                        width: recentMessagesColumn.width
                                        visible: messageRows().length === 0
                                        height: visible ? 84 : 0
                                        radius: 14
                                        color: "#F8FAFC"
                                        border.width: visible ? 1 : 0
                                        border.color: line

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text { text: "No messages yet"; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold }
                                            Text { text: "Sent and draft messages will appear here."; color: muted; font.pixelSize: 11 }
                                        }
                                    }

                                    Repeater {
                                        model: messageRows()
                                        delegate: Rectangle {
                                            width: recentMessagesColumn.width
                                            readonly property bool matchesSearchRow: root.matchesSearch(modelData.subject + " " + modelData.body + " " + modelData.className, root.messageSearchText)
                                            visible: matchesSearchRow
                                            implicitHeight: matchesSearchRow ? 76 : 0
                                            radius: 14
                                            color: "#F8FAFC"
                                            border.width: 1
                                            border.color: line
                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 5

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8
                                                    Text { Layout.fillWidth: true; text: modelData.subject; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                                    Badge { textValue: modelData.state; bgColor: modelData.state === "Sent" ? greenSoft : amberSoft; fgColor: modelData.state === "Sent" ? green : amber }
                                                    ActionButton {
                                                        text: "Open"
                                                        kind: "ghost"
                                                        onClicked: {
                                                            root.selectedMaterialTitle = modelData.subject
                                                            root.selectedMaterialMeta = modelData.className + " • " + modelData.createdAtPretty + " • " + modelData.state
                                                            root.selectedMaterialDescription = modelData.body
                                                            messageDialog.open()
                                                        }
                                                    }
                                                    ActionButton { text: "Delete"; kind: "ghost"; onClicked: root.deleteMessage(modelData.messageId) }
                                                }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8
                                                    Text { Layout.fillWidth: true; text: modelData.className; color: muted; font.pixelSize: 11; elide: Text.ElideRight; verticalAlignment: Text.AlignTop }
                                                    Text { text: modelData.createdAtPretty; color: muted; font.pixelSize: 11; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignTop; Layout.rightMargin: 8 }
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
        }
    }

    Component {
        id: reportsPage
        Flickable {
            contentWidth: width
            contentHeight: repCol.implicitHeight
            clip: true

            ColumnLayout {
                id: repCol
                width: parent.width
                spacing: 14

                PageHeader { title: "Reports"; iconText: "📈" }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    SectionFrame {
                        Layout.fillWidth: true
                        implicitHeight: 380
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10
                            Text { text: "System summary"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }
                            ReportLine { label: "Classes"; value: classesModel.count.toString() }
                            ReportLine { label: "Students"; value: totalStudentsAll().toString() }
                            ReportLine { label: "Assignments"; value: assignmentsModel.count.toString() }
                            ReportLine { label: "Materials"; value: materialsModel.count.toString() }
                            ReportLine { label: "Saved messages"; value: messageLogModel.count.toString() }
                            ReportLine { label: "Pending approvals"; value: pendingStudentsModel.count.toString() }
                        }
                    }

                    SectionFrame {
                        Layout.fillWidth: true
                        implicitHeight: 380
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10
                            Text { text: "Useful insights"; color: ink; font.pixelSize: 16; font.weight: Font.DemiBold }
                            ReportLine { label: "Open assignments"; value: countOpenAssignments().toString() }
                            ReportLine { label: "Reviewed grades"; value: (gradesModel.count - countUnreviewedGrades()).toString() }
                            ReportLine { label: "Unreviewed grades"; value: countUnreviewedGrades().toString() }
                            ReportLine { label: "AI-enabled tasks"; value: countAiEnabledAssignments().toString() }
                            ReportLine { label: "Best class"; value: topClassByAverage() ? topClassByAverage().name : "-" }
                            ReportLine { label: "Busiest class"; value: busiestClassByOpenAssignments() ? busiestClassByOpenAssignments().name : "-" }
                        }
                    }
                }
            }

        }
    }

    component ReportLine : Rectangle {
        property string label: ""
        property string value: ""
        Layout.fillWidth: true
        implicitHeight: 42
        radius: 12
        color: "#F8FAFC"
        border.width: 1
        border.color: line
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            Text { Layout.fillWidth: true; text: label; color: muted; font.pixelSize: 12 }
            Text { text: value; color: ink; font.pixelSize: 13; font.weight: Font.DemiBold }
        }
    }

    component StyledScrollBar : ScrollBar {
        id: sb
        LayoutMirroring.enabled: false
        hoverEnabled: true
        interactive: true
        policy: ScrollBar.AsNeeded
        minimumSize: 0.14
        visible: size < 1.0
        z: 50

        padding: 0
        topPadding: 0
        bottomPadding: 0
        leftPadding: 0
        rightPadding: 0

        implicitWidth: sb.orientation === Qt.Vertical ? 10 : 10
        implicitHeight: sb.orientation === Qt.Horizontal ? 10 : 10
        width: sb.orientation === Qt.Vertical ? 10 : (parent ? parent.width : 10)
        height: sb.orientation === Qt.Horizontal ? 10 : (parent ? parent.height : 10)

        anchors {
            right: sb.orientation === Qt.Vertical && parent ? parent.right : undefined
            left: sb.orientation === Qt.Horizontal && parent ? parent.left : undefined
            top: parent ? parent.top : undefined
            bottom: parent ? parent.bottom : undefined
            rightMargin: 0
            leftMargin: 0
            topMargin: 0
            bottomMargin: 0
        }

        contentItem: Item {
            implicitWidth: sb.orientation === Qt.Vertical ? 10 : 72
            implicitHeight: sb.orientation === Qt.Horizontal ? 10 : 72

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 4
                color: sb.pressed ? "#4338CA" : "#6366F1"
                opacity: (sb.hovered || sb.active || sb.pressed) ? 0.98 : 0.78
            }
        }

        background: Item {
            Rectangle {
                anchors.fill: parent
                radius: 5
                color: "#EEF2FF"
                border.width: 1
                border.color: "#D9E0FF"
                opacity: sb.size < 1.0 ? 0.95 : 0.0
            }
        }
    }

    component SearchField : Rectangle {
        property alias text: searchInput.text
        property string placeholderText: "Search"
        Layout.fillWidth: true
        implicitHeight: 48
        radius: 14
        color: "#F8FAFC"
        border.width: 1
        border.color: line
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8
            Text { text: "🔎"; font.pixelSize: 14 }
            TextField {
                id: searchInput
                Layout.fillWidth: true
                placeholderText: parent.parent.placeholderText
                background: null
                color: ink
                font.pixelSize: 12
                selectByMouse: true
            }
        }
    }

    component DateTimeSpin : ColumnLayout {
        id: dt
        property string label: ""
        property int from: 0
        property int to: 100
        property int value: 0
        signal valueModified(int value)
        spacing: 5
        Layout.fillWidth: true

        function formatValue(v) {
            return dt.label === "Year" ? ("" + v) : (v < 10 ? "0" + v : "" + v)
        }

        function normalizeValue(rawText) {
            var cleaned = (rawText || "").replace(/[^0-9]/g, "")
            if (cleaned.length === 0)
                return dt.value
            var parsed = parseInt(cleaned, 10)
            if (isNaN(parsed))
                return dt.value
            if (parsed < dt.from)
                parsed = dt.from
            if (parsed > dt.to)
                parsed = dt.to
            return parsed
        }

        function commitEditor() {
            var nextValue = normalizeValue(editor.text)
            if (nextValue !== dt.value) {
                dt.value = nextValue
                dt.valueModified(nextValue)
            }
            editor.text = formatValue(dt.value)
        }

        function stepBy(delta) {
            commitEditor()
            var nextValue = dt.value + delta
            if (nextValue < dt.from)
                nextValue = dt.from
            if (nextValue > dt.to)
                nextValue = dt.to
            if (nextValue !== dt.value) {
                dt.value = nextValue
                dt.valueModified(nextValue)
            }
            editor.text = formatValue(dt.value)
        }

        Text { text: dt.label; color: muted; font.pixelSize: 11; font.weight: Font.Medium }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            radius: 14
            color: "white"
            border.width: 1
            border.color: editor.activeFocus ? indigo600 : line

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 8
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                spacing: 8

                TextField {
                    id: editor
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 0
                    implicitWidth: 0
                    maximumLength: dt.label === "Year" ? 4 : 2
                    text: dt.formatValue(dt.value)
                    background: null
                    color: ink
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    inputMethodHints: Qt.ImhDigitsOnly
                    selectByMouse: true
                    clip: true
                    onEditingFinished: dt.commitEditor()
                }

                Column {
                    spacing: 3

                    Rectangle {
                        width: 24
                        height: 14
                        radius: 7
                        color: upMouse.pressed ? "#C7D2FE" : "#EEF2FF"
                        border.width: 1
                        border.color: "#D9E0FF"
                        Text { anchors.centerIn: parent; text: "▴"; color: indigo700; font.pixelSize: 9; font.weight: Font.Bold }
                        MouseArea {
                            id: upMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dt.stepBy(1)
                        }
                    }

                    Rectangle {
                        width: 24
                        height: 14
                        radius: 7
                        color: downMouse.pressed ? "#C7D2FE" : "#EEF2FF"
                        border.width: 1
                        border.color: "#D9E0FF"
                        Text { anchors.centerIn: parent; text: "▾"; color: indigo700; font.pixelSize: 9; font.weight: Font.Bold }
                        MouseArea {
                            id: downMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dt.stepBy(-1)
                        }
                    }
                }
            }

            Connections {
                target: dt
                function onValueChanged() {
                    if (!editor.activeFocus)
                        editor.text = dt.formatValue(dt.value)
                }
            }
        }
    }
}
