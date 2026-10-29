// =============================================================================
// StsimRuns.cs - the ST-Sim runs of a project (historical runs and projections) for the pages that pick one: Run Figures, Compare Runs
// =============================================================================
// A run is a result scenario whose pipeline holds the ST-Sim stage. Results are in Project.Results, not Project.Scenarios (which holds
// only the scenarios you edit); pages reread the list whenever a drop-down opens, so a run that finished while the page was open is
// listed. When the pipelines cannot be read every result is listed.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using SyncroSim.Core;

namespace lucasCoreUI
{
    internal class RunItem
    {
        public object Key; public string Name;
        public override string ToString() { return Name; }
    }

    internal static class StsimRuns
    {
        private static IEnumerable<DataRow> Live(DataTable dt) { return dt.Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted); }

        // "[id] name" (a result's DisplayName already starts with its id)
        public static string Name(Scenario s) { return s.DisplayName.StartsWith("[" + s.Id + "]") ? s.DisplayName : string.Format("[{0}] {1}", s.Id, s.DisplayName); }

        // the runs of the project, newest first
        public static List<RunItem> List(Project p)
        {
            List<Scenario> res = p.Results.Cast<Scenario>().OrderByDescending(s => s.Id).ToList();
            HashSet<int> stsim = null;
            try
            {
                stsim = new HashSet<int>(Live(p.GetDataSheet("core_StageName").GetData())
                    .Where(r => Convert.ToString(r["Name"]).IndexOf("ST-Sim", StringComparison.OrdinalIgnoreCase) >= 0).Select(r => Convert.ToInt32(r["StageNameId"])));
            }
            catch (Exception) { }
            Func<Scenario, bool> isRun = s =>
            {
                if (stsim == null || stsim.Count == 0) return true;
                try { return Live(s.GetDataSheet("core_Pipeline").GetData()).Any(r => r["StageNameId"] != DBNull.Value && stsim.Contains(Convert.ToInt32(r["StageNameId"]))); }
                catch (Exception) { return true; }
            };
            return res.Where(isRun).Select(s => new RunItem { Key = s.Id, Name = Name(s) }).ToList();
        }

        // the historical run a run starts from (its Projection Start), or -1
        public static int History(Project p, int rid)
        {
            try
            {
                Scenario s = p.Results.Cast<Scenario>().FirstOrDefault(x => x.Id == rid);
                if (s == null) return -1;
                DataRow r = Live(s.GetDataSheet("lucasCore_ProjectionStart").GetData()).FirstOrDefault();
                return r == null || r["HistoricalScenarioId"] == DBNull.Value ? -1 : Convert.ToInt32(r["HistoricalScenarioId"]);
            }
            catch (Exception) { return -1; }
        }
    }
}
