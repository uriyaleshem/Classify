import { Link } from "@tanstack/react-router";
import appIcon from "@/assets/app-icon.png";

export function Footer() {
  return (
    <footer className="border-t border-hairline bg-background">
      <div className="mx-auto max-w-7xl px-6 py-12">
        <div className="flex flex-col gap-8 md:flex-row md:items-center md:justify-between">
          <div className="flex items-center gap-2.5">
            <img src={appIcon} alt="" className="h-9 w-9 object-contain" aria-hidden="true" />
            <div>
              <div className="text-sm font-semibold text-foreground">Classify</div>
              <div className="text-xs text-muted-foreground">v1.0 · Windows desktop client</div>
            </div>
          </div>
          <nav className="flex flex-wrap items-center gap-6 text-sm text-muted-foreground">
            <a href="/#features" className="hover:text-foreground transition-colors">
              Features
            </a>
            <a href="/#download" className="hover:text-foreground transition-colors">
              Download
            </a>
            <a href="/#faq" className="hover:text-foreground transition-colors">
              FAQ
            </a>
            <Link to="/docs" className="hover:text-foreground transition-colors">
              Documentation
            </Link>
            <Link to="/installation-guide" className="hover:text-foreground transition-colors">
              Installation
            </Link>
          </nav>
        </div>
        <div className="mt-10 pt-6 border-t border-hairline flex flex-col sm:flex-row items-center justify-between gap-2 text-xs text-muted-foreground">
          <p>
            Need help? Contact support at{" "}
            <a
              href="mailto:support@classify.org?subject=Classify%20Support%20Request"
              className="font-medium text-foreground transition-colors hover:text-primary"
            >
              support@classify.org
            </a>
            .
          </p>
          <p>© {new Date().getFullYear()} Classify. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
}
