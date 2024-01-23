import { Hono } from "hono";
import { jsonnet } from "jsonnet_wasm";

const app = new Hono();

app.get("/", (c) => {
  const result = jsonnet("test.jsonnet");
  console.log(result);
  return c.text("Hello Hono!");
});

export default app;
