// =============================================================================
// NonForestBudget.cs - the grassland, shrubland and wetland rates of one class as a compartment model, and its steady state
// =============================================================================
// Values as stage 3 sets them (src/3-carbon-flows.R put_rows): the package tables (defaults/stockflow/nonforest-*.csv: one row per
// ecodivision, class and flow, and per age for forested wetlands), then this scenario's rows on top, the more specific last - a class's
// row for every ecodivision and age, then for one age (matching the package row's age), then for one ecodivision, then for both.
// Rates are per year; Net Growth groups split net growth among the live pools; for emergent wetlands a "<pool> ->" group is the pool's
// total yearly loss and the flows out of it are shares of that loss. The steady state is ST-Sim's (to-do 39, 2026-11-06; as
// src/nonforest-solve.R): a year runs in flow order (defaults/stockflow/stsim_FlowOrder.csv), the flows of one order computed from the
// stocks at the start of their step (ApplyEquallyRankedSimultaneously = TRUE), so one year is an affine map S -> M S + c and the steady
// state solves (I - M) S = c over the pools that lose carbon. A pool's stock is its year-end value; each flux is what one year at the
// steady state moves, from the stock at the start of that flow's step (Edge.Base). Deep soil only accumulates. With the package rates
// it lands on the Build's starting pools. (Before 2026-11-06 this solved stock = inputs / loss, which ignores the order: emergent
// wetlands, which grow at order 1 and die back at 6, showed live 36 and dead 49 Mg C/ha instead of ST-Sim's 4.9 and 17.4.)
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

        public class Edge { public string Kind, From, To, Group; public double Entered, Rate, Flux, Base, Order; public bool Yours; }
        public class Pool { public string Key, Label; public int Col; public bool Above; public double Stock, In, Out, Co2, Aquatic, Total; }

        public double Growth; public bool GrowthYours, Emergent, AgeVarying;
        public readonly List<Edge> Edges = new List<Edge>();
        public readonly Dictionary<string, Pool> P = new Dictionary<string, Pool>();
        public readonly List<string> Totals = new List<string>();   // emergent pools with a total-loss group

        // ---- package tables, read once --------------------------------------------------------------------------------------
        private class Row { public int? Min, Max; public string Flow; public double V; }
        private static Dictionary<string, List<Row>> s_rates, s_growth;
        private static Dictionary<string, double> s_order;   // flow type -> flow order
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
            var order = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);
            foreach (string[] r in Defaults.ReadCsv(Defaults.PackageFile("defaults", "stockflow", "stsim_FlowOrder.csv")).Skip(1))
            {
                double v; if (r.Length >= 4 && double.TryParse(r[3], NumberStyles.Float, CultureInfo.InvariantCulture, out v)) order[r[2].Trim()] = v;
            }
            s_rates = rates; s_growth = growth; s_order = order;
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
                double ord; string ft = kv.Key.EndsWith(" [Type]") ? kv.Key.Substring(0, kv.Key.Length - 7) : kv.Key;
                b.Edges.Add(new Edge { Kind = kind, From = a, To = t, Group = kv.Key, Entered = v, Rate = rate, Yours = kv.Value.Value,
                                       Order = s_order.TryGetValue(ft, out ord) ? ord : double.MaxValue });   // a flow with no order runs last
            }
            foreach (Edge e in b.Edges.Where(x => x.Kind != "Net growth" && b.P.ContainsKey(x.From))) b.P[e.From].Out += e.Rate;
            b.Solve();
            return b;
        }

        // ST-Sim's year in flow order: the steady state of the affine map S -> M S + c, then one year from it for the fluxes
        private void Solve()
        {
            List<string> keys = Pools.Select(p => p[0]).ToList(); int n = keys.Count;
            var at = new Dictionary<string, int>(); for (int i = 0; i < n; i++) at[keys[i]] = i;
            List<Edge> live = Edges.Where(e => e.Rate != 0 && (e.Kind == "Net growth" ? at.ContainsKey(e.To) : at.ContainsKey(e.From))).ToList();
            List<double> orders = live.Select(e => e.Order).Distinct().OrderBy(x => x).ToList();
            double[,] M = Identity(n); double[] c = new double[n];
            foreach (double o in orders)
            {
                double[,] A = Identity(n); double[] g = new double[n];
                foreach (Edge e in live.Where(x => x.Order == o))
                {
                    if (e.Kind == "Net growth") { g[at[e.To]] += Growth * e.Rate; continue; }
                    int f = at[e.From]; A[f, f] -= e.Rate; int t; if (at.TryGetValue(e.To, out t)) A[t, f] += e.Rate;
                }
                M = Mul(A, M); double[] c2 = new double[n];
                for (int i = 0; i < n; i++) { double s = g[i]; for (int j = 0; j < n; j++) s += A[i, j] * c[j]; c2[i] = s; }
                c = c2;
            }
            // the pools that lose carbon settle; Deep Soil and pools without a loss are sinks (start at 0, their yearly gain is In)
            List<int> k = Enumerable.Range(0, n).Where(i => keys[i] != "DS" && P[keys[i]].Out > 0).ToList();
            double[] S = new double[n];
            if (k.Count > 0)
            {
                var Q = new double[k.Count, k.Count + 1];
                for (int r = 0; r < k.Count; r++) { for (int s = 0; s < k.Count; s++) Q[r, s] = (r == s ? 1 : 0) - M[k[r], k[s]]; Q[r, k.Count] = c[k[r]]; }
                double[] x = Gauss(Q, k.Count);
                for (int r = 0; r < k.Count; r++) S[k[r]] = Math.Max(0, x[r]);
            }
            foreach (Pool p in P.Values) { p.Stock = S[at[p.Key]]; p.In = 0; p.Co2 = 0; p.Aquatic = 0; }
            // one year from the steady state: each flow from the stocks at the start of its order's step
            double[] cur = (double[])S.Clone();
            foreach (double o in orders)
            {
                double[] start = (double[])cur.Clone();
                foreach (Edge e in live.Where(x => x.Order == o))
                {
                    double amt; if (e.Kind == "Net growth") { e.Base = 0; amt = Growth * e.Rate; } else { e.Base = start[at[e.From]]; amt = e.Rate * e.Base; cur[at[e.From]] -= amt; }
                    e.Flux = amt; int t;
                    if (at.TryGetValue(e.To, out t)) { cur[t] += amt; P[e.To].In += amt; }
                    else if (e.Kind != "Net growth") { if (e.To == "ATM") P[e.From].Co2 += amt; if (e.To == "AQ") P[e.From].Aquatic += amt; }
                }
            }
            foreach (Edge e in Edges.Where(x => x.Rate == 0)) { e.Flux = 0; e.Base = 0; }
        }

        private static double[,] Identity(int n) { var m = new double[n, n]; for (int i = 0; i < n; i++) m[i, i] = 1; return m; }
        private static double[,] Mul(double[,] a, double[,] b)
        {
            int n = a.GetLength(0); var m = new double[n, n];
            for (int i = 0; i < n; i++) for (int j = 0; j < n; j++) { double s = 0; for (int l = 0; l < n; l++) s += a[i, l] * b[l, j]; m[i, j] = s; }
            return m;
        }
        // Gaussian elimination with partial pivoting on an n x (n + 1) augmented matrix
        private static double[] Gauss(double[,] q, int n)
        {
            for (int col = 0; col < n; col++)
            {
                int piv = col; for (int r = col + 1; r < n; r++) if (Math.Abs(q[r, col]) > Math.Abs(q[piv, col])) piv = r;
                if (Math.Abs(q[piv, col]) < 1e-300) continue;
                if (piv != col) for (int j = 0; j <= n; j++) { double tmp = q[col, j]; q[col, j] = q[piv, j]; q[piv, j] = tmp; }
                for (int r = 0; r < n; r++)
                {
                    if (r == col) continue; double f = q[r, col] / q[col, col]; if (f == 0) continue;
                    for (int j = col; j <= n; j++) q[r, j] -= f * q[col, j];
                }
            }
            var x = new double[n]; for (int i = 0; i < n; i++) x[i] = Math.Abs(q[i, i]) < 1e-300 ? 0 : q[i, n] / q[i, i];
            return x;
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
