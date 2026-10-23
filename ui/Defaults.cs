// =============================================================================
// Defaults.cs - Reset to defaults: replace a multi-row sheet's rows with a package defaults CSV (defaults/<folder>/<file>.csv)
// =============================================================================
// The CSVs are the ones the stages fall back to when a sheet is empty, and tools/build_starter.R prefills the starter from them. Values
// are matched to the sheet's columns as the stages match them: a list column by the start of its label ("Target" = "1:Target (area by
// strata)"), a lookup column by the row's name, Yes/No as a check box. CSV columns the sheet lacks (Note) are skipped. The package
// folder is the one this DLL sits in (the package is an external reference to its source folder).
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Text;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public static class Defaults
    {
        public static string PackageFile(params string[] parts)
        {
            string dir = Path.GetDirectoryName(typeof(Defaults).Assembly.Location);
            return Path.Combine(new[] { dir }.Concat(parts).ToArray());
        }

        // a small RFC 4180 reader: quoted fields may hold commas, doubled quotes and line breaks
        public static List<string[]> ReadCsv(string file)
        {
            var rows = new List<string[]>(); var row = new List<string>(); var f = new StringBuilder();
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

        // the stored value for a CSV entry, or null when it cannot be matched (the row is then reported, not guessed)
        private static object Convert(DataSheetColumn col, string text)
        {
            if (text.Length == 0) return DBNull.Value;
            if (col.ValidationTable != null)
            {
                ValidationTable vt = col.ValidationTable;
                foreach (DataRow r in vt.DataSource.Rows)
                {
                    if (r.RowState == DataRowState.Deleted) continue;
                    string name = System.Convert.ToString(r[vt.DisplayMember]);
                    if (string.Equals(name, text, StringComparison.OrdinalIgnoreCase) || name.StartsWith(text + " ", StringComparison.OrdinalIgnoreCase)) return r[vt.ValueMember];
                }
                return null;
            }
            // a list column without a validation table: its formula ("1:Target (area by strata)|2:...")
            if (!string.IsNullOrEmpty(col.Formula1) && col.Formula1.Contains(":") && col.Formula1.Contains("|"))
            {
                foreach (string item in col.Formula1.Split('|'))
                {
                    int k = item.IndexOf(':'); if (k < 0) continue;
                    string name = item.Substring(k + 1);
                    if (string.Equals(name, text, StringComparison.OrdinalIgnoreCase) || name.StartsWith(text + " ", StringComparison.OrdinalIgnoreCase)) return int.Parse(item.Substring(0, k));
                }
                return null;
            }
            if (col.DataType == typeof(bool) || col.DataType == typeof(Boolean))
                return text.Equals("Yes", StringComparison.OrdinalIgnoreCase) || text.Equals("TRUE", StringComparison.OrdinalIgnoreCase) || text == "1" || text == "-1";
            if (col.DataType == typeof(int)) { int v; return int.TryParse(text, out v) ? (object)v : null; }
            if (col.DataType == typeof(double)) { double v; return double.TryParse(text, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out v) ? (object)v : null; }
            return text;
        }

        // replaces the sheet's rows; returns what could not be matched (empty = all rows loaded)
        public static List<string> Load(DataSheet ds, string file, Dictionary<string, string> rename)
        {
            var problems = new List<string>();
            if (!File.Exists(file)) { problems.Add("not found: " + file); return problems; }
            List<string[]> rows = ReadCsv(file);
            if (rows.Count == 0) return problems;
            string[] head = rows[0].Select(h => rename != null && rename.ContainsKey(h) ? rename[h] : h).ToArray();
            var cols = new Dictionary<int, DataSheetColumn>();
            for (int j = 0; j < head.Length; j++) { DataSheetColumn c = ds.Columns.Cast<DataSheetColumn>().FirstOrDefault(x => x.Name == head[j]); if (c != null) cols[j] = c; }
            DataTable dt = ds.GetData();
            List<DataRow> old = dt.Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted).ToList();
            if (old.Count > 0) ds.DeleteRows(old);
            ds.BeginAddRows();
            try
            {
                for (int i = 1; i < rows.Count; i++)
                {
                    DataRow nr = dt.NewRow(); bool ok = true;
                    foreach (var kv in cols)
                    {
                        string text = kv.Key < rows[i].Length ? rows[i][kv.Key].Trim() : "";
                        object v = Convert(kv.Value, text);
                        if (v == null) { problems.Add(string.Format("row {0}: {1} '{2}' is not in this library", i, kv.Value.DisplayName, text)); ok = false; break; }
                        nr[kv.Value.Name] = v;
                    }
                    if (ok) dt.Rows.Add(nr);
                }
            }
            finally { ds.EndAddRows(); }
            return problems;
        }
    }
}
