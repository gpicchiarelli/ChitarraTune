# Conformità Apple – ChitarraTune

Aspetti rilevanti per App Store, Human Interface Guidelines e requisiti di sistema.

---

## ✅ Già a posto

| Aspetto | Stato |
|--------|--------|
| **Privacy manifest** | `PrivacyInfo.xcprivacy`: no tracking, no dati raccolti, UserDefaults (CA92.1) |
| **Microfono** | `NSMicrophoneUsageDescription` in Info.plist, localizzato (it/en) in InfoPlist.strings |
| **Sandbox** | Abilitata; solo `device.audio-input` |
| **Categoria** | `LSApplicationCategoryType` = music |
| **Localizzazione** | it + en (CFBundleLocalizations, Localizable.strings, InfoPlist.strings) |
| **Copyright** | NSHumanReadableCopyright in Info.plist |
| **Accessibilità** | Label e value su schermata principale e nota; Dynamic Type; annunci VoiceOver (macOS) |
| **Nessun log** | Nessun OSLog/print in produzione |

---

## Consigliati / da verificare

### 1. **Export compliance (crittografia)**  
L’app non usa crittografia propria (no rete, no HTTPS nell’app). In App Store Connect, alla domanda “Does your app use encryption?” puoi rispondere **No**.  
Se in futuro aggiungi rete: valuta se dichiarare `ITSAppUsesNonExemptEncryption` = NO in Info.plist se usi solo HTTPS standard.

### 2. **Accessibilità (estensione)**  
- Aggiungere `accessibilityHint` sui pulsanti principali (Avvia/Stop, Auto/Manuale, preset).  
- Verificare ordine di lettura VoiceOver (soprattutto barra tuner e pulsanti).  
- Rispettare **Reduce Motion**: evitare animazioni non necessarie se l’utente ha attivato “Riduci movimento”.

### 3. **iOS / iPad (quando li aggiungi)**  
- Stessa `NSMicrophoneUsageDescription` (già localizzata).  
- Aggiungere `UIBackgroundModes` solo se serve audio in background (es. tuner attivo con app in secondo piano).  
- Controllare che il Privacy manifest sia incluso nel target iOS (stesso file condiviso va bene).

### 4. **App Store Connect (al momento della submission)**  
- **Age rating**: di solito 4+ (nessun contenuto sensibile).  
- **Privacy Nutrition Labels**: “Data Not Collected” (nessuna raccolta dati).  
- **Support URL** e **Marketing URL** (se previsti dalla scheda app).  
- **Notarization** (macOS): richiesta per distribuzione fuori dall’App Store; per distribuzione solo tramite App Store la gestisce Apple.

### 5. **Human Interface Guidelines**  
- Layout già adattivo (size class, Dynamic Type).  
- Evitare stati UI che “spariscono” senza feedback (es. pulsante che non indica “in ascolto”).  
- Mantenere contrasti adeguati per accessibilità visiva (test con “Increase contrast” se possibile).

### 6. **Info.plist opzionali (macOS)**  
- `NSSupportsDocumentConnection` / `NSSupportsAutomaticTermination`: già usato `NSSupportsAutomaticTermination`.  
- `LSRequiresNativeExecution`: già impostato (esecuzione nativa).

---

## Riepilogo

Per **piena conformità Apple** in vista dell’App Store sono già coperti: privacy (manifest + microfono), sandbox, localizzazione, copyright e base di accessibilità. Il resto è miglioramento progressivo (accessibilità dettagliata, Reduce Motion, etichetta privacy in App Store Connect e notarization per distribuzione macOS fuori dall’App Store).
