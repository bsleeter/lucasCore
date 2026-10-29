// =============================================================================
// FigureView.cs - the figure pages of a result: Build Figures, Run Figures and Compare Figures shown as pictures, not as a file grid
// =============================================================================
// Output sheets lucasCore_OutputBuildFigure / OutputRunFigure / OutputCompareFigure (Figure, Title, Caption, FileName; stages 12, 13,
// 14), read only. A drop-down of the figures ("Figure 3. Carbon fluxes per year") with Previous / Next (or the arrow keys), the PNG
// fitted to the page, its caption under it, and buttons to open it full size in the default image viewer, save it, or save them all
// to a folder. The PNGs are in the sheet's folder of the library's data folder (Library.GetFolderName); they are read into memory,
// so the files stay unlocked.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;
using SyncroSim.Core.Forms;

namespace lucasCoreUI
{
    public abstract class FigureView : DataFeedView
    {
        protected abstract string SheetName { get; }

        private class Fig { public int Number; public string Title, Caption, File; public override string ToString() { return string.Format("Figure {0}. {1}", Number, Title); } }

        private readonly ComboBox m_list = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 460, Margin = new Padding(3, 4, 6, 3) };
        private readonly Button m_prev = new Button { Text = "< Previous", AutoSize = true }, m_next = new Button { Text = "Next >", AutoSize = true };
        private readonly Button m_open = new Button { Text = "Open full size", AutoSize = true }, m_save = new Button { Text = "Save as...", AutoSize = true };
        private readonly Button m_saveAll = new Button { Text = "Save all...", AutoSize = true };
        private readonly PictureBox m_pic = new PictureBox { Dock = DockStyle.Fill, SizeMode = PictureBoxSizeMode.Zoom, BackColor = Color.White };
        private readonly Label m_caption = new Label { Dock = DockStyle.Fill, AutoSize = false, ForeColor = SystemColors.ControlText, Padding = new Padding(6, 4, 6, 4) };
        private readonly Label m_state = new Label { AutoSize = true, ForeColor = SystemColors.GrayText, Margin = new Padding(9, 8, 3, 3) };
        private List<Fig> m_figs = new List<Fig>();

