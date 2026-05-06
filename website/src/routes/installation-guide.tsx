import { createFileRoute } from "@tanstack/react-router";
import {
  DocList,
  DocsLayout,
  DocSection,
  DocSteps,
  DocSubsection,
  SupportEmail,
} from "@/components/docs/DocsLayout";

export const Route = createFileRoute("/installation-guide")({
  component: InstallationGuide,
  head: () => ({
    meta: [
      { title: "Classify Installation Guide" },
      {
        name: "description",
        content:
          "Step-by-step instructions for installing, launching, updating, and troubleshooting the Classify Windows desktop app.",
      },
    ],
  }),
});

function InstallationGuide() {
  return (
    <DocsLayout
      eyebrow="Installation"
      title="Classify Installation Guide"
      description="Step-by-step guidance for installing Classify on Windows and getting ready to sign in."
    >
      <DocSection title="1. Before You Begin">
        <p>Before installing Classify, make sure you have:</p>
        <DocList
          items={[
            "A Windows computer running Windows 10 or later.",
            "Internet access or access to your school network, depending on your school setup.",
            "The Classify installer file.",
            "Login details provided by your school, teacher, or administrator.",
            "A server address if your school uses a custom server.",
          ]}
        />
        <p>If you are not sure which details to use, contact your school administrator.</p>
      </DocSection>

      <DocSection title="2. Download Classify">
        <DocSteps
          items={[
            "Go to the official Classify download area on the website or follow your school's download instructions.",
            "Click the Download Installer button.",
            "Save the installer file to your computer.",
          ]}
        />
        <p>
          If your browser shows a download warning, continue only if the file came from the official
          Classify website or was provided directly by your school.
        </p>
        <p>Do not install Classify from unknown or untrusted sources.</p>
      </DocSection>

      <DocSection title="3. Install on Windows">
        <DocSteps
          items={[
            "Open the downloaded Classify installer file.",
            "If Windows asks for permission to make changes, choose Yes only if the installer came from a trusted source.",
            "Follow the setup instructions on screen.",
            "If asked, choose where to install Classify.",
            "Wait for the installation to finish.",
            "Click Finish when the setup is complete.",
            "Open Classify from the desktop shortcut or the Windows Start menu.",
          ]}
        />
      </DocSection>

      <DocSection title="4. First Launch">
        <DocSteps
          items={[
            "Open Classify.",
            "If requested, enter your school or server details.",
            "Sign in using the username and password provided by your school, teacher, or administrator.",
            "Use Show password if you need to check what you typed.",
          ]}
        />
        <p>If sign-in does not work, check that:</p>
        <DocList
          items={[
            "Your username and password are correct.",
            "You are connected to the internet or school network.",
            "The server address is correct, if one is required.",
          ]}
        />
        <p>
          If you still cannot sign in, contact your school staff or email <SupportEmail />.
        </p>
      </DocSection>

      <DocSection title="5. Updating Classify">
        <p>Your school may provide updated installers from time to time.</p>
        <DocSteps
          items={[
            "Download the latest installer from the official Classify website or from your school's instructions.",
            "Close Classify before updating.",
            "Open the new installer.",
            "Follow the setup instructions.",
            "Open Classify again after the update is complete.",
          ]}
        />
        <p>
          Your school or administrator manages your school and account access. Installing an update
          should not require creating a new account unless your school tells you otherwise.
        </p>
      </DocSection>

      <DocSection title="6. Uninstalling Classify">
        <DocSteps
          items={[
            "Open Windows Settings.",
            "Go to Apps.",
            "Find Classify in the list of installed apps.",
            "Select Uninstall.",
            "Follow the Windows prompts to complete removal.",
          ]}
        />
        <p>
          Uninstalling Classify removes the app from your computer. It may not delete school records
          or account information stored by your school.
        </p>
      </DocSection>

      <DocSection title="7. Common Installation Issues">
        <DocSubsection title="Installer Will Not Open">
          <DocList
            items={[
              "Make sure the download finished completely.",
              "Download the installer again from the official website or from your school's official instructions.",
              "Move the installer to a simple location, such as the Downloads folder.",
              "Restart your computer and try again.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Windows Security Warning">
          <DocList
            items={[
              "Check that the installer came from the official Classify website or your school.",
              "Do not continue if you are unsure where the file came from.",
              "Contact your school administrator if you need confirmation.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="App Does Not Launch">
          <DocList
            items={[
              "Restart your computer.",
              "Open Classify from the Start menu.",
              "Check whether Classify is already open in the background.",
              "Reinstall Classify using the latest installer.",
            ]}
          />
          <p>
            If the app still does not open, contact <SupportEmail />.
          </p>
        </DocSubsection>

        <DocSubsection title="Cannot Connect to Server">
          <DocList
            items={[
              "Check your internet or school network connection.",
              "Confirm the server address is correct.",
              "Make sure you are connected to the required school network, if your school requires it.",
              "Ask your school administrator whether Classify access is currently available.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Login Does Not Work">
          <DocList
            items={[
              "Check your username and password.",
              "Use Show password to confirm your password was typed correctly.",
              "Make sure you are using the login details provided by your school.",
              "Confirm the correct server address is entered, if required.",
              "Contact your teacher or school administrator to reset or confirm your account details.",
            ]}
          />
        </DocSubsection>

        <DocSubsection title="Old Version Still Opens">
          <DocList
            items={[
              "Close Classify completely.",
              "Restart your computer.",
              "Run the latest installer again.",
              "Check that you are opening Classify from the Start menu or the newest desktop shortcut.",
              "If needed, uninstall Classify and then install the latest version again.",
            ]}
          />
        </DocSubsection>
      </DocSection>

      <DocSection title="8. For School IT / Administrators">
        <p>Before sharing Classify with users:</p>
        <DocList
          items={[
            "Confirm that you are distributing the correct installer.",
            "Provide users with the correct download instructions.",
            "Confirm the correct server address and access details.",
            "Make sure users receive clear login instructions.",
            "Confirm that the school network or firewall allows Classify to connect to the school server.",
            "Test installation and sign-in on at least one Windows computer before wider distribution.",
          ]}
        />
        <p>
          If deployment issues continue, contact <SupportEmail />.
        </p>
      </DocSection>

      <DocSection title="9. Support">
        <p>
          If you need help installing or opening Classify, contact support at <SupportEmail />.
        </p>
      </DocSection>
    </DocsLayout>
  );
}
