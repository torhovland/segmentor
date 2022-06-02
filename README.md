# Segmentor
A web app for analyzing Strava segments.

## Developing

In one shell:

```
nix develop
cd frontend
npm start
```

In another shell:

```
nix develop
cd backend
ENVIRONMENT=Development cargo run # or cargo watch -x run
```

Now go to http://localhost:8088/login.
