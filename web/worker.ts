const REPOSITORY = "apoorvdarshan/fud-ai";
const HISTORY_KEY = "github-star-history-v1";
const GITHUB_GRAPHQL_URL = "https://api.github.com/graphql";

interface Env {
  ASSETS: {
    fetch(request: Request): Promise<Response>;
  };
  GITHUB_TOKEN: string;
  STAR_HISTORY: {
    get(key: string): Promise<string | null>;
    put(key: string, value: string): Promise<void>;
  };
}

interface GitHubStargazerEdge {
  starredAt: string;
}

interface GitHubGraphQLResponse {
  data?: {
    repository: {
      stargazerCount: number;
      stargazers: {
        edges: GitHubStargazerEdge[];
        pageInfo: {
          endCursor: string | null;
          hasNextPage: boolean;
        };
      };
    };
  };
  errors?: Array<{
    message: string;
  }>;
}

interface GitHubStargazerPage {
  edges: GitHubStargazerEdge[];
  endCursor: string | null;
  hasNextPage: boolean;
  total: number;
}

interface GitHubGraphQLVariables {
  owner: string;
  name: string;
  cursor: string | null;
}

interface GitHubGraphQLPayload {
  query: string;
  variables: GitHubGraphQLVariables;
}

interface GitHubGraphQLRepository {
  stargazerCount: number;
  stargazers: {
    edges: GitHubStargazerEdge[];
    pageInfo: {
      endCursor: string | null;
      hasNextPage: boolean;
    };
  };
}

interface StarPoint {
  date: string;
  count: number;
}

interface StarHistory {
  repository: string;
  generatedAt: string;
  total: number;
  points: StarPoint[];
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/star-history.json") {
      const history = await getHistory(env);
      return Response.json(history, {
        headers: publicCacheHeaders("application/json; charset=utf-8"),
      });
    }

    if (url.pathname === "/star-history.svg") {
      const history = await getHistory(env);
      const theme = url.searchParams.get("theme") === "dark" ? "dark" : "light";
      return new Response(renderChart(history, theme), {
        headers: publicCacheHeaders("image/svg+xml; charset=utf-8"),
      });
    }

    return env.ASSETS.fetch(request);
  },

  async scheduled(_controller: unknown, env: Env): Promise<void> {
    await refreshHistory(env);
  },
};

async function getHistory(env: Env): Promise<StarHistory> {
  const cached = await env.STAR_HISTORY.get(HISTORY_KEY);
  if (cached) {
    return JSON.parse(cached) as StarHistory;
  }

  return refreshHistory(env);
}

async function refreshHistory(env: Env): Promise<StarHistory> {
  const stargazers: GitHubStargazerEdge[] = [];
  let cursor: string | null = null;
  let hasNextPage = true;
  let reportedTotal = 0;

  while (hasNextPage) {
    const page = await fetchStargazerPage(env.GITHUB_TOKEN, cursor);
    stargazers.push(...page.edges);
    cursor = page.endCursor;
    hasNextPage = page.hasNextPage;
    reportedTotal = page.total;
  }

  const history = buildHistory(stargazers, reportedTotal);
  await env.STAR_HISTORY.put(HISTORY_KEY, JSON.stringify(history));
  return history;
}

async function fetchStargazerPage(
  token: string,
  cursor: string | null,
): Promise<GitHubStargazerPage> {
  const payload: GitHubGraphQLPayload = {
    query: `query StarHistory($owner: String!, $name: String!, $cursor: String) {
      repository(owner: $owner, name: $name) {
        stargazerCount
        stargazers(first: 100, after: $cursor) {
          edges {
            starredAt
          }
          pageInfo {
            endCursor
            hasNextPage
          }
        }
      }
    }`,
    variables: {
      owner: "apoorvdarshan",
      name: "fud-ai",
      cursor,
    },
  };
  const response = await fetch(GITHUB_GRAPHQL_URL, {
    method: "POST",
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      "User-Agent": "fud-ai-star-history",
    },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw new Error(`GitHub GraphQL request failed with status ${response.status}`);
  }

  const result = (await response.json()) as GitHubGraphQLResponse;
  if (result.errors?.length || !result.data?.repository) {
    throw new Error(result.errors?.[0]?.message ?? "GitHub returned no repository data");
  }

  return parseGraphQLRepository(result.data.repository);
}

function parseGraphQLRepository(repository: GitHubGraphQLRepository): GitHubStargazerPage {
  return {
    edges: repository.stargazers.edges,
    endCursor: repository.stargazers.pageInfo.endCursor,
    hasNextPage: repository.stargazers.pageInfo.hasNextPage,
    total: repository.stargazerCount,
  };
}

function buildHistory(
  stargazers: GitHubStargazerEdge[],
  reportedTotal: number,
): StarHistory {
  const dailyCounts = new Map<string, number>();

  for (const stargazer of stargazers) {
    const date = stargazer.starredAt.slice(0, 10);
    dailyCounts.set(date, (dailyCounts.get(date) ?? 0) + 1);
  }

  let runningTotal = 0;
  const points = [...dailyCounts.entries()]
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([date, stars]) => {
      runningTotal += stars;
      return { date, count: runningTotal };
    });

  if (reportedTotal !== runningTotal) {
    if (points.length === 0) {
      points.push({
        date: new Date().toISOString().slice(0, 10),
        count: reportedTotal,
      });
    } else {
      points[points.length - 1].count = reportedTotal;
    }
  }

  return {
    repository: REPOSITORY,
    generatedAt: new Date().toISOString(),
    total: reportedTotal,
    points,
  };
}

