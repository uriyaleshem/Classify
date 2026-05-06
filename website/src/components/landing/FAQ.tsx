import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";

const faqs = [
  { q: "How do I install Classify?", a: "Download the installer and follow the setup wizard. The process takes less than a minute." },
  { q: "Does Classify require an internet connection?", a: "The system connects to a local or remote server. Internet is required only if your server is remote." },
  { q: "Is my data secure?", a: "Yes. All communication is encrypted using modern cryptographic protocols (AES + secure key exchange)." },
  { q: "What file types are supported?", a: "Classify supports text files, code files, documents, and archives such as ZIP and RAR." },
  { q: "Can teachers override AI grading?", a: "Yes. Teachers always have full control and can adjust final grades." },
  { q: "Is there a file size limit?", a: "Yes, files are limited to approximately 25MB per upload." },
  { q: "Do students see AI feedback?", a: "Yes, students receive structured feedback after grading." },
  { q: "Can I run it locally at my school?", a: "Yes. The system is designed to run on local servers or internal networks." },
];

export function FAQ() {
  return (
    <section id="faq" className="py-24 lg:py-32">
      <div className="mx-auto max-w-3xl px-6">
        <div className="text-center">
          <div className="text-xs font-semibold uppercase tracking-widest text-primary">FAQ</div>
          <h2 className="mt-3 text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight text-foreground">
            Frequently asked questions
          </h2>
          <p className="mt-4 text-lg text-muted-foreground">
            Everything you need to know before getting started.
          </p>
        </div>
        <Accordion type="single" collapsible className="mt-12 space-y-3">
          {faqs.map((f, i) => (
            <AccordionItem
              key={i}
              value={`item-${i}`}
              className="rounded-2xl bg-card hairline px-5 shadow-soft border-b-0"
            >
              <AccordionTrigger className="text-left text-base font-semibold text-foreground hover:no-underline py-5">
                {f.q}
              </AccordionTrigger>
              <AccordionContent className="text-muted-foreground text-[15px] leading-relaxed pb-5">
                {f.a}
              </AccordionContent>
            </AccordionItem>
          ))}
        </Accordion>
      </div>
    </section>
  );
}
