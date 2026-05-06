import { WindowFrame } from "./Hero";
import login from "@/assets/screenshot-login.png";
import dashboard from "@/assets/screenshot-dashboard.png";
import student from "@/assets/screenshot-student.png";
import assignment from "@/assets/screenshot-assignment.png";

const shots = [
  { src: login, label: "Login", alt: "Classify login screen" },
  { src: dashboard, label: "Teacher dashboard", alt: "Teacher dashboard view" },
  { src: student, label: "Student dashboard", alt: "Student dashboard view" },
  { src: assignment, label: "Assignment review", alt: "Assignment review with AI feedback" },
];

export function Screenshots() {
  return (
    <section id="screenshots" className="relative py-24 lg:py-32 bg-secondary/40">
      <div className="mx-auto max-w-7xl px-6">
        <div className="flex flex-col items-center text-center">
          <div className="text-xs font-semibold uppercase tracking-widest text-primary">
            Product tour
          </div>
          <h2 className="mt-3 text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight text-foreground max-w-3xl">
            A native desktop experience, designed for the classroom
          </h2>
          <p className="mt-4 max-w-2xl text-lg text-muted-foreground">
            A clean, fast workspace for teachers and students to manage assignments with less
            friction.
          </p>
        </div>
      </div>

      <div className="mt-14 overflow-x-auto pb-6">
        <div className="mx-auto flex w-max gap-6 px-6 lg:px-12">
          {shots.map((s) => (
            <figure key={s.label} className="w-[680px] max-w-[85vw] flex-shrink-0">
              <WindowFrame>
                <img
                  src={s.src}
                  alt={s.alt}
                  width={1600}
                  height={1024}
                  loading="lazy"
                  className="block w-full h-auto"
                />
              </WindowFrame>
              <figcaption className="mt-4 text-center text-sm font-medium text-muted-foreground">
                {s.label}
              </figcaption>
            </figure>
          ))}
        </div>
      </div>
    </section>
  );
}
