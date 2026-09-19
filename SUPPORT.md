# Support

Thanks for using ChitarraTune. The **[User Guide](docs/guide/en/index.md)** explains how to use it, task by task; on the Mac it is also in the app, under Help ▸ ChitarraTune Help. For anything else, help is one of these away:

- **Email:** [gpicchiarelli@gmail.com](mailto:gpicchiarelli@gmail.com?subject=ChitarraTune), in English or Italian.
- **Bugs and ideas:** [open an issue](https://github.com/gpicchiarelli/ChitarraTune/issues/new/choose) (needs a free GitHub account).
- **Security problems:** report them privately, as described in [SECURITY.md](SECURITY.md).

When something goes wrong, the most useful thing to send is the diagnostic report. Open **About ChitarraTune** (on the Mac in the *ChitarraTune* menu; on iPhone and iPad at the bottom of *Settings*), choose **Copy Diagnostics** and paste it into your message. It holds the app and system versions, the app's own recent log and a summary of earlier crashes: never audio, never personal data.

## Common questions

**The needle does not move.** Check that ChitarraTune may use the microphone: *Settings ▸ Privacy & Security ▸ Microphone*, on iPhone, iPad and Mac. Then play a little closer to the microphone. The tuner adapts to how quiet your room is, but it cannot hear a string below the room's own noise. If one string stays silent, send the diagnostic report after trying it: its `stream:` line says whether the sound was too quiet, not clear enough, or too far from any string.

**It shows the wrong string.** Tap the string you are tuning to pin it: the tuner then listens only for that one. Tap **Auto** to go back to automatic detection.

**The reading wobbles.** Let the string ring and do not touch the others; the tuner measures one string at a time. Mute the strings you are not tuning, and keep the guitar close to the microphone.

**My audio interface is not used.** On the Mac, choose it from the microphone menu in the window's toolbar; the tuner listens to whichever input channel your guitar is on. On iPhone and iPad, connect it before you start listening: iOS chooses the input.

**Listening stopped by itself.** After a period of silence the tuner stops, so the microphone does not drain the battery. Change or turn this off in *Settings ▸ Battery ▸ Stop When Silent*.

**I tune to A = 432 Hz, or to baroque 415.** Set it in *Settings ▸ Calibration ▸ Reference Pitch (A4)*.

**Which version do I have?** It is shown in About, and at the top of the diagnostic report.

---

## Assistenza

Il **[Manuale utente](docs/guide/it/index.md)** spiega come usare ChitarraTune, passo per passo; sul Mac è anche nell'app, in Aiuto ▸ Aiuto di ChitarraTune. Per tutto il resto:

- **Email:** [gpicchiarelli@gmail.com](mailto:gpicchiarelli@gmail.com?subject=ChitarraTune), in italiano o in inglese.
- **Problemi e idee:** [apri una issue](https://github.com/gpicchiarelli/ChitarraTune/issues/new/choose) (serve un account GitHub gratuito).
- **Problemi di sicurezza:** segnalali in privato, come spiegato in [SECURITY.md](SECURITY.md).

Se qualcosa non va, la cosa più utile da inviare è il resoconto diagnostico. Apri **Informazioni su ChitarraTune** (sul Mac nel menu *ChitarraTune*; su iPhone e iPad in fondo alle *Impostazioni*), scegli **Copia diagnostica** e incollalo nel messaggio. Contiene le versioni dell'app e del sistema, il log recente dell'app e un riepilogo degli arresti anomali precedenti: mai audio, mai dati personali.

**L'ago non si muove.** Verifica che ChitarraTune possa usare il microfono in *Impostazioni ▸ Privacy e sicurezza ▸ Microfono*, poi suona un po' più vicino al microfono. L'accordatore si adatta al silenzio della stanza, ma non sente una corda più debole del rumore di fondo. Se una corda resta muta, prova e poi invia il resoconto diagnostico: la riga `stream:` dice se il suono era troppo debole, poco chiaro o troppo lontano da ogni corda.

**Riconosce la corda sbagliata.** Tocca la corda che stai accordando per fissarla; tocca **Auto** per tornare al riconoscimento automatico.

**La lettura oscilla.** Lascia suonare la corda senza toccare le altre: l'accordatore misura una corda alla volta. Smorza le corde che non stai accordando e tieni la chitarra vicina al microfono.

**L'ascolto si è fermato da solo.** Dopo un periodo di silenzio l'accordatore si ferma per non scaricare la batteria. Puoi cambiarlo in *Impostazioni ▸ Batteria ▸ Ferma in silenzio*.

**Accordo a La = 432 Hz, o al barocco 415.** Impostalo in *Impostazioni ▸ Calibrazione ▸ Diapason (La4)*.
