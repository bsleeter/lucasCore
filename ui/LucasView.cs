// =============================================================================
// LucasView.cs - what the single-row option pages share: framed groups, captions and notes, radio choices written to a column
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;
using SyncroSim.Core.Forms;

namespace lucasCoreUI
{
    public abstract class LucasView : DataFeedView
    {
        protected readonly TableLayoutPanel Root = new TableLayoutPanel();
        protected bool Refreshing;

        protected abstract string SheetName { get; }
        protected DataSheet Sheet { get { return this.DataFeed.GetDataSheet(SheetName); } }

        protected LucasView()
        {
            Root.Dock = DockStyle.Fill; Root.ColumnCount = 1; Root.Padding = new Padding(8); Root.AutoScroll = true;
            this.Controls.Add(Root);
        }

        // ---- layout ---------------------------------------------------------------------------------------------------------
        protected void AddGroup(GroupBox g) { Root.RowStyles.Add(new RowStyle(SizeType.AutoSize)); Root.Controls.Add(g); }
        protected void EndGroups() { Root.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); Root.Controls.Add(new Panel { Height = 1 }); }

        protected static GroupBox Group(string title, Control content)
        {
            var gb = new GroupBox { Text = title, Dock = DockStyle.Top, AutoSize = true, AutoSizeMode = System.Windows.Forms.AutoSizeMode.GrowAndShrink,
                                    Padding = new Padding(10, 6, 10, 8), Margin = new Padding(3, 3, 3, 8) };
            content.Dock = DockStyle.Fill;
            gb.Controls.Add(content);
            return gb;
        }

        protected static FlowLayoutPanel Row() { return new FlowLayoutPanel { AutoSize = true, WrapContents = true, FlowDirection = FlowDirection.LeftToRight, Margin = new Padding(0) }; }
        protected static FlowLayoutPanel Column() { return new FlowLayoutPanel { AutoSize = true, WrapContents = false, FlowDirection = FlowDirection.TopDown, Margin = new Padding(0) }; }

        // a two-column form: caption on the left, the control (and an optional note) on the right
        protected static TableLayoutPanel Form() { var t = new TableLayoutPanel { AutoSize = true, ColumnCount = 3 }; t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize)); t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize)); t.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100)); return t; }
        protected static void FormRow(TableLayoutPanel t, string caption, Control c, string note)
        {
            int r = t.RowCount; t.RowCount = r + 1; t.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            t.Controls.Add(Caption(caption), 0, r); t.Controls.Add(c, 1, r);
            if (note != null) t.Controls.Add(Note(note), 2, r);
        }

        protected static Label Caption(string text) { return new Label { Text = text, AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(3, 7, 6, 3) }; }
        protected static Label Note(string text) { return new Label { Text = text, AutoSize = true, ForeColor = SystemColors.GrayText, Anchor = AnchorStyles.Left, Margin = new Padding(3, 7, 3, 3) }; }
        protected static Label Wrapped(string text, int width) { return new Label { Text = text, AutoSize = true, MaximumSize = new Size(width, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(22, 0, 3, 6) }; }
        protected static TextBox Box(int width) { return new TextBox { Width = width, TextAlign = HorizontalAlignment.Right, Anchor = AnchorStyles.Left, Margin = new Padding(3, 3, 12, 3) }; }
        protected static ComboBox List(int width) { return new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = width, Anchor = AnchorStyles.Left, Margin = new Padding(3, 3, 12, 3) }; }

        // ---- data -----------------------------------------------------------------------------------------------------------
        protected object Value(DataSheet ds, string column)
        {
            if (ds == null || !ds.HasData()) return DBNull.Value;
            DataRow r = ds.GetDataRow();
            return r == null ? DBNull.Value : r[column];
        }
        protected object Value(string column) { return Value(Sheet, column); }
        protected int IntValue(string column, int blank) { object v = Value(column); return v == DBNull.Value ? blank : Convert.ToInt32(v); }

        protected void Write(string column, object value) { Write(Sheet, column, value); }
        protected void Write(DataSheet ds, string column, object value)
        {
            object now = Value(ds, column);
            if (Equals(now, value) || (now != DBNull.Value && value != DBNull.Value && value != null && Convert.ToString(now) == Convert.ToString(value))) return;
            ds.SetSingleRowData(column, value ?? DBNull.Value);
        }

        // a number box written to an Integer/Double column on leaving it (blank = DBNull); a bad entry is put back
        protected void BindNumber(TextBox t, Func<DataSheet> ds, string column, bool integer)
        {
            t.Validated += (s, e) =>
            {
                if (Refreshing) return;
                string v = t.Text.Trim(); double d;
                if (v.Length == 0) Write(ds(), column, DBNull.Value);
                else if (double.TryParse(v, out d) && (!integer || d == Math.Floor(d))) Write(ds(), column, integer ? (object)Convert.ToInt32(d) : d);
                RefreshControls();
            };
        }
        protected static string Show(object v) { return v == DBNull.Value || v == null ? "" : Convert.ToString(v); }

        // SyncroSim's own grid for one multi-row sheet of this feed, in a fixed-height panel of the page (made in LoadDataFeed:
        // the session and scenario are not known in the constructor)
        protected static Panel GridHost(int height) { return new Panel { Height = height, Dock = DockStyle.Top, Margin = new Padding(0, 3, 0, 3), MinimumSize = new Size(200, height) }; }
        protected void LoadGrid(Panel host, string sheet)
        {
            host.Controls.Clear();
            MultiRowDataFeedView v = this.Session.CreateMultiRowDataFeedView(this.Scenario, this.ControllingScenario);
            v.LoadDataFeed(this.DataFeed, sheet);
            v.Dock = DockStyle.Fill;
            host.Controls.Add(v);
        }

        // a radio choice for an Integer list column: one button per value, the column's default when blank
        protected class Choice
        {
            public readonly string Column; public readonly int Default; public readonly List<RadioButton> Buttons = new List<RadioButton>();
            public Choice(string column, int dflt) { Column = column; Default = dflt; }
        }

        protected RadioButton Option(Choice c, int value, string text)
        {
            var rb = new RadioButton { Text = text, Tag = value, AutoSize = true, Margin = new Padding(3, 3, 18, 3) };
            rb.CheckedChanged += (s, e) => { if (!Refreshing && rb.Checked) { Write(c.Column, value); OnChoiceChanged(c); } };
            c.Buttons.Add(rb);
            return rb;
        }

        protected void ShowChoice(Choice c)
        {
            int v = IntValue(c.Column, c.Default);
            foreach (RadioButton rb in c.Buttons) rb.Checked = (int)rb.Tag == v;
        }

        protected virtual void OnChoiceChanged(Choice c) { RefreshControls(); }

        protected abstract void ShowData();

        public override void RefreshControls()
        {
            base.RefreshControls();
            if (this.DataFeed == null) return;
            Refreshing = true;
            try { ShowData(); Root.Enabled = this.ShouldEnableView(); }
            finally { Refreshing = false; }
        }

        protected override void OnRowsAdded(object sender, DataSheetRowEventArgs e) { base.OnRowsAdded(sender, e); if (!Refreshing) RefreshControls(); }
        protected override void OnRowsModified(object sender, DataSheetRowEventArgs e) { base.OnRowsModified(sender, e); if (!Refreshing) RefreshControls(); }
        protected override void OnRowsDeleted(object sender, DataSheetRowEventArgs e) { base.OnRowsDeleted(sender, e); if (!Refreshing) RefreshControls(); }
    }
}
