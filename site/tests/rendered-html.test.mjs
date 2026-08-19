import assert from "node:assert/strict";
import test from "node:test";

const workerUrl = new URL("../dist/server/index.js", import.meta.url);

async function render(pathname) {
  const url = new URL(workerUrl);
  url.searchParams.set("test", `${process.pid}-${Date.now()}-${pathname}`);
  const { default: worker } = await import(url.href);
  return worker.fetch(
    new Request(`http://localhost${pathname}`, { headers: { accept: "text/html" } }),
    { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } },
    { waitUntil() {}, passThroughOnException() {} },
  );
}

for (const [pathname, destination] of [
  ["/", "https://fanr.co/pulse/"],
  ["/privacy", "https://fanr.co/pulse/privacy/"],
  ["/support", "https://fanr.co/pulse/support/"],
]) {
  test(`redirects ${pathname} to the canonical site`, async () => {
    const response = await render(pathname);
    assert.ok([307, 308].includes(response.status));
    assert.equal(response.headers.get("location"), destination);
  });
}
