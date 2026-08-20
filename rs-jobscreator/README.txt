RS Jobs Creator 1.1.0

INSTALLATIE
1. Plaats de map rs-jobscreator in resources/[rs]/
2. Controleer dat deze resources gestart zijn:
   - oxmysql
   - es_extended
   - ox_lib
   - ox_inventory (nodig voor stash/shop/crafting/harvest/process)
3. Zet in server.cfg:
   ensure oxmysql
   ensure ox_lib
   ensure es_extended
   ensure ox_inventory
   ensure rs-jobscreator
4. Geef je admin/txAdmin-groep toegang of voeg ACE toe:
   add_ace group.admin rsjobscreator.admin allow
5. Open met /jobscreator of F10.

WEBHOOK LOGGING
- Vul Config.WebhookUrl in om beheeracties en callback/serverfouten naar Discord te loggen.
- Config.WebhookName bepaalt de naam van de webhookbot.
- Laat Config.WebhookUrl leeg om webhooklogging uit te schakelen.

BELANGRIJK
- Deze resource voert GEEN ALTER TABLE uit. Daardoor veroorzaakt hij niet de 'Duplicate column whitelisted'-fout.
- De resource detecteert automatisch of jobs.whitelisted en jobs.enabled bestaan.
- De standaard ESX jobs/job_grades/users tabellen moeten al door ESX aanwezig zijn.
- rs_jobscreator_points en rs_jobscreator_logs worden automatisch aangemaakt.
- Job rename/delete en rang-delete gebruiken transacties zodat een SQL-fout geen halve wijziging achterlaat.
- Servercallbacks zijn afgevangen zodat een fout altijd als response naar de NUI terugkomt.
- Online ESX-spelers worden direct gesynchroniseerd bij job rename/delete en rang-delete.

BESTAANDE JOBS
Je kunt bestaande ESX jobs beheren zonder ze opnieuw te importeren.
Nieuwe jobs krijgen automatisch grade 0 'employee'.

JOB & RANG IMPORTER
- Open Jobs Creator > Importeren.
- Kies bij "Jobs & rangen uit resource halen" een gestarte resource.
- De scanner zoekt onder andere naar ESX.RegisterSociety, Config.JobName, Config.Job en veelvoorkomende rangtabellen.
- Gevonden jobs tonen bronbestand en detectiezekerheid voordat je importeert.
- Importeren werkt merge-safe: bestaande jobs blijven bestaan en gevonden grades worden toegevoegd of bijgewerkt.
- Dynamische, gecompileerde of encrypted/escrow configs kunnen niet altijd automatisch worden uitgelezen.

PUNTEN
- Interactiepunten worden server-side gecontroleerd op job, grade, duty en afstand.
- De getPoints response gebruikt vanaf 1.1.0 het verwachte response.points formaat, zodat punten werkelijk op de client geladen worden.
- De interactie gebruikt ox_lib context menus en ox_inventory.

NPC / PROP SELECTIE
- NPC en prop instellingen hebben een echte dropdown met de ingebouwde modellenlijst.
- "Custom model invoeren" blijft beschikbaar voor eigen peds, props en MLO-objectmodellen.