function publicCacheHeaders(contentType: string): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Cache-Control": "public, max-age=900, s-maxage=3600, stale-while-revalidate=86400",
    "Content-Type": contentType,
    "X-Content-Type-Options": "nosniff",
  };
}

function renderChart(history: StarHistory, theme: "dark" | "light"): string {
  const width = 900;
  const height = 520;
  const padding = { top: 82, right: 54, bottom: 72, left: 78 };
  const plotWidth = width - padding.left - padding.right;
  const plotHeight = height - padding.top - padding.bottom;
  const dark = theme === "dark";
  const colors = {
    background: dark ? "#0d1117" : "#ffffff",
    panel: dark ? "#161b22" : "#f6f8fa",
    grid: dark ? "#30363d" : "#d8dee4",
    muted: dark ? "#8b949e" : "#57606a",
    text: dark ? "#f0f6fc" : "#24292f",
    accent: "#ff3764",
    accentFill: dark ? "#ff376433" : "#ff376426",
  };

  if (history.points.length === 0) {
    return emptyChart(width, height, colors);
  }

  const firstDate = Date.parse(history.points[0].date);
  const lastDate = Date.parse(history.points.at(-1)!.date);
  const dateSpan = Math.max(lastDate - firstDate, 86_400_000);
  const yMax = Math.max(10, Math.ceil(history.total / 10) * 10);
  const x = (date: string) =>
    padding.left + ((Date.parse(date) - firstDate) / dateSpan) * plotWidth;
  const y = (count: number) =>
    padding.top + plotHeight - (count / yMax) * plotHeight;

  const linePoints = history.points.map((point) => `${x(point.date)},${y(point.count)}`);
  const linePath = `M ${linePoints.join(" L ")}`;
  const areaPath = `${linePath} L ${x(history.points.at(-1)!.date)},${padding.top + plotHeight} L ${x(history.points[0].date)},${padding.top + plotHeight} Z`;
  const yTicks = Array.from({ length: 5 }, (_, index) => Math.round((yMax / 4) * index));
  const xTicks = Array.from({ length: 5 }, (_, index) => {
    const value = new Date(firstDate + (dateSpan / 4) * index);
    return {
      date: value.toISOString().slice(0, 10),
      label: value.toLocaleDateString("en", { month: "short", year: "numeric", timeZone: "UTC" }),
    };
  });

  const gridLines = yTicks
    .map((tick) => {
      const tickY = y(tick);
      return `<line x1="${padding.left}" y1="${tickY}" x2="${padding.left + plotWidth}" y2="${tickY}" stroke="${colors.grid}" stroke-width="1"/><text x="${padding.left - 14}" y="${tickY + 5}" text-anchor="end" fill="${colors.muted}" font-size="14">${tick}</text>`;
    })
    .join("");
  const dateLabels = xTicks
    .map(
      (tick) =>
        `<text x="${x(tick.date)}" y="${height - 35}" text-anchor="middle" fill="${colors.muted}" font-size="14">${escapeXml(tick.label)}</text>`,
    )
    .join("");

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img" aria-labelledby="title description">
  <title id="title">${escapeXml(REPOSITORY)} star history</title>
  <desc id="description">${history.total} GitHub stars as of ${escapeXml(history.generatedAt)}</desc>
  <rect width="${width}" height="${height}" rx="18" fill="${colors.background}"/>
  <rect x="24" y="24" width="${width - 48}" height="${height - 48}" rx="14" fill="${colors.panel}" stroke="${colors.grid}"/>
  <text x="${padding.left}" y="57" fill="${colors.text}" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif" font-size="23" font-weight="700">${escapeXml(REPOSITORY)}</text>
  <text x="${width - padding.right}" y="57" text-anchor="end" fill="${colors.accent}" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif" font-size="22" font-weight="700">★ ${history.total}</text>
  <g font-family="-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif">${gridLines}${dateLabels}</g>
  <path d="${areaPath}" fill="${colors.accentFill}"/>
  <path d="${linePath}" fill="none" stroke="${colors.accent}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="${x(history.points.at(-1)!.date)}" cy="${y(history.total)}" r="6" fill="${colors.accent}" stroke="${colors.panel}" stroke-width="3"/>
</svg>`;
}

function emptyChart(
  width: number,
  height: number,
  colors: Record<string, string>,
): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
  <rect width="${width}" height="${height}" rx="18" fill="${colors.background}"/>
  <text x="${width / 2}" y="${height / 2}" text-anchor="middle" fill="${colors.muted}" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif" font-size="22">No star history yet</text>
</svg>`;
}

function escapeXml(value: string): string {
  return value.replace(/[<>&"']/g, (character) => {
    const entities: Record<string, string> = {
      "<": "&lt;",
      ">": "&gt;",
      "&": "&amp;",
      '"': "&quot;",
      "'": "&apos;",
    };
    return entities[character];
  });
}
