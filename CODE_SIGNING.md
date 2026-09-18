# Code signing (condizionale)

## Da cosa dipende il code sign?

La richiesta di **firma del codice** non è una scelta del progetto, ma della **politica del sistema operativo**:

- **macOS** (soprattutto da versioni recenti, es. 26 Tahoe) può **rifiutare di avviare** un eseguibile non firmato quando lo lanci da **Xcode** (Run). L’errore tipico è: *"The executable is not codesigned"* (LaunchExecutableValidationErrorDomain).
- Su **macOS più vecchi** o aprendo l’app **da Finder/Terminale** (doppio clic su `.app` o `open ChitarraTune.app`), l’avvio senza firma è spesso ancora consentito.
- Per **distribuzione** (App Store, notarizzazione, utenti esterni) la firma è **obbligatoria**.

Quindi: **il code sign è “dato” (richiesto) dal sistema operativo e dal contesto** (Xcode vs apertura manuale, versione macOS, distribuzione).

## Configurazioni nel progetto

Il progetto ha **due coppie** di configurazioni:

| Configurazione   | Firma              | Uso tipico                          |
|------------------|--------------------|-------------------------------------|
| **Debug**        | Sì (Automatic)     | Run da Xcode, sviluppo (firma con Team) |
| **Release**      | No (Manual, `-`)   | Build senza firma (es. CI con CODE_SIGNING_ALLOWED=NO) |
| **Debug-Signed** | Sì (Automatic)     | Come Debug, alternativa se usi scheme con Signed |
| **Release-Signed** | Sì (Automatic)   | Archive / distribuzione firmata     |

## Come usare

- **Scheme "ChitarraTune"** (predefinito): usa **Debug** con **firma automatica** (Team 7722WYMVXU). Il Run da Xcode firma l’app e la avvia; su macOS 26+ è richiesto. Se non hai ancora un Team, in Xcode vai su target ChitarraTune → **Signing & Capabilities** e imposta il tuo **Team** (Apple ID / Personal Team).
- Per build **senza firma** (es. CI): `xcodebuild ... CODE_SIGNING_ALLOWED=NO` oppure usa la configurazione **Release**.

Per **Archive** con firma: seleziona lo scheme **ChitarraTune-Signed** e fai **Product → Archive** (userà Release-Signed).
