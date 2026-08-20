RS Jobs Creator 1.0.0

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

BELANGRIJK
- Deze resource voert GEEN ALTER TABLE uit. Daardoor veroorzaakt hij niet de 'Duplicate column whitelisted'-fout.
- De resource detecteert automatisch of jobs.whitelisted en jobs.enabled bestaan.
- De standaard ESX jobs/job_grades/users tabellen moeten al door ESX aanwezig zijn.
- rs_jobscreator_points en rs_jobscreator_logs worden automatisch aangemaakt.

BESTAANDE JOBS
Je kunt bestaande ESX jobs beheren zonder ze opnieuw te importeren.
Nieuwe jobs krijgen automatisch grade 0 'employee'.

PUNTEN
Punten worden server-side gecontroleerd op job, grade, duty en afstand.
De interactie gebruikt ox_lib context menus en ox_inventory.
