# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an ASP.NET Web Forms website (.NET Framework 4.5) that acts as a middleware bridge between the [Nightscout](https://nightscout.github.io/) CGM API (and Sugarmate.io) and the [LaMetric TIME](https://lametric.com/) smart display API.

The web service is deployed directly to IIS as a website — there is no compilation step; files are deployed as-is and compiled on first request by ASP.NET.

## Deployment

Deploy the files directly to an IIS website root. `Web.config` is gitignored (private) and must be present on the server. The solution file (`lametric_ns_mon.sln`) references an external physical path for local development with Visual Studio.

To test locally, open the solution in Visual Studio and use IIS Express (port 61878).

## Architecture

The entire service logic lives in two files:

- **`lametric.ashx`** — The sole HTTP handler (`NSConvert1 : IHttpHandler`). Accepts query parameters, fetches data from upstream APIs, and returns LaMetric-formatted JSON.
- **`App_Code/DynamicJsonConverter.cs`** — A `JavaScriptConverter` that deserializes JSON into `dynamic` objects via `DynamicJsonObject : DynamicObject`. This is needed because `JavaScriptSerializer` doesn't support `dynamic` natively.

## Request Parameters

The handler accepts these query string parameters:

| Parameter | Description |
|-----------|-------------|
| `site` | Nightscout hostname (e.g. `yoursite.herokuapp.com`) or `sugarmate.io` |
| `token` | Nightscout API token, or Sugarmate username |
| `units` | `mg/dL` or `mmol/L` |
| `low` | Low BG threshold (default: 70 mg/dL or 3.9 mmol/L) |
| `high` | High BG threshold (default: 160 mg/dL or 8.9 mmol/L) |
| `timeago` | `true`/`1` to include a "minutes ago" frame |
| `chart` | `true`/`1` to include a sparkline chart frame |

## Response Format

Returns LaMetric JSON with up to 3 frames:
1. **Index 0** — BG value + delta, with a directional trend icon (normal or red if out of range)
2. **Index 1** (optional) — Minutes since last sensor reading; uses a different icon if stale (>330 seconds)
3. **Index 2** (optional) — Sparkline chart of last ~9 SGV readings, normalized by subtracting 54

`sgv.json` is a sample response for reference.

## Upstream APIs

- **Nightscout**: fetches from `/api/v1/entries.json` (raw SGV data for chart) and `/api/v2/properties/bgnow,delta` (current reading + delta)
- **Sugarmate**: fetches from `https://sugarmate.io/api/v1/{token}/latest.json`

The Sugarmate path does not support the chart frame.

## LaMetric Icon IDs

Trend arrow icons use these LaMetric store IDs (animated icons use `a` prefix, static use `i`):

| Direction | Normal | Out-of-range (red) |
|-----------|--------|-------------------|
| DoubleUp | a30916 | a30924 |
| SingleUp | i30914 | i30922 |
| FortyFiveUp | i30912 | i30920 |
| Flat | i30913 | i30921 |
| FortyFiveDown | i30911 | i30919 |
| SingleDown | i30915 | i30923 |
| DoubleDown | a30917 | a30925 |
| Stale/Unknown | i3769 | — |
| Stale time indicator | i30918 (fresh) / i30926 (stale) | — |
