# pane_resize.vim

Modal pane resize:
 - Free movement between panes.
 - Horizontal and vertical splits.
 - Smart incremental adjustments.
 - Set a pane to take half of the screen or make it all the same size.
 - Confirm or cancel back to the layout you started with.
 
## Requirements
- Vim 8.1+ or Neovim (uses `win_getid()`, `win_execute()`, `winlayout()`).
- `win_move_separator()` / `win_move_statusline()` (Vim 8.2.4052+ / modern Neovim) are used when present so the correct bar moves. Older Vim falls back to `:resize` on the neighbouring window.
 
## Install
Drop `pane_resize.vim` on the runtime path, for example:
```text
~/.vim/plugin/pane_resize.vim
```
or with:

[vim-plug](https://github.com/junegunn/vim-plug):
```vim
Plug 'Z1g0t0/vim-pane-resize'
```
[packer.nvim](https://github.com/wbthomason/packer.nvim):
```lua
use 'Z1g0t0/vim-pane-resize'
```
[lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{ 'Z1g0t0/vim-pane-resize' }
```

## Usage
Start with `:PaneResize`(alias `:Resize`) or **`<C-r>`** in normal mode enters resize mode. Needs at least 2 panes.

 - h/j/k/l : Navigates through panes.
 - H/J/K/L : Incremental resize(defaults bottom/left borders unless at screen edge, adaptable).
 - _ : Splits horizontally(`:split`).
 - \| : Splits vertically.(`:vsplit`).
 - C-h/j/k/l : Fills half of the left/bottom/top/right screen.
 - C-= : Balances all panes to the same size.
 - [Enter] : Confirms the layout.
 - [Esc] : Cancels the layout(restores the initial layout).
---

## Technicals
1. **Width (`H`/`L`)** — Defaults to the **left** split.
2. If pane touches **left edge of the screen**(no left split), grab the **right** split instead.
3. **Height (`J` / `K`)** — Defaults to the **bottom** split.
4. If pane touches **bottom edge of the screen**, grab the **top** split instead.
5. Note that a pane can touch 3 edges at once(fills half of the screen), in which case only one axis can be resized.

While the mode is active the plugin sets `'winwidth'`/`'winheight'` to 1 so Vim does not auto-expand the focused window to the default 20 columns(“top-left thinks it is on the right edge” bug).

Cancel uses `winrestcmd()` when you only changed sizes, and a session snapshot of the tab if you split or conquered (those change the window tree). Syntax/filetype is re-applied after a session restore.


## Configuration

```vim
" Keep redo; start resize mode with leader+r
let g:resize_enter = '<Leader>r'
```
You can also skip the automatic map and bind it yourself:

```vim
let g:resize_enter = ''
nnoremap <silent> <Leader>r :PaneResize<CR>
```

### Resize amount
```vim
" Default = 1
let g:resize_width  = 6   " columns per H/L
let g:resize_height = 3   " lines per J/K
```
```vim
let g:resize_keys = {
	\ 'focus_left'    : 'h',
	\ 'focus_down'    : 'j',
	\ 'focus_up'      : 'k',
	\ 'focus_right'   : 'l',
	\ 'inc_left'      : 'H',
	\ 'inc_down'      : 'J',
	\ 'inc_up'        : 'K',
	\ 'inc_right'     : 'L',
	\ 'conquer_left'  : '<C-h>',
	\ 'conquer_down'  : '<C-j>',
	\ 'conquer_up'    : '<C-k>',
	\ 'conquer_right' : '<C-l>',
	\ 'split_h'       : '_',
	\ 'split_v'       : '|',
	\ 'fair_share'    : '=',
	\ 'confirm'       : '<CR>',
	\ 'cancel'        : '<Esc>',
	\ }
```
