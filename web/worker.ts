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
  const padding = { top: 122, right: 62, bottom: 78, left: 76 };
  const plotWidth = width - padding.left - padding.right;
  const plotHeight = height - padding.top - padding.bottom;
  const dark = theme === "dark";
  const colors = {
    background: dark ? "#0b0f13" : "#fff9fb",
    panel: dark ? "#151b20" : "#fffdf8",
    panelEdge: dark ? "#334049" : "#e4d7dc",
    grid: dark ? "#34414a" : "#eadde1",
    muted: dark ? "#9aa7ae" : "#756b70",
    text: dark ? "#fffaf5" : "#302630",
    accent: "#ff3764",
    accentSoft: dark ? "#ff91aa" : "#d91f4e",
    accentFill: dark ? "#ff37643d" : "#ff376429",
    leaf: dark ? "#9bd37e" : "#5ea862",
    sunshine: "#ffd166",
    aqua: dark ? "#66d9d0" : "#24aeb6",
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
      label: value.toLocaleDateString("en", {
        day: "numeric",
        month: "short",
        timeZone: "UTC",
      }),
    };
  });

  const gridLines = yTicks
    .map((tick) => {
      const tickY = y(tick);
      return `<path d="M ${padding.left} ${tickY} C ${padding.left + plotWidth * 0.32} ${tickY - 1}, ${padding.left + plotWidth * 0.68} ${tickY + 1}, ${padding.left + plotWidth} ${tickY}" fill="none" stroke="${colors.grid}" stroke-width="1.2" stroke-dasharray="4 7" stroke-linecap="round"/><text x="${padding.left - 16}" y="${tickY + 5}" text-anchor="end" fill="${colors.muted}" font-size="13">${tick}</text>`;
    })
    .join("");
  const dateLabels = xTicks
    .map(
      (tick) =>
        `<text x="${x(tick.date)}" y="${height - 37}" text-anchor="middle" fill="${colors.muted}" font-size="13" font-weight="600">${escapeXml(tick.label)}</text>`,
    )
    .join("");
  const leafSprouts = [0.27, 0.52, 0.76]
    .map((ratio, index) => {
      const point = history.points[Math.round((history.points.length - 1) * ratio)];
      const pointX = x(point.date);
      const pointY = y(point.count);
      const direction = index % 2 === 0 ? -1 : 1;
      return `<g transform="translate(${pointX} ${pointY}) rotate(${direction * 8})" filter="url(#softSketch)">
        <path d="M 0 1 Q ${direction * 2} -11 ${direction * 10} -16" fill="none" stroke="${colors.leaf}" stroke-width="2.2" stroke-linecap="round"/>
        <ellipse cx="${direction * 11}" cy="-17" rx="7" ry="3.8" transform="rotate(${direction * -28} ${direction * 11} -17)" fill="${colors.leaf}"/>
        <ellipse cx="${direction * 3}" cy="-10" rx="5.5" ry="3" transform="rotate(${direction * 30} ${direction * 3} -10)" fill="${colors.leaf}" opacity="0.82"/>
      </g>`;
    })
    .join("");
  const endX = x(history.points.at(-1)!.date);
  const endY = y(history.total);

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img" aria-labelledby="title description">
  <title id="title">${escapeXml(REPOSITORY)} star history</title>
  <desc id="description">${history.total} GitHub stars as of ${escapeXml(history.generatedAt)}</desc>
  <defs>
    <linearGradient id="growthWash" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="${colors.accent}" stop-opacity="0.34"/>
      <stop offset="100%" stop-color="${colors.accent}" stop-opacity="0.03"/>
    </linearGradient>
    <pattern id="paperDots" width="24" height="24" patternUnits="userSpaceOnUse">
      <circle cx="3" cy="3" r="0.8" fill="${colors.grid}" opacity="0.34"/>
    </pattern>
    <filter id="softSketch" x="-20%" y="-20%" width="140%" height="140%">
      <feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="8" result="noise"/>
      <feDisplacementMap in="SourceGraphic" in2="noise" scale="1.15" xChannelSelector="R" yChannelSelector="G"/>
    </filter>
    <filter id="warmGlow" x="-80%" y="-80%" width="260%" height="260%">
      <feGaussianBlur stdDeviation="5" result="blur"/>
      <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <rect width="${width}" height="${height}" rx="28" fill="${colors.background}"/>
  <rect x="16" y="16" width="${width - 32}" height="${height - 32}" rx="26" fill="${colors.panel}" stroke="${colors.panelEdge}" stroke-width="1.5"/>
  <rect x="26" y="26" width="${width - 52}" height="${height - 52}" rx="20" fill="url(#paperDots)" stroke="${colors.panelEdge}" stroke-width="1" stroke-dasharray="7 8" opacity="0.8"/>

  <g transform="translate(48 37)" filter="url(#softSketch)">
    <path d="M 10 18 C 2 10, 5 1, 14 3 C 19 -1, 29 1, 30 11 C 31 22, 22 30, 17 30 C 11 30, 4 25, 4 18 Z" fill="${colors.accent}"/>
    <path d="M 17 4 C 17 -2, 20 -6, 24 -8" fill="none" stroke="${colors.leaf}" stroke-width="3" stroke-linecap="round"/>
    <path d="M 23 -7 C 31 -8, 33 -3, 27 1 C 23 2, 21 -1, 23 -7 Z" fill="${colors.leaf}"/>
    <path d="M 9 11 Q 16 7 24 11" fill="none" stroke="${colors.accentSoft}" stroke-width="1.8" stroke-linecap="round" opacity="0.8"/>
  </g>
  <text x="94" y="53" fill="${colors.text}" font-family="ui-rounded,'Arial Rounded MT Bold','Trebuchet MS',sans-serif" font-size="25" font-weight="800">Fud AI is growing!</text>
  <text x="95" y="77" fill="${colors.muted}" font-family="'Trebuchet MS',sans-serif" font-size="13.5" font-weight="600">Every star helps healthier habits reach a little farther.</text>

  <g transform="translate(717 34)">
    <path d="M 18 0 H 112 Q 128 0 128 16 V 38 Q 128 52 112 52 H 18 Q 0 52 0 35 V 17 Q 0 0 18 0 Z" fill="${colors.accentFill}" stroke="${colors.accent}" stroke-width="1.5" stroke-dasharray="6 4"/>
    <path d="M 25 13 L 29 22 L 39 23 L 31 30 L 33 40 L 25 35 L 16 40 L 19 30 L 11 23 L 21 22 Z" fill="${colors.sunshine}" filter="url(#warmGlow)"/>
    <text x="48" y="34" fill="${colors.text}" font-family="ui-rounded,'Arial Rounded MT Bold','Trebuchet MS',sans-serif" font-size="21" font-weight="800">${history.total}</text>
    <text x="91" y="32" fill="${colors.muted}" font-family="'Trebuchet MS',sans-serif" font-size="11" font-weight="700">STARS</text>
  </g>

  <g font-family="'Trebuchet MS',sans-serif">${gridLines}${dateLabels}</g>
  <path d="${areaPath}" fill="url(#growthWash)"/>
  <path d="${linePath}" fill="none" stroke="${colors.accentSoft}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round" opacity="0.16" transform="translate(1 -1)"/>
  <path d="${linePath}" fill="none" stroke="${colors.accent}" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" filter="url(#softSketch)"/>
  ${leafSprouts}

  <g transform="translate(${endX} ${endY})" filter="url(#softSketch)">
    <circle r="7.5" fill="${colors.accent}" stroke="${colors.panel}" stroke-width="3"/>
    <path d="M 1 -7 Q 2 -14 7 -17" fill="none" stroke="${colors.leaf}" stroke-width="2.3" stroke-linecap="round"/>
    <ellipse cx="9" cy="-17" rx="5.8" ry="3.2" transform="rotate(-24 9 -17)" fill="${colors.leaf}"/>
  </g>

  <g transform="translate(164 458)" fill="none" stroke="${colors.aqua}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" filter="url(#softSketch)" opacity="0.8">
    <path d="M 10 0 C 10 0, 2 10, 2 16 C 2 22, 6 25, 11 25 C 17 25, 21 21, 21 16 C 21 10, 10 0, 10 0 Z"/>
    <path d="M 28 19 C 35 14, 40 15, 45 19"/>
  </g>
  <g transform="translate(728 451) rotate(-8)" fill="none" stroke-linecap="round" stroke-linejoin="round" filter="url(#softSketch)" opacity="0.78">
    <path d="M 10 8 C 1 10, 1 20, 10 33 C 19 20, 20 10, 10 8 Z" fill="${colors.sunshine}" stroke="${colors.sunshine}" stroke-width="2"/>
    <path d="M 9 8 C 4 2, 6 -3, 10 4 C 12 -3, 18 -1, 13 8" stroke="${colors.leaf}" stroke-width="3"/>
    <path d="M 6 18 L 13 20 M 7 24 L 11 25" stroke="${colors.accentSoft}" stroke-width="1.5"/>
  </g>
</svg>`;
}

function emptyChart(
  width: number,
  height: number,
  colors: Record<string, string>,
): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
  <rect width="${width}" height="${height}" rx="28" fill="${colors.background}"/>
  <rect x="16" y="16" width="${width - 32}" height="${height - 32}" rx="26" fill="${colors.panel}" stroke="${colors.panelEdge}"/>
  <text x="${width / 2}" y="${height / 2 - 5}" text-anchor="middle" fill="${colors.text}" font-family="ui-rounded,'Arial Rounded MT Bold','Trebuchet MS',sans-serif" font-size="25" font-weight="800">Plant the first star ★</text>
  <text x="${width / 2}" y="${height / 2 + 27}" text-anchor="middle" fill="${colors.muted}" font-family="'Trebuchet MS',sans-serif" font-size="15">The growth doodle will begin here.</text>
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
