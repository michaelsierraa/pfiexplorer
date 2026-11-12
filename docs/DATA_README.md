# Police Firearm Injury Explorer (PFIE) data, 2014–2020

Data on firearm injuries to on-duty U.S. law enforcement officers shot by suspects, 2014–2020. The data derive from the Gun Violence Archive (GVA). The project team manually verified, cleaned, and recoded each case.

Live app: https://pfiexplorer.com
Code repository: https://github.com/michaelsierraa/pfiexplorer

## Files

| File | Contents |
|---|---|
| `pfie20142020.csv` | Main dataset. 1,779 rows, one per injured officer, covering 1,437 unique GVA incident IDs. |
| `statecentroids.csv` | State centroid latitude and longitude. The app uses it as a fallback when an incident has no point location. |
| `statebounds.csv` | State bounding boxes. The app uses them to fit the map to a state. |
| `PFIE GVA Data Cleaning Guide.pdf` | Inclusion criteria, cleaning steps, and coding rules. |
| `data_dictionary.md` | Description of every column in the main dataset. |

## Scope

- Period: 2014-01-02 to 2020-12-29.
- Geography: 50 states and the District of Columbia.
- Included: sworn, on-duty officers of local or state agencies who were struck by a bullet or fragment from a firearm fired by someone who was not an on-duty officer. Shots to on-person equipment count.
- Excluded: off-duty, retired, corrections, and federal officers. Blue-on-blue shootings. Self-inflicted injuries. Cases with no officer struck.

The cleaning guide gives the full rules and the edge cases.

## Data source and rights

The incident records start from GVA (https://www.gunviolencearchive.org). GVA data are freely distributable. The project team verified each case against news and agency sources and recoded outcome and agency type.

The `sources` column holds URLs to news and agency pages. The pages may change or disappear. This deposit does not archive them.

## Citation

Sierra-Arévalo, Michael, Justin Nix, Aidan Bach, Paul Thomas Flaherty, Ciara Garcia, Kateryna Kaplun, Phillip Phu Pham, and Jamie Villarreal. 2026. *Police Firearm Injury Explorer (PFIE)*, Version 1 [Data set]. Harvard Dataverse. DOI: [to be added at publication]

The data are released under CC BY 4.0. Anyone who uses them must credit the authors and cite this dataset.

Earlier versions of this project were cited with the OSF DOI https://doi.org/10.17605/OSF.IO/6X2RP. The OSF project becomes read-only on 2027-02-19. The OSF DOI and URL are to be redirected to this record.

## Related publications

1. Sierra-Arévalo, Michael, Justin Nix, and Scott M. Mourtgos. 2023. The "war on cops," retaliatory violence, and the murder of George Floyd. *Criminology, 61*(3), 389–420. https://doi.org/10.1111/1745-9125.12334
2. Sierra-Arévalo, Michael, Justin Nix, and Bradley O'Guinn. 2022. A national analysis of trauma care proximity and firearm assault survival among U.S. police. *Police Practice and Research, 23*(3), 388–396. https://doi.org/10.1080/15614263.2022.2036611
3. Sierra-Arévalo, Michael, and Justin Nix. 2020. Gun victimization in the line of duty: Fatal and nonfatal firearm assaults on police officers in the United States, 2014–2019. *Criminology & Public Policy, 19*(3), 1041–1066. https://doi.org/10.1111/1745-9133.12507

## Contact

Michael Sierra-Arévalo, Department of Sociology, University of Texas at Austin (msa@utexas.edu).
