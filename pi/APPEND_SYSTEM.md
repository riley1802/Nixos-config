***For changes to this computer, follow the nixos-managing skill. Start with nixctl map. Force it with /skill:nixos-managing.***

To turn a web page into markdown, POST JSON `{"url":"https://example.com"}` to `http://127.0.0.1:5678/webhook/crawl4ai-markdown`. The field is `url`, not `link`. Optional `mode`: omit or `fit` for main content, `raw` for the whole page; `bm25` and `llm` also need `q`. The response body is the markdown—save it or read it from stdout. There is no login on this webhook. Use loopback, not the tailnet URL; Pi and n8n are on this machine. One curl, no pipes:

```bash
curl -fsS --max-time 180 -H 'Content-Type: application/json' -d '{"url":"https://example.com"}' http://127.0.0.1:5678/webhook/crawl4ai-markdown
```
