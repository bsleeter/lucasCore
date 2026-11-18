// =============================================================================
// WoodProductsFate.cs - where the carbon of one year's harvest is a number of years later: the Wood Products page's diagram
// =============================================================================
// The wood products model of stage 18 (src/wood-products.R) for 100 units of harvested carbon (wood and bark) of one region, wood type
// and log size, with the published values (no draws) and the tables held at their last year, as the stage holds them for every later
// year. The page's levers (wp_levers in src/wood-products.R) act in full. Same steps as wp_inputs, wp_enduses and wp_pools: bark,
// fuelwood and mill residue burned with energy capture in the harvest year, primary products, end uses, the loss when placed in use,
// first-order decay in use, discard fates, recovered products discarded again, landfills (a fixed share never decays) and dumps.
// tests/unit-wood-products-fate.R runs the same cases in R and compares the two (tests/wood-products-fate.ps1 calls this class).
// No SyncroSim types here, so the check can load the class by itself. C# 5.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;

namespace lucasCoreUI
{
    public static class WoodProductsFate
    {
        public const double ShortLife = 12, LongLife = 67;   // WP_SHORT_LIFE, WP_LONG_LIFE
        public static readonly string[] Classes = { "Buildings", "Furniture and remodeling", "Short-lived wood products", "Paper" };
        public static readonly string[] Ends = { "Recovered", "Landfills", "Dumps", "Burned with energy capture", "Burned without energy capture or composted" };
        private static readonly string[] FateNames = { "Recovered", "Landfills", "Dumps", "Burned with energy capture", "Burned without energy capture", "Composted" };

        public class Levers
        {
            public double Long, Life = 1, Energy, RecWood = double.NaN, RecPaper = double.NaN, DiscEnergy = double.NaN;
            public bool Active { get { return Long != 0 || Life != 1 || Energy != 0 || !double.IsNaN(RecWood) || !double.IsNaN(RecPaper) || !double.IsNaN(DiscEnergy); } }
            // what the stage would refuse (wp_levers), or null
            public string Problem()
            {
                if (Long < 0 || Long > 1) return "Shift to long-lived products must be between 0 and 1.";
                if (Energy < 0 || Energy > 1) return "Extra share burned for energy must be between 0 and 1.";
                if (Life <= 0) return "Product lifetime multiplier must be above 0.";
                foreach (double v in new[] { RecWood, RecPaper, DiscEnergy }) if (!double.IsNaN(v) && (v < 0 || v > 1)) return "The shares of discards must be between 0 and 1.";
                foreach (double v in new[] { RecWood, RecPaper }) if (!double.IsNaN(v) && !double.IsNaN(DiscEnergy) && v + DiscEnergy > 1) return "Discards recovered and burned for energy add to more than 1.";
                return null;
            }
        }

        // every value in % of the harvested carbon
        public class Result
        {
            public int Years;
            public double Bark, Fuelwood, MillResidue, ExtraEnergy;                  // burned with energy capture in the harvest year
            public double AtHarvest { get { return Bark + Fuelwood + MillResidue + ExtraEnergy; } }
            public readonly double[] Made = new double[4], InUse = new double[4], Discarded = new double[4];   // by class; Discarded by the year shown, the loss when placed in use included
            public readonly double[] DiscTotal = new double[2];                      // wood, paper: discarded by the year shown (first time)
            public readonly double[,] To = new double[2, 5];                         // material x Ends: recovered is what is still there; the rest is all that went, recovered products discarded again included
            public double Recovered, Landfill, Dump, LandfillDecay, DumpDecay, EmitEnergy, EmitNo;
            public double InUseTotal { get { return InUse.Sum(); } }
            public double Stored { get { return InUseTotal + Recovered + Landfill + Dump; } }
            public double RecoveredDefault, RecoveredPaperDefault;                   // the tables' recovered shares (wood, paper), for the page's notes
        }

