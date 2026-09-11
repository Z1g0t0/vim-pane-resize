# vim-pane-resize

Simple split window resizing. 

## Installation

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

### Fine resize 
Increments border to a given side.
```
H : Increments border to the left.
J : Increments border to the bottom.
K : Increments border to the top.
L : Increments border to the right.
```
Note: Allows continued press.

### Focus resize
Brings current pane to take half of screen.
```
<C-h> : Conquers left half of the screen.
<C-j> : Conquers down half of the screen.
<C-k> : Conquers top half of the screen.
<C-l> : Conquers right half of the screen.
```

### Extra
```
<C-=> : Balance all splits equally.
```

### Configuration
Bind your preferred keys:

init.vim
```
let g:pane_resize_disable_defaults = 1

" Example: Fine resize with Alt instead of Shift
nmap <A-h> <Plug>(ResizeLeft)
nmap <A-j> <Plug>(ResizeDown)
nmap <A-k> <Plug>(ResizeUp)
nmap <A-l> <Plug>(ResizeRight)

" Example: Conquer half a screen with Ctrl
nmap <C-a> <Plug>(ConquerLeft)
nmap <C-d> <Plug>(ConquerDown)
nmap <C-s> <Plug>(ConquerUp)
nmap <C-f> <Plug>(ConquerRight)
```
or

init.lua
```
vim.g.pane_resize_disable_defaults = 1

local map = vim.keymap.set
-- Example: Fine resize with Alt instead of Shift
map('n', '<A-h>', '<Plug>(ResizeLeft)')
map('n', '<A-j>', '<Plug>(ResizeDown)')
map('n', '<A-k>', '<Plug>(ResizeUp)')
map('n', '<A-l>', '<Plug>(ResizeRight)')

-- Example: Conquer half a screen with Ctrl
map('n', '<C-a>', '<Plug>(ConquerLeft)')
map('n', '<C-d>', '<Plug>(ConquerDown)')
map('n', '<C-s>', '<Plug>(ConquerUp)')
map('n', '<C-f>', '<Plug>(ConquerRight)')
```