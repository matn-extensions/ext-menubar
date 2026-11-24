module matn.ui.shell.menubar;

import std.algorithm : max, min, clamp;
import std.conv : to;

import matn.platform.sdl;
import matn.platform.font : FontEngine;
import matn.ui.grid.cell;
import matn.ui.grid.grid;
import matn.extension.base;

/// Represents an item in a menubar dropdown menu
struct MenuBarItem
{
    string id;
    string label;
    string icon;
    string shortcut;
    bool isSeparator;
    bool isCheckbox;
    bool isChecked;
    bool isEnabled = true;
    void delegate() onSelect;

    static MenuBarItem separator()
    {
        MenuBarItem it;
        it.isSeparator = true;
        return it;
    }

    static MenuBarItem item(string id, string label, string icon, string shortcut, void delegate() onSelect, bool isEnabled = true)
    {
        MenuBarItem it;
        it.id = id;
        it.label = label;
        it.icon = icon;
        it.shortcut = shortcut;
        it.onSelect = onSelect;
        it.isEnabled = isEnabled;
        return it;
    }

    static MenuBarItem checkbox(string id, string label, string icon, string shortcut, bool isChecked, void delegate() onSelect, bool isEnabled = true)
    {
        MenuBarItem it;
        it.id = id;
        it.label = label;
        it.icon = icon;
        it.shortcut = shortcut;
        it.isCheckbox = true;
        it.isChecked = isChecked;
        it.onSelect = onSelect;
        it.isEnabled = isEnabled;
        return it;
    }
}

/// Dynamic context passed from the host application to the menubar on render and interaction
struct MenuBarContext
{
    int gridCols;
    int gridRows;
    int startRow = 0;
    Color bg;
    Color barBg;
    Color text;
    Color muted;
    Color accent;
    Color border;
    Color activeLine;
    bool showIcons;
    bool isLight;

    // Active document/project info
    string activeFileName;
    string activeProjectName;
    bool hasActiveBuffer;
    bool isModified;
    bool canUndo;
    bool canRedo;
    bool hasSelection;
    bool hasProject;

    // View toggles
    bool isTreeVisible;
    bool isMinimapVisible;
    bool isBreadcrumbsVisible;
    bool isKeyboardVisible;
    bool isDiagnosticsVisible;
    bool isRunnerVisible;
    bool isIconsEnabled;
    bool isLineNumbersEnabled;
    bool isBlurredBgEnabled;

    // File Actions
    void delegate() onNewFile;
    void delegate() onOpenFile;
    void delegate() onOpenFolder;
    void delegate() onQuickOpen;
    void delegate() onSave;
    void delegate() onSaveAs;
    void delegate() onSaveAll;
    void delegate() onCloseTab;
    void delegate() onCloseAllTabs;
    void delegate() onCloseProject;
    void delegate() onExit;

    // Edit Actions
    void delegate() onUndo;
    void delegate() onRedo;
    void delegate() onCut;
    void delegate() onCopy;
    void delegate() onPaste;
    void delegate() onToggleComment;
    void delegate() onFind;
    void delegate() onFindInProject;
    void delegate() onSelectAll;
    void delegate() onClearSelection;

    // View Actions
    void delegate() onToggleTree;
    void delegate() onToggleMinimap;
    void delegate() onToggleBreadcrumbs;
    void delegate() onToggleKeyboard;
    void delegate() onToggleDiagnostics;
    void delegate() onToggleProjectFind;
    void delegate() onZoomIn;
    void delegate() onZoomOut;
    void delegate() onResetZoom;
    void delegate() onToggleIcons;
    void delegate() onToggleLineNumbers;
    void delegate() onToggleBlurredBg;
    void delegate() onCycleTheme;
    void delegate() onFontPicker;

    // Navigation Actions
    void delegate() onGoToDefinition;
    void delegate() onFindReferences;
    void delegate() onGoToSymbol;
    void delegate() onHomeTab;
    void delegate() onNextTab;
    void delegate() onPrevTab;