        protected FigureView()
        {
            var bar = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, WrapContents = true, Padding = new Padding(4, 4, 4, 0) };
            bar.Controls.AddRange(new Control[] { m_list, m_prev, m_next, m_open, m_save, m_saveAll, m_state });
            var t = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 3 };
            t.RowStyles.Add(new RowStyle(SizeType.AutoSize)); t.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); t.RowStyles.Add(new RowStyle(SizeType.Absolute, 70));
            t.Controls.Add(bar, 0, 0); t.Controls.Add(m_pic, 0, 1); t.Controls.Add(m_caption, 0, 2);
            this.Controls.Add(t);
            m_list.SelectedIndexChanged += (s, e) => Show(m_list.SelectedItem as Fig);
            m_prev.Click += (s, e) => Step(-1); m_next.Click += (s, e) => Step(1);
            m_open.Click += (s, e) => { var f = m_list.SelectedItem as Fig; if (f != null && File.Exists(f.File)) try { Process.Start(f.File); } catch (Exception) { } };
            m_save.Click += (s, e) => SaveOne();
            m_saveAll.Click += (s, e) => SaveAll();
            m_pic.DoubleClick += (s, e) => m_open.PerformClick();
            var tip = new ToolTip(); tip.SetToolTip(m_pic, "Double-click to open the figure full size"); tip.SetToolTip(m_list, "Left and right arrow keys step through the figures");
            m_caption.Resize += (s, e) => m_caption.MaximumSize = new Size(m_caption.Width, 0);
        }

        protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
        {
            if (keyData == Keys.Left || keyData == Keys.PageUp) { Step(-1); return true; }
            if (keyData == Keys.Right || keyData == Keys.PageDown) { Step(1); return true; }
            return base.ProcessCmdKey(ref msg, keyData);
        }

        private void Step(int d)
        {
            if (m_list.Items.Count == 0) return;
            int i = Math.Max(0, Math.Min(m_list.Items.Count - 1, m_list.SelectedIndex + d));
            if (i != m_list.SelectedIndex) m_list.SelectedIndex = i;
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            RefreshControls();
        }

        // the folder holding the sheet's files: SyncroSim's own answer, else <library>.ssim.data\Scenario-<id>\<sheet>
        private string Folder(DataSheet ds)
        {
            try { string f = this.Scenario.Library.GetFolderName(ds, false); if (!string.IsNullOrEmpty(f) && Directory.Exists(f)) return f; } catch (Exception) { }
            try { string f = this.Scenario.Library.GetFolderName(LibraryFolderType.Data, ds, false); if (!string.IsNullOrEmpty(f) && Directory.Exists(f)) return f; } catch (Exception) { }
            return null;
        }

        public override void RefreshControls()
        {
            base.RefreshControls();
            if (this.DataFeed == null) return;
            DataSheet ds = this.DataFeed.GetDataSheet(SheetName);
            string folder = Folder(ds);
            var figs = new List<Fig>();
            try
            {
                foreach (DataRow r in ds.GetData().Rows.Cast<DataRow>().Where(x => x.RowState != DataRowState.Deleted))
                {
                    string fn = Convert.ToString(r["FileName"]);
                    if (fn.Length == 0) continue;
                    string path = Path.IsPathRooted(fn) ? fn : (folder == null ? fn : Path.Combine(folder, Path.GetFileName(fn)));
                    figs.Add(new Fig { Number = r["Figure"] == DBNull.Value ? 0 : Convert.ToInt32(r["Figure"]), Title = Convert.ToString(r["Title"]), Caption = Convert.ToString(r["Caption"]), File = path });
                }
            }
            catch (Exception) { }
            figs = figs.OrderBy(f => f.Number).ToList();
            string keep = m_list.SelectedItem is Fig ? ((Fig)m_list.SelectedItem).File : null;
            m_figs = figs;
            m_list.BeginUpdate(); m_list.Items.Clear(); foreach (Fig f in figs) m_list.Items.Add(f); m_list.EndUpdate();
            int idx = keep == null ? 0 : Math.Max(0, figs.FindIndex(f => f.File == keep));
            if (figs.Count > 0) m_list.SelectedIndex = idx; else Show(null);
            m_list.Enabled = m_prev.Enabled = m_next.Enabled = m_open.Enabled = m_save.Enabled = m_saveAll.Enabled = figs.Count > 0;
            m_state.Text = figs.Count == 0 ? "No figures: run the scenario first (figures appear in its result)." : string.Format("{0} figure{1}", figs.Count, figs.Count == 1 ? "" : "s");
        }

        private void Show(Fig f)
        {
            Image old = m_pic.Image; m_pic.Image = null; if (old != null) old.Dispose();
            if (f == null) { m_caption.Text = ""; return; }
            if (!File.Exists(f.File)) { m_caption.Text = "The figure file is missing: " + f.File; return; }
            try { using (var ms = new MemoryStream(File.ReadAllBytes(f.File))) using (var img = Image.FromStream(ms)) m_pic.Image = new Bitmap(img); }
            catch (Exception ex) { m_caption.Text = "Could not read " + f.File + ": " + ex.Message; return; }
            m_caption.Text = f.Caption;
            m_prev.Enabled = m_list.SelectedIndex > 0; m_next.Enabled = m_list.SelectedIndex < m_list.Items.Count - 1;
        }

        private void SaveOne()
        {
            var f = m_list.SelectedItem as Fig; if (f == null || !File.Exists(f.File)) return;
            using (var d = new SaveFileDialog { FileName = Path.GetFileName(f.File), Filter = "PNG Files (*.png)|*.png", Title = "Save the figure" })
                if (d.ShowDialog(this) == DialogResult.OK) try { File.Copy(f.File, d.FileName, true); } catch (Exception ex) { MessageBox.Show(this, ex.Message, "Save the figure"); }
        }

        private void SaveAll()
        {
            using (var d = new FolderBrowserDialog { Description = "Choose the folder to save every figure into" })
            {
                if (d.ShowDialog(this) != DialogResult.OK) return;
                int n = 0;
                foreach (Fig f in m_figs) if (File.Exists(f.File)) try { File.Copy(f.File, Path.Combine(d.SelectedPath, Path.GetFileName(f.File)), true); n++; } catch (Exception) { }
                m_state.Text = string.Format("{0} figure{1} saved to {2}", n, n == 1 ? "" : "s", d.SelectedPath);
            }
        }
    }

    public class BuildFigureView : FigureView { protected override string SheetName { get { return "lucasCore_OutputBuildFigure"; } } }
    public class RunFigureView : FigureView { protected override string SheetName { get { return "lucasCore_OutputRunFigure"; } } }
    public class CompareFigureView : FigureView { protected override string SheetName { get { return "lucasCore_OutputCompareFigure"; } } }
}
