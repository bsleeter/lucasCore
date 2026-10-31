// =============================================================================
// NonForestBudget.cs - the grassland, shrubland and wetland rates of one class as a compartment model, and its steady state
// =============================================================================
// Values as stage 3 sets them (src/3-carbon-flows.R put_rows): the package tables (defaults/stockflow/nonforest-*.csv: one row per
// ecodivision, class and flow, and per age for forested wetlands), then this scenario's rows on top, the more specific last - a class's
// row for every ecodivision and age, then for one age (matching the package row's age), then for one ecodivision, then for both.
// Rates are per year; Net Growth groups split net growth among the live pools; for emergent wetlands a "<pool> ->" group is the pool's
// total yearly loss and the flows out of it are shares of that loss. The steady state solves each pool in flow order: stock = inputs /
// total loss rate; deep soil only accumulates. With the package rates it lands near the Build's starting pools, which came from a
// spin-up with the same rates.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;

namespace lucasCoreUI
{
    internal class NonForestBudget
    {
        // pool key, label, column (0 live, 1 fast dead, 2 slow), above ground
        public static readonly string[][] Pools = {
            new[] { "F", "Foliage", "0", "1" }, new[] { "OW", "Other wood", "0", "1" }, new[] { "M", "Merchantable", "0", "1" },
            new[] { "FR", "Fine roots", "0", "0" }, new[] { "CR", "Coarse roots", "0", "0" },
            new[] { "SS", "Snag stems", "1", "1" }, new[] { "SB", "Snag branches", "1", "1" }, new[] { "AGM", "AG medium", "1", "1" },
            new[] { "AGF", "AG fast", "1", "1" }, new[] { "AGVF", "AG very fast", "1", "1" }, new[] { "BGVF", "BG very fast", "1", "0" },
            new[] { "BGF", "BG fast", "1", "0" }, new[] { "AGS", "AG slow", "2", "1" }, new[] { "BGS", "BG slow (soil)", "2", "0" },
            new[] { "DS", "Deep soil", "2", "0" } };
        private static readonly Dictionary<string, string> Names = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) {
            { "Foliage", "F" }, { "Other Wood", "OW" }, { "Merchantable", "M" }, { "Fine Roots", "FR" }, { "Coarse Roots", "CR" },
            { "Snag Stems", "SS" }, { "Snag Stem", "SS" }, { "Snag Branches", "SB" }, { "Snag Branch", "SB" }, { "AG Medium", "AGM" },
            { "AG Fast", "AGF" }, { "AG Very Fast", "AGVF" }, { "BG Very Fast", "BGVF" }, { "BG Fast", "BGF" }, { "AG Slow", "AGS" },
            { "BG Slow", "BGS" }, { "Deep Soil", "DS" }, { "Atmosphere", "ATM" }, { "Aquatic", "AQ" } };
        private static readonly Regex Flow = new Regex(@"^(Net Growth[^:]*|Biomass Turnover|Decay|Emission|Transfer|Lateral Transport|Stabilization): (.+?) -> (.+?) \[Type\]$");
        private static readonly Regex Total = new Regex(@"^(.+?) ->$");

        public class Edge { public string Kind, From, To, Group; public double Entered, Rate, Flux; public bool Yours; }
        public class Pool { public string Key, Label; public int Col; public bool Above; public double Stock, In, Out, Co2, Aquatic, Total; }

        public double Growth; public bool GrowthYours, Emergent, AgeVarying;
        public readonly List<Edge> Edges = new List<Edge>();
        public readonly Dictionary<string, Pool> P = new Dictionary<string, Pool>();
        public readonly List<string> Totals = new List<string>();   // emergent pools with a total-loss group

        // ---- package tables, read once --------------------------------------------------------------------------------------
        private class Row { public int? Min, Max; public string Flow; public double V; }
        private static Dictionary<string, List<Row>> s_rates, s_growth;
        private static string Key(string eco, string cls) { return eco + "|" + cls; }
        private static int? Int(string s) { int v; return int.TryParse(s, out v) ? v : (int?)null; }