    // Code / LSP Actions
    void delegate() onFormatDocument;
    void delegate() onRenameSymbol;
    void delegate() onHoverDoc;
    void delegate() onTriggerSuggestions;

    // Run / Swiss Army Knife Actions
    void delegate() onRunCurrentFile;
    void delegate() onBuildProject;
    void delegate() onTestProject;
    void delegate() onCleanProject;
    void delegate() onDScannerLint;
    void delegate() onDScannerSyntax;
    void delegate() onToggleRunner;
    void delegate() onClearRunner;

    // Tools / Extensions Actions
    void delegate() onDoctorHub;
    void delegate() onLogsView;
    void delegate() onMarketplace;
    void delegate() onSettings;
    void delegate() onReloadExtensions;
    void delegate() onScanProjectWatcher;
    void delegate() onSshOnline;

    // Help Actions
    void delegate() onHelp;
    void delegate() onAbout;
}

/// Top-level Menu Bar Extension providing comprehensive desktop GUI navigation
class MenuBarExtension : Extension, VisualExtension
{
    private bool _visible = true;

    @property bool visible() const { return _visible; }
    @property void visible(bool val) { _visible = val; }
    override @property bool isVisible() const { return isActive && _visible; }

    void toggle()
    {
        _visible = !_visible;
        if (!_visible) closeMenu();
    }

    int getHeight() const
    {
        return isVisible ? 1 : 0;
    }

    struct TopMenu
    {
        string id;
        string title;
        int colStart;
        int colEnd;
    }

    TopMenu[] topMenus;
    int hoveredMenuIdx = -1;
    int openMenuIdx = -1;
    int selectedItemIdx = -1;

    // Dropdown bounding box
    int dropdownX = 0;
    int dropdownY = 0;
    int dropdownW = 0;
    int dropdownH = 0;

    @property bool isOpen() const
    {
        return isVisible && (openMenuIdx >= 0 && openMenuIdx < topMenus.length);
    }

    void closeMenu()
    {
        openMenuIdx = -1;
        selectedItemIdx = -1;
        hoveredMenuIdx = -1;
    }

    this()
    {
        super(ExtensionManifest(
            "matn.menubar",
            "Application Menu Bar",
            "1.0.0",
            "Khozayn",
            "Desktop GUI Menu Bar providing complete access to editor, file, LSP, tools, and view commands",
            true
        ));

        topMenus = [
            TopMenu("file", " File "),
            TopMenu("edit", " Edit "),
            TopMenu("selection", " Selection "),
            TopMenu("view", " View "),
            TopMenu("go", " Go "),
            TopMenu("code", " Code "),
            TopMenu("run", " Run "),
            TopMenu("tools", " Tools "),
            TopMenu("help", " Help ")
        ];
    }

