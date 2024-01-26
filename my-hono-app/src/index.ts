import { Hono } from "hono";
import {jsonnet_make, jsonnet_destroy, jsonnet_evaluate_snippet} from "jsonnet_wasm";

const app = new Hono();

const jsonnet = jsonnet_make();

app.get("/", async (c) => {
  const code = `
  local Person(name='Alice') = {
    name: name,
    welcome: 'Hello ' + name + '!',
  };
  {
    person1: Person(),
    person2: Person('Bob'),
  }`;
  const result = jsonnet_evaluate_snippet(jsonnet, "snippet", code);
  console.log(result);
  jsonnet_destroy(jsonnet);
  return c.text("Hello Hono!");
});

export default app;
