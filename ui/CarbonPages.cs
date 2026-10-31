// =============================================================================
// CarbonPages.cs - what the Live Turnover, Spin-up and Fixed Decay Multipliers pages share: lookups by name, the Build result a page
// shows values from, and edits of one override row
// =============================================================================
// These three Carbon Assumptions sheets hold overrides only: an empty sheet means the Carbon Method's own values. The pages show those
// values beside the rows. Values the Build works out itself (LANDFIRE return intervals, calibrated decay multipliers) come from the
// newest result of the Build (Scenario.Results; Project.Results is only the active results), named on the page so a stale one shows.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.Linq;
using SyncroSim.Core;

namespace lucasCoreUI
{
    internal static class CarbonPages
    {
        public static IEnumerable<DataRow> Live(DataTable dt) { return dt == null ? Enumerable.Empty<DataRow>() : dt.Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted); }
        public static List<DataRow> Rows(DataSheet ds) { return ds != null && ds.HasData() ? Live(ds.GetData()).ToList() : new List<DataRow>(); }

        // id -> name of a lookup column, and name -> id
        public static Dictionary<int, string> Names(DataSheet ds, string column)
        {
            var d = new Dictionary<int, string>();
            DataSheetColumn c = ds == null ? null : ds.Columns.Cast<DataSheetColumn>().FirstOrDefault(x => x.Name == column);
            if (c == null || c.ValidationTable == null) return d;
            foreach (DataRow r in Live(c.ValidationTable.DataSource)) { object k = r[c.ValidationTable.ValueMember]; if (k != DBNull.Value) d[Convert.ToInt32(k)] = Convert.ToString(r[c.ValidationTable.DisplayMember]); }
            return d;
        }
        public static Dictionary<string, int> Ids(DataSheet ds, string column)
        {
            var d = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            foreach (var kv in Names(ds, column)) d[kv.Value.Trim()] = kv.Key;
            return d;
        }

        // the package's forest types (Growth Inputs' defaults) this library defines, as (id, name) in the package's order
        public static List<KeyValuePair<int, string>> ForestTypes(DataSheet ds)
        {
            Dictionary<string, int> ids = Ids(ds, "StateClassId");
            var list = new List<KeyValuePair<int, string>>();
            foreach (string[] r in Defaults.ReadCsv(Defaults.PackageFile("defaults", "growth", "forest-type-crosswalk.csv")).Skip(1))
            {
                int id; string name = r.Length > 1 ? "Forest: " + r[1].Trim() : "";
                if (ids.TryGetValue(name, out id) && !list.Any(x => x.Key == id)) list.Add(new KeyValuePair<int, string>(id, name));
            }
            return list.OrderBy(x => x.Value).ToList();
        }

        // the Build result whose values a page shows: the scenario itself when it is a result, else its newest result (null = not run)
        public static Scenario BuildResult(Scenario s)
        {
            if (s == null) return null;
            if (s.IsResult) return s;
            try { return s.Results.Cast<Scenario>().OrderByDescending(x => x.Id).FirstOrDefault(); } catch (Exception) { return null; }
        }
        public static List<DataRow> ResultRows(Scenario r, string sheet)
        {
            if (r == null) return new List<DataRow>();
            try { return Rows(r.GetDataSheet(sheet)); } catch (Exception) { return new List<DataRow>(); }
        }
        public static string ResultName(Scenario r) { return r == null ? "" : StsimRuns.Name(r); }

        // the Carbon Method's dead organic matter choice (blank = 4, FIA measured dead wood)
        public static int Method(DataFeed feed)
        {
            DataSheet ds = feed.GetDataSheet("lucasCore_CarbonOptions");
            if (ds == null || !ds.HasData()) return 4;
            DataRow r = ds.GetDataRow();
            return r == null || r["DeadOrganicMatterModel"] == DBNull.Value ? 4 : Convert.ToInt32(r["DeadOrganicMatterModel"]);
        }

        public static double? Num(object v) { return v == null || v == DBNull.Value ? (double?)null : Convert.ToDouble(v); }
        public static double? Parse(string s)
        {
            double d; s = (s ?? "").Trim();
            return s.Length > 0 && double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out d) ? d : (double?)null;
        }
        public static string Format(double? v, string fmt) { return v.HasValue ? v.Value.ToString(fmt, CultureInfo.InvariantCulture) : ""; }

        // the row of a sheet for one ecodivision (null = all) and one state class, or null
        public static DataRow Find(DataSheet ds, int? eco, int type)
        {
            return Rows(ds).FirstOrDefault(r => r["StateClassId"] != DBNull.Value && Convert.ToInt32(r["StateClassId"]) == type &&
                                                (eco.HasValue ? r["StratumId"] != DBNull.Value && Convert.ToInt32(r["StratumId"]) == eco.Value : r["StratumId"] == DBNull.Value));
        }

        // sets one value of the (ecodivision, state class) row: adds the row when it is missing, deletes it when every listed column is
        // blank afterwards
        public static void SetValue(DataSheet ds, int? eco, int type, string column, object value, IEnumerable<string> valueColumns)
        {
            DataRow r = Find(ds, eco, type);
            if (r == null)
            {
                if (value == null || value == DBNull.Value) return;
                DataTable dt = ds.GetData();
                ds.BeginAddRows();
                try { DataRow nr = dt.NewRow(); if (eco.HasValue) nr["StratumId"] = eco.Value; nr["StateClassId"] = type; nr[column] = value; dt.Rows.Add(nr); }
                finally { ds.EndAddRows(); }
                return;
            }
            if (Equals(r[column], value ?? DBNull.Value)) return;
            if ((value == null || value == DBNull.Value) && valueColumns.Where(c => c != column).All(c => r[c] == DBNull.Value)) { ds.DeleteRows(new[] { r }); return; }
            ds.BeginModifyRows(); r[column] = value ?? DBNull.Value; ds.EndModifyRows();
        }
    }
}