    MenuBarItem[] getMenuItems(string menuId, MenuBarContext ctx)
    {
        MenuBarItem[] items;
        switch (menuId)
        {
        case "file":
            items ~= MenuBarItem.item("file.new", "New File", "󰈔", "Ctrl+N", ctx.onNewFile);
            items ~= MenuBarItem.item("file.open", "Open File...", "󰈞", "Ctrl+O", ctx.onOpenFile);
            items ~= MenuBarItem.item("file.openFolder", "Open Folder...", "󰉋", "Ctrl+Shift+O", ctx.onOpenFolder);
            items ~= MenuBarItem.item("file.quickOpen", "Quick Open File...", "󰍉", "Ctrl+P", ctx.onQuickOpen);
            items ~= MenuBarItem.separator();
            items ~= MenuBarItem.item("file.save", "Save", "󰆓", "Ctrl+S", ctx.onSave, ctx.hasActiveBuffer);
            items ~= MenuBarItem.item("file.saveAs", "Save As...", "󰆔", "Ctrl+Shift+S", ctx.onSaveAs, ctx.hasActiveBuffer);
            items ~= MenuBarItem.item("file.saveAll", "Save All", "󰆓", "", ctx.onSaveAll);
            items ~= MenuBarItem.separator();
            items ~= MenuBarItem.item("file.closeTab", "Close Tab", "󰅖", "Ctrl+W", ctx.onCloseTab);
            items ~= MenuBarItem.item("file.closeAllTabs", "Close All Tabs", "󰅖", "", ctx.onCloseAllTabs);
            items ~= MenuBarItem.item("file.closeProject", "Close Project", "󰉋", "", ctx.onCloseProject, ctx.hasProject);
            items ~= MenuBarItem.separator();
            items ~= MenuBarItem.item("file.exit", "Exit Matn", "󰗼", "Ctrl+Q", ctx.onExit);
            break;

        case "edit":
            items ~= MenuBarItem.item("edit.undo", "Undo", "󰕌", "Ctrl+Z", ctx.onUndo, ctx.canUndo);
            items ~= MenuBarItem.item("edit.redo", "Redo", "󰑎", "Ctrl+Y", ctx.onRedo, ctx.canRedo);
            items ~= MenuBarItem.separator();
            items ~= MenuBarItem.item("edit.cut", "Cut", "󰆐", "Ctrl+X", ctx.onCut, ctx.hasSelection);
            items ~= MenuBarItem.item("edit.copy", "Copy", "󰆏", "Ctrl+C", ctx.onCopy, ctx.hasSelection);
            items ~= MenuBarItem.item("edit.paste", "Paste", "󰆒", "Ctrl+V", ctx.onPaste);
            items ~= MenuBarItem.separator();
            items ~= MenuBarItem.item("edit.find", "Find in File", "󰍉", "Ctrl+F", ctx.onFind);
            items ~= MenuBarItem.item("edit.findInProject", "Find in Project", "󰍉", "Ctrl+Shift+F", ctx.onFindInProject);
            items ~= MenuBarItem.separator();
            items ~= MenuBarItem.item("edit.comment", "Toggle Line Comment", "󰅺", "Ctrl+/", ctx.onToggleComment, ctx.hasActiveBuffer);
            items ~= MenuBarItem.item("edit.format", "Format Document", "󰦨", "Ctrl+Shift+I", ctx.onFormatDocument, ctx.hasActiveBuffer);
            items ~= MenuBarItem.item("edit.rename", "Rename Symbol", "󰑕", "F2", ctx.onRenameSymbol, ctx.hasActiveBuffer);
            break;

        case "selection":
            items ~= MenuBarItem.item("select.all", "Select All", "󰒅", "Ctrl+A", ctx.onSelectAll, ctx.hasActiveBuffer);
            items ~= MenuBarItem.item("select.clear", "Clear Selection", "󰅖", "Esc", ctx.onClearSelection, ctx.hasSelection);
            break;

        case "view":
            items ~= MenuBarItem.checkbox("view.tree", "File Tree", "󰙅", "Ctrl+B", ctx.isTreeVisible, ctx.onToggleTree);
            items ~= MenuBarItem.checkbox("view.minimap", "Minimap", "󰍹", "Ctrl+M", ctx.isMinimapVisible, ctx.onToggleMinimap);
            items ~= MenuBarItem.checkbox("view.breadcrumbs", "Breadcrumbs", "󰄯", "Ctrl+Shift+B", ctx.isBreadcrumbsVisible, ctx.onToggleBreadcrumbs);
            items ~= MenuBarItem.checkbox("view.keyboard", "Virtual Keyboard", "󰌌", "", ctx.isKeyboardVisible, ctx.onToggleKeyboard);
            items ~= MenuBarItem.checkbox("view.runner", "Output / Task Console", "󰍹", "Ctrl+`", ctx.isRunnerVisible, ctx.onToggleRunner);
            items ~= MenuBarItem.separator();
            items ~= MenuBarItem.item("view.diagnostics", "Problems / Diagnostics", "󰅚", "Ctrl+Shift+M", ctx.onToggleDiagnostics);
            items ~= MenuBarItem.item("view.projectFind", "Project Find Results", "󰍉", "Ctrl+Shift+F", ctx.onToggleProjectFind);
            items ~= MenuBarItem.separator();
            items ~= MenuBarItem.item("view.zoomIn", "Zoom In", "󰍉", "Ctrl+=", ctx.onZoomIn);
            items ~= MenuBarItem.item("view.zoomOut", "Zoom Out", "󰍉", "Ctrl+-", ctx.onZoomOut);
            items ~= MenuBarItem.item("view.resetZoom", "Reset Zoom", "󰍉", "Ctrl+0", ctx.onResetZoom);
            items ~= MenuBarItem.separator();
            items ~= MenuBarItem.checkbox("view.icons", "File Icons", "󰀻", "", ctx.isIconsEnabled, ctx.onToggleIcons);
            items ~= MenuBarItem.checkbox("view.lineNumbers", "Line Numbers", "󰔱", "", ctx.isLineNumbersEnabled, ctx.onToggleLineNumbers);
            items ~= MenuBarItem.checkbox("view.blurredBg", "Blurred Background", "󰂵", "", ctx.isBlurredBgEnabled, ctx.onToggleBlurredBg);
            items ~= MenuBarItem.separator();
            items ~= MenuBarItem.item("view.theme", "Cycle Color Theme", "󰏘", "F2", ctx.onCycleTheme);
            items ~= MenuBarItem.item("view.font", "Font Settings...", "󰬡", "", ctx.onFontPicker);
            break;

        case "go":
            items ~= MenuBarItem.item("go.file", "Go to File...", "󰈞", "Ctrl+P", ctx.onQuickOpen);
            items ~= MenuBarItem.item("go.symbol", "Go to Symbol in File", "󰄯", "Ctrl+Shift+.", ctx.onGoToSymbol);
            items ~= MenuBarItem.item("go.definition", "Go to Definition", "󰑕", "F12", ctx.onGoToDefinition);
            items ~= MenuBarItem.item("go.references", "Find References", "󰌹", "Shift+F12", ctx.onFindReferences);
            items ~= MenuBarItem.separator();
            items ~= MenuBarItem.item("go.home", "Home Tab", "󰋜", "Esc", ctx.onHomeTab);
            items ~= MenuBarItem.item("go.nextTab", "Next Tab", "󰒭", "", ctx.onNextTab);
            items ~= MenuBarItem.item("go.prevTab", "Previous Tab", "󰒮", "", ctx.onPrevTab);
            break;

        case "code":
            items ~= MenuBarItem.item("code.format", "Format Document", "󰦨", "Ctrl+Shift+I", ctx.onFormatDocument);
            items ~= MenuBarItem.item("code.rename", "Rename Symbol", "󰑕", "F2", ctx.onRenameSymbol);
            items ~= MenuBarItem.item("code.hover", "Hover Documentation", "󰋽", "F1", ctx.onHoverDoc);
            items ~= MenuBarItem.item("code.suggestions", "Trigger Suggestions", "󰞋", "Ctrl+Space", ctx.onTriggerSuggestions);
            items ~= MenuBarItem.separator();
            items ~= MenuBarItem.item("code.definition", "Go to Definition", "󰑕", "F12", ctx.onGoToDefinition);
            items ~= MenuBarItem.item("code.references", "Find References", "󰌹", "Shift+F12", ctx.onFindReferences);
            items ~= MenuBarItem.item("code.diagnostics", "Language Server Diagnostics", "󰅚", "Ctrl+Shift+M", ctx.onToggleDiagnostics);
            break;

        case "run":
            items ~= MenuBarItem.item("run.start", "Run Current File / Project", "󰐊", "F5", ctx.onRunCurrentFile);
            items ~= MenuBarItem.item("run.build", "Build Project", "󰑮", "F7", ctx.onBuildProject);
            items ~= MenuBarItem.item("run.test", "Run Tests", "󰄬", "F6", ctx.onTestProject);
            items ~= MenuBarItem.item("run.clean", "Clean Project Artifacts", "󰃢", "", ctx.onCleanProject);
            items ~= MenuBarItem.separator();
            items ~= MenuBarItem.item("run.dscannerLint", "D-Scanner Lint / Style Check", "󰈈", "", ctx.onDScannerLint);
            items ~= MenuBarItem.item("run.dscannerSyntax", "D-Scanner Syntax Check", "󰅚", "", ctx.onDScannerSyntax);
            items ~= MenuBarItem.separator();
            items ~= MenuBarItem.item("run.toggleConsole", "Toggle Output Console", "󰍹", "Ctrl+`", ctx.onToggleRunner);
            items ~= MenuBarItem.item("run.clearConsole", "Clear Output Console", "󰅖", "", ctx.onClearRunner);
            break;

        case "tools":
            items ~= MenuBarItem.item("tools.doctor", "Doctor Hub & Process Profiler...", "󰚥", "Ctrl+Shift+D", ctx.onDoctorHub);
            items ~= MenuBarItem.item("tools.logs", "System & Extension Logs (From Start)...", "󰌱", "Ctrl+Shift+L", ctx.onLogsView);
            items ~= MenuBarItem.item("tools.marketplace", "Extension Marketplace", "󰏖", "Ctrl+Shift+X", ctx.onMarketplace);
            items ~= MenuBarItem.item("tools.settings", "Extension Settings", "󰒓", "Ctrl+,", ctx.onSettings);
            items ~= MenuBarItem.item("tools.reload", "Reload External Extensions", "󰑐", "Ctrl+Shift+R", ctx.onReloadExtensions);
            items ~= MenuBarItem.separator();
            items ~= MenuBarItem.item("tools.watcher", "Scan Project (Watcher)", "󰈈", "Alt+W", ctx.onScanProjectWatcher);
            items ~= MenuBarItem.item("tools.ssh", "SSH Remote Connect...", "󰒍", "", ctx.onSshOnline);
            break;

        case "help":
            items ~= MenuBarItem.item("help.commands", "Command Palette / Help", "󰋖", "Ctrl+Shift+P", ctx.onHelp);
            items ~= MenuBarItem.item("help.shortcuts", "Keyboard Shortcuts", "󰈙", "F1", ctx.onHelp);
            items ~= MenuBarItem.separator();
            items ~= MenuBarItem.item("help.about", "About Matn", "󰋽", "", ctx.onAbout);
            break;

        default:
            break;
        }
        return items;
    }

