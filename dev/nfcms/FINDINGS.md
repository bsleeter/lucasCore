# P26 historical run vs NFCMS v3.0, 2020 (validation) - 2026-10-26

`01-p26-2020.R`: result 14 (P26 historical run, 150 m, iteration average) against NFCMS 3.0 (RDS-2025-0019, PSW, 30 m averaged over each
cell's forest pixels), on cells forest in both (20,420 km2). Outputs in dev/nfcms/out.

| Pool (2020) | lucasCore Tg C | NFCMS Tg C | ratio | Mg C/ha (lucas / NFCMS) | cell correlation |
| --- | --- | --- | --- | --- | --- |
| Live biomass (above + below, leaves, fine roots) | 218.8 | 291.9 | 0.75 | 107 / 143 | 0.82 |
| Aboveground woody (no leaves) | 172.8 | 196.7 | 0.88 | 85 / 96 | 0.81 |
| Soil (organic + mineral) | 168.0 | 156.9 | 1.07 | 82 / 77 | 0.51 |
| Total ecosystem | 449.0 | 569.8 | 0.79 | 220 / 279 | 0.78 |

- Where carbon is placed agrees well (live r = 0.82); the levels differ.
- Aboveground wood is 12% lower; most of the live gap is roots and foliage: live minus aboveground wood is 22 Mg C/ha in lucasCore
  (27% of wood) and 47 in NFCMS (48% of wood).
- Dead wood and litter (total - live - soil): 30 Mg C/ha in lucasCore, 59 in NFCMS.
- Soil: 7% higher in lucasCore (calibrated to gSSURGO), weakly correlated (0.51).
- By type, the largest live gaps are Western Oak (58 vs 104 Mg C/ha), Pinyon/Juniper and Ponderosa Pine; California Mixed Conifer is
  closest (128 vs 157). Every county is low (total ecosystem ratio 0.74-0.94).
- Forest area: lucasCore's 2020 forest state classes cover 21,394 km2, NFCMS forest pixels 27,636 km2 (20,420 in both).
