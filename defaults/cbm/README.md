# CBM-CFS3 default tables

Copied unchanged from the ApexRMS lucasbuilder 2.0.4 package (`data/`), which takes them from the CBM-CFS3 archive index defaults
(Natural Resources Canada). lucasCore uses them only in stage 3, where no FIA source exists:

- `tblDOMParametersDefault.csv`, `tblSlowAGToBGTransferRate.csv`: DOM base decay rates, Q10, reference temperature and the share
  emitted (decay is evaluated at each ecodivision's PRISM temperature; stage 3b calibrates it to FIA dead-carbon stocks).
- `tblEcoBoundaryDefault.csv`, `tblSpeciesTypeDefault.csv` through `species-crosswalk.csv` (each forest state class -> CBM ecozone
  and species): stem, branch, foliage and root turnover rates and snag-to-DOM transfers. Foliage fall is weighted by each class's
  US deciduous share (FIA species volume, `defaults/growth/merch-carbon-density.csv`).

Not used: the Boudewyn stemwood tables (2026-10-20: stage 2 converts merchantable volume to carbon with US wood and bark densities,
`defaults/growth/merch-carbon-density.csv`, from FIA REF_SPECIES and EVALIDator) and the disturbance matrices (LUCAS event flows
are in `defaults/stockflow/event-pathways.csv`).
