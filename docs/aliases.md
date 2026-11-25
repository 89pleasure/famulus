# Aliase

Teil des Projektwissens; Vorgaben, Regeln und die Übersicht aller Dateien stehen in
[AGENTS.md](../AGENTS.md). Verweise der Form „siehe X“ meinen eine Überschrift oder einen fett
gesetzten Eintrag; in welcher Datei er steht, sagt die Übersicht dort.

Eigene Namen für andere Spieler, Vorbild ist das Addon CustomNames
(`github.com/Jods-GH/CustomNames`, unterstützt Forever). Entscheidungen des Assistenten vom
2026-11-16, vom Auftraggeber noch nicht bestätigt:

- **Eigene Kategorie `aliases`** mit Hauptschalter, als eigener Bereich in der Seitenleiste (seit
  2026-11-18, siehe „Das Fenster“). Reiter „Namen“: Eingabezeile (Charaktername, Alias,
  „Speichern“) und je Alias eine Zeile (Klick lädt sie in die Eingabezeile, das Kreuz entfernt
  sie); Reiter „Einstellungen“: die Features. Die Suche findet Aliase und Charakternamen.
- **Daten, keine Einstellung:** `FamulusDB.aliases = { [schlüssel] = { name, alias } }`, accountweit,
  außerhalb der Profile; „Zurücksetzen“ und Profilwechsel lassen die Liste in Ruhe. Zugriff nur
  über `ns.AliasService` (`Modules/Aliases/AliasService.lua`); Änderungen melden sich mit dem Signal
  `ALIASES_CHANGED`.
- **Schlüssel:** voller Charaktername, klein geschrieben, Leerzeichen und Bindestriche zu „-“. Forever
  hat keine Realms, sondern Vor- und Nachname (`UnitName` liefert `name, surname`); der Client
  schreibt denselben Namen je nach Stelle mit Leerzeichen oder Bindestrich. Welche Schreibweise der
  Chat liefert, ist unbestätigt, deshalb die Normalisierung; der Selbsttest (Gruppe `names`) hält
  Trennzeichen und Form von `UnitName("player")` fest, ohne einen Namen zu speichern.
- **Alias ist reiner Text:** `|` wird entfernt (keine Farben, Texturen, Links), höchstens 48 Bytes.
- **`chatAliases`:** `ChatFrameUtil.AddSenderNameFilter` ändert nur den Text in den Klammern; das
  Linkziel bleibt der echte Name. Der Filter lässt sich entfernen (`RemoveSenderNameFilter`), der
  Client überspringt ihn bei secret Namen selbst. Nicht `AddMessageEventFilter` (würde auch das
  Linkziel ändern) und kein Hook auf `AddMessage` (CustomNames ersetzt dort die Methode). Schon
  gedruckte Zeilen ändern sich nicht. Option `style`: „Alias“ oder „Alias (Name)“.
- **`tooltipAliases`:** eigene Zeile über `TooltipDataProcessor` (Typ `Unit`), nur für Spieler; die
  Namenszeile des Spiels wird nicht überschrieben.
- **`aliasMenu`:** `Menu.ModifyMenu` auf die Spieler-Menüs (`aliasMenu.TAGS`), fügt „Alias
  festlegen/ändern/entfernen“ an. „Festlegen“ öffnet das Fenster auf der Seite mit eingetragenem Namen
  (`ns:EditAlias`); kein eigener Dialog und kein Eintrag in `StaticPopupDialogs`. Im Forever-Client
  trägt `contextData` `name` und `surname`, kein `server`.
- **Alle Alias-Features sind standardmäßig an:** Sie handeln nicht im Namen des Spielers und tun ohne Alias
  nichts; sie brauchen keinen Timer und, außer `accountAliases` bei vorhandenem Account-Alias,
  kein Spielereignis.
- **Andere Addons (Entscheidung des Auftraggebers, 2026-11-18):** gezielt unterstützen, keine
  öffentliche Schnittstelle (Famulus ist zu unbekannt, als dass andere sie einbinden würden).
  Je Anbindung ein Feature `Modules/Aliases/<Addon>Aliases.lua` mit `addon = "<Ordnername>"`: Ohne
  das Addon bleibt es aus und fehlt im Fenster; `## OptionalDeps` in der `.toc` lädt das Addon
  zuerst. Nur über dessen offizielle Erweiterungspunkte, nichts ersetzen. Weitere stehen noch nicht
  fest. Eine Automatik für alle Addons gibt es nicht ohne `AddMessageEventFilter` (ändert das
  Linkziel) oder überschriebene Methoden (Taint).
- **`guildyAliases` (2026-11-18, im Spiel bestätigt):** Guildy
  (`github.com/svengabr/Guildy`) baut seinen Chat selbst, der Absenderfilter erreicht ihn nicht, und
  es hatte keinen Erweiterungspunkt. Deshalb ein PR an Guildy (Branch `name-formatter-api` im Fork
  `89pleasure/Guildy`): `GuildyAPI.RegisterNameFormatter(owner, fn)`,
  `UnregisterNameFormatter`, `Refresh`; Guildy fragt den Formatter in `W.ClassName`, Links behalten
  den echten Namen. Das Feature meldet dort einen Formatter an (Option `style` wie im Chat) und ruft
  bei `ALIASES_CHANGED` `Refresh`. Entscheidung des Auftraggebers (2026-11-18): Der PR wird erst
  eingereicht, wenn Famulus veröffentlicht werden soll; bis dahin wird mit dem Fork gearbeitet.
  Das installierte Guildy im Spielordner ist ein Klon des Branches (Remotes `fork` und `upstream`).
  Aktuell halten: dort `git fetch upstream && git rebase upstream/main`, Tests (`luajit
  tests/run.lua`), dann `git push --force-with-lease fork name-formatter-api`. Mit dem normalen
  Guildy fehlt das Feature einfach. Im Spiel bestätigt: Aliase
  erscheinen in Guildy. Ein früherer Test per `/run` mit einem eigenen Formatter zeigte nichts;
  die Ursache wurde nicht geklärt, die Anbindung selbst funktioniert.