    /// Renders the top menubar strip and calculates dropdown geometry
    void render(GlyphGrid grid, MenuBarContext ctx)
    {
        if (!isVisible || grid is null) return;

        // 1. Draw Menubar row background
        grid.fillRect(0, ctx.startRow, ctx.gridCols, 1, ' ', CellStyle(ctx.text, ctx.barBg));

        int col = 1;
        foreach (i, ref m; topMenus)
        {
            m.colStart = col;
            m.colEnd = col + cast(int) m.title.length;

            bool isOpen = (openMenuIdx == cast(int) i);
            bool isHovered = (hoveredMenuIdx == cast(int) i);

            Color btnBg;
            Color btnFg;
            ubyte attr = CellAttr.none;

            if (isOpen)
            {
                btnBg = ctx.accent;
                btnFg = Color.black;
                attr = CellAttr.bold;
            }
            else if (isHovered)
            {
                btnBg = Color(cast(ubyte) clamp(ctx.barBg.r + 20, 0, 255),
                              cast(ubyte) clamp(ctx.barBg.g + 20, 0, 255),
                              cast(ubyte) clamp(ctx.barBg.b + 28, 0, 255));
                btnFg = ctx.text;
                attr = CellAttr.bold;
            }
            else
            {
                btnBg = ctx.barBg;
                btnFg = ctx.text;
            }

            grid.putString(col, ctx.startRow, to!dstring(m.title), CellStyle(btnFg, btnBg, attr));
            col += cast(int) m.title.length;
        }

        // 2. Right side document / project status pill
        string rightPill = "";
        if (ctx.activeProjectName.length > 0)
            rightPill ~= "[" ~ ctx.activeProjectName ~ "] ";
        if (ctx.activeFileName.length > 0)
            rightPill ~= (ctx.isModified ? "● " : "") ~ ctx.activeFileName;
        else
            rightPill ~= "Matn";

        int pillLen = cast(int) rightPill.length;
        int pillCol = ctx.gridCols - pillLen - 2;
        if (pillCol > col + 3)
        {
            grid.putString(pillCol, ctx.startRow, to!dstring(" " ~ rightPill ~ " "),
                           CellStyle(ctx.muted, ctx.barBg));
        }

        // 3. Pre-calculate dropdown coordinates so callers can clip or check hits
        if (openMenuIdx >= 0 && openMenuIdx < topMenus.length)
        {
            auto items = getMenuItems(topMenus[openMenuIdx].id, ctx);
            if (items.length > 0)
            {
                int maxLen = 22;
                foreach (ref it; items)
                {
                    if (it.isSeparator) continue;
                    int len = cast(int) it.label.length + (it.shortcut.length ? (cast(int) it.shortcut.length + 4) : 0) + 6;
                    if (len > maxLen) maxLen = len;
                }
                dropdownW = clamp(maxLen + 2, 24, max(26, ctx.gridCols - 2));
                dropdownH = cast(int) items.length;
                dropdownX = clamp(topMenus[openMenuIdx].colStart, 0, max(0, ctx.gridCols - dropdownW));
                dropdownY = ctx.startRow + 1;
                if (dropdownY + dropdownH > ctx.gridRows)
                    dropdownY = max(0, ctx.gridRows - dropdownH);
            }
        }
    }

