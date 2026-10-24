// =============================================================================
// LibrarySetup.cs - fill a new lucasCore project from defaults/: what tools/new-library.R does, for a library made in Studio
// =============================================================================
// package.xml gives the hidden project sheet lucasCore_LibrarySetup this class (and one record, so SyncroSim calls it). SyncroSim calls
// AddDefaultRecords for each project sheet with records when the package is added to a library (File > New > Empty Library, then
// Library Properties > Packages > Add) and when a project is created, so a new project gets:
//   defaults/stsim/manifest.csv            the ST-Sim definitions (strata, state classes, transition types and groups, stocks, flows...)
//   defaults/library/project/manifest.csv  Stratum Sources, the Secondary and Tertiary unit lists and the LOCA2 lists
//                                          (tools/export-project-defaults.R writes them from the starter)
// A project that already has state classes is left alone (a starter copy, or a library made by new-library.R). The outcome is written to
// the sheet's own row (Status, Detail). The stock-flow definitions are scenario data: stage 0 writes them into the Build result.
// Rows are added to the sheets' data the way SyncroSim adds package records, which it saves with them: rows written to the database
// directly collided with the records it saved afterwards. CSV values that name a row of another sheet (lookups) are matched by that
// sheet's display name, as rsyncrosim's saveDatasheet does; a row whose name is already there (a SyncroSim record) is skipped, and a
// single-row sheet's existing row takes the CSV's values.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class LibrarySetupDataSheet : DataSheet
    {
        protected override void AddDefaultRecords(DataStore store)
        {
            LibrarySetup.Trace(string.Format("AddDefaultRecords: project {0}, process {1}", this.Project == null ? "none" : this.Project.Id.ToString(), System.Diagnostics.Process.GetCurrentProcess().ProcessName));
            try { base.AddDefaultRecords(store); }
            catch (Exception ex) { LibrarySetup.Trace("base AddDefaultRecords failed: " + ex); throw; }
            // a multiprocessing job library (<library>.temp\MultiProc\...\Job-N.ssim) is made empty and then filled by SyncroSim with the
            // main library's project; filling it here first made that copy fail on duplicate ids (UNIQUE constraint failed:
            // core_ExternalVariableType, found 2026-10-24 with spatial multiprocessing), so a job library is left alone
            string where = LibrarySetup.Location(this.Library);
            if (LibrarySetup.IsJobLibrary(where)) { LibrarySetup.Trace("Skipped: multiprocessing job library " + where); return; }
            string status, detail;
            try
            {
                detail = LibrarySetup.Fill(this.Project, store, LibrarySetup.PackageDirectory());
                status = detail == null ? "Skipped" : "Filled";
                if (detail == null) detail = "the project already had ST-Sim definitions; nothing written";
            }
            catch (Exception ex) { status = "Failed"; detail = ex.ToString(); }
            LibrarySetup.Trace(status + ": " + detail);
            try { LibrarySetup.Record(this, store, status, detail); } catch (Exception ex) { LibrarySetup.Trace("Record failed: " + ex); }
        }
    }

    public static class LibrarySetup
    {
        // the library's file, from its connection string ("Data Source=...;"), or "" when it cannot be read
        public static string Location(Library lib)
        {
            try { return lib == null || lib.Connection == null ? "" : (lib.Connection.ConnectionString ?? ""); }
            catch { return ""; }
        }

        public static bool IsJobLibrary(string where)
        {
            return where.Replace('/', '\\').ToLowerInvariant().Contains(".temp\\multiproc\\");
        }

        public static string PackageDirectory()
        {
            string dir = Path.GetDirectoryName(typeof(LibrarySetup).Assembly.Location);
            if (!Directory.Exists(Path.Combine(dir, "defaults")))
            {
                // a shadow copy: fall back to where the assembly was loaded from
                dir = Path.GetDirectoryName(new Uri(typeof(LibrarySetup).Assembly.CodeBase).LocalPath);
            }
            if (!Directory.Exists(Path.Combine(dir, "defaults"))) throw new DirectoryNotFoundException("lucasCore defaults folder not found next to " + dir);
            return dir;
        }

        // null = the project already had definitions
        public static string Fill(Project p, DataStore store, string dir)
        {
            if (p == null) throw new InvalidOperationException("no project");
            if (Live(p.GetDataSheet("stsim_StateClass").GetData(store)).Any()) return null;
            var log = new StringBuilder();
            foreach (string manifest in new[] { Path.Combine(dir, "defaults", "stsim", "manifest.csv"), Path.Combine(dir, "defaults", "library", "project", "manifest.csv") })
            {
                List<string[]> m = Csv.Read(manifest); string[] h = m[0];
                int iSheet = Array.IndexOf(h, "Datasheet"), iScope = Array.IndexOf(h, "Scope");
                foreach (string[] r in m.Skip(1))
                {
                    if (r.Length <= iSheet || r[iSheet] == "" || (iScope >= 0 && r[iScope] != "Project")) continue;
                    string file = Path.Combine(Path.GetDirectoryName(manifest), r[iSheet] + ".csv");
                    log.AppendFormat("{0}: {1}; ", r[iSheet], LoadSheet(p, store, r[iSheet], file));
                    Save(p.GetDataSheet(r[iSheet]), store);
                }
            }
            log.Append(AutoGroups(p, store));
            return log.ToString();
        }

        // ST-Sim's "<type> [Type]" group for every transition, stock and flow type (IsAuto). ST-Sim's own RowsAdded handlers make them in
        // Studio, but fail here (no editing context), so they are added as rsyncrosim's import would leave them.
        private static string AutoGroups(Project p, DataStore store)
        {
            var log = new StringBuilder();
            foreach (var g in new[] { new[] { "stsim_TransitionType", "stsim_TransitionGroup", "stsim_TransitionTypeGroup", "TransitionTypeId", "TransitionGroupId" },
                                      new[] { "stsim_StockType", "stsim_StockGroup", null, null, null },
                                      new[] { "stsim_FlowType", "stsim_FlowGroup", null, null, null } })
            {
                DataSheet types = p.GetDataSheet(g[0]), groups = p.GetDataSheet(g[1]);
                DataTable gt = groups.GetData(store);
                var have = new HashSet<string>(Live(gt).Select(r => Convert.ToString(r["Name"], CultureInfo.InvariantCulture)), StringComparer.OrdinalIgnoreCase);
                var made = new List<KeyValuePair<object, object>>();   // type id, group id

                foreach (DataRow t in Live(types.GetData(store)))
                {
                    string name = Convert.ToString(t["Name"], CultureInfo.InvariantCulture) + " [Type]";
                    if (have.Contains(name)) continue;
                    DataRow row = NewRow(groups, store, gt); row["Name"] = name; row["IsAuto"] = -1;
                    made.Add(new KeyValuePair<object, object>(t[types.PrimaryKeyColumn.Name], row[groups.PrimaryKeyColumn.Name]));
                }
                Save(groups, store);
                log.AppendFormat("{0} [Type]: {1} rows; ", g[1], made.Count);
                if (g[2] == null || made.Count == 0) continue;
                DataSheet members = p.GetDataSheet(g[2]); DataTable mt = members.GetData(store);

                foreach (var kv in made) { DataRow row = NewRow(members, store, mt); row[g[3]] = kv.Key; row[g[4]] = kv.Value; row["IsAuto"] = -1; }
                Save(members, store);
                log.AppendFormat("{0} [Type]: {1} rows; ", g[2], made.Count);
            }
            return log.ToString();
        }

        // the outcome in the sheet's single row (the package.xml record made it "Pending")
        public static void Record(DataSheet sheet, DataStore store, string status, string detail)
        {
            string version = "";
            try { var x = new System.Xml.XmlDocument(); x.Load(Path.Combine(PackageDirectory(), "package.xml")); version = x.DocumentElement.GetAttribute("version"); } catch (Exception) { }
            DataTable dt = sheet.GetData(store);
            DataRow row = Live(dt).FirstOrDefault() ?? NewRow(sheet, store, dt);
            row["PackageVersion"] = version; row["Status"] = status; row["Detail"] = detail;
        }

        // development trace in %TEMP%\lucasCore-library-setup.log
        public static void Trace(string s)
        {
            try { File.AppendAllText(Path.Combine(Path.GetTempPath(), "lucasCore-library-setup.log"), DateTime.Now.ToString("s") + " " + s + Environment.NewLine); } catch (Exception) { }
        }

        // Write the sheet's added and changed rows through the package-add store, raising no events. SyncroSim saves each sheet right
        // after its own package records, so ST-Sim's sheets are already saved when this runs; and DataSheet.EndAddRows would raise
        // RowsAdded, whose listeners (Studio's open windows, ST-Sim's handlers) read on Studio's own connection and fail with "database
        // is locked" while the package add holds the write lock - which rolls the whole add back.
        private static void Save(DataSheet ds, DataStore store)
        {
            try { store.Update(ds); }
            catch (Exception ex) { throw new InvalidOperationException("saving " + ds.Name + ": " + ex.Message, ex); }
        }

        private static IEnumerable<DataRow> Live(DataTable dt) { return dt.Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted); }

        // a new row in the sheet's data, with the next identity and (project sheets) the project
        private static DataRow NewRow(DataSheet ds, DataStore store, DataTable dt)
        {
            DataRow row = dt.NewRow();
            string pk = ds.PrimaryKeyColumn.Name;
            long id = ds.GetNextRowIdentity(store);
            long max = Live(dt).Where(r => r[pk] != DBNull.Value).Select(r => Convert.ToInt64(r[pk], CultureInfo.InvariantCulture)).DefaultIfEmpty(0).Max();
            row[pk] = id > max ? id : max + 1;
            if (dt.Columns.Contains("ProjectId") && ds.DataScope == DataScope.Project) row["ProjectId"] = ds.Project.Id;
            dt.Rows.Add(row);
            return row;
        }

        private static string LoadSheet(Project p, DataStore store, string name, string file)
        {
            DataSheet ds = p.GetDataSheet(name);
            if (ds == null) throw new InvalidDataException(name + " is not a sheet of this library");
            List<string[]> rows = Csv.Read(file); string[] head = rows[0];
            var cols = new List<DataSheetColumn>(); var idx = new List<int>();
            var lookups = new Dictionary<string, Dictionary<string, object>>();
            for (int i = 0; i < head.Length; i++)
            {
                DataSheetColumn c = ds.Columns.Cast<DataSheetColumn>().FirstOrDefault(x => string.Equals(x.Name, head[i], StringComparison.OrdinalIgnoreCase));
                if (c == null || c.IsPrimaryKey || c.Name == "ProjectId" || c.Name == "ScenarioId") continue;
                cols.Add(c); idx.Add(i);
                if (c.ValidationType == ColumnValidationType.IsDataSheet && !lookups.ContainsKey(c.Formula1)) lookups[c.Formula1] = Names(p, store, c.Formula1);
            }
            DataTable dt = ds.GetData(store);
            List<DataRow> have = Live(dt).ToList();
            if (ds.IsSingleRow)
            {
                if (rows.Count < 2) return "no row";
                DataRow row = have.FirstOrDefault() ?? NewRow(ds, store, dt);
                for (int k = 0; k < cols.Count; k++) row[cols[k].Name] = idx[k] < rows[1].Length ? Value(cols[k], rows[1][idx[k]], lookups, name) : DBNull.Value;
                return have.Any() ? "updated" : "1 row";
            }
            DataSheetColumn named = string.IsNullOrEmpty(ds.DisplayMember) ? null : cols.FirstOrDefault(c => c.Name == ds.DisplayMember);
            if (have.Any() && named == null) return string.Format("kept {0} rows", have.Count);
            var exists = new HashSet<string>(named == null ? new string[0] : have.Select(r => Convert.ToString(r[named.Name], CultureInfo.InvariantCulture)), StringComparer.OrdinalIgnoreCase);
            int n = 0, skipped = 0;

            foreach (string[] r in rows.Skip(1))
            {
                if (r.Length == 1 && r[0] == "") continue;
                if (named != null && exists.Contains(r[idx[cols.IndexOf(named)]])) { skipped++; continue; }
                DataRow row = NewRow(ds, store, dt);
                for (int k = 0; k < cols.Count; k++) row[cols[k].Name] = idx[k] < r.Length ? Value(cols[k], r[idx[k]], lookups, name) : DBNull.Value;
                n++;
            }

            return skipped > 0 ? string.Format("{0} rows ({1} already there)", n, skipped) : string.Format("{0} rows", n);
        }

        // display name -> primary key of a sheet, from its data (so rows added a moment ago count)
        private static Dictionary<string, object> Names(Project p, DataStore store, string sheet)
        {
            DataSheet ds = p.GetDataSheet(sheet);
            var d = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            if (ds == null || string.IsNullOrEmpty(ds.DisplayMember)) return d;
            foreach (DataRow r in Live(ds.GetData(store)))
                if (r[ds.DisplayMember] != DBNull.Value) d[Convert.ToString(r[ds.DisplayMember], CultureInfo.InvariantCulture)] = r[ds.PrimaryKeyColumn.Name];
            return d;
        }

        private static object Value(DataSheetColumn c, string s, Dictionary<string, Dictionary<string, object>> lookups, string sheet)
        {
            if (s == null || s == "" || s == "NA") return DBNull.Value;
            if (c.ValidationType == ColumnValidationType.IsDataSheet)
            {
                object id; if (lookups[c.Formula1].TryGetValue(s, out id)) return id;
                throw new InvalidDataException(string.Format("{0}.{1}: '{2}' is not a row of {3}", sheet, c.Name, s, c.Formula1));
            }
            Type t = c.DataType;
            if (c.ValidationType == ColumnValidationType.IsList && !string.IsNullOrEmpty(c.Formula1))
            {
                long k; if (long.TryParse(s, NumberStyles.Integer, CultureInfo.InvariantCulture, out k)) return Convert.ChangeType(k, t, CultureInfo.InvariantCulture);
                foreach (string item in c.Formula1.Split('|')) { int j = item.IndexOf(':'); if (j > 0 && string.Equals(item.Substring(j + 1), s, StringComparison.OrdinalIgnoreCase)) return Convert.ChangeType(long.Parse(item.Substring(0, j), CultureInfo.InvariantCulture), t, CultureInfo.InvariantCulture); }
                throw new InvalidDataException(string.Format("{0}.{1}: '{2}' is not in its list", sheet, c.Name, s));
            }
            if (t == typeof(bool))
            {
                string v = s.Trim().ToUpperInvariant();
                return (v == "TRUE" || v == "-1" || v == "1" || v == "YES" || v == "T") ? -1 : 0;   // SyncroSim's true is -1
            }
            if (t == typeof(string)) return s;
            return Convert.ChangeType(double.Parse(s, CultureInfo.InvariantCulture), t, CultureInfo.InvariantCulture);
        }
    }

    // RFC 4180 CSV: quoted fields may hold commas, quotes ("") and line breaks
    internal static class Csv
    {
        public static List<string[]> Read(string file)
        {
            string text = File.ReadAllText(file, Encoding.UTF8);
            var rows = new List<string[]>(); var row = new List<string>(); var f = new StringBuilder();
            bool q = false;
            for (int i = 0; i < text.Length; i++)
            {
                char ch = text[i];
                if (q)
                {
                    if (ch == '"') { if (i + 1 < text.Length && text[i + 1] == '"') { f.Append('"'); i++; } else q = false; }
                    else f.Append(ch);
                }
                else if (ch == '"') q = true;
                else if (ch == ',') { row.Add(f.ToString()); f.Clear(); }
                else if (ch == '\n' || ch == '\r')
                {
                    if (ch == '\r' && i + 1 < text.Length && text[i + 1] == '\n') i++;
                    row.Add(f.ToString()); f.Clear(); rows.Add(row.ToArray()); row = new List<string>();
                }
                else f.Append(ch);
            }
            if (f.Length > 0 || row.Count > 0) { row.Add(f.ToString()); rows.Add(row.ToArray()); }
            if (rows.Count == 0) throw new InvalidDataException(file + " is empty");
            return rows;
        }
    }
}