        // ---- tables, read once per folder -------------------------------------------------------------------------------------
        private class Tables
        {
            public Dictionary<string, string> RoundwoodRegion = new Dictionary<string, string>();
            public Dictionary<string, double[]> Roundwood = new Dictionary<string, double[]>();          // region|wood|log -> irr, bark, fuelwood
            public Dictionary<string, List<KeyValuePair<string, double>>> Primary = new Dictionary<string, List<KeyValuePair<string, double>>>();
            public Dictionary<string, Dictionary<string, double>> EndUse = new Dictionary<string, Dictionary<string, double>>();   // product -> end use -> ratio (last year)
            public List<string> Uses = new List<string>(); public List<double> HalfLife = new List<double>();
            public double[][] Fate = { new double[6], new double[6] };              // wood, paper x FateNames (last year)
            public double[] DumpHl = new double[2], LfFixed = new double[2], LfHl = new double[2], RecHl = new double[2];
            public double LossWood, LossPaper;
        }
        private static readonly Dictionary<string, Tables> s_tables = new Dictionary<string, Tables>(StringComparer.OrdinalIgnoreCase);
        private static double Num(string s) { return double.Parse(s, NumberStyles.Float, CultureInfo.InvariantCulture); }

        private static List<Dictionary<string, string>> Read(string dir, string file)
        {
            List<string[]> rows = Csv(Path.Combine(dir, file)); var l = new List<Dictionary<string, string>>(); if (rows.Count == 0) return l;
            string[] h = rows[0];
            foreach (string[] r in rows.Skip(1)) { var d = new Dictionary<string, string>(); for (int i = 0; i < h.Length && i < r.Length; i++) d[h[i].Trim()] = r[i].Trim(); l.Add(d); }
            return l;
        }
        // RFC 4180, as Defaults.ReadCsv (kept here so this class stands alone)
        private static List<string[]> Csv(string file)
        {
            var rows = new List<string[]>(); var row = new List<string>(); var f = new System.Text.StringBuilder();
            string s = File.ReadAllText(file); bool q = false;
            for (int i = 0; i < s.Length; i++)
            {
                char c = s[i];
                if (q) { if (c == '"') { if (i + 1 < s.Length && s[i + 1] == '"') { f.Append('"'); i++; } else q = false; } else f.Append(c); }
                else if (c == '"') q = true;
                else if (c == ',') { row.Add(f.ToString()); f.Clear(); }
                else if (c == '\n' || c == '\r') { if (c == '\r' && i + 1 < s.Length && s[i + 1] == '\n') i++; row.Add(f.ToString()); f.Clear(); if (row.Any(x => x.Length > 0)) rows.Add(row.ToArray()); row = new List<string>(); }
                else f.Append(c);
            }
            row.Add(f.ToString()); if (row.Any(x => x.Length > 0)) rows.Add(row.ToArray());
            return rows;
        }

        private static Tables Load(string dir)
        {
            Tables t;
            if (s_tables.TryGetValue(dir, out t)) return t;
            t = new Tables();
            foreach (var r in Read(dir, "regions.csv")) t.RoundwoodRegion[r["Region"]] = r["RoundwoodRegion"];
            foreach (var r in Read(dir, "roundwood-factors.csv"))
                t.Roundwood[r["RoundwoodRegion"] + "|" + r["Wood"] + "|" + r["LogSize"]] = new[] { Num(r["IndustrialRoundwoodRatio"]), Num(r["BarkToWood"]), Num(r["FuelwoodRatio"]) };
            foreach (var r in Read(dir, "primary-products.csv"))
            {
                string k = r["Region"] + "|" + r["Wood"] + "|" + r["LogSize"]; List<KeyValuePair<string, double>> l;
                if (!t.Primary.TryGetValue(k, out l)) t.Primary[k] = l = new List<KeyValuePair<string, double>>();
                l.Add(new KeyValuePair<string, double>(r["Product"], Num(r["Fraction"])));
            }
            var eu = Read(dir, "end-use-ratios.csv"); int last = eu.Max(r => int.Parse(r["Year"], CultureInfo.InvariantCulture));
            foreach (var r in eu.Where(r => int.Parse(r["Year"], CultureInfo.InvariantCulture) == last))
            {
                Dictionary<string, double> d; if (!t.EndUse.TryGetValue(r["Product"], out d)) t.EndUse[r["Product"]] = d = new Dictionary<string, double>();
                d[r["EndUse"]] = Num(r["Ratio"]);
            }
            foreach (var r in Read(dir, "end-use-half-lives.csv")) { t.Uses.Add(r["EndUse"]); t.HalfLife.Add(Num(r["HalfLife"])); }
            var fa = Read(dir, "discard-fates.csv"); last = fa.Max(r => int.Parse(r["Year"], CultureInfo.InvariantCulture));
            foreach (var r in fa.Where(r => int.Parse(r["Year"], CultureInfo.InvariantCulture) == last))
            {
                int k = Array.IndexOf(FateNames, r["Fate"]); if (k < 0) continue;
                t.Fate[r["Material"] == "paper" ? 1 : 0][k] = Num(r["Fraction"]);
            }
            foreach (var r in Read(dir, "swds.csv"))
            {
                int m = r["Material"] == "paper" ? 1 : 0;
                t.DumpHl[m] = Num(r["DumpHalfLife"]); t.LfFixed[m] = Num(r["LandfillFixedFraction"]); t.LfHl[m] = Num(r["LandfillHalfLife"]); t.RecHl[m] = Num(r["RecoveredHalfLife"]);
            }
            foreach (var r in Read(dir, "settings.csv")) { if (r["Setting"] == "LossInUseWood") t.LossWood = Num(r["Value"]); if (r["Setting"] == "LossInUsePaper") t.LossPaper = Num(r["Value"]); }
            s_tables[dir] = t;
            return t;
        }

