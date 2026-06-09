import { Link } from 'react-router';
import { Button } from '@/components/ui/button';
import { Music, Scan, BarChart3, Zap, ArrowRight, Sparkles } from 'lucide-react';

export default function Home() {
  return (
    <div className="min-h-screen flex flex-col">
      {/* Hero Section */}
      <section className="relative overflow-hidden bg-gradient-to-br from-neutral-900 via-neutral-800 to-neutral-900 text-white">
        <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PGNpcmNsZSBjeD0iMSIgY3k9IjEiIHI9IjEiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC4wNSkiLz48L3N2Zz4=')] opacity-30" />
        <div className="relative max-w-5xl mx-auto px-4 py-24 sm:py-32 text-center">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/10 text-sm text-white/80 mb-6 border border-white/10">
            <Sparkles className="w-3.5 h-3.5" />
            Powered by Google Gemini AI
          </div>
          <h1 className="text-4xl sm:text-5xl md:text-6xl font-bold tracking-tight mb-6">
            Music Funnel AI
          </h1>
          <p className="text-lg sm:text-xl text-white/70 max-w-2xl mx-auto mb-8 leading-relaxed">
            Find broken creator funnels automatically. Discover music creators with
            missing Linktrees, broken Instagram links, and inactive accounts — then
            score them with Google Gemini AI.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link to="/dashboard">
              <Button size="lg" className="gap-2 text-base px-8">
                Launch Dashboard
                <ArrowRight className="w-4 h-4" />
              </Button>
            </Link>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="flex-1 py-20 bg-background">
        <div className="max-w-5xl mx-auto px-4">
          <div className="text-center mb-14">
            <h2 className="text-2xl sm:text-3xl font-bold mb-3">
              Everything You Need to Find Leads
            </h2>
            <p className="text-muted-foreground max-w-xl mx-auto">
              A complete toolkit for music industry scouts to identify and score
              potential creator leads.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {/* Feature 1 */}
            <div className="rounded-xl border bg-card p-6 text-card-foreground shadow-sm">
              <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center mb-4">
                <Scan className="w-5 h-5 text-primary" />
              </div>
              <h3 className="font-semibold text-lg mb-2">Funnel Scanning</h3>
              <p className="text-muted-foreground text-sm leading-relaxed">
                Scan any music creator's social funnel. Detect broken Instagram
                links, missing Linktrees, and inactive profiles automatically.
              </p>
            </div>

            {/* Feature 2 */}
            <div className="rounded-xl border bg-card p-6 text-card-foreground shadow-sm">
              <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center mb-4">
                <BarChart3 className="w-5 h-5 text-primary" />
              </div>
              <h3 className="font-semibold text-lg mb-2">Lead Scoring</h3>
              <p className="text-muted-foreground text-sm leading-relaxed">
                Every lead gets a score from 0-8 with a tier badge (COLD, WARM,
                HOT). Gemini AI provides insights on why each lead is valuable.
              </p>
            </div>

            {/* Feature 3 */}
            <div className="rounded-xl border bg-card p-6 text-card-foreground shadow-sm">
              <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center mb-4">
                <Zap className="w-5 h-5 text-primary" />
              </div>
              <h3 className="font-semibold text-lg mb-2">AI Insights</h3>
              <p className="text-muted-foreground text-sm leading-relaxed">
                Powered by Google Gemini AI. Get intelligent insights about each
                creator's funnel health and outreach priority with explainable
                reasoning.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* How It Works */}
      <section className="py-20 bg-muted/50">
        <div className="max-w-5xl mx-auto px-4">
          <div className="text-center mb-14">
            <h2 className="text-2xl sm:text-3xl font-bold mb-3">How It Works</h2>
            <p className="text-muted-foreground max-w-xl mx-auto">
              Three simple steps to find and score music creator leads.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-8">
            <div className="text-center">
              <div className="w-12 h-12 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-lg font-bold mx-auto mb-4">
                1
              </div>
              <h3 className="font-semibold mb-2">Configure</h3>
              <p className="text-sm text-muted-foreground">
                Choose manual or AI mode. Select your Gemini model and enter your API key.
              </p>
            </div>
            <div className="text-center">
              <div className="w-12 h-12 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-lg font-bold mx-auto mb-4">
                2
              </div>
              <h3 className="font-semibold mb-2">Scan</h3>
              <p className="text-sm text-muted-foreground">
                Let the system scan and analyze creator funnels automatically for broken links.
              </p>
            </div>
            <div className="text-center">
              <div className="w-12 h-12 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-lg font-bold mx-auto mb-4">
                3
              </div>
              <h3 className="font-semibold mb-2">Score</h3>
              <p className="text-sm text-muted-foreground">
                Review AI-generated scores, tier badges, and actionable insights for each lead.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 bg-background">
        <div className="max-w-3xl mx-auto px-4 text-center">
          <Music className="w-10 h-10 text-primary mx-auto mb-4" />
          <h2 className="text-2xl sm:text-3xl font-bold mb-4">
            Ready to Find Your Next Lead?
          </h2>
          <p className="text-muted-foreground mb-8 max-w-lg mx-auto">
            Jump into the dashboard and start scanning music creators for broken
            funnels and outreach opportunities.
          </p>
          <Link to="/dashboard">
            <Button size="lg" className="gap-2">
              Get Started
              <ArrowRight className="w-4 h-4" />
            </Button>
          </Link>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t py-6 bg-background">
        <div className="max-w-5xl mx-auto px-4 text-center text-sm text-muted-foreground">
          Music Funnel AI — Google Cloud Edition
        </div>
      </footer>
    </div>
  );
}