    /// Renders the floating dropdown card ON TOP of all editor views
    void renderDropdown(GlyphGrid grid, MenuBarContext ctx)
    {
        if (!isOpen || grid is null) return;

        auto items = getMenuItems(topMenus[openMenuIdx].id, ctx);
        if (items.length == 0) return;

        Color cardBg = ctx.barBg;
        Color hoverRowBg = ctx.activeLine;
        Color sepColor = ctx.border;

        // Fill background over whatever is underneath (tabbar, editor text, treeview)
        grid.fillRect(dropdownX, dropdownY, dropdownW, dropdownH, ' ', CellStyle(ctx.text, cardBg));

        foreach (i, ref it; items)
        {
            int r = dropdownY + cast(int) i;
            if (it.isSeparator)
            {
                grid.fillRect(dropdownX + 1, r, dropdownW - 2, 1, ' ', CellStyle(sepColor, sepColor));
                continue;
            }

            bool isHovered = (cast(int) i == selectedItemIdx);
            Color rowBg = isHovered ? hoverRowBg : cardBg;
            Color rowFg = it.isEnabled ? (isHovered ? ctx.accent : ctx.text) : ctx.muted;
            ubyte rowAttr = isHovered ? CellAttr.bold : CellAttr.none;

            if (isHovered)
                grid.fillRect(dropdownX, r, dropdownW, 1, ' ', CellStyle(rowFg, rowBg));

            string prefix = "  ";
            if (it.isCheckbox)
            {
                prefix = ctx.showIcons ? (it.isChecked ? "󰄬 " : "󰄱 ") : (it.isChecked ? "✔ " : "· ");
            }
            else if (ctx.showIcons && it.icon.length > 0)
            {
                prefix = it.icon ~ " ";
            }

            string lineStr = prefix ~ it.label;
            grid.putString(dropdownX + 1, r, to!dstring(lineStr), CellStyle(rowFg, rowBg, rowAttr));

            if (it.shortcut.length > 0)
            {
                int scCol = dropdownX + dropdownW - cast(int) it.shortcut.length - 1;
                if (scCol > dropdownX + cast(int) lineStr.length + 2)
                {
                    grid.putString(scCol, r, to!dstring(it.shortcut), CellStyle(ctx.muted, rowBg));
                }
            }
        }
    }