- **Alias für einen Battle.net-Account (Wunsch des Auftraggebers, 2026-11-23, nach dem Vorbild von
  CustomNames; nur gegen den Mock geprüft, noch nicht im Spiel):** Ein Alias am BattleTag gilt für
  alle Charaktere des Freundes, man muss nicht je Charakter einen anlegen. Aufbau und Grenzen sind
  Entscheidungen des Assistenten:
  - **Daten:** `FamulusDB.accountAliases = { [battletag klein] = { tag, alias, chars = { [schlüssel]
    = "Vorname Nachname" } } }`, accountweit, außerhalb der Profile. Gespeichert werden nur Accounts
    mit Alias (keine Sammlung aller Battle.net-Freunde). `AliasService.Set` und `GetOwn` nehmen
    Charaktername oder BattleTag (`Name#1234`; ein Charaktername enthält nie „#“).
    `AliasService.Get(name)` liefert den eigenen Alias des Charakters, sonst den seines Accounts:
    **Der Alias am Charakter hat Vorrang** (wie bei CustomNames). Chat, Tooltip, Guildy und Chronik
    brauchen dafür keine Änderung.
  - **Woher die Charaktere kommen:** Der Client verrät nur, mit welchem Charakter ein
    Battle.net-Freund gerade online ist (`C_BattleNet.GetFriendAccountInfo(i).gameAccountInfo`,
    dazu `GetFriendNumGameAccounts`/`GetFriendGameAccountInfo` für weitere Lizenzen; nur
    `wowProjectID == WOW_PROJECT_ID`). `AliasService.ScanFriends` liest die Liste und merkt sich
    die Charaktere dauerhaft. Ein Charakter, mit dem der Freund nie online gesehen wurde, hat
    den Alias also noch nicht. Beim Setzen eines Account-Alias wird einmal sofort gelesen.
  - **Feature `accountAliases`** (`Modules/Aliases/AccountAliases.lua`, Standard an): lauscht auf
    `BN_FRIEND_INFO_CHANGED` (nennt den Platz in der Liste, dann wird nur dieser Freund gelesen),
    `BN_FRIEND_ACCOUNT_ONLINE` und `BN_CONNECTED`, aber **nur, solange mindestens ein Account einen
    Alias hat**. Mit Standardwerten ist deshalb weiter kein Spielereignis registriert; das ist die
    Begründung, warum es trotz Spielereignissen standardmäßig an ist. Abgeschaltet gelten
    Account-Aliase weiter für die schon bekannten Charaktere.
  - **Fenster:** Das Namensfeld nimmt „Charakter oder BattleTag#1234“. Ein Account steht in der
    Liste mit „Battle.net · Tag · seine Charaktere“ (oder „noch kein Charakter gesehen“); die Suche
    findet ihn auch über einen Charakter.
  - **Kontextmenü:** zusätzlich `MENU_UNIT_BN_FRIEND` und `MENU_UNIT_BN_FRIEND_OFFLINE`
    (`contextData.battleTag`, sonst `contextData.accountInfo.battleTag`, so setzt es
    `FriendsFrame_ShowBNDropdown` im Forever-Quellcode). Einträge „Alias für alle Charaktere
    festlegen/ändern/entfernen“. Im Menü eines Charakters erscheinen sie zusätzlich, wenn er zu
    einem Account mit Alias gehört oder ein Battle.net-Freund gerade mit ihm online ist
    (`AliasService.FindBattleTag` geht dafür beim Öffnen des Menüs die Freundesliste durch).
  - **Nicht enthalten:** Charaktere von Hand einem Account zuordnen oder wieder lösen (CustomNames
    kann beides), ein Alias für den eigenen Account, Aliase vor Battle.net-Flüstern (dort steht
    ohnehin der Account-Name). Ein gemerkter Charakter bleibt beim Account, bis dessen Alias
    entfernt wird, auch wenn der Freund ihn löscht.
  - **Im Spiel ungeprüft:** ob `characterName` in Forever Vor- und Nachname enthält und mit
    welchem Trennzeichen (der Schlüssel gleicht Leerzeichen und Bindestrich an), ob
    `wowProjectID` für Forever-Charaktere gleich `WOW_PROJECT_ID` ist, die Argumente der drei
    Ereignisse und die beiden Menü-Tags. `/fam test` meldet dazu (Gruppe `names`, „Battle.net
    friends“), wie viele Freunde auf einem Charakter dieses Spiels sind und wie die Namen
    geschrieben werden, ohne einen Namen zu speichern.
- **Bewusst nicht enthalten:** Aliase auf Blizzards Unitframes, Raidframes und Namensplaketten
  (CustomNames überschreibt dort `SetText` auf Blizzards FontStrings, Taint-Risiko, Namen im Kampf
  secret), Gildenliste, Import/Export, Slash-Befehl zum Eintragen.
