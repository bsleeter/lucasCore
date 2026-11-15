// =============================================================================
// NaturalChangeView.cs - the Natural Change page of a projection: reforestation now; insects and drought later
// =============================================================================
// User 2026-11-14: vegetation change that is neither land use nor fire gets its own page ("Where should Reforestation go? And in the
// future, other natural changes like Insects and Drought?"). Reforestation Options (single row, displayed as Natural Change; the view sits on the sheet, since a data feed needs two sheets; was its own item
// in the LUCAS Core list): the Build's reforestation rule (on or off, the cutoff, how riparian and savanna BpS are read; stages 5-6)
// and the projection's draw (the last N historical years). Below it the Reforestation row of Projection Transitions and its placement
// (TransitionWalk.cs; the rows stay in the Land Use tables).
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class NaturalChangeView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_ReforestationOptions"; } }

        private readonly CheckBox m_on = new CheckBox { Text = "Reforestation transition", AutoSize = true, Margin = new Padding(3, 5, 12, 3) };
        private readonly TextBox m_cutoff = Box(60), m_recent = Box(60);
        private readonly Choice m_riparian = new Choice("RiparianAs", 1);
        private readonly TransitionWalk m_walk;
        private readonly Label m_walkInfo = Note("");
        private bool m_own;
        private DataSheet Tr() { return TransitionWalk.OwnOrDependency(this.Scenario, TransitionWalk.TRANSITIONS, out m_own); }
        private DataSheet Al() { bool o; return TransitionWalk.OwnOrDependency(this.Scenario, TransitionWalk.ALLOCATION, out o); }

        public NaturalChangeView()
        {
            this.SuspendLayout();
            AddGroup(Group("What natural change covers", ProjectionTransitionsView.Stack(
                Note("Vegetation change that is not land use or fire: reforestation now; insects and drought later."))));
            var rip = Row(); rip.Controls.Add(Option(m_riparian, 1, "Forest potential")); rip.Controls.Add(Option(m_riparian, 2, "Non-forest potential"));
            AddGroup(Group("Reforestation: the Build's rule (set on the Build scenario)", ManagementActionsView.Lines(
                ManagementActionsView.Line("Transition:", m_on, Note("Off works in a projection alone; on needs a Build made with it on.")),
                ManagementActionsView.Line("Cutoff (years):", m_cutoff, Note("Forest-potential land that first turns forest this many years after the start counts as reforestation; sooner is regrowth. Blank = fitted. Needs a new Build.")),
                ManagementActionsView.Line("Riparian, savanna:", rip, Note("Whether they follow the forest rule (cutoff) or the non-forest rule (any new forest is reforestation). Needs a new Build.")))));
            AddGroup(Group("Reforestation in a projection", ManagementActionsView.Lines(
                ManagementActionsView.Line("Draw from the last:", m_recent, Note("Historical years (blank = 10). Projection only.")))));
            m_walk = new TransitionWalk(new[] { TransitionWalk.REFOREST }, Tr, Al, () => Refreshing, () => RefreshControls());
            m_walk.Title[TransitionWalk.REFOREST] = "Reforestation each year";
            m_walk.FamilyNote[TransitionWalk.REFOREST] = "Its row of the Land Use tables.";
            Root.RowStyles.Add(new RowStyle(SizeType.AutoSize)); Root.Controls.Add(m_walk.Host);
            Root.RowStyles.Add(new RowStyle(SizeType.AutoSize)); Root.Controls.Add(m_walkInfo);
            EndGroups();
            m_on.CheckedChanged += (s, e) => { if (!Refreshing) { Write("Enabled", m_on.Checked ? -1 : 0); RefreshControls(); } };
            BindNumber(m_cutoff, () => Sheet, "CutoffYears", true); BindNumber(m_recent, () => Sheet, "RecentYears", true);
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            if (this.Scenario != null) { try { m_walk.Ms.Load(this.Scenario.Project, this.Scenario); } catch (Exception) { } }
            m_walk.Rebuild();
            RefreshControls();
        }

        protected override void ShowData()
        {
            object on = Value("Enabled"); m_on.Checked = on == DBNull.Value || Convert.ToBoolean(on);
            m_cutoff.Text = Show(Value("CutoffYears")); m_recent.Text = Show(Value("RecentYears"));
            ShowChoice(m_riparian);
            m_cutoff.Enabled = m_recent.Enabled = m_on.Checked;
            Tr(); m_walk.Editable = m_own && m_on.Checked && !(this.Scenario != null && this.Scenario.IsResult) && this.ShouldEnableView();
            m_walk.Show();
            m_walkInfo.Text = !m_walk.Shows(TransitionWalk.REFOREST) ? "No Reforestation row in the Land Use tables: open Land Use once to fill them from the defaults."
                            : !m_own ? "The reforestation draw comes from a dependency (read-only here); give this scenario its own Land Use tables to change it." : "";
            m_walkInfo.Visible = m_walkInfo.Text.Length > 0;
        }
    }
}
