# ChitarraTune — Sito GitHub Pages

Sito statico in stile macOS per presentare e distribuire ChitarraTune. Include SEO, accessibilità, badge GitHub e pagina 404.

## Setup rapido (GitHub Pages)
- Crea un repo pubblico chiamato `chitarratune.github.io` nel tuo account GitHub.
- Copia i file di questa cartella nella root del repo e fai push su `main`.
- Il sito sarà pubblicato su `https://<tuo-utente>.github.io/` (o su un dominio personalizzato se configurato).

## Configura link di repository e download
I link principali sono guidati da attributi `data-*` in `index.html` e inizializzati da `assets/js/main.js`.
- `data-github`: URL del repository dell’app (esempio: `https://github.com/<utente>/ChitarraTune`).
- `data-download`: URL della release (esempio: `https://github.com/<utente>/ChitarraTune/releases/latest`).

Attenzione agli slash doppi:
- Evita di aggiungere una `/` finale se poi concateni un percorso che inizia con `/` (o viceversa).
- Preferisci URL assoluti completi come negli esempi sopra per scongiurare `//` accidentali.

## SEO e Social
`index.html` include Open Graph, Twitter Card, canonical e JSON‑LD `SoftwareApplication`.
- Se pubblichi su un dominio diverso, aggiorna: `link[rel=canonical]`, `og:url` e `twitter:image`.
- Per evitare `//`, usa URL assoluti (es: `https://example.com/chitarratune.png`).

## Icone
- L’icona del sito è `assets/img/app-icon.svg` (favicon + UI). Sostituiscila mantenendo nome e percorso.
- Facoltativo: Apple touch icon (PNG 180×180) con `<link rel="apple-touch-icon" href="/apple-touch-icon.png">` (verifica di non introdurre `//`).

## Personalizzazioni
- Stili (colori/tipografia/layout): `assets/css/main.css`
- Sezioni e testi: `index.html`
- Badge: generati da `assets/js/main.js` usando `data-repo="owner/repo"` su `#badges`.

## Anteprima locale
Usa un server statico per testare i percorsi relativi.
- Python: `python3 -m http.server 8080`
- Node (serve): `npx serve -l 8080`
Apri `http://localhost:8080/` e verifica che i link non producano `//`.

## Risoluzione problemi
- Slash doppi `//`:
  - Evita trailing slash negli URL base se il percorso successivo inizia con `/`.
  - Usa URL assoluti quando possibile (niente concatenazioni manuali).
  - Controlla `og:url`, `twitter:image` e i link in `index.html`.
- Badge vuoti: assicurati che `data-repo` sia nel formato `owner/repo` corretto.

## Licenza
Distribuito con licenza BSD 3‑Clause. Vedi `license.html`.
