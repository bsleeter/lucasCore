// =============================================================================
// StsimRuns.cs - the ST-Sim runs of a project (historical runs and projections) for the pages that pick one: Run Figures, Compare Runs
// =============================================================================
// A run is a result scenario whose pipeline holds the ST-Sim stage. Results hang off the scenarios that made them (Scenario.Results);
// Project.Results is only the active results. Pages reread the list whenever a drop-down opens, so a run that finished while the page
// was open is listed. When the pipelines cannot be read every result is listed.
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

        // why the last List found no runs, for the pages to show; blank when it found some
        public static string Problem = "";

        // the result scenarios of the project, newest first: every scenario's own Results. Project.Results holds only the active results
        // (the toolbar's Results list), so a page that read it alone listed no runs until some were made active
        public static List<Scenario> Results(Project p)
        {
            return p.Scenarios.Cast<Scenario>().SelectMany(s => s.Results.Cast<Scenario>()).Concat(p.Results.Cast<Scenario>())
                .GroupBy(s => s.Id).Select(g => g.First()).OrderByDescending(s => s.Id).ToList();
        }

        // the runs of the project, newest first. A result whose pipeline cannot be read, or reads empty, is listed: Studio may not have
        // loaded the sheets of a result another process wrote while the library was open
        public static List<RunItem> List(Project p)
        {
            List<Scenario> res;
            try { res = Results(p); }
            catch (Exception e) { Problem = "the project's results could not be read: " + e.Message; return new List<RunItem>(); }
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
                try
                {
                    List<DataRow> pipe = Live(s.GetDataSheet("core_Pipeline").GetData()).ToList();
                    return pipe.Count == 0 || pipe.Any(r => r["StageNameId"] != DBNull.Value && stsim.Contains(Convert.ToInt32(r["StageNameId"])));
                }
                catch (Exception) { return true; }
            };
            List<RunItem> runs = res.Where(isRun).Select(s => new RunItem { Key = s.Id, Name = Name(s) }).ToList();
            Problem = runs.Count > 0 ? "" : res.Count == 0 ? "no scenario in this project has a result yet."
                : string.Format("none of the project's {0} results has the ST-Sim stage in its pipeline.", res.Count);
            return runs;
        }

        // the drop-down line of a saved run that List left out: its name when it is a result of this project, else why not
        public static RunItem Missing(Project p, int rid)
        {
            Scenario s = null;
            try { s = Results(p).FirstOrDefault(x => x.Id == rid); } catch (Exception) { }
            return new RunItem { Key = rid, Name = s != null ? Name(s) : string.Format("[{0}] (not a result of this project)", rid) };
        }

        // the historical run a run starts from (its Projection Start), or -1
        public static int History(Project p, int rid)
        {
            try
            {
                Scenario s = Results(p).FirstOrDefault(x => x.Id == rid);
                if (s == null) return -1;
                DataRow r = Live(s.GetDataSheet("lucasCore_ProjectionStart").GetData()).FirstOrDefault();
                return r == null || r["HistoricalScenarioId"] == DBNull.Value ? -1 : Convert.ToInt32(r["HistoricalScenarioId"]);
            }
            catch (Exception) { return -1; }
        }
    }
}
