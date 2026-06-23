import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Switch } from '@/components/ui/switch';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Separator } from '@/components/ui/separator';
import { Skeleton } from '@/components/ui/skeleton';
import { Alert, AlertDescription } from '@/components/ui/alert';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Music,
  ArrowLeft,
  Sparkles,
  Users,
  Flame,
  Snowflake,
  Thermometer,
  Search,
  Link2,
  Activity,
  AlertCircle,
  Zap,
  CheckCircle2,
  XCircle,
  Clock,
  BookOpen,
  Settings,
  BarChart3,
  Youtube,
  Instagram,
  ExternalLink,
} from 'lucide-react';
import type { Lead, LeadScore, AppConfig } from '@/types';

const API_BASE = '/api';

function getTierIcon(tier: LeadScore['tier']) {
  switch (tier) {
    case 'HOT':
      return <Flame className="w-3.5 h-3.5" />;
    case 'WARM':
      return <Thermometer className="w-3.5 h-3.5" />;
    case 'COLD':
      return <Snowflake className="w-3.5 h-3.5" />;
  }
}

function getTierColor(tier: LeadScore['tier']) {
  switch (tier) {
    case 'HOT':
      return 'bg-red-100 text-red-700 border-red-200 hover:bg-red-100';
    case 'WARM':
      return 'bg-amber-100 text-amber-700 border-amber-200 hover:bg-amber-100';
    case 'COLD':
      return 'bg-slate-100 text-slate-700 border-slate-200 hover:bg-slate-100';
  }
}

function getScoreColor(score: number) {
  if (score >= 6) return 'text-red-600';
  if (score >= 3) return 'text-amber-600';
  return 'text-slate-600';
}

