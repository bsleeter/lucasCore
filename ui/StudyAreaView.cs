// =============================================================================
// StudyAreaView.cs - the Study Area page: pick the kind of unit first (radio buttons), then the units of that kind (drop-down)
// =============================================================================
// Replaces the default grid of lucasCore_StudyArea, whose single drop-down listed all 6,221 units of every source. The sheet itself
// is unchanged (one row per unit, UnitId = a stsim_SecondaryStratum row), so stage 1 reads it as before; the kind chosen is kept in
// Study Area Type (lucasCore_StudyAreaOptions.SourceId). The picker itself is UnitPicker (shared with the Spatial Allocation page).
// Built by tools/build_ui.ps1 into lucasCoreUI.dll (C# 5, .NET Framework 4.8, against SyncroSim's own assemblies).
// =============================================================================
using System.Windows.Forms;
using SyncroSim.Core;
using SyncroSim.Core.Forms;

namespace lucasCoreUI
{
    public class StudyAreaView : DataFeedView
    {
        private readonly UnitPicker m_picker = new UnitPicker("Define the study area by", 120);

        public StudyAreaView()
        {
            m_picker.Dock = DockStyle.Fill; m_picker.Padding = new Padding(8);
            m_picker.UnitSheet = () => this.DataFeed.GetDataSheet("lucasCore_StudyArea");
            m_picker.KindSheet = () => this.DataFeed.GetDataSheet("lucasCore_StudyAreaOptions");
            m_picker.Changed = RefreshControls;
            this.Controls.Add(m_picker);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            // the lists are read when the page opens: SyncroSim's sheet monitors read a single row, so they cannot watch multi-row lists
            m_picker.LoadLists(dataFeed.Project);
            RefreshControls();
        }

        public override void RefreshControls()
        {
            base.RefreshControls();
            if (this.DataFeed == null) return;
            m_picker.ShowData(!(this.Scenario != null && this.Scenario.IsResult));
        }

        protected override void OnRowsAdded(object sender, DataSheetRowEventArgs e) { base.OnRowsAdded(sender, e); if (!m_picker.IsRefreshing) RefreshControls(); }
        protected override void OnRowsDeleted(object sender, DataSheetRowEventArgs e) { base.OnRowsDeleted(sender, e); if (!m_picker.IsRefreshing) RefreshControls(); }
        protected override void OnRowsModified(object sender, DataSheetRowEventArgs e) { base.OnRowsModified(sender, e); if (!m_picker.IsRefreshing) RefreshControls(); }
    }
}