    void renderReal(SDL_Renderer* renderer, FontEngine font, float padX, float padY, Color accentCol, Color borderCol)
    {
        if (!isVisible || renderer is null) return;

        // Hairline outline around dropdown card when open
        if (isOpen && dropdownW > 0 && dropdownH > 0)
        {
            SDL_FRect r;
            r.x = padX + dropdownX * font.charWidth;
            r.y = padY + dropdownY * font.lineHeight;
            r.w = dropdownW * font.charWidth;
            r.h = dropdownH * font.lineHeight;

            SDL_SetRenderDrawColor(renderer, borderCol.r, borderCol.g, borderCol.b, 255);
            SDL_RenderRect(renderer, &r);
        }
    }

    bool handleMouseMove(int col, int row, MenuBarContext ctx)
    {
        if (!isVisible) return false;

        // 1. Mouse is hovering over the Menubar row
        if (row == ctx.startRow)
        {
            hoveredMenuIdx = -1;
            foreach (i, ref m; topMenus)
            {
                if (col >= m.colStart && col < m.colEnd)
                {
                    hoveredMenuIdx = cast(int) i;
                    break;
                }
            }

            // User requirement: "it should open when hover"!
            // So whenever mouse hovers any menubar item, open it immediately
            if (hoveredMenuIdx != -1)
            {
                if (openMenuIdx != hoveredMenuIdx)
                {
                    openMenuIdx = hoveredMenuIdx;
                    selectedItemIdx = -1;
                }
            }
            return true;
        }

        // 2. Mouse is hovering inside the open dropdown
        if (openMenuIdx >= 0 && openMenuIdx < topMenus.length)
        {
            if (col >= dropdownX && col < dropdownX + dropdownW &&
                row >= dropdownY && row < dropdownY + dropdownH)
            {
                int itemIdx = row - dropdownY;
                auto items = getMenuItems(topMenus[openMenuIdx].id, ctx);
                if (itemIdx >= 0 && itemIdx < items.length && !items[itemIdx].isSeparator)
                {
                    selectedItemIdx = itemIdx;
                }
                else
                {
                    selectedItemIdx = -1;
                }
                return true;
            }
            else
            {
                // Mouse left both the menubar row and the open dropdown -> close menu
                closeMenu();
                return false;
            }
        }

        hoveredMenuIdx = -1;
        return false;
    }

