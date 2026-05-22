# ClearSpend DeepSeek Proxy

This Cloudflare Worker keeps the DeepSeek API key out of the iOS app. The app calls `/invoke-llm`, the Worker checks the ClearSpend client header, then forwards the prompt to DeepSeek `deepseek-v4-pro`.

## Setup

Install dependencies:

```sh
npm install
```

Store the DeepSeek key as a Worker secret:

```sh
npx wrangler secret put DEEPSEEK_API_KEY
```

For local development, create `server/deepseek-proxy/.dev.vars`:

```sh
DEEPSEEK_API_KEY=your_key_here
```

`.dev.vars` is ignored by git.

## Run Locally

```sh
npm run dev
```

## Deploy

```sh
npm run deploy
```

After deploy, copy the Worker URL into `APIConstants.aiProxyURL` in the iOS app.
