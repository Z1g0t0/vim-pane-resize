" pane_resize.vim — modal window resize / move / split

if exists('g:resize_enter_mapped') && !empty(g:resize_enter_mapped)
	silent! execute 'nunmap' g:resize_enter_mapped
endif

let g:pane_resize   = 1
let g:resize_enter  = get(g:, 'resize_enter',  '<C-r>')
let g:resize_width  = get(g:, 'resize_width',  1)
let g:resize_height = get(g:, 'resize_height', 1)
let g:resize_leave  = get(g:, 'resize_leave',  1)
let g:resize_prompt = get(g:, 'resize_prompt', '<-RESIZE-MODE-> : [Enter] : [Esc]')

let s:default_keys = {
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

" -----------------------------------------------------------------------------
" Key translation
" getchar() returns a Number for single-byte keys and sometimes a String.
" Dictionary keys are strings, so everything is normalised to string(char2nr).
" -----------------------------------------------------------------------------

" Convert a Vim key notation ('h', '<C-h>', '<CR>', …) to the getchar() token.
function! s:Key2Char(key) abort
	if type(a:key) == type(0)
		return string(a:key)
	endif
	let key = a:key
	if key =~# '^<.*>$'
		try
			let raw = eval('"' . '\' . key . '"')
		catch
			return key
		endtry
		if strlen(raw) == 1
			return string(char2nr(raw))
		endif
		return raw
	endif
	if strlen(key) == 1
		return string(char2nr(key))
	endif
	return key
endfunction

" Rebuild action lookup from defaults + g:resize_keys.
function! s:BuildKeymap() abort
	let keys = extend(copy(s:default_keys), get(g:, 'resize_keys', {}))
	let s:keymap = {}
	for [action, key] in items(keys)
		let s:keymap[s:Key2Char(key)] = action
	endfor
endfunction

call s:BuildKeymap()

" Normalise a getchar() result so it matches s:Key2Char() tokens.
function! s:CharKey(c) abort
	if type(a:c) == type(0)
		return string(a:c)
	endif
	if strlen(a:c) == 1
		return string(char2nr(a:c))
	endif
	return a:c
endfunction

" -----------------------------------------------------------------------------
" Layout snapshot
" winrestcmd() only restores SIZES of the current window tree.
" Conquer (wincmd H/J/K/L) and :split change the tree, so we also write a
" session of the current tab and replay it when the tree actually changed.
" -----------------------------------------------------------------------------

" Write a session file for the current tab (no 'tabpages' → this tab only).
function! s:SaveSession() abort
	let tmp = tempname() . '.vim'
	let save = &sessionoptions
	try
		set sessionoptions=blank,buffers,help,winsize,resize
		execute 'mksession!' fnameescape(tmp)
	finally
		let &sessionoptions = save
	endtry
	return tmp
endfunction

" Session was sourced with eventignore=all, so FileType/Syntax never ran.
function! s:RefreshHighlight() abort
	if exists('g:syntax_on') && g:syntax_on
		silent! syntax enable
	endif
	let cur = win_getid()
	for w in range(1, winnr('$'))
		call win_execute(win_getid(w),
			\ 'if !empty(&filetype) | silent! doautocmd <nomodeline> FileType | endif')
	endfor
	call win_gotoid(cur)
endfunction

" Restore the tab from a session file, then re-apply syntax.
function! s:RestoreSession(file) abort
	if empty(a:file) || !filereadable(a:file)
		return
	endif
	let hide = &hidden
	let ei = &eventignore
	try
		set hidden
		set eventignore=all
		silent! execute 'source' fnameescape(a:file)
	finally
		let &hidden = hide
		let &eventignore = ei
		call delete(a:file)
	endtry
	call s:RefreshHighlight()
endfunction

" Fingerprint of the split tree (ids + nesting). Sizes do not affect it.
function! s:LayoutSig() abort
	return string(winlayout())
endfunction

" :resize can steal rows from the command line; put cmdheight back.
function! s:FixCmdline(cmdheight) abort
	if &cmdheight != a:cmdheight
		let &cmdheight = a:cmdheight
	endif
endfunction

" Screen rows available for windows (minus cmdline / status / tabline).
function! s:UsableHeight() abort
	let tab = (&showtabline == 2 || (&showtabline == 1 && tabpagenr('$') > 1)) ? 1 : 0
	let stl = (&laststatus == 0) ? 0 : 1
	return max([1, &lines - &cmdheight - stl - tab])
endfunction

" -----------------------------------------------------------------------------
" Neighbours — screen geometry, not wincmd
" winnr('l') / wincmd l lie when 'winwidth' (default 20) blocks the move,
" which made the top-left pane look like a right-edge pane.
" Floating windows are ignored.
" -----------------------------------------------------------------------------

function! s:Overlaps(a1, a2, b1, b2) abort
	return a:a1 <= a:b2 && a:b1 <= a:a2
endfunction

function! s:IsFloat(w) abort
	if !exists('*nvim_win_get_config')
		return 0
	endif
	try
		return !empty(nvim_win_get_config(win_getid(a:w)).relative)
	catch
		return 0
	endtry
endfunction

" Closest window whose right edge sits on our left edge, or 0.
function! s:WinLeft() abort
	let pos = win_screenpos(0)
	let top = pos[0]
	let bot = pos[0] + winheight(0) - 1
	let left = pos[1]
	if left <= 1
		return 0
	endif
	let cur = winnr()
	for w in range(1, winnr('$'))
		if w == cur || s:IsFloat(w) | continue | endif
		let p = win_screenpos(w)
		let r = p[1] + winwidth(w) - 1
		let t = p[0]
		let b = p[0] + winheight(w) - 1
		if r < left && r >= left - 2 && s:Overlaps(top, bot, t, b)
			return w
		endif
	endfor
	return 0
endfunction

" Closest window whose left edge sits on our right edge, or 0.
function! s:WinRight() abort
	let pos = win_screenpos(0)
	let top = pos[0]
	let bot = pos[0] + winheight(0) - 1
	let right = pos[1] + winwidth(0) - 1
	if right >= &columns
		return 0
	endif
	let cur = winnr()
	for w in range(1, winnr('$'))
		if w == cur || s:IsFloat(w) | continue | endif
		let p = win_screenpos(w)
		let t = p[0]
		let b = p[0] + winheight(w) - 1
		if p[1] > right && p[1] <= right + 2 && s:Overlaps(top, bot, t, b)
			return w
		endif
	endfor
	return 0
endfunction

" Closest window sitting directly above, or 0.
function! s:WinAbove() abort
	let pos = win_screenpos(0)
	let left = pos[1]
	let right = pos[1] + winwidth(0) - 1
	let top = pos[0]
	if top <= 1
		return 0
	endif
	let cur = winnr()
	for w in range(1, winnr('$'))
		if w == cur || s:IsFloat(w) | continue | endif
		let p = win_screenpos(w)
		let b = p[0] + winheight(w) - 1
		let l = p[1]
		let r = p[1] + winwidth(w) - 1
		if b < top && b >= top - 3 && s:Overlaps(left, right, l, r)
			return w
		endif
	endfor
	return 0
endfunction

" Closest window sitting directly below, or 0.
function! s:WinBelow() abort
	let pos = win_screenpos(0)
	let left = pos[1]
	let right = pos[1] + winwidth(0) - 1
	let bot = pos[0] + winheight(0) - 1
	let cur = winnr()
	for w in range(1, winnr('$'))
		if w == cur || s:IsFloat(w) | continue | endif
		let p = win_screenpos(w)
		let l = p[1]
		let r = p[1] + winwidth(w) - 1
		if p[0] > bot && p[0] <= bot + 3 && s:Overlaps(left, right, l, r)
			return w
		endif
	endfor
	return 0
endfunction

" -----------------------------------------------------------------------------
" Incremental resize
" Try the preferred bar first. If this window's size does not move in the
" requested direction, undo and try the opposite bar (edge fallback).
" -----------------------------------------------------------------------------

function! s:IncResize(dir, amount) abort
	if a:dir ==# 'h'
		call s:ChangeWidth(a:amount)
	elseif a:dir ==# 'l'
		call s:ChangeWidth(-a:amount)
	elseif a:dir ==# 'j'
		call s:ChangeHeight(a:amount)
	elseif a:dir ==# 'k'
		call s:ChangeHeight(-a:amount)
	endif
endfunction

" delta > 0 → this window must get wider, < 0 → narrower.
function! s:ChangeWidth(delta) abort
	if a:delta == 0
		return
	endif
	let minw = max([1, &winminwidth])
	if a:delta < 0 && winwidth(0) + a:delta < minw
		let need = minw - winwidth(0)
		if need == 0
			return
		endif
	else
		let need = a:delta
	endif

	let cur   = winnr()
	let left  = s:WinLeft()
	let right = s:WinRight()

	" On a left-edge pane the only movable bar is the right one.
	" Flip need so H/L still travel in their named direction:
	"   H (left) → right bar moves left  → shrinks
	"   L (right) → right bar moves right → widens
	if !left && right
		let need = -need
	endif

	" [window-that-owns-the-bar, offset-sign relative to `need`]
	" Left bar: moving it left (negative) grows us.
	" Right bar: moving it right (positive) grows us.
	let tries = []
	if left  | call add(tries, [left, -1]) | endif
	if right | call add(tries, [cur,  1])  | endif

	call s:TryMove(tries, need, 1)
endfunction

" delta > 0 → this window must get taller, < 0 → shorter.
function! s:ChangeHeight(delta) abort
	if a:delta == 0
		return
	endif
	let minh = max([1, &winminheight])
	if a:delta < 0 && winheight(0) + a:delta < minh
		let need = minh - winheight(0)
		if need == 0
			return
		endif
	else
		let need = a:delta
	endif

	let cur   = winnr()
	let below = s:WinBelow()
	let above = s:WinAbove()
	
	if !below && above
		let need = -need
	endif

	" Bottom bar: moving it down (positive) grows us.
	" Top bar:    moving it up   (negative) grows us.
	let tries = []
	if below | call add(tries, [cur,   1]) | endif
	if above | call add(tries, [above, -1]) | endif

	call s:TryMove(tries, need, 0)
endfunction

" Apply offset = sign * need to each candidate bar until THIS window's
" width (or height) moves the right way. Undo a failed candidate first.
function! s:TryMove(tries, need, horiz) abort
	let before = a:horiz ? winwidth(0) : winheight(0)
	let mover  = a:horiz
		\ ? (exists('*win_move_separator')  ? 'win_move_separator'  : '')
		\ : (exists('*win_move_statusline') ? 'win_move_statusline' : '')

	for spec in a:tries
		let wnr  = spec[0]
		let sign = spec[1]
		if !empty(mover)
			call call(mover, [wnr, sign * a:need])
		else
			call s:LegacyMove(a:horiz, wnr, sign * a:need)
		endif
		let now = a:horiz ? winwidth(0) : winheight(0)
		if (a:need > 0 && now > before) || (a:need < 0 && now < before)
			return
		endif
		" Wrong way or no-op: reverse the same offset, then try the next bar.
		if now != before
			if !empty(mover)
				call call(mover, [wnr, -sign * a:need])
			elseif a:horiz
				execute 'vertical resize' before
			else
				execute 'resize' before
			endif
		endif
	endfor
endfunction

" :resize fallback when win_move_* is missing. Still only touches one bar.
function! s:LegacyMove(horiz, wnr, offset) abort
	let cur = winnr()
	if a:wnr != cur
		execute a:wnr . 'wincmd w'
	endif
	if a:horiz
		execute 'vertical resize' max([1, winwidth(0) + a:offset])
	else
		execute 'resize' max([1, winheight(0) + a:offset])
	endif
	if winnr() != cur
		execute cur . 'wincmd w'
	endif
endfunction

" Move the current window to an edge (wincmd H/J/K/L) and take half the screen.
function! s:Conquer(dir) abort
	if winnr('$') == 1
		return
	endif
	execute 'wincmd' a:dir
	if a:dir ==# 'H' || a:dir ==# 'L'
		execute 'vertical resize' max([1, &columns / 2])
	else
		execute 'resize' max([1, s:UsableHeight() / 2])
	endif
endfunction

" -----------------------------------------------------------------------------
" Mode loop
" -----------------------------------------------------------------------------
function! s:Main() abort
	if winnr('$') == 1
		echom '[PaneResize]: Only one window.'
		return
	endif

	call s:BuildKeymap()

	let l:restore_cmd 	= winrestcmd()
	let l:restore_sig 	= s:LayoutSig()
	let l:restore_win 	= win_getid()
	let l:session     	= s:SaveSession()
	let l:hlsearch    	= &hlsearch
	let l:cmdheight   	= max([1, &cmdheight])
	let l:ea          	= &equalalways
	let l:confirmed 	= 0
	let l:prompt      	= get(g:, 'resize_prompt', '<-RESIZE-MODE-> : [Enter] : [Esc] ')

	set nohlsearch
	set noequalalways

	while 1
		call s:FixCmdline(l:cmdheight)
		redraw!
		echohl ModeMsg
		echo l:prompt
		echohl None

		let c = getchar()
		let action = get(s:keymap, s:CharKey(c), '')

		if action ==# 'confirm'
			let l:confirmed = 1
			break

		elseif action ==# 'cancel'
			if s:LayoutSig() ==# l:restore_sig
				execute l:restore_cmd
				call win_gotoid(l:restore_win)
			else
				call s:RestoreSession(l:session)
				let l:session = ''
			endif
			break

		elseif action ==# 'inc_left'
			call s:IncResize('h', g:resize_width)
		elseif action ==# 'inc_right'
			call s:IncResize('l', g:resize_width)
		elseif action ==# 'inc_down'
			call s:IncResize('j', g:resize_height)
		elseif action ==# 'inc_up'
			call s:IncResize('k', g:resize_height)

		elseif action ==# 'conquer_left'
			call s:Conquer('H')
		elseif action ==# 'conquer_down'
			call s:Conquer('J')
		elseif action ==# 'conquer_up'
			call s:Conquer('K')
		elseif action ==# 'conquer_right'
			call s:Conquer('L')

		elseif action ==# 'focus_left'
			wincmd h
		elseif action ==# 'focus_down'
			wincmd j
		elseif action ==# 'focus_up'
			wincmd k
		elseif action ==# 'focus_right'
			wincmd l

		elseif action ==# 'fair_share'
			wincmd =

		elseif action ==# 'split_h'
			split
		elseif action ==# 'split_v'
			vsplit
		endif
	endwhile
	
	let l:final_restore = l:confirmed ? winrestcmd() : ''

	if !empty(l:session) && filereadable(l:session)
		call delete(l:session)
	endif
	let &hlsearch = l:hlsearch
	let &equalalways = l:ea
	if !empty(l:final_restore)
    	execute l:final_restore
	endif
	call s:FixCmdline(l:cmdheight)
	redraw!
	echo ''
	echon "\r"
endfunction

function! PaneResize() abort
	call s:Main()
endfunction

silent! delcommand PaneResize
silent! delcommand Resize
command! -bar -nargs=0 PaneResize call s:Main()
command! -bar -nargs=0 Resize call s:Main()

nnoremap <silent> <Plug>(PaneResize) :PaneResize<CR>

if !empty(g:resize_enter)
	execute 'nmap <silent>' g:resize_enter '<Plug>(PaneResize)'
	let g:resize_enter_mapped = g:resize_enter
endif