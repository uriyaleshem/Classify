import { BookOpen, Upload, CheckCircle2 } from "lucide-react";

const steps = [
  { n: "01", icon: BookOpen, title: "Create Courses", desc: "Teachers create courses and assignments with custom rubrics and deadlines." },
  { n: "02", icon: Upload, title: "Students Submit Work", desc: "Students upload files directly through the desktop client — securely." },
  { n: "03", icon: CheckCircle2, title: "AI + Teacher Review", desc: "AI evaluates submissions instantly, and teachers finalize the grade." },
];

export function HowItWorks() {
  return (
    <section className="py-24 lg:py-32">
      <div className="mx-auto max-w-7xl px-6">
        <div className="mx-auto max-w-2xl text-center">
          <div className="text-xs font-semibold uppercase tracking-widest text-primary">How it works</div>
          <h2 className="mt-3 text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight text-foreground">
            From assignment to grade in three steps
          </h2>
        </div>
        <div className="mt-16 grid gap-6 md:grid-cols-3">
          {steps.map((s, i) => (
            <div
              key={s.n}
              className="relative rounded-2xl bg-card hairline p-8 shadow-soft animate-fade-up"
              style={{ animationDelay: `${i * 120}ms` }}
            >
              <div className="text-xs font-mono font-semibold text-primary">{s.n}</div>
              <div className="mt-4 inline-flex h-12 w-12 items-center justify-center rounded-xl bg-gradient-primary text-primary-foreground shadow-elevated">
                <s.icon className="h-5 w-5" />
              </div>
              <h3 className="mt-6 text-xl font-semibold text-foreground">{s.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{s.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