    bool handleMouseDown(int col, int row, MenuBarContext ctx)
    {
        if (!isVisible) return false;

        // 1. Click on Menubar row
        if (row == ctx.startRow)
        {
            foreach (i, ref m; topMenus)
            {
                if (col >= m.colStart && col < m.colEnd)
                {
                    if (openMenuIdx == cast(int) i)
                    {
                        closeMenu();
                    }
                    else
                    {
                        openMenuIdx = cast(int) i;
                        selectedItemIdx = -1;
                    }
                    return true;
                }
            }
            closeMenu();
            return true;
        }

        // 2. Click inside open dropdown
        if (openMenuIdx >= 0 && openMenuIdx < topMenus.length)
        {
            if (col >= dropdownX && col < dropdownX + dropdownW &&
                row >= dropdownY && row < dropdownY + dropdownH)
            {
                int itemIdx = row - dropdownY;
                auto items = getMenuItems(topMenus[openMenuIdx].id, ctx);
                if (itemIdx >= 0 && itemIdx < items.length && !items[itemIdx].isSeparator)
                {
                    auto it = items[itemIdx];
                    if (it.isEnabled && it.onSelect)
                    {
                        if (!it.isCheckbox)
                            closeMenu();
                        it.onSelect();
                    }
                    return true;
                }
                return true;
            }

            // Click outside closes dropdown
            closeMenu();
            return false;
        }

        return false;
    }

