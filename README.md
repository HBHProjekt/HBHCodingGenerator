# HBHCoding Generator · webová verze

## Spuštění

Otevři `index.html` v aktuálním Chrome nebo Edge. Aplikace je statická a běží lokálně v prohlížeči; JSONy se nikam neodesílají. Nevyžaduje instalaci ani server.

Všechny soubory ve složce `data` ponech vedle `index.html`. `catalog-data.js` obsahuje vestavěný CCI katalog, IFC 4.3 schéma a české popisy entit.

## Funkce

- Načtení jednoho nebo více HBHCoding JSONů jako základu nebo dosypání; při kolizi si uživatel volí mezi zachováním a nahrazením.
- Import seznamu kódů z CSV a XLSX, výběr listu a sloupce a nastavení výskytu `Civil_code` / `DSS_code`.
- Ruční založení datového objektu, úprava CCI typového aspektu a sestavení jedné či více CCI produktových cest.
- Výběr IFC entity, `PredefinedType` a IFC typové entity s fulltextovým hledáním, českým popisem a anglickým popisem ze schématu.
- U IFC entit a typových entit se zobrazuje anglický originál vlevo a český překlad vedle něj v samostatném sloupci.
- Úprava `ObjectType` a `ElementType`, hromadné použití produktové cesty a bezpečné doplnění shodných CCI kombinací.
- Export projektu ve struktuře HBHCoding 0.3; neznámá pole v načtených objektech zůstávají zachována.

Starý excelový formát XLS musí být před importem uložen jako XLSX nebo CSV. Při exportu prohlížeč stáhne JSON do obvyklé složky pro stahování.

## Obnova vestavěných katalogů

Po změně CCI sešitu, IFC schématu nebo českých popisů spusť v PowerShellu ze složky projektu:

```powershell
.\HbhCodingGenerator.Web\build-catalogs.ps1
```

Skript znovu vytvoří `data/catalog-data.js` z lokálních zdrojových souborů v `DSS`, `ifcopenshell` a `HbhCodingGenerator`.
