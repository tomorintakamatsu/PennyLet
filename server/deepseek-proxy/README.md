# ClearSpend AI Proxy

This Cloudflare Worker keeps the AI provider key out of the iOS app. The app calls `/invoke-llm`, the Worker checks the ClearSpend client header, then forwards the prompt to the configured provider model for the user's access tier.

## Setup

Install dependencies:

```sh
npm install
```

Store the provider key as a Worker secret:

```sh
npx wrangler secret put AI_PROVIDER_API_KEY
```

For local development, create `server/deepseek-proxy/.dev.vars`:

```sh
AI_PROVIDER_API_KEY=your_key_here
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
