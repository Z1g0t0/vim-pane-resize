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
Resizes border of the current pane by 1 unit. 
```
<C-h> : Resizes to the left
<C-j> : Resizes to the bottom
<C-k> : Resizes to the top 
<C-l> : Resizes to the right
```
Note: Allows continued press.

### Focus resize
Brings current pane to take half of screen.
```
<C-a> : Takes left half
<C-d> : Takes down half
<C-s> : Takes top half
<C-f> : Takes right half
```

### Extra
```
<C-=> : Balance all splits equally.
```