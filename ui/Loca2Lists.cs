// =============================================================================
// Loca2Lists.cs - the LOCA2 Climate Scenarios, Models and Replicates lists, from the runs found in the user's LOCA2 folder
// =============================================================================
// The same rule as tools/new-library.R: <folder>/<gcm>/<member>/<ssp>/{pr,tasmax,tasmin}/*.monthly.nc, and a model's member is listed
// when it has a historical run and at least one SSP with all three variables. LibrarySetup fills a new project from a scan of Data
// Sources: LOCA2 Folder (the shipped CSVs when the folder is missing or holds no runs); the Projection Climate page's Rescan button
// updates an existing project's lists in place: rows are matched by name, new runs are added, and rows whose runs are gone are kept
// (a scenario may point at them) and marked, so their models drop out of the page's lists.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Xml;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class Loca2Lists
    {
        public const string Gone = "none found in the LOCA2 folder";
        private static readonly Dictionary<string, string> SspNames = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            { { "ssp126", "SSP1-2.6" }, { "ssp245", "SSP2-4.5" }, { "ssp370", "SSP3-7.0" }, { "ssp585", "SSP5-8.5" } };

        private class Run { public string Gcm, Member, Ssp; }

        public string Folder;
        public int RunCount;
        public List<string[]> Scenarios = new List<string[]>();    // Name, Code
        public List<string[]> Models = new List<string[]>();       // Name, Runs ("SSP2-4.5: r1i1p1f1, r2i1p1f1; SSP3-7.0: ...")
        public List<string[]> Replicates = new List<string[]>();   // Name, Runs ("ACCESS-CM2 (SSP2-4.5, SSP5-8.5); ...")

        public static string SspName(string code) { string n; return SspNames.TryGetValue(code, out n) ? n : code; }

        private static bool HasRun(string dir)
        {
            return new[] { "pr", "tasmax", "tasmin" }.All(v => Directory.Exists(Path.Combine(dir, v)) && Directory.EnumerateFiles(Path.Combine(dir, v), "*.monthly.nc").Any());
        }

        // null when the folder is missing or holds no complete run
        public static Loca2Lists Scan(string folder)
        {
            if (string.IsNullOrEmpty(folder) || !Directory.Exists(folder)) return null;
            var runs = new List<Run>();
            foreach (string g in Directory.GetDirectories(folder))
                foreach (string m in Directory.GetDirectories(g))
                {
                    if (!HasRun(Path.Combine(m, "historical"))) continue;
                    foreach (string s in Directory.GetDirectories(m))
                    {
                        string ssp = Path.GetFileName(s);
                        if (!ssp.Equals("historical", StringComparison.OrdinalIgnoreCase) && HasRun(s)) runs.Add(new Run { Gcm = Path.GetFileName(g), Member = Path.GetFileName(m), Ssp = ssp });
                    }
                }
            if (runs.Count == 0) return null;
            var L = new Loca2Lists { Folder = folder, RunCount = runs.Count };
            StringComparer o = StringComparer.OrdinalIgnoreCase;
            foreach (string c in runs.Select(r => r.Ssp).Distinct(o).OrderBy(c => c, o)) L.Scenarios.Add(new[] { SspName(c), c });
            foreach (var g in runs.GroupBy(r => r.Gcm, o).OrderBy(g => g.Key, o))
                L.Models.Add(new[] { g.Key, string.Join("; ", g.GroupBy(r => r.Ssp, o).OrderBy(s => s.Key, o)
                    .Select(s => SspName(s.Key) + ": " + string.Join(", ", s.Select(r => r.Member).OrderBy(x => x, o)))) });
            foreach (var m in runs.GroupBy(r => r.Member, o).OrderBy(m => m.Key, o))
                L.Replicates.Add(new[] { m.Key, string.Join("; ", m.GroupBy(r => r.Gcm, o).OrderBy(g => g.Key, o)
                    .Select(g => g.Key + " (" + string.Join(", ", g.Select(r => SspName(r.Ssp)).OrderBy(x => x, o)) + ")")) });
            return L;
        }

        public string Summary() { return string.Format("{0} scenarios, {1} models, {2} replicates ({3} runs) in {4}", Scenarios.Count, Models.Count, Replicates.Count, RunCount, Folder); }

        // Data Sources: LOCA2 Folder, else package.xml's default for it
        public static string FolderOf(Project p, DataStore store)
        {
            try
            {
                DataSheet ds = p.GetDataSheet("lucasCore_DataSource");
                DataTable dt = store == null ? ds.GetData() : ds.GetData(store);
                DataRow r = dt.Rows.Cast<DataRow>().FirstOrDefault(x => x.RowState != DataRowState.Deleted);
                if (r != null && dt.Columns.Contains("Loca2Folder") && r["Loca2Folder"] != DBNull.Value && Convert.ToString(r["Loca2Folder"]).Trim().Length > 0)
                    return Convert.ToString(r["Loca2Folder"]).Trim();
            }
            catch (Exception) { }
            try
            {
                var x = new XmlDocument(); x.Load(Defaults.PackageFile("package.xml"));
                foreach (XmlElement c in x.GetElementsByTagName("column")) if (c.GetAttribute("name") == "Loca2Folder") return c.GetAttribute("defaultValue");
            }
            catch (Exception) { }
            return null;
        }

        // the three lists as CSVs in dir, named as the shipped ones (for LibrarySetup's loader)
        public void WriteCsv(string dir)
        {
            Write(Path.Combine(dir, "lucasCore_ClimateScenario.csv"), "Name,Code", Scenarios);
            Write(Path.Combine(dir, "lucasCore_ClimateModel.csv"), "Name,Runs", Models);
            Write(Path.Combine(dir, "lucasCore_ClimateReplicate.csv"), "Name,Runs", Replicates);
        }
        private static void Write(string file, string head, List<string[]> rows)
        {
            var sb = new StringBuilder(head + "\n");
            foreach (string[] r in rows) sb.Append(string.Join(",", r.Select(v => v.IndexOfAny(new[] { ',', '"', '\n' }) >= 0 ? "\"" + v.Replace("\"", "\"\"") + "\"" : v))).Append("\n");
            File.WriteAllText(file, sb.ToString());
        }

        // Studio: update an open project's lists in place; returns what changed
        public string Apply(Project p)
        {
            int added = 0, gone = 0;
            added += Merge(p.GetDataSheet("lucasCore_ClimateScenario"), Scenarios, "Code", ref gone);
            added += Merge(p.GetDataSheet("lucasCore_ClimateModel"), Models, "Runs", ref gone);
            added += Merge(p.GetDataSheet("lucasCore_ClimateReplicate"), Replicates, "Runs", ref gone);
            return string.Format("Found {0}. {1} rows added, {2} no longer found (kept, marked \"{3}\").", Summary(), added, gone, Gone);
        }

        private static int Merge(DataSheet ds, List<string[]> rows, string col, ref int gone)
        {
            DataTable dt = ds.GetData();
            List<DataRow> have = dt.Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted).ToList();
            var byName = new Dictionary<string, DataRow>(StringComparer.OrdinalIgnoreCase);
            foreach (DataRow r in have) if (r["Name"] != DBNull.Value) byName[Convert.ToString(r["Name"])] = r;
            var found = new HashSet<string>(rows.Select(r => r[0]), StringComparer.OrdinalIgnoreCase);
            // the scenario sheet keeps its folder code; a run that is gone is noted in its Description instead
            string goneCol = col == "Code" ? "Description" : col;

            ds.BeginModifyRows();
            try
            {
                foreach (string[] r in rows) { DataRow x; if (byName.TryGetValue(r[0], out x) && Convert.ToString(x[col]) != r[1]) x[col] = r[1]; if (x != null && goneCol == "Description" && Convert.ToString(x[goneCol]) == Gone) x[goneCol] = DBNull.Value; }
                foreach (var kv in byName) if (!found.Contains(kv.Key) && Convert.ToString(kv.Value[goneCol]) != Gone) { kv.Value[goneCol] = Gone; gone++; }
            }
            finally { ds.EndModifyRows(); }

            List<string[]> add = rows.Where(r => !byName.ContainsKey(r[0])).ToList();
            if (add.Count == 0) return 0;
            ds.BeginAddRows();
            try { foreach (string[] r in add) { DataRow n = dt.NewRow(); n["Name"] = r[0]; n[col] = r[1]; dt.Rows.Add(n); } }
            finally { ds.EndAddRows(); }
            return add.Count;
        }
    }
}
