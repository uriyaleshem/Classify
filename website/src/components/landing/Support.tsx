import { Link } from "@tanstack/react-router";
import { Button } from "@/components/ui/button";
import { Mail, FileText } from "lucide-react";

export function Support() {
  return (
    <section className="py-24 lg:py-28 bg-secondary/40">
      <div className="mx-auto max-w-4xl px-6 text-center">
        <h2 className="text-3xl sm:text-4xl font-bold tracking-tight text-foreground">
          Need Help?
        </h2>
        <p className="mt-4 mx-auto max-w-xl text-lg text-muted-foreground">
          Our team is here to help with installation, setup, and any technical questions you may
          have.
        </p>
        <div className="mt-8 grid gap-4 sm:grid-cols-3 max-w-2xl mx-auto text-left">
          {[
            { t: "Email support", d: "Reach out anytime — typical reply under 24h." },
            { t: "Installation help", d: "Step-by-step setup assistance." },
            { t: "Technical assistance", d: "Server, network, and config support." },
          ].map((c) => (
            <div key={c.t} className="rounded-2xl bg-card hairline p-5 shadow-soft">
              <div className="text-sm font-semibold text-foreground">{c.t}</div>
              <div className="mt-1 text-sm text-muted-foreground">{c.d}</div>
            </div>
          ))}
        </div>
        <div className="mt-10 flex flex-wrap items-center justify-center gap-3">
          <Button
            asChild
            size="lg"
            className="rounded-full bg-primary hover:bg-primary/90 px-6 h-12 text-base font-medium"
          >
            <a href="mailto:support@classify.org?subject=Classify%20Support%20Request">
              <Mail className="mr-2 h-4 w-4" /> Contact Support
            </a>
          </Button>
          <Button
            asChild
            size="lg"
            variant="outline"
            className="rounded-full h-12 px-6 text-base font-medium border-hairline bg-card hover:bg-secondary"
          >
            <Link to="/docs">
              <FileText className="mr-2 h-4 w-4" /> Documentation
            </Link>
          </Button>
        </div>
      </div>
    </section>
  );
}
