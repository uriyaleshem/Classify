import { Link } from "@tanstack/react-router";
import { Button } from "@/components/ui/button";
import { Download as DownloadIcon, BookOpen, Check } from "lucide-react";

const bullets = ["Windows installer (.exe)", "Simple, guided setup", "Secure local environment"];

export function Download() {
  return (
    <section id="download" className="py-24 lg:py-32 bg-secondary/40">
      <div className="mx-auto max-w-5xl px-6">
        <div className="relative overflow-hidden rounded-3xl bg-card hairline shadow-elevated">
          <div className="absolute inset-0 bg-gradient-hero opacity-60" aria-hidden />
          <div className="relative p-10 lg:p-16 text-center">
            <h2 className="text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight text-foreground">
              Get Started in Minutes
            </h2>
            <p className="mt-4 mx-auto max-w-xl text-lg text-muted-foreground">
              Download the Classify desktop client and connect to your school's server. No accounts
              to create, no setup fees.
            </p>
            <ul className="mx-auto mt-8 inline-flex flex-col items-start gap-3 text-left">
              {bullets.map((b) => (
                <li key={b} className="flex items-center gap-3 text-sm text-foreground">
                  <span className="inline-flex h-5 w-5 items-center justify-center rounded-full bg-primary/10 text-primary">
                    <Check className="h-3 w-3" />
                  </span>
                  {b}
                </li>
              ))}
            </ul>
            <div className="mt-10 flex flex-wrap items-center justify-center gap-3">
              <Button
                size="lg"
                className="rounded-full bg-primary hover:bg-primary/90 px-6 h-12 text-base font-medium shadow-elevated"
              >
                <DownloadIcon className="mr-2 h-4 w-4" /> Download Installer
              </Button>
              <Button
                asChild
                size="lg"
                variant="outline"
                className="rounded-full h-12 px-6 text-base font-medium border-hairline bg-card hover:bg-secondary"
              >
                <Link to="/installation-guide">
                  <BookOpen className="mr-2 h-4 w-4" /> View Installation Guide
                </Link>
              </Button>
            </div>
            <p className="mt-6 text-xs text-muted-foreground">Supports Windows 10 and above</p>
          </div>
        </div>
      </div>
    </section>
  );
}
