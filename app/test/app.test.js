const request = require("supertest");
const app = require("../src/app");

describe("task-intray app", () => {
  test("GET / returns 200", async () => {
    const response = await request(app).get("/");
    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe("ok");
  });

  test("GET /health returns healthy", async () => {
    const response = await request(app).get("/health");
    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe("healthy");
  });

  test("GET /metrics exposes Prometheus metrics", async () => {
    const response = await request(app).get("/metrics");
    expect(response.statusCode).toBe(200);
    expect(response.text).toContain("process_cpu");
  });

  test("unknown paths share a single route label", async () => {
    await request(app).get("/does-not-exist-1");
    await request(app).get("/does-not-exist-2");
    const response = await request(app).get("/metrics");
    expect(response.text).toContain('route="unmatched"');
    expect(response.text).not.toContain("does-not-exist");
  });
});