    bool handleKeyDown(uint key, uint mod, MenuBarContext ctx)
    {
        if (!isVisible) return false;

        // F10 key toggles the first menu
        if (key == 0x40000043) // SDLK_F10
        {
            if (isOpen)
                closeMenu();
            else
            {
                openMenuIdx = 0;
                selectedItemIdx = -1;
            }
            return true;
        }

        if (!isOpen) return false;

        auto items = getMenuItems(topMenus[openMenuIdx].id, ctx);

        if (key == 0x1b) // ESC
        {
            closeMenu();
            return true;
        }
        else if (key == 0x40000050) // SDLK_LEFT
        {
            openMenuIdx = (openMenuIdx - 1 + cast(int) topMenus.length) % cast(int) topMenus.length;
            selectedItemIdx = -1;
            return true;
        }
        else if (key == 0x4000004f) // SDLK_RIGHT
        {
            openMenuIdx = (openMenuIdx + 1) % cast(int) topMenus.length;
            selectedItemIdx = -1;
            return true;
        }
        else if (key == 0x40000051) // SDLK_DOWN
        {
            if (items.length == 0) return true;
            int next = (selectedItemIdx < 0) ? 0 : (selectedItemIdx + 1);
            foreach (_; 0 .. items.length)
            {
                if (next >= items.length) next = 0;
                if (!items[next].isSeparator)
                {
                    selectedItemIdx = next;
                    break;
                }
                next++;
            }
            return true;
        }
        else if (key == 0x40000052) // SDLK_UP
        {
            if (items.length == 0) return true;
            int prev = (selectedItemIdx <= 0) ? (cast(int) items.length - 1) : (selectedItemIdx - 1);
            foreach (_; 0 .. items.length)
            {
                if (prev < 0) prev = cast(int) items.length - 1;
                if (!items[prev].isSeparator)
                {
                    selectedItemIdx = prev;
                    break;
                }
                prev--;
            }
            return true;
        }
        else if (key == 13 || key == 0x40000058 || key == 32) // ENTER or SPACE
        {
            if (selectedItemIdx >= 0 && selectedItemIdx < items.length)
            {
                auto it = items[selectedItemIdx];
                if (!it.isSeparator && it.isEnabled && it.onSelect)
                {
                    if (!it.isCheckbox)
                        closeMenu();
                    it.onSelect();
                    return true;
                }
            }
            return true;
        }

        return false;
    }
}

unittest
{
    auto mb = new MenuBarExtension();
    assert(mb.manifest.id == "matn.menubar");
    assert(!mb.isActive);
    assert(mb.getHeight() == 0);

    mb.activate(null);
    assert(mb.isActive);
    assert(mb.isVisible);
    assert(mb.getHeight() == 1);
    assert(!mb.isOpen);

    MenuBarContext ctx;
    ctx.gridCols = 80;
    ctx.gridRows = 24;
    ctx.startRow = 0;

    auto fileItems = mb.getMenuItems("file", ctx);
    assert(fileItems.length > 5);

    auto editItems = mb.getMenuItems("edit", ctx);
    assert(editItems.length > 5);

    auto viewItems = mb.getMenuItems("view", ctx);
    assert(viewItems.length > 5);

    auto codeItems = mb.getMenuItems("code", ctx);
    assert(codeItems.length > 4);

    auto runItems = mb.getMenuItems("run", ctx);
    assert(runItems.length >= 6);

    auto toolsItems = mb.getMenuItems("tools", ctx);
    assert(toolsItems.length > 3);

    auto helpItems = mb.getMenuItems("help", ctx);
    assert(helpItems.length >= 3);

    // Mouse hover opening menu
    mb.render(new GlyphGrid(80, 24), ctx);
    assert(mb.handleMouseMove(2, 0, ctx));
    assert(mb.isOpen);
    assert(mb.openMenuIdx == 0); // "File"

    // Key navigation
    assert(mb.handleKeyDown(0x4000004f, 0, ctx)); // Right arrow -> "Edit"
    assert(mb.openMenuIdx == 1);

    assert(mb.handleKeyDown(0x40000051, 0, ctx)); // Down arrow -> item selection
    assert(mb.selectedItemIdx >= 0);

    // ESC closes menu
    assert(mb.handleKeyDown(0x1b, 0, ctx));
    assert(!mb.isOpen);

    // Toggle visibility
    mb.toggle();
    assert(!mb.visible);
    assert(!mb.isVisible);
    assert(mb.getHeight() == 0);

    mb.toggle();
    assert(mb.visible);
    assert(mb.isVisible);
    assert(mb.getHeight() == 1);
}