        // the class of an end use: 0 buildings, 1 furniture and remodeling, 2 short-lived solid wood, 3 paper; -1 fuel
        private static int ClassOf(string use, double h) { return use == "wood pulp" ? 3 : h <= 0 ? -1 : h >= LongLife ? 0 : h <= ShortLife ? 2 : 1; }

        // dir: defaults/wood-products; region: Smith's code (NE ... PWW); wood: SW or HW; log: Sawlog or Pulpwood; years after the harvest year.
        // Returns null when the tables have no row for the choice.
        public static Result Make(string dir, string region, string wood, string log, int years, Levers L)
        {
            Tables T = Load(dir); if (L == null) L = new Levers();
            string rr; double[] rw; List<KeyValuePair<string, double>> pp;
            if (!T.RoundwoodRegion.TryGetValue(region, out rr) || !T.Roundwood.TryGetValue(rr + "|" + wood + "|" + log, out rw) || !T.Primary.TryGetValue(region + "|" + wood + "|" + log, out pp)) return null;
            var R = new Result { Years = years }; int n = T.Uses.Count;
            double irr = rw[0], bark = rw[1], fr = rw[2];
            double w = 100 / (1 + bark); R.Bark = 100 - w; R.Fuelwood = w * fr / (irr + fr);
            double ind = w * irr / (irr + fr); R.ExtraEnergy = ind * L.Energy; ind -= R.ExtraEnergy;

            // primary products to end uses, before the loss in use: solid wood and paper apart
            double[] solid = new double[n], pulp = new double[n]; double psum = pp.Sum(x => x.Value);
            foreach (var p in pp)
            {
                double c = ind * p.Value / psum; if (c <= 0) continue;
                if (p.Key == "Fuel and other emissions") { R.MillResidue += c; continue; }
                Dictionary<string, double> ratio; if (!T.EndUse.TryGetValue(p.Key, out ratio)) return null;
                double rs = ratio.Values.Sum();
                for (int u = 0; u < n; u++)
                {
                    double v; if (!ratio.TryGetValue(T.Uses[u], out v)) continue; v = c * v / rs;
                    if (p.Key == "Wood pulp") pulp[u] += v; else if (T.Uses[u] == "fuelwood and other") R.MillResidue += v; else solid[u] += v;
                }
            }
            // lever: part of what was bound for paper and short-lived end uses goes to buildings, in the building mix of the solid wood
            // (none: softwood lumber's), and is solid wood from there on
            if (L.Long > 0)
            {
                double moved = 0; double[] mix = new double[n];
                for (int u = 0; u < n; u++)
                {
                    double h = T.HalfLife[u];
                    if (h > 0 && h <= ShortLife) { moved += (solid[u] + pulp[u]) * L.Long; solid[u] *= 1 - L.Long; pulp[u] *= 1 - L.Long; }
                    if (h >= LongLife) mix[u] = solid[u];
                }
                if (mix.Sum() <= 0)
                {
                    Dictionary<string, double> sl = T.EndUse["Softwood lumber"]; double all = sl.Values.Sum();
                    for (int u = 0; u < n; u++) { double v; if (T.HalfLife[u] >= LongLife && sl.TryGetValue(T.Uses[u], out v)) mix[u] = v / all; }
                }
                double ms = mix.Sum(); for (int u = 0; u < n; u++) solid[u] += moved * mix[u] / ms;
            }
            double[] loss = { solid.Sum() * T.LossWood, pulp.Sum() * T.LossPaper };
            double[] pool = new double[n], keep = new double[n]; int[] cls = new int[n]; bool[] paper = new bool[n];
            for (int u = 0; u < n; u++)
            {
                cls[u] = ClassOf(T.Uses[u], T.HalfLife[u]); paper[u] = T.Uses[u] == "wood pulp";
                keep[u] = T.HalfLife[u] > 0 ? Math.Exp(-Math.Log(2) / (T.HalfLife[u] * L.Life)) : 0;
                // what a class is made of counts the carbon bound for it, the loss when placed in use included (it is discarded that year)
                int k = paper[u] ? 3 : cls[u]; if (pulp[u] > 0) { R.Made[3] += pulp[u]; R.Discarded[3] += pulp[u] * T.LossPaper; }
                if (solid[u] > 0 && k >= 0) { R.Made[k == 3 ? 2 : k] += solid[u]; R.Discarded[k == 3 ? 2 : k] += solid[u] * T.LossWood; }
            }
            // discard fates of the last year with the levers: the set fates take their targets, the rest keep their proportions
            double[][] fate = new double[2][];
            for (int m = 0; m < 2; m++)
            {
                double[] f = (double[])T.Fate[m].Clone(); double s = f.Sum(); for (int k = 0; k < 6; k++) f[k] /= s;
                if (m == 0) R.RecoveredDefault = f[0]; else R.RecoveredPaperDefault = f[0];
                double rec = m == 0 ? L.RecWood : L.RecPaper; bool sr = !double.IsNaN(rec), se = !double.IsNaN(L.DiscEnergy);
                if (sr || se)
                {
                    double rest = 0; for (int k = 0; k < 6; k++) if (!(k == 0 && sr) && !(k == 3 && se)) rest += f[k];
                    double left = 1 - (sr ? rec : 0) - (se ? L.DiscEnergy : 0);
                    for (int k = 0; k < 6; k++) f[k] = (k == 0 && sr) ? rec : (k == 3 && se) ? L.DiscEnergy : rest > 0 ? f[k] * left / rest : 0;
                }
                fate[m] = f;
            }
            double[] qlf = new double[2], qdump = new double[2], qrec = new double[2], fixedShare = new double[2];
            for (int m = 0; m < 2; m++)
            {
                qlf[m] = Math.Exp(-Math.Log(2) / T.LfHl[m]); qdump[m] = Math.Exp(-Math.Log(2) / T.DumpHl[m]); qrec[m] = Math.Exp(-Math.Log(2) / T.RecHl[m]);
                fixedShare[m] = Math.Min(1, T.LfFixed[m]);
            }
            double[] rc = new double[2], lfd = new double[2], lff = new double[2], dump = new double[2];
            double ec = 0, no = 0;
            for (int t = 0; t <= years; t++)
            {
                double[] disc = new double[2];
                for (int u = 0; u < n; u++)
                {
                    double d = pool[u] * (1 - keep[u]); pool[u] = pool[u] * keep[u] + (t == 0 ? solid[u] * (1 - T.LossWood) + pulp[u] * (1 - T.LossPaper) : 0);
                    disc[paper[u] ? 1 : 0] += d; if (cls[u] >= 0) R.Discarded[cls[u]] += d;
                }
                if (t == 0) { disc[0] += loss[0]; disc[1] += loss[1]; }
                for (int m = 0; m < 2; m++)
                {
                    R.DiscTotal[m] += disc[m];
                    double d = disc[m] + rc[m] * (1 - qrec[m]), lfe = lfd[m] * (1 - qlf[m]), dpe = dump[m] * (1 - qdump[m]); double[] f = fate[m];
                    rc[m] = rc[m] * qrec[m] + d * f[0];
                    lfd[m] = lfd[m] * qlf[m] + d * f[1] * (1 - fixedShare[m]); lff[m] += d * f[1] * fixedShare[m];
                    dump[m] = dump[m] * qdump[m] + d * f[2];
                    ec += d * f[3]; no += d * (f[4] + f[5]) + lfe + dpe;
                    R.To[m, 1] += d * f[1]; R.To[m, 2] += d * f[2]; R.To[m, 3] += d * f[3]; R.To[m, 4] += d * (f[4] + f[5]);
                    R.LandfillDecay += lfe; R.DumpDecay += dpe;
                }
            }
            for (int u = 0; u < n; u++) if (cls[u] >= 0) R.InUse[cls[u]] += pool[u];
            for (int m = 0; m < 2; m++) R.To[m, 0] = rc[m];
            R.Recovered = rc.Sum(); R.Landfill = lfd.Sum() + lff.Sum(); R.Dump = dump.Sum();
            R.EmitEnergy = R.AtHarvest + ec; R.EmitNo = no;
            return R;
        }
    }
}
