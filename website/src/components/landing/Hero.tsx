import { Button } from "@/components/ui/button";
import { Download, ArrowRight, ShieldCheck } from "lucide-react";
import dashboardImg from "@/assets/screenshot-dashboard.png";

export function Hero() {
  return (
    <section className="relative overflow-hidden bg-gradient-hero">
      {/* Floating shapes */}
      <div aria-hidden className="pointer-events-none absolute inset-0 overflow-hidden">
        <div className="absolute -top-24 -left-24 h-72 w-72 rounded-full bg-primary/10 blur-3xl animate-float-slow" />
        <div
          className="absolute top-40 -right-20 h-80 w-80 rounded-full bg-[#6366F1]/10 blur-3xl animate-float-slow"
          style={{ animationDelay: "2s" }}
        />
        <div
          className="absolute bottom-0 left-1/3 h-64 w-64 rounded-full bg-primary/5 blur-3xl animate-float-slow"
          style={{ animationDelay: "4s" }}
        />
      </div>

      <div className="relative mx-auto max-w-7xl px-6 pt-20 pb-24 lg:pt-28 lg:pb-32">
        <div className="grid items-center gap-16 lg:grid-cols-12">
          <div className="lg:col-span-6 animate-fade-up">
            <div className="inline-flex items-center gap-2 rounded-full border border-hairline bg-card px-3 py-1 text-xs font-medium text-muted-foreground shadow-soft">
              <ShieldCheck className="h-3.5 w-3.5 text-primary" />
              Secure end-to-end encryption
            </div>
            <h1 className="mt-6 text-4xl sm:text-5xl lg:text-6xl font-bold leading-[1.05] tracking-tight text-foreground">
              AI-Powered Assignment <span className="text-gradient-primary">Grading</span> & School
              Management
            </h1>
            <p className="mt-6 max-w-xl text-lg leading-relaxed text-muted-foreground">
              Automate grading, manage courses, and streamline your school workflow with secure,
              intelligent tools designed for modern education.
            </p>
            <div className="mt-8 flex flex-wrap items-center gap-3">
              <a href="#download">
                <Button
                  size="lg"
                  className="rounded-full bg-primary hover:bg-primary/90 px-6 h-12 text-base font-medium shadow-elevated"
                >
                  <Download className="mr-2 h-4 w-4" /> Download for Windows
                </Button>
              </a>
              <a href="#features">
                <Button
                  size="lg"
                  variant="outline"
                  className="rounded-full h-12 px-6 text-base font-medium border-hairline bg-card hover:bg-secondary"
                >
                  Learn more <ArrowRight className="ml-2 h-4 w-4" />
                </Button>
              </a>
            </div>
            <div className="mt-8 flex items-center gap-6 text-xs text-muted-foreground">
              <div>Windows 10+</div>
              <div className="h-3 w-px bg-hairline" />
              <div>Local or self-hosted server</div>
              <div className="h-3 w-px bg-hairline" />
              <div>Free for educators</div>
            </div>
          </div>

          <div className="lg:col-span-6 animate-fade-up delay-200">
            <WindowFrame>
              <img
                src={dashboardImg}
                alt="Classify teacher dashboard showing assignments and class performance"
                width={1600}
                height={1024}
                className="block w-full h-auto"
              />
            </WindowFrame>
          </div>
        </div>
      </div>
    </section>
  );
}

export function WindowFrame({ children }: { children: React.ReactNode }) {
  return (
    <div className="relative rounded-2xl bg-card hairline shadow-window overflow-hidden">
      <div className="flex items-center gap-2 px-4 h-9 border-b border-hairline bg-secondary/60">
        <span className="h-3 w-3 rounded-full bg-[#FF5F57]" />
        <span className="h-3 w-3 rounded-full bg-[#FEBC2E]" />
        <span className="h-3 w-3 rounded-full bg-[#28C840]" />
        <div className="mx-auto text-[11px] font-medium text-muted-foreground">
          classify · desktop
        </div>
      </div>
      <div className="bg-background">{children}</div>
    </div>
  );
}
