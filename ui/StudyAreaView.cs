// =============================================================================
// StudyAreaView.cs - the Study Area page: pick the kind of unit first (radio buttons), then the units of that kind (drop-down)
// =============================================================================
// Replaces the default grid of lucasCore_StudyArea, whose single drop-down listed all 6,221 units of every source. The sheet itself
// is unchanged (one row per unit, UnitId = a stsim_SecondaryStratum row), so stage 1 reads it as before; the kind chosen is kept in
// Study Area Type (lucasCore_StudyAreaOptions.SourceId). The picker itself is UnitPicker (shared with the Spatial Allocation page).
// The units may be of several kinds (stage 1 takes the cells of any of them): the kind chosen only says which is added next.
// Built by tools/build_ui.ps1 into lucasCoreUI.dll (C# 5, .NET Framework 4.8, against SyncroSim's own assemblies).
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
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
            m_picker.Changed = RefreshControls; m_picker.MixKinds = true;
            m_picker.EmptyNote = Inherited;
            this.Controls.Add(m_picker);
        }

        // With no units chosen here, the study area of the first scenario this one depends on that has one (a Build that depends on
        // its Data Download scenario: the units are entered once; user 2026-11-21). SyncroSim hands a run the dependency's rows, so
        // the page says so in place of "all of CONUS". A result holds the rows itself.
        private string Inherited()
        {
            Scenario sc = this.Scenario; if (sc == null || sc.IsResult) return null;
            foreach (Scenario d in sc.Dependencies)
            {
                DataSheet x = d.GetDataSheet("lucasCore_StudyArea"); if (x == null || !x.HasData()) continue;
                List<string> names = x.GetData().Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted && r["UnitId"] != DBNull.Value)
                    .Select(r => m_picker.UnitName(Convert.ToInt32(r["UnitId"])) ?? "unit " + r["UnitId"]).OrderBy(n => n, StringComparer.CurrentCultureIgnoreCase).ToList();
                if (names.Count == 0) continue;
                return string.Format("Study area: {0} unit{1} from \"{2}\", a scenario this one depends on: {3}. Units chosen here would replace them.",
                                     names.Count, names.Count == 1 ? "" : "s", d.Name, string.Join("; ", names));
            }
            return null;
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
