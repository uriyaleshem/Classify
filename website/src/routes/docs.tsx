import { createFileRoute } from "@tanstack/react-router";
import {
  DocList,
  DocsLayout,
  DocSection,
  DocSteps,
  DocSubsection,
  SupportEmail,
} from "@/components/docs/DocsLayout";

export const Route = createFileRoute("/docs")({
  component: Documentation,
  head: () => ({
    meta: [
      { title: "Classify Documentation" },
      {
        name: "description",
        content:
          "Classify documentation for teachers, students, and school coordinators using the Windows desktop app.",
      },
    ],
  }),
});

function Documentation() {
  return (
    <DocsLayout
      eyebrow="Documentation"
      title="Classify Documentation"
      description="A practical guide for teachers, students, and school teams using Classify."
    >
      <DocSection title="1. Overview">
        <p>
          Classify is a Windows desktop application for schools, teachers, and students. It helps
          manage classes, assignments, submissions, grading review, feedback, study materials, and
          communication.
        </p>
        <p>Classify is designed for:</p>
        <DocList
          items={[
            "Teachers managing coursework and reviewing student work.",
            "Students submitting assignments and viewing feedback.",
            "School administrators or coordinators managing access and setup.",
          ]}
        />
        <p>Features may vary depending on your school's setup.</p>
      </DocSection>

      <DocSection title="2. Main Features">
        <p>Classify may include:</p>
        <DocList
          items={[
            "Class and course management.",
            "Assignment creation and tracking.",
            "Student submissions.",
            "AI-assisted grading suggestions.",
            "Teacher review and final grade approval.",
            "Feedback for students.",
            "Study materials and resources.",
            "Messages or communication tools.",
            "Grade overview and class progress reports, where available.",
          ]}
        />
      </DocSection>

      <DocSection title="3. User Roles">
        <DocSubsection title="Teachers">
          <p>
            Teachers can manage classes, create assignments, review submissions, edit feedback, and
            approve final grades.
          </p>
        </DocSubsection>
        <DocSubsection title="Students">
          <p>
            Students can view classes, open assignments, submit work, read feedback, check grades,
            and access study materials.
          </p>
        </DocSubsection>
        <DocSubsection title="School Administrators / Coordinators">
          <p>
            Administrators or coordinators may help distribute the app, provide login details,
            manage school access, and confirm connection settings.
          </p>
        </DocSubsection>
      </DocSection>

      <DocSection title="4. Teacher Guide">
        <DocSubsection title="Sign In">
          <DocSteps
            items={[
              "Open Classify.",
              "Enter the login details provided by your school.",
              "If requested, enter your school server address.",
              "Select Sign In.",
            ]}
          />
          <p>
            If you cannot sign in, contact your school coordinator or <SupportEmail />.
          </p>
        </DocSubsection>

        <DocSubsection title="Create or Open a Class">
          <DocSteps
            items={[
              "Go to the class or course area.",
              "Select an existing class, or choose the option to create a new class if available.",
              "Enter the class name and other required details.",
              "Save the class.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Create Assignments">
          <DocSteps
            items={[
              "Open the relevant class.",
              "Choose Create Assignment or a similar option.",
              "Add the assignment title, instructions, due date, and allowed submission details.",
              "Attach study materials if needed.",
              "Save or publish the assignment.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Review Student Submissions">
          <DocSteps
            items={[
              "Open the class.",
              "Select the assignment.",
              "Open the list of submissions.",
              "Choose a student submission to review.",
              "Read the submitted files or text.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Understand AI Score vs Final Grade">
          <p>
            Classify may provide an AI-assisted suggested score and feedback. This is intended to
            support review.
          </p>
          <p>The teacher remains responsible for:</p>
          <DocList
            items={[
              "Checking the student's work.",
              "Reviewing suggested feedback.",
              "Adjusting the score if needed.",
              "Approving the final grade.",
            ]}
          />
          <p>AI-assisted grading should not replace teacher judgment.</p>
        </DocSubsection>

        <DocSubsection title="Edit Feedback">
          <DocSteps
            items={[
              "Open the student's submission.",
              "Review the suggested or existing feedback.",
              "Edit the feedback so it is accurate and helpful.",
              "Add any additional comments if needed.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Save the Final Review">
          <DocSteps
            items={[
              "Confirm the final grade.",
              "Confirm the feedback.",
              "Select Save, Approve, or the relevant review button.",
              "Check that the submission status has updated.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Download Submissions">
          <p>If downloading is available:</p>
          <DocSteps
            items={[
              "Open the assignment.",
              "Select the submission or submissions.",
              "Choose the download option.",
              "Save the files to your computer.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Check Class Progress">
          <p>Use the class overview, assignment list, or grade overview to check:</p>
          <DocList
            items={[
              "Which students submitted work.",
              "Which submissions still need review.",
              "Published grades and feedback.",
              "Assignment progress across the class.",
            ]}
          />
        </DocSubsection>
      </DocSection>

      <DocSection title="5. Student Guide">
        <DocSubsection title="Sign In">
          <DocSteps
            items={[
              "Open Classify.",
              "Enter the username and password provided by your school or teacher.",
              "If requested, enter your school server address.",
              "Select Sign In.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Join or View Classes">
          <DocSteps
            items={[
              "Open the classes area.",
              "View the classes assigned to you.",
              "If your school uses class codes or invitations, enter the details provided by your teacher.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Open Assignments">
          <DocSteps
            items={[
              "Select a class.",
              "Open the assignment list.",
              "Choose the assignment you want to view.",
              "Read the instructions carefully before submitting work.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Submit Work">
          <DocSteps
            items={[
              "Open the assignment.",
              "Attach or enter your work as requested.",
              "Check that the correct file or text was added.",
              "Select Submit.",
              "Wait for confirmation that your submission was received.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="View Feedback">
          <DocSteps
            items={[
              "Open the class.",
              "Select the assignment.",
              "Open your submission or results area.",
              "Read the teacher's feedback.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Check Grades">
          <DocSteps
            items={[
              "Open the grades or assignment results area.",
              "Select the relevant class or assignment.",
              "Review the grade shown by your teacher.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Read Messages or Materials">
          <p>Use the messages, announcements, or materials area to view:</p>
          <DocList
            items={[
              "Teacher updates.",
              "Study resources.",
              "Assignment notes.",
              "Class instructions.",
            ]}
          />
        </DocSubsection>
      </DocSection>

      <DocSection title="6. Files and Submissions">
        <p>Classify may support different types of files, depending on school settings.</p>
        <p>Common submission types may include:</p>
        <DocList
          items={["Documents.", "Text files.", "Code files.", "Archives such as ZIP or RAR."]}
        />
        <p>
          Your school may set limits for file size, file type, or number of files. If a file cannot
          be uploaded, check the assignment instructions or contact your teacher.
        </p>
      </DocSection>

      <DocSection title="7. AI-Assisted Grading">
        <p>
          Classify may help teachers by generating a suggested score and feedback for submitted
          work.
        </p>
        <p>Important points:</p>
        <DocList
          items={[
            "AI-assisted results are suggestions.",
            "Teachers review the suggested score and feedback.",
            "Teachers can edit feedback and change grades.",
            "The final grade is controlled by the teacher.",
            "AI feedback should be treated as support, not a replacement for teacher judgment.",
          ]}
        />
      </DocSection>

      <DocSection title="8. Account and Access">
        <p>Users receive access details from their school, teacher, or administrator.</p>
        <p>You may need:</p>
        <DocList
          items={[
            "Username.",
            "Password.",
            "School name or class information.",
            "Server address, if your school uses one.",
          ]}
        />
        <p>If login fails:</p>
        <DocList
          items={[
            "Check that your username and password are correct.",
            "Confirm you are connected to the internet or school network.",
            "Confirm the server address, if required.",
          ]}
        />
        <p>
          Contact your teacher, school administrator, or <SupportEmail />.
        </p>
      </DocSection>

      <DocSection title="9. Troubleshooting">
        <DocSubsection title="Cannot Sign In">
          <DocList
            items={[
              "Check your username and password.",
              "Use Show password if available.",
              "Confirm your internet or school network connection.",
              "Ask your school to confirm your account is active.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Forgot Password">
          <DocList
            items={[
              "Contact your teacher or school administrator.",
              "Follow your school's password reset process if one is available.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Cannot Connect to Server">
          <DocList
            items={[
              "Check your internet or school network connection.",
              "Confirm the server address with your school.",
              "Try closing and reopening Classify.",
              "Contact your school coordinator if the issue continues.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="File Upload Failed">
          <DocList
            items={[
              "Check that the file type is allowed.",
              "Check that the file is not too large.",
              "Make sure the file is not open in another app.",
              "Try uploading again after reconnecting to the network.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Assignment Not Visible">
          <DocList
            items={[
              "Confirm you are signed in with the correct account.",
              "Check that you are viewing the correct class.",
              "Ask your teacher whether the assignment has been published.",
              "Refresh or reopen the app.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Grade or Feedback Not Visible">
          <DocList
            items={[
              "The teacher may not have finished reviewing the submission yet.",
              "Check the correct class and assignment.",
              "Try refreshing or reopening Classify.",
              "Contact your teacher if you believe the grade should already be available.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="App Looks Outdated or Data Is Not Refreshing">
          <DocList
            items={[
              "Check your internet or school network connection.",
              "Close and reopen Classify.",
              "Ask your school if a newer installer is available.",
              "Restart your computer if the issue continues.",
            ]}
          />
        </DocSubsection>
      </DocSection>

      <DocSection title="10. Support">
        <p>
          For help with setup, access, or technical questions, contact support at <SupportEmail />.
        </p>
      </DocSection>
    </DocsLayout>
  );
}