export default function Dashboard() {
  const [leads, setLeads] = useState<Lead[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [config, setConfig] = useState<AppConfig | null>(null);
  const [configLoading, setConfigLoading] = useState(true);

  const [aiMode, setAiMode] = useState(false);
  const [apiKey, setApiKey] = useState(() => localStorage.getItem('mf_gemini_key') || '');
  const [youtubeApiKey, setYoutubeApiKey] = useState(() => localStorage.getItem('mf_youtube_key') || '');
  const [selectedModel, setSelectedModel] = useState('');
  const [searchQuery, setSearchQuery] = useState('Producer');
  const [minSubs, setMinSubs] = useState('1000');
  const [locationFilter, setLocationFilter] = useState('');

  const [showSettings, setShowSettings] = useState(false);

  // Persist keys to localStorage
  useEffect(() => {
    localStorage.setItem('mf_gemini_key', apiKey);
  }, [apiKey]);

  useEffect(() => {
    localStorage.setItem('mf_youtube_key', youtubeApiKey);
  }, [youtubeApiKey]);

  // Fetch app config (models)
  useEffect(() => {
    fetch(`${API_BASE}/config`)
      .then((res) => res.json())
      .then((data: AppConfig) => {
        setConfig(data);
        if (data.models.length > 0) {
          setSelectedModel(data.models[0].id);
        }
      })
      .catch((err) => {
        console.error('Failed to load config:', err);
        // Fallback models if API fails
        const fallback: AppConfig = {
          models: [
            { id: 'gemini-2.0-flash-lite', name: 'Gemini 2.0 Flash Lite' },
            { id: 'gemini-1.5-flash', name: 'Gemini 1.5 Flash' },
            { id: 'gemini-1.5-pro', name: 'Gemini 1.5 Pro' },
          ],
        };
        setConfig(fallback);
        setSelectedModel(fallback.models[0].id);
      })
      .finally(() => setConfigLoading(false));
  }, []);

  const handleScan = useCallback(async () => {
    setLoading(true);
    setError(null);
    setLeads([]);

    try {
      const params = new URLSearchParams();
      params.append('mode', aiMode ? 'ai' : 'manual');
      params.append('query', searchQuery);
      params.append('min_subs', minSubs);
      if (locationFilter) {
        params.append('location', locationFilter);
      }
      if (selectedModel) {
        params.append('model', selectedModel);
      }

      const headers: HeadersInit = {};
      if (aiMode && apiKey) {
        headers['X-API-Key'] = apiKey;
      }
      if (youtubeApiKey) {
        headers['X-YouTube-Key'] = youtubeApiKey;
      }

      const res = await fetch(`${API_BASE}/scan?${params.toString()}`, {
        method: 'GET',
        headers,
      });

      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        throw new Error(errData.detail || errData.error || `Scan failed: ${res.status}`);
      }

      const data: Lead[] = await res.json();
      setLeads(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Scan failed');
    } finally {
      setLoading(false);
    }
  }, [aiMode, selectedModel, apiKey, youtubeApiKey, searchQuery, minSubs, locationFilter]);

  const stats = {
    total: leads.length,
    hot: leads.filter((l) => l.score.tier === 'HOT').length,
    warm: leads.filter((l) => l.score.tier === 'WARM').length,
    cold: leads.filter((l) => l.score.tier === 'COLD').length,
    avgScore: leads.length
      ? Math.round(leads.reduce((s, l) => s + l.score.score, 0) / leads.length)
      : 0,
  };

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 sticky top-0 z-50">
        <div className="max-w-5xl mx-auto px-4 h-14 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Link to="/" className="flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors">
              <ArrowLeft className="w-4 h-4" />
            </Link>
            <Music className="w-5 h-5" />
            <h1 className="font-semibold text-sm sm:text-base">Music Funnel AI</h1>
            <Badge variant="secondary" className="gap-1 text-xs">
              <Sparkles className="w-3 h-3" />
              Gemini Powered
            </Badge>
          </div>
          <div className="text-xs text-muted-foreground hidden sm:block">
            Google Cloud Edition
          </div>
        </div>
      </header>

      <main className="max-w-5xl mx-auto px-4 py-6 space-y-6">
        {/* Scan Input Card */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 text-lg">
              <Search className="w-5 h-5" />
              Scan Creator
            </CardTitle>
            <CardDescription>
              Scan for music creators with broken Instagram links, missing Linktrees, and inactive accounts.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex flex-col sm:flex-row gap-3">
              <div className="relative flex-1">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                <Input
                  placeholder="Search creators (e.g. UK Drill, Afrobeat)..."
                  className="pl-9"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                />
              </div>
              <Button
                onClick={handleScan}
                disabled={loading}
                className="gap-2"
              >
                {loading ? (
                  <>
                    <Clock className="w-4 h-4 animate-spin" />
                    Scanning...
                  </>
                ) : (
                  <>
                    <Zap className="w-4 h-4" />
                    Scan
                  </>
                )}
              </Button>
              <Button
                variant="outline"
                size="icon"
                onClick={() => setShowSettings(!showSettings)}
                className={showSettings ? 'bg-secondary' : ''}
              >
                <Settings className="w-4 h-4" />
              </Button>
            </div>

            {showSettings && (
              <div className="p-4 rounded-lg border bg-slate-50/50 space-y-4 animate-in fade-in slide-in-from-top-2 duration-200">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="youtube-key" className="text-xs font-medium">YouTube Data API Key</Label>
                    <Input
                      id="youtube-key"
                      type="password"
                      placeholder="Paste YouTube API Key..."
                      className="h-8 text-xs"
                      value={youtubeApiKey}
                      onChange={(e) => setYoutubeApiKey(e.target.value)}
                    />
                    <p className="text-[10px] text-muted-foreground">Used to fetch real creators from YouTube.</p>
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="gemini-key" className="text-xs font-medium">Gemini API Key (Optional)</Label>
                    <Input
                      id="gemini-key"
                      type="password"
                      placeholder="Paste Gemini API Key..."
                      className="h-8 text-xs"
                      value={apiKey}
                      onChange={(e) => setApiKey(e.target.value)}
                    />
                    <p className="text-[10px] text-muted-foreground">Overrides server-side key for AI insights.</p>
                  </div>
                </div>

                <Separator />

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="min-subs" className="text-xs font-medium">Min Subscribers</Label>
                    <Input
                      id="min-subs"
                      type="number"
                      placeholder="0"
                      className="h-8 text-xs"
                      value={minSubs}
                      onChange={(e) => setMinSubs(e.target.value)}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="location-filter" className="text-xs font-medium">Location Filter</Label>
                    <Input
                      id="location-filter"
                      placeholder="e.g. UK, US, London..."
                      className="h-8 text-xs"
                      value={locationFilter}
                      onChange={(e) => setLocationFilter(e.target.value)}
                    />
                  </div>
                </div>
              </div>
            )}

            {/* Quick Settings Row */}
            <div className="flex flex-wrap items-center gap-4 text-sm">
              <div className="flex items-center gap-2">
                <Switch
                  id="ai-mode"
                  checked={aiMode}
                  onCheckedChange={setAiMode}
                />
                <Label htmlFor="ai-mode" className="cursor-pointer">
                  Gemini AI Mode
                </Label>
              </div>
              {aiMode && (
                <>
                  <div className="flex items-center gap-2">
                    <Label className="text-xs text-muted-foreground whitespace-nowrap">Model:</Label>
                    {configLoading ? (
                      <Skeleton className="h-9 w-40" />
                    ) : (
                      <Select value={selectedModel} onValueChange={setSelectedModel}>
                        <SelectTrigger className="h-8 text-xs w-auto min-w-[180px]">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {config?.models.map((m) => (
                            <SelectItem key={m.id} value={m.id}>
                              {m.name}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  </div>
                </>
              )}
            </div>

            {error && (
              <Alert variant="destructive">
                <AlertCircle className="h-4 w-4" />
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            )}
          </CardContent>
        </Card>

        {/* Results Section */}
        {leads.length > 0 && (
          <>
            {/* Stats Cards */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
              <Card className="py-4">
                <CardContent className="px-4 py-0">
                  <div className="flex items-center gap-2 text-muted-foreground text-xs mb-1">
                    <Users className="w-3.5 h-3.5" />
                    Total Leads
                  </div>
                  <div className="text-2xl font-bold">{stats.total}</div>
                </CardContent>
              </Card>
              <Card className="py-4">
                <CardContent className="px-4 py-0">
                  <div className="flex items-center gap-2 text-red-500 text-xs mb-1">
                    <Flame className="w-3.5 h-3.5" />
                    HOT
                  </div>
                  <div className="text-2xl font-bold text-red-600">{stats.hot}</div>
                </CardContent>
              </Card>
              <Card className="py-4">
                <CardContent className="px-4 py-0">
                  <div className="flex items-center gap-2 text-amber-500 text-xs mb-1">
                    <Thermometer className="w-3.5 h-3.5" />
                    WARM
                  </div>
                  <div className="text-2xl font-bold text-amber-600">{stats.warm}</div>
                </CardContent>
              </Card>
              <Card className="py-4">
                <CardContent className="px-4 py-0">
                  <div className="flex items-center gap-2 text-muted-foreground text-xs mb-1">
                    <BarChart3 className="w-3.5 h-3.5" />
                    Avg Score
                  </div>
                  <div className={`text-2xl font-bold ${getScoreColor(stats.avgScore)}`}>
                    {stats.avgScore}
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* Tier Distribution */}
            <div className="flex gap-2">
              <div className="flex-1 h-2 bg-red-500 rounded-full" style={{ opacity: stats.hot > 0 ? 1 : 0.2 }} />
              <div className="flex-1 h-2 bg-amber-500 rounded-full" style={{ opacity: stats.warm > 0 ? 1 : 0.2 }} />
              <div className="flex-1 h-2 bg-slate-300 rounded-full" style={{ opacity: stats.cold > 0 ? 1 : 0.2 }} />
            </div>

            {/* Lead Cards */}
            <div className="space-y-3">
              {leads.map((lead, idx) => (
                <Card key={idx} className="py-4">
                  <CardContent className="px-4 py-0">
                    <div className="flex flex-col sm:flex-row sm:items-start gap-4">
                      {/* Left: Name + Score */}
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-2 flex-wrap">
                          <h3 className="font-semibold text-base">{lead.name}</h3>
                          <Badge
                            variant="outline"
                            className={`gap-1 ${getTierColor(lead.score.tier)}`}
                          >
                            {getTierIcon(lead.score.tier)}
                            {lead.score.tier}
                          </Badge>
                        </div>

                        <div className="grid grid-cols-2 sm:grid-cols-4 gap-x-4 gap-y-2 text-sm">
                          <div className="flex items-center gap-1.5">
                            <Activity className="w-3.5 h-3.5 text-muted-foreground" />
                            <span className="text-muted-foreground">IG:</span>
                            <span className="truncate">{lead.instagram_status}</span>
                          </div>
                          <div className="flex items-center gap-1.5">
                            <Link2 className="w-3.5 h-3.5 text-muted-foreground" />
                            <span className="text-muted-foreground">Linktree:</span>
                            {lead.linktree ? (
                              <CheckCircle2 className="w-3.5 h-3.5 text-green-500" />
                            ) : (
                              <XCircle className="w-3.5 h-3.5 text-red-500" />
                            )}
                          </div>
                          <div className="flex items-center gap-1.5">
                            <Clock className="w-3.5 h-3.5 text-muted-foreground" />
                            <span className="text-muted-foreground">Inactive:</span>
                            {lead.inactive ? (
                              <CheckCircle2 className="w-3.5 h-3.5 text-amber-500" />
                            ) : (
                              <XCircle className="w-3.5 h-3.5 text-green-500" />
                            )}
                          </div>
                          <div className="flex items-center gap-1.5">
                            <Users className="w-3.5 h-3.5 text-muted-foreground" />
                            <span className="text-muted-foreground">Subs:</span>
                            <span>{lead.subscribers.toLocaleString()}</span>
                          </div>
                        </div>

                        {/* Quick Links */}
                        <div className="mt-3 flex flex-wrap gap-2">
                          {lead.youtube_url && (
                            <Button variant="outline" size="xs" className="h-7 text-[10px] gap-1 px-2" asChild>
                              <a href={lead.youtube_url} target="_blank" rel="noopener noreferrer">
                                <Youtube className="w-3 h-3 text-red-600" />
                                YouTube
                              </a>
                            </Button>
                          )}
                          {lead.instagram_url && (
                            <Button variant="outline" size="xs" className="h-7 text-[10px] gap-1 px-2" asChild>
                              <a href={lead.instagram_url} target="_blank" rel="noopener noreferrer">
                                <Instagram className="w-3 h-3 text-pink-600" />
                                Instagram
                              </a>
                            </Button>
                          )}
                          {lead.linktree_url && (
                            <Button variant="outline" size="xs" className="h-7 text-[10px] gap-1 px-2" asChild>
                              <a href={lead.linktree_url} target="_blank" rel="noopener noreferrer">
                                <ExternalLink className="w-3 h-3 text-green-600" />
                                Bio Link
                              </a>
                            </Button>
                          )}
                        </div>

                        {/* Gemini Insight */}
                        {lead.score.ai_insight && (
                          <div className="mt-3 p-3 rounded-lg bg-gradient-to-r from-purple-50 to-blue-50 border border-purple-100">
                            <div className="flex items-center gap-1.5 mb-1">
                              <Sparkles className="w-3.5 h-3.5 text-purple-600" />
                              <span className="text-xs font-medium text-purple-700">
                                Gemini Insight
                              </span>
                            </div>
                            <p className="text-sm text-purple-900 leading-relaxed">
                              {lead.score.ai_insight}
                            </p>
                          </div>
                        )}
                      </div>

                      {/* Right: Score Circle */}
                      <div className="flex flex-col items-center justify-center min-w-[70px]">
                        <div
                          className={`text-3xl font-bold ${getScoreColor(lead.score.score)}`}
                        >
                          {lead.score.score}
                        </div>
                        <span className="text-xs text-muted-foreground">/ 8</span>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </>
        )}

        {/* Loading Skeletons */}
        {loading && leads.length === 0 && (
          <div className="space-y-3">
            <Skeleton className="h-32" />
            <Skeleton className="h-32" />
            <Skeleton className="h-32" />
          </div>
        )}

        {/* Info Tabs */}
        {!loading && leads.length === 0 && (
          <Tabs defaultValue="guide" className="space-y-4">
            <TabsList>
              <TabsTrigger value="guide" className="gap-1.5">
                <BookOpen className="w-3.5 h-3.5" />
                Manual Guide
              </TabsTrigger>
              <TabsTrigger value="settings" className="gap-1.5">
                <Settings className="w-3.5 h-3.5" />
                Settings
              </TabsTrigger>
            </TabsList>

            <TabsContent value="guide">
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <BookOpen className="w-5 h-5" />
                    Manual Scanning Guide
                  </CardTitle>
                  <CardDescription>
                    How to manually identify broken creator funnels and score leads.
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-3">
                    <div className="flex gap-3">
                      <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-sm font-medium shrink-0">
                        1
                      </div>
                      <div>
                        <h4 className="font-medium text-sm">Check Instagram Bio Link</h4>
                        <p className="text-sm text-muted-foreground">
                          Visit the creator's Instagram profile. Look for a link in their bio.
                          If it's missing, broken, or leads to a 404 — that's a broken funnel signal.
                        </p>
                      </div>
                    </div>

                    <Separator />

                    <div className="flex gap-3">
                      <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-sm font-medium shrink-0">
                        2
                      </div>
                      <div>
                        <h4 className="font-medium text-sm">Look for Linktree</h4>
                        <p className="text-sm text-muted-foreground">
                          Check if the creator has a Linktree or similar link aggregator.
                          Missing Linktrees suggest the creator hasn't optimized their
                          social funnel for cross-platform traffic.
                        </p>
                      </div>
                    </div>

                    <Separator />

                    <div className="flex gap-3">
                      <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-sm font-medium shrink-0">
                        3
                      </div>
                      <div>
                        <h4 className="font-medium text-sm">Assess Activity Level</h4>
                        <p className="text-sm text-muted-foreground">
                          Check the creator's recent posting frequency. Accounts that haven't
                          posted in 90+ days are marked as inactive — a strong signal for
                          outreach opportunity.
                        </p>
                      </div>
                    </div>

                    <Separator />

                    <div className="flex gap-3">
                      <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-sm font-medium shrink-0">
                        4
                      </div>
                      <div>
                        <h4 className="font-medium text-sm">Score the Lead</h4>
                        <p className="text-sm text-muted-foreground">
                          Score from 0-8 based on: broken Instagram link (+4), missing Linktree
                          (+1), inactive account (+2), and 10K+ subscribers (+1).
                          6+ = HOT, 3-5 = WARM, below 3 = COLD.
                        </p>
                      </div>
                    </div>

                    <Separator />

                    <div className="flex gap-3">
                      <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-sm font-medium shrink-0">
                        5
                      </div>
                      <div>
                        <h4 className="font-medium text-sm">Reach Out</h4>
                        <p className="text-sm text-muted-foreground">
                          Contact creators with broken funnels offering link management
                          services, social media optimization, or cross-platform strategy
                          consulting.
                        </p>
                      </div>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="settings">
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <Settings className="w-5 h-5" />
                    Settings
                  </CardTitle>
                  <CardDescription>
                    Configure your Gemini API key and model preferences.
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="api-key">Gemini API Key</Label>
                    <Input
                      id="api-key"
                      type="password"
                      placeholder="Enter your Gemini API key"
                      value={apiKey}
                      onChange={(e) => setApiKey(e.target.value)}
                    />
                    <p className="text-xs text-muted-foreground">
                      Your API key is used for Gemini AI-powered lead scoring and insights.
                      It is never stored on the server.
                    </p>
                  </div>

                  <div className="space-y-2">
                    <Label>Gemini Model</Label>
                    {configLoading ? (
                      <Skeleton className="h-9 w-full" />
                    ) : (
                      <Select value={selectedModel} onValueChange={setSelectedModel}>
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {config?.models.map((m) => (
                            <SelectItem key={m.id} value={m.id}>
                              {m.name}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                    <p className="text-xs text-muted-foreground">
                      Select the Gemini model for AI scoring. Flash models are faster;
                      Pro models offer deeper reasoning.
                    </p>
                  </div>

                  <Separator />

                  <div className="flex items-center justify-between">
                    <div className="space-y-0.5">
                      <Label>AI Mode Default</Label>
                      <p className="text-xs text-muted-foreground">
                        Enable Gemini AI mode by default for new scans.
                      </p>
                    </div>
                    <Switch
                      checked={aiMode}
                      onCheckedChange={setAiMode}
                    />
                  </div>
                </CardContent>
              </Card>
            </TabsContent>
          </Tabs>
        )}
      </main>
    </div>
  );
}
