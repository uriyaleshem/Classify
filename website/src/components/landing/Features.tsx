import { Bot, Zap, FolderArchive, Lock } from "lucide-react";

const features = [
  {
    icon: Bot,
    title: "AI Grading",
    desc: "Automatically evaluate assignments using advanced AI models trained on academic rubrics.",
  },
  {
    icon: Zap,
    title: "Fast Feedback",
    desc: "Students receive structured, actionable feedback in seconds instead of days.",
  },
  {
    icon: FolderArchive,
    title: "Multi-format Support",
    desc: "Supports source code, documents, archives (ZIP, RAR), and more — all in one place.",
  },
  {
    icon: Lock,
    title: "Secure Communication",
    desc: "Encrypted client-server communication using Diffie-Hellman key exchange and AES.",
  },
];

export function Features() {
  return (
    <section id="features" className="relative py-24 lg:py-32">
      <div className="mx-auto max-w-7xl px-6">
        <div className="mx-auto max-w-2xl text-center">
          <div className="text-xs font-semibold uppercase tracking-widest text-primary">Features</div>
          <h2 className="mt-3 text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight text-foreground">
            Everything your school needs to grade smarter
          </h2>
          <p className="mt-4 text-lg text-muted-foreground">
            Built for teachers who want their time back, and students who deserve faster feedback.
          </p>
        </div>

        <div className="mt-16 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {features.map((f, i) => (
            <div
              key={f.title}
              className="group relative rounded-2xl bg-card hairline p-6 shadow-soft transition-all duration-300 hover:-translate-y-1 hover:shadow-elevated animate-fade-up"
              style={{ animationDelay: `${i * 100}ms` }}
            >
              <div className="inline-flex h-11 w-11 items-center justify-center rounded-xl bg-accent text-primary">
                <f.icon className="h-5 w-5" />
              </div>
              <h3 className="mt-5 text-base font-semibold text-foreground">{f.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{f.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
