# go_macos_todo

Minimal Go backend scaffold for the todo app.

## Environment Setup

1. Copy env template:

```bash
cp .env.example .env
```

2. Set your Appwrite auth API key in `.env`:

```env
APPWRITE_AUTH_API_KEY=your_real_key
```

## Run

```bash
make run
```

Server starts on `http://localhost:8080` with `GET /hello`.
