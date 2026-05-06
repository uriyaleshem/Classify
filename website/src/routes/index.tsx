import { createFileRoute } from "@tanstack/react-router";
import { Header } from "@/components/landing/Header";
import { Hero } from "@/components/landing/Hero";
import { Features } from "@/components/landing/Features";
import { Screenshots } from "@/components/landing/Screenshots";
import { HowItWorks } from "@/components/landing/HowItWorks";
import { Download } from "@/components/landing/Download";
import { FAQ } from "@/components/landing/FAQ";
import { Support } from "@/components/landing/Support";
import { Footer } from "@/components/landing/Footer";

export const Route = createFileRoute("/")({
  component: Index,
  head: () => ({
    meta: [
      { title: "Classify — AI-Powered Assignment Grading & School Management" },
      {
        name: "description",
        content:
          "Automate grading, manage courses, and streamline your school workflow with secure, AI-powered tools. Built for teachers, schools, and students.",
      },
    ],
  }),
});

function Index() {
  return (
    <main className="min-h-screen bg-background text-foreground">
      <Header />
      <Hero />
      <Features />
      <Screenshots />
      <HowItWorks />
      <Download />
      <FAQ />
      <Support />
      <Footer />
    </main>
  );
}