        private static void Load()
        {
            if (s_rates != null) return;
            var rates = new Dictionary<string, List<Row>>(StringComparer.OrdinalIgnoreCase);
            foreach (string f in new[] { "nonforest-multipliers-grassland-shrubland.csv", "nonforest-multipliers-wetland.csv" })
                foreach (string[] r in Defaults.ReadCsv(Defaults.PackageFile("defaults", "stockflow", f)).Skip(1))
                {
                    double v; if (r.Length < 11 || !double.TryParse(r[10], NumberStyles.Float, CultureInfo.InvariantCulture, out v)) continue;
                    string k = Key(r[2].Trim(), r[5].Trim()); List<Row> l; if (!rates.TryGetValue(k, out l)) rates[k] = l = new List<Row>();
                    l.Add(new Row { Min = Int(r[6]), Max = Int(r[7]), Flow = r[8].Trim(), V = v });
                }
            var growth = new Dictionary<string, List<Row>>(StringComparer.OrdinalIgnoreCase);
            foreach (string[] r in Defaults.ReadCsv(Defaults.PackageFile("defaults", "stockflow", "nonforest-net-growth.csv")).Skip(1))
            {
                double v; if (r.Length < 13 || !double.TryParse(r[12], NumberStyles.Float, CultureInfo.InvariantCulture, out v)) continue;
                string k = Key(r[2].Trim(), r[5].Trim()); List<Row> l; if (!growth.TryGetValue(k, out l)) growth[k] = l = new List<Row>();
                l.Add(new Row { Min = Int(r[7]), Max = Int(r[8]), Flow = "Net Growth", V = v });
            }
            s_rates = rates; s_growth = growth;
        }

        // the classes the package has values for in an ecodivision (by name)
        public static List<string> Classes(string eco)
        {
            Load();
            return s_rates.Keys.Where(k => k.StartsWith(eco + "|", StringComparison.OrdinalIgnoreCase)).Select(k => k.Substring(eco.Length + 1)).OrderBy(x => x).ToList();
        }
        public static bool HasAges(string eco, string cls)
        {
            Load(); List<Row> l;
            return s_growth.TryGetValue(Key(eco, cls), out l) && l.Any(r => r.Max.HasValue);
        }

        // the package row that applies at an age: one without an age, else the one whose range holds it (the latest start)
        private static Dictionary<string, Row> AtAge(List<Row> rows, int age)
        {
            var d = new Dictionary<string, Row>();
            foreach (Row r in rows)
            {
                bool hit = !r.Min.HasValue || (r.Min.Value <= age && (!r.Max.HasValue || age <= r.Max.Value));
                Row have;
                if (hit && (!d.TryGetValue(r.Flow, out have) || (r.Min ?? -1) > (have.Min ?? -1))) d[r.Flow] = r;
            }
            return d;
        }

        // a scenario row: ecodivision name (null = all), class name, age (null = all), flow (null for growth), value
        public class SheetRow { public string Eco, Cls, Flow; public int? Age; public double V; }

        private static double Apply(double v, int? pkgAge, string eco, IEnumerable<SheetRow> rows, out bool yours)
        {
            yours = false;
            // the more specific last: all, one age, one ecodivision, both
            foreach (int lv in new[] { 0, 1, 2, 3 })
                foreach (SheetRow s in rows.Where(x => (x.Eco != null) == (lv >= 2) && (x.Age.HasValue) == (lv % 2 == 1)))
                {
                    if (s.Eco != null && !string.Equals(s.Eco, eco, StringComparison.OrdinalIgnoreCase)) continue;
                    if (s.Age.HasValue && (!pkgAge.HasValue || s.Age.Value != pkgAge.Value)) continue;   // an age row meets only a package row of that age
                    v = s.V; yours = true;
                }
            return v;
        }

