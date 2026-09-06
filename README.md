# Neovim configuration

I got bored, configured Neovim until I forgot what I was supposed to be doing, and made it public. Enjoy my questionable keybindings. HAHAHA

[Installation](#installation) · [Setup options](#installation-options) · [Keybindings](#keybindings)

## Installation

Automatic setup supports **Ubuntu 24.04 or newer**, on x86_64 or ARM64.
Run as your normal user; the script uses `sudo` only for system packages.
Install Git and Python 3 first, then clone and run setup:

```bash
sudo apt update
sudo apt install -y git python3
git clone https://github.com/arnoldzkie2/nvim.git ~/.config/nvim
cd ~/.config/nvim
./setup.sh
```

You can also clone elsewhere and run `./setup.sh` there. It links the checkout to
`${XDG_CONFIG_HOME:-~/.config}/nvim` if that location is empty. It stops if another
configuration occupies that location, without replacing it.

Commit and push the configuration, `lazy-lock.json`, `setup.sh`, and `scripts/`
before cloning on another computer. Uncommitted files cannot transfer through Git.

The script installs:

- Neovim 0.11.4 and Node.js 24.12.0 under `~/.local/share/nvim-setup`, with verified
  archive checksums. It adds their paths to `.profile`, `.bashrc`, and `.zshrc`.
- Plugins restored from `lazy-lock.json`, including the compiled Telescope fzf matcher, completion, snippets,
  multiple cursors, the terminal panel, the file tree, and activity tracking.
- Mason tools: Prettier, StyLua, Ruff, shfmt, google-java-format, PHP CS Fixer,
  rubyfmt, sql-formatter, Taplo, and typescript-language-server.
- System dependencies including Python venv support, Java 21, PHP, Go/gofmt,
  Rust/cargo/rustfmt, clang-format, ripgrep, compiler tools, and clipboard support.
- The configured Treesitter parsers, waiting for installation to finish.
- Ubuntu Sans Mono for text and Symbols Nerd Font Mono for missing icons.
  The default GNOME Terminal profile uses **Ubuntu Sans Mono 11**. The desktop's
  global font setting stays unchanged. Other terminals need this font selected
  in their own preferences.
- Wakapi's endpoint and a privately entered API key in `~/.wakatime.cfg` with
  owner-only permissions. An existing valid Wakapi configuration is retained.
  The plugin downloads its tracking CLI when you first open Neovim normally.

Restart the terminal after setup to load the tool paths and fonts. For fish or
other shells, add the paths shown in `~/.local/share/nvim-setup/env.sh` using your
shell's syntax. Dependencies inside each project still need installation with
that project's package manager. JS/TS language servers use those project files;
formatter support for other languages does not automatically add their LSPs.

## Installation options

```bash
./setup.sh --dry-run           # Show planned actions; no changes or downloads
./setup.sh --check             # Check executable availability; no changes
./setup.sh --non-interactive   # Skip asking for a missing Wakapi key (sudo may prompt)
./setup.sh --wakapi-only       # Add your private key later
./setup.sh --skip-system       # Already installed all apt dependencies
./setup.sh --skip-terminal     # Keep your terminal profile preferences
./setup.sh --skip-fonts        # Keep your existing font setup
./setup.sh --skip-wakapi       # Leave tracking credentials alone
```

Rerunning setup reuses installed binary archives and Mason packages, restores
pinned plugin commits, and avoids duplicate shell initialization lines. Downloads
or installation failures stop setup; fix the reported problem and rerun. Setup
requires internet access. `--check` is an availability check, not a full plugin
health check; use `:checkhealth` inside Neovim for that.

Editor settings and plugin commits are reproducible. Apt and Mason tools use
available versions on first installation, so their versions can differ between
computers. Setup does not copy project-specific aliases or project dependencies.
macOS, Windows, and other Linux distributions need manual installation for now.

Download sources: [Neovim release](https://github.com/neovim/neovim/releases/tag/v0.11.4),
[Node.js release](https://nodejs.org/dist/v24.12.0/), and
[Nerd Fonts](https://github.com/ryanoasis/nerd-fonts/tree/v3.4.0).

## Keybindings

**Normal** is the neutral/navigation mode; press `Esc` to leave Insert mode.
**Visual** selects text. **Terminal** sends input to the embedded shell.
The leader key is **Space**. A `+` means hold the keys together; `jk`, `gg`,
and `Space`, then `B` are sequences. Letter keys are lowercase unless Shift
or an uppercase letter is explicitly shown.

These tables cover the configured shortcuts and the enabled picker/completion
plugin bindings. Standard Neovim editing commands still apply unless overridden.
Plugin-local mappings take priority: for example, Alt+D moves the cursor in an
editor, opens a right split in Telescope, and cycles sessions in the terminal.

### Editor and navigation

| Shortcut | Mode | Action |
| --- | --- | --- |
| `;` | Normal | Open the command line, like `:` |
| `jk` | Insert | Return to Normal mode |
| Alt+W / Alt+A / Alt+S / Alt+D | Normal, Insert, Visual | Move cursor up / left / down / right |
| Alt+Shift+W / Alt+Shift+A / Alt+Shift+S / Alt+Shift+D | Normal, Insert, Visual | Focus split above / left / below / right; finish Visual selection first |
| Ctrl+W | Normal, Insert, Visual, Terminal | Immediately close current split; close its tab if it is the last split; exit Neovim if it is the final window; confirm unsaved changes |
| `n` | Normal | Next tab |
| Ctrl+K | Normal, Insert | Next tab; completion signature help can take priority in Insert mode |
| Ctrl+Q | Normal, Insert | **Force-close the current tab**, potentially discarding unsaved changes |
| Ctrl+E | Normal, Insert | Find files with Telescope; completion cancellation can take priority in Insert mode |
| Space, then `b` | Normal | Search open buffers with Telescope |
| Ctrl+F | Normal, Insert | Toggle the file tree; completion documentation scrolling can take priority in Insert mode |
| Ctrl+C | Normal, Insert | Copy the current line to a Neovim register and enter Insert mode |
| Ctrl+X | Normal, Insert | Cut the current line and enter Insert mode |
| Ctrl+V | Normal, Insert | Paste from the Neovim register and enter Insert mode |
| Ctrl+Z | Normal, Insert | Undo and enter Insert mode |
| Ctrl+R | Normal, Insert, Visual | Delete the whole word under the cursor (Visual selection ends first) |
| Alt+F | Normal, Insert, Visual | Format current file or selected range |
| Alt+Q / Alt+E | Normal, Insert | Duplicate line above / below |
| Alt+J / Alt+K | Normal, Insert | Move line up / down |
| Shift+Up / Shift+Down | Visual | Move selected lines up / down |
| `c` / Shift+C | Visual | Yank selection / selected lines |
| `d` / Shift+D | Visual | Delete selection / selected lines |

Ctrl+W replaces Neovim's usual window-command prefix. To create splits without
Telescope, use `:vsplit` (side by side) or `:split` (above/below).
Copy/paste bindings currently use Neovim registers, not the system clipboard.

### Telescope: search and open files

These shortcuts apply inside the picker. Enter always creates a **new tab**, even
when the selected file is already open elsewhere. Directional splits are placed
relative to the editing window from which the picker was opened.

| Shortcut | Picker mode | Action |
| --- | --- | --- |
| Enter | Insert, Normal | Open selected file/buffer in a new tab |
| Alt+W / Alt+A / Alt+S / Alt+D | Insert, Normal | Open selection in a split above / left / below / right |
| Alt+Enter | Insert, Normal | Open selection in a vertical split |
| Ctrl+Enter | Insert, Normal | Vertical split, only in terminals that send it distinctly from Enter |
| Up / Down | Insert, Normal | Previous / next result |
| Ctrl+P / Ctrl+N | Insert | Previous / next result |
| `k` / `j` | Normal | Previous / next result |
| Ctrl+X / Ctrl+V / Ctrl+T | Insert, Normal | Horizontal split / vertical split / new tab |
| Ctrl+C | Insert | Close picker |
| Esc | Insert, then Normal | Leave prompt typing mode; press again to close picker |
| Tab / Shift+Tab | Insert, Normal | Toggle selection and move to the next / previous result |
| Ctrl+U / Ctrl+D | Insert, Normal | Scroll preview up / down |
| Ctrl+F / Ctrl+K | Insert, Normal | Scroll preview left / right |
| PageUp / PageDown | Insert, Normal | Scroll results up / down |
| Alt+F / Alt+K | Insert, Normal | Scroll results left / right |
| Ctrl+Q | Insert, Normal | Send results to the quickfix list and open it |
| Alt+Q | Insert, Normal | Send marked results to the quickfix list and open it |
| Ctrl+L | Insert | Complete tag in the query |
| Ctrl+/ | Insert | Show picker shortcut help; Ctrl+_ is an equivalent terminal encoding |
| `?` | Normal | Show picker shortcut help |
| `gg` / Shift+G | Normal | First / last result |
| Shift+H / Shift+M / Shift+L | Normal | Top / middle / bottom of results |
| Ctrl+W | Insert | Delete the previous word in the search prompt (picker-local override) |
| Ctrl+R, then Ctrl+W / Ctrl+A / Ctrl+F / Ctrl+L | Insert | Insert original editor word / WORD / filename / line into query |
| Ctrl+J | Insert | No action; Telescope blocks newlines in its prompt |
| Left-click / double-click | Insert, Normal | Select / open a result using the picker's mouse action |

GNOME Terminal 3.52/VTE 0.76 sends Ctrl+Enter as plain Enter. Use Alt+Enter or the
directional Alt shortcuts there. The native fzf matcher handles sorting; previews
skip files larger than 0.5 MB and syntax highlighting above 0.1 MB.

### Completion and snippets

These are Blink's Insert-mode bindings; snippet jumping also applies inside
snippet placeholders. Simply browsing suggestions does **not** insert their text.

| Shortcut | Action |
| --- | --- |
| Tab | Accept selected/first completion; otherwise jump to next snippet placeholder, then fall back to Tab |
| Enter | Accept selected completion; otherwise normal Enter |
| Ctrl+Y | Accept selected/first completion |
| Shift+Tab | Previous snippet placeholder |
| Up / Down, Ctrl+P / Ctrl+N | Previous / next completion |
| Ctrl+Space | Show completion, then show/hide documentation |
| Ctrl+E | Cancel completion; fall back to the editor mapping when not handled |
| Ctrl+B / Ctrl+F | Scroll documentation up / down |
| Ctrl+K | Show/hide signature help, falling back when not handled |

### Multiple cursors

| Shortcut | Mode/context | Action |
| --- | --- | --- |
| Ctrl+D | Normal, Insert | Select the word; press again to add the next matching occurrence |
| Ctrl+D | Visual | Add the selected text through vim-visual-multi's subword mapping |
| Ctrl+L | Normal, Insert | Add the entire current line as an editable region |
| Up / Down | Multiple-cursor Insert mode | Browse completion when visible; otherwise move the cursors |
| Enter | Multiple-cursor Insert mode | Accept completion when available; otherwise insert a return at the cursors |
| Esc | Multiple-cursor editing | Leave Insert mode; press again to exit multiple-cursor editing |

### Embedded terminal

| Shortcut | Mode/context | Action |
| --- | --- | --- |
| Ctrl+J | Normal, Insert, Visual, Terminal | Toggle terminal panel; opening focuses the shell, hiding returns to editor Insert mode |
| Alt+N | Normal, Insert, Visual, Terminal | Create a terminal session |
| Alt+X | Normal, Insert, Visual, Terminal | Delete active session, or the session highlighted in the list |
| Alt+T | Normal, Insert, Visual, Terminal | Focus the terminal list |
| Alt+D | Terminal, terminal-buffer Normal/Visual, terminal list | Next terminal session |
| `n` | Terminal list | Create a session |
| Enter / double-click | Terminal list | Switch to highlighted session; the first row creates a session |
| `d` | Terminal list | Delete highlighted session |
| `q` | Terminal list | Hide panel |
| Ctrl+\, then Ctrl+N | Terminal | Leave shell input mode for terminal-buffer Normal mode |

Use Ctrl+J to hide the complete panel while keeping its shells alive. Closing
either panel window with Ctrl+W also hides the other half and retains the sessions.

### File tree

Ctrl+F toggles the tree. Its local mappings below override editor mappings while
it has focus. `s`, Enter, and double-click show the file and keep focus in the
tree; `o` opens it and focuses the editor; `i` enters Insert mode in the editing
window. Folder selections expand/collapse instead of opening a file.

<details>
<summary>All active file-tree shortcuts (custom and inherited)</summary>

| Key (Neovim notation) | Mode | Action |
| --- | --- | --- |
| `-` | Normal | Up |
| `.` | Normal | Run Command |
| `<2-LeftMouse>` | Normal | Open file or toggle folder; stay in tree |
| `<2-RightMouse>` | Normal | CD |
| `<BS>` | Normal | Close Directory |
| `<C-E>` | Normal | Open: In Place |
| `<C-K>` | Normal | Info |
| `<C-R>` | Normal | Rename: Omit Filename |
| `<C-T>` | Normal | Open: New Tab |
| `<C-V>` | Normal | Open: Vertical Split |
| `<C-X>` | Normal | Open: Horizontal Split |
| `<C-]>` | Normal | CD |
| `<CR>` | Normal | Open file or toggle folder; stay in tree |
| `<Del>` | Normal | Delete |
| `<Del>` | Visual | Delete |
| `<Tab>` | Normal | Open Preview |
| `<lt>` | Normal | Previous Sibling |
| `>` | Normal | Next Sibling |
| `B` | Normal | Toggle Filter: No Buffer |
| `C` | Normal | Toggle Filter: Git Clean |
| `D` | Normal | Trash |
| `D` | Visual | Trash |
| `E` | Normal | Expand All |
| `F` | Normal | Live Filter: Clear |
| `H` | Normal | Toggle Filter: Dotfiles |
| `I` | Normal | Toggle Filter: Git Ignored |
| `J` | Normal | Last Sibling |
| `K` | Normal | First Sibling |
| `L` | Normal | Toggle Group Empty |
| `M` | Normal | Toggle Filter: No Bookmark |
| `O` | Normal | Open: No Window Picker |
| `P` | Normal | Parent Directory |
| `R` | Normal | Refresh |
| `S` | Normal | Search |
| `U` | Normal | Toggle Filter: Custom |
| `W` | Normal | Collapse All |
| `Y` | Normal | Copy Relative Path |
| `[c` | Normal | Prev Git |
| `[e` | Normal | Prev Diagnostic |
| `]c` | Normal | Next Git |
| `]e` | Normal | Next Diagnostic |
| `a` | Normal | Create File Or Directory |
| `bd` | Normal | Delete Bookmarked |
| `bmv` | Normal | Move Bookmarked |
| `bt` | Normal | Trash Bookmarked |
| `c` | Normal | Copy |
| `c` | Visual | Copy |
| `d` | Normal | Delete |
| `d` | Visual | Delete |
| `e` | Normal | Rename: Basename |
| `f` | Normal | Live Filter: Start |
| `g?` | Normal | Help |
| `ge` | Normal | Copy Basename |
| `gp` | Normal | Move |
| `gy` | Normal | Copy Absolute Path |
| `gy` | Visual | Copy Absolute Path |
| `i` | Normal | Return to file and insert |
| `m` | Normal | Toggle Bookmark |
| `m` | Visual | Toggle Bookmark |
| `o` | Normal | Open file and focus editor |
| `p` | Normal | Paste |
| `q` | Normal | Close |
| `r` | Normal | Rename |
| `s` | Normal | Open file or toggle folder; stay in tree |
| `u` | Normal | Rename: Full Path |
| `x` | Normal | Cut |
| `x` | Visual | Cut |
| `y` | Normal | Copy Name |

</details>

### Configuration locations

Editor shortcuts live in `lua/core/keymaps.lua`. Terminal shortcuts live in
`lua/core/terminal.lua`; Telescope, file tree, formatting, and completion shortcuts
live with their respective configurations in `lua/plugins/`.

## Verification

```bash
bash -n setup.sh
python3 -B -m unittest discover -s scripts -p 'test_*.py'
./setup.sh --dry-run
```

Editor regression checks (temporary buffers and shell sessions; tracking disabled):

```bash
nvim --headless -i NONE --cmd 'let g:loaded_wakatime = 1' '+luafile tests/editor.lua'
nvim --headless -i NONE --cmd 'let g:loaded_wakatime = 1' '+luafile tests/telescope_tabs.lua'
nvim --headless -i NONE --cmd 'let g:loaded_wakatime = 1' '+luafile tests/telescope_splits.lua'
```
