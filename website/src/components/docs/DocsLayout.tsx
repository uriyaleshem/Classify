import { Link } from "@tanstack/react-router";
import { ArrowLeft, Mail } from "lucide-react";
import { Header } from "@/components/landing/Header";
import { Footer } from "@/components/landing/Footer";

type DocsLayoutProps = {
  eyebrow: string;
  title: string;
  description: string;
  children: React.ReactNode;
};

export function DocsLayout({ eyebrow, title, description, children }: DocsLayoutProps) {
  return (
    <main className="min-h-screen bg-background text-foreground">
      <Header />
      <section className="border-b border-hairline bg-gradient-hero">
        <div className="mx-auto max-w-5xl px-6 py-16 lg:py-20">
          <Link
            to="/"
            className="inline-flex items-center gap-2 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to home
          </Link>
          <div className="mt-8 max-w-3xl">
            <div className="text-xs font-semibold uppercase tracking-widest text-primary">
              {eyebrow}
            </div>
            <h1 className="mt-3 text-4xl font-bold tracking-tight text-foreground sm:text-5xl">
              {title}
            </h1>
            <p className="mt-5 text-lg leading-relaxed text-muted-foreground">{description}</p>
          </div>
        </div>
      </section>
      <section className="mx-auto max-w-5xl px-6 py-14 lg:py-16">
        <article className="space-y-10 rounded-2xl bg-card p-6 shadow-soft hairline sm:p-8 lg:p-10">
          {children}
        </article>
      </section>
      <Footer />
    </main>
  );
}

export function DocSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-4">
      <h2 className="text-2xl font-bold tracking-tight text-foreground">{title}</h2>
      <div className="space-y-4 text-[15px] leading-7 text-muted-foreground">{children}</div>
    </section>
  );
}

export function DocSubsection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="space-y-3">
      <h3 className="text-lg font-semibold text-foreground">{title}</h3>
      <div className="space-y-3">{children}</div>
    </div>
  );
}

export function DocList({ items }: { items: string[] }) {
  return (
    <ul className="list-disc space-y-2 pl-5">
      {items.map((item) => (
        <li key={item}>{item}</li>
      ))}
    </ul>
  );
}

export function DocSteps({ items }: { items: string[] }) {
  return (
    <ol className="list-decimal space-y-2 pl-5">
      {items.map((item) => (
        <li key={item}>{item}</li>
      ))}
    </ol>
  );
}

export function SupportEmail() {
  return (
    <a
      href="mailto:support@classify.org?subject=Classify%20Support%20Request"
      className="inline-flex items-center gap-2 font-medium text-primary transition-colors hover:text-primary/80"
    >
      <Mail className="h-4 w-4" />
      support@classify.org
    </a>
  );
}
