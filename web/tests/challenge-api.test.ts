import { describe, expect, it } from "vitest";

import { handleChallengeRequest } from "../challenge-api";

function testEnvironment(participant: unknown = null): Env {
  const session = {
    prepare: () => ({
      bind: () => ({
        first: async () => participant,
        run: async () => ({ success: true }),
      }),
    }),
  };
  const rateLimiter = {
    limit: async () => ({ success: true }),
  };

  return {
    CHALLENGE_DB: {
      withSession: () => session,
    },
    CHALLENGE_API_RATE_LIMITER: rateLimiter,
    CHALLENGE_CREATE_RATE_LIMITER: rateLimiter,
  } as unknown as Env;
}

describe("challenge API error responses", () => {
  it("turns an asynchronously rejected authentication into the documented 401 JSON", async () => {
    const response = await handleChallengeRequest(
      new Request(
        "https://fud-ai.app/api/challenge/v1/leaderboard"
          + "?category=overall&weekStart=2026-08-31&limit=100",
        {
          headers: {
            Authorization: `Bearer ${"a".repeat(43)}`,
          },
        },
      ),
      testEnvironment(),
    );

    expect(response.status).toBe(401);
    expect(response.headers.get("Content-Type")).toContain("application/json");
    await expect(response.json()).resolves.toMatchObject({
      error: { code: "unauthorized" },
    });
  });

  it("keeps profile deletion idempotent after the participant row is gone", async () => {
    const request = () => new Request("https://fud-ai.app/api/challenge/v1/profile", {
      method: "DELETE",
      headers: { Authorization: `Bearer ${"b".repeat(43)}` },
    });
    const environment = testEnvironment();

    const first = await handleChallengeRequest(request(), environment);
    const retry = await handleChallengeRequest(request(), environment);

    expect(first.status).toBe(200);
    expect(retry.status).toBe(200);
    await expect(retry.json()).resolves.toEqual({ deleted: true });
  });

  it("turns asynchronous body validation failures into the documented 400 JSON", async () => {
    const response = await handleChallengeRequest(
      new Request("https://fud-ai.app/api/challenge/v1/profile", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          displayName: "QA Runner",
          acceptedRules: false,
          eligibilityAccepted: true,
        }),
      }),
      testEnvironment(),
    );

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toMatchObject({
      error: {
        code: "validation_error",
        fields: ["acceptedRules"],
      },
    });
  });
});
