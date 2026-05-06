import { useEffect, useState } from "react";
import { Link } from "@tanstack/react-router";
import { Button } from "@/components/ui/button";
import appIcon from "@/assets/app-icon.png";

const navLinks = [
  { href: "/#features", label: "Features" },
  { href: "/#screenshots", label: "Product" },
  { href: "/#download", label: "Download" },
  { href: "/#faq", label: "FAQ" },
];

export function Header() {
  const [scrolled, setScrolled] = useState(false);
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);
  return (
    <header
      className={`sticky top-0 z-50 w-full transition-all duration-300 ${
        scrolled ? "backdrop-blur-xl bg-background/75 border-b border-hairline" : "bg-transparent"
      }`}
    >
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-6">
        <Link to="/" className="flex items-center gap-2.5">
          <img src={appIcon} alt="" className="h-9 w-9 object-contain" aria-hidden="true" />
          <span className="text-lg font-semibold tracking-tight text-foreground">Classify</span>
        </Link>
        <nav className="hidden md:flex items-center gap-8">
          {navLinks.map((l) => (
            <a
              key={l.href}
              href={l.href}
              className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
            >
              {l.label}
            </a>
          ))}
        </nav>
        <div className="flex items-center gap-3">
          <a href="/#download" className="hidden sm:inline-flex">
            <Button
              size="sm"
              className="rounded-full bg-primary hover:bg-primary/90 px-4 font-medium"
            >
              Download
            </Button>
          </a>
        </div>
      </div>
    </header>
  );
}