        public static NonForestBudget Make(string eco, string cls, int age, List<SheetRow> rateRows, List<SheetRow> growthRows)
        {
            Load();
            var b = new NonForestBudget();
            List<Row> pr, pg;
            if (!s_rates.TryGetValue(Key(eco, cls), out pr)) return null;
            s_growth.TryGetValue(Key(eco, cls), out pg);
            b.AgeVarying = pg != null && pg.Any(r => r.Max.HasValue);
            Dictionary<string, Row> g = AtAge(pg ?? new List<Row>(), age);
            Row gr; bool gy;
            b.Growth = Apply(g.TryGetValue("Net Growth", out gr) ? gr.V : 0, gr == null ? null : gr.Min, eco, growthRows.Where(x => x.Cls == cls), out gy); b.GrowthYours = gy;
            var values = new Dictionary<string, KeyValuePair<double, bool>>();
            foreach (var kv in AtAge(pr, age))
            {
                bool y; double v = Apply(kv.Value.V, kv.Value.Min, eco, rateRows.Where(x => x.Cls == cls && x.Flow == kv.Key), out y);
                values[kv.Key] = new KeyValuePair<double, bool>(v, y);
            }
            foreach (string[] p in Pools) b.P[p[0]] = new Pool { Key = p[0], Label = p[1], Col = int.Parse(p[2]), Above = p[3] == "1" };
            // emergent wetlands: a pool's total loss, of which its outflows are shares
            var total = new Dictionary<string, double>();
            foreach (var kv in values) { Match m = Total.Match(kv.Key); string pk; if (m.Success && Names.TryGetValue(m.Groups[1].Value, out pk)) { total[pk] = kv.Value.Key; b.Totals.Add(pk); b.P[pk].Total = kv.Value.Key; } }
            b.Emergent = total.Count > 0;
            foreach (var kv in values)
            {
                Match m = Flow.Match(kv.Key); string a, t;
                if (!m.Success || !Names.TryGetValue(m.Groups[2].Value, out a) || !Names.TryGetValue(m.Groups[3].Value, out t)) continue;
                string kind = m.Groups[1].Value.StartsWith("Net Growth") ? "Net growth" : m.Groups[1].Value;
                double v = kv.Value.Key, rate = kind != "Net growth" && kind != "Biomass Turnover" && total.ContainsKey(a) ? total[a] * v : v;
                b.Edges.Add(new Edge { Kind = kind, From = a, To = t, Group = kv.Key, Entered = v, Rate = rate, Yours = kv.Value.Value });
            }
            // inputs and losses in flow order
            foreach (Edge e in b.Edges.Where(x => x.Kind == "Net growth" && b.P.ContainsKey(x.To))) { e.Flux = b.Growth * e.Rate; b.P[e.To].In += e.Flux; }
            foreach (Edge e in b.Edges.Where(x => x.Kind != "Net growth" && b.P.ContainsKey(x.From))) b.P[e.From].Out += e.Rate;
            foreach (string[] p in Pools)
            {
                Pool q = b.P[p[0]];
                foreach (Edge e in b.Edges.Where(x => x.To == q.Key && x.Kind != "Net growth" && b.P.ContainsKey(x.From))) { e.Flux = e.Rate * b.P[e.From].Stock; q.In += e.Flux; }
                q.Stock = q.Key == "DS" || q.Out <= 0 ? 0 : q.In / q.Out;
                foreach (Edge e in b.Edges.Where(x => x.From == q.Key)) { e.Flux = e.Rate * q.Stock; if (e.To == "ATM") q.Co2 += e.Flux; if (e.To == "AQ") q.Aquatic += e.Flux; }
            }
            return b;
        }

        public double Sum(Func<Pool, bool> which, Func<Pool, double> what) { return P.Values.Where(which).Sum(what); }
        public double Live { get { return Sum(p => p.Col == 0, p => p.Stock); } }
        public double Dead { get { return Sum(p => p.Col > 0 && p.Key != "BGS" && p.Key != "DS", p => p.Stock); } }
        public double Soil { get { return P["BGS"].Stock; } }
        public double Co2 { get { return Sum(p => true, p => p.Co2); } }
        public double Aquatic { get { return Sum(p => true, p => p.Aquatic); } }
        public double Burial { get { return P["DS"].In; } }
    }
}
