// =============================================================================
// RunFiguresView.cs - the Run Figures page (stage 13): the run to draw, picked from a drop-down of the project's ST-Sim runs
// =============================================================================
// Single-row sheet lucasCore_RunFigureOptions (RunScenarioId; blank = the newest ST-Sim result), unchanged; stage 13 reads it.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class RunFiguresView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_RunFigureOptions"; } }
        private readonly ComboBox m_run = List(460);
        private List<RunItem> m_runs = new List<RunItem>();

        public RunFiguresView()
        {
            this.SuspendLayout();
            var c = Column();
            c.Controls.Add(m_run);
            c.Controls.Add(Note("A historical run or a projection of this project. A stand-alone projection is drawn with its historical run in front. The scenario must depend on the run's Build result."));
            AddGroup(Group("Run to draw", c));
            EndGroups();
            m_run.DropDown += (s, e) => { m_runs = StsimRuns.List(this.DataFeed.Project); RefreshControls(); };
            m_run.SelectionChangeCommitted += (s, e) => { var i = m_run.SelectedItem as RunItem; Write("RunScenarioId", i == null ? DBNull.Value : i.Key); RefreshControls(); };
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            m_runs = StsimRuns.List(this.DataFeed.Project);
            RefreshControls();
        }

        protected override void ShowData()
        {
            object rid = Value("RunScenarioId");
            m_run.BeginUpdate(); m_run.Items.Clear();
            m_run.Items.Add(new RunItem { Key = DBNull.Value, Name = "(the newest run)" });
            foreach (RunItem i in m_runs) m_run.Items.Add(i);
            int idx = 0;
            for (int k = 1; k < m_run.Items.Count; k++) if (rid != DBNull.Value && Convert.ToInt32(((RunItem)m_run.Items[k]).Key) == Convert.ToInt32(rid)) idx = k;
            if (rid != DBNull.Value && idx == 0) { m_run.Items.Add(StsimRuns.Missing(this.DataFeed.Project, Convert.ToInt32(rid))); idx = m_run.Items.Count - 1; }
            m_run.SelectedIndex = idx; m_run.EndUpdate();
        }
    }
}
