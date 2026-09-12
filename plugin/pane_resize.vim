if exists('g:pane_resize')
	finish
endif
let g:pane_resize = 1

" ── User configuration ────────────────────────────────────────────────
let g:resize_enter = get(g:, 'resize_enter', '<C-r>')
let g:resize_width  = get(g:, 'resize_width',  1)
let g:resize_height = get(g:, 'resize_height', 1)
let g:resize_leave  = get(g:, 'resize_leave',  1)

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
let g:resize_keys = extend(copy(s:default_keys), get(g:, 'resize_keys', {}))

" ── Key translation ───────────────────────────────────────────────────
" getchar() returns a Number for single-byte keys and a String for
" special keys. Dictionary keys are always strings, so we stringify.
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

function! s:BuildKeymap() abort
	let s:keymap = {}
	for [action, key] in items(g:resize_keys)
		let s:keymap[s:Key2Char(key)] = action
	endfor
endfunction

call s:BuildKeymap()

function! s:CharKey(c) abort
	return type(a:c) == type(0) ? string(a:c) : a:c
endfunction

" ── Layout snapshot ───────────────────────────────────────────────────
" winrestcmd() only restores SIZES of the current layout. Conquer (wincmd
" H/J/K/L) and split change the layout *tree*, so we also keep a session
" of the current tab and use it whenever the tree changed.
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
endfunction

function! s:LayoutSig() abort
	return string(winlayout())
endfunction

" ── Incremental resize (edge-aware so j/k h/l feel consistent) ────────
function! s:IsEdge(dir) abort
	let cur = winnr()
	noautocmd execute 'wincmd' a:dir
	let edge = (cur == winnr())
	if !edge
		noautocmd execute cur 'wincmd w'
	endif
	return edge
endfunction

function! s:Resize(dir, amount) abort
	let actions = {
		\ 'h': 'vertical resize -',
		\ 'j': 'resize +',
		\ 'k': 'resize -',
		\ 'l': 'vertical resize +'
		\ }
	let opposites = {'h': 'l', 'j': 'k', 'k': 'j', 'l': 'h'}
	if (a:dir ==# 'j' || a:dir ==# 'l') && s:IsEdge(a:dir)
		let opp = opposites[a:dir]
		let cur = winnr()
		noautocmd execute 'wincmd' opp
		execute actions[a:dir] . a:amount
		noautocmd execute cur 'wincmd w'
	elseif (a:dir ==# 'h' || a:dir ==# 'k') && s:IsEdge(opposites[a:dir])
		let cur = winnr()
		noautocmd execute 'wincmd' a:dir
		execute actions[a:dir] . a:amount
		noautocmd execute cur 'wincmd w'
	else
		execute actions[a:dir] . a:amount
	endif
endfunction

function! s:Conquer(dir) abort
	if winnr('$') == 1
		return
	endif
	execute 'wincmd' a:dir
	if a:dir ==# 'H' || a:dir ==# 'L'
		let target = max([1, &columns / 2])
		execute 'vertical resize' target
	else
		let usable = &lines - &cmdheight
					\ - (&laststatus ? 1 : 0)
					\ - (&showtabline ? 1 : 0)
		let target = max([1, usable / 2])
		execute 'resize' target
	endif
endfunction

" ── Mode ──────────────────────────────────────────────────────────────
function! s:Main() abort
	if winnr('$') == 1
		echo '[PaneResize]: Only one window.'
		return
	endif

	call s:BuildKeymap()

	let l:restore_cmd = winrestcmd()
	let l:restore_sig = s:LayoutSig()
	let l:restore_win = win_getid()
	let l:session     = s:SaveSession()
	let l:hlsearch    = &hlsearch
	set nohlsearch

	while 1
		redraw!
		echohl ModeMsg
		echo '<-RESIZE-MODE-ON-> : [Enter/Esc] '
		echohl None

		let c = getchar()
		let action = get(s:keymap, s:CharKey(c), '')

		if action ==# 'confirm'
			break

		elseif (action ==# 'cancel' && g:resize_leave)
			if s:LayoutSig() ==# l:restore_sig
				execute l:restore_cmd
				call win_gotoid(l:restore_win)
			else
				call s:RestoreSession(l:session)
				let l:session = ''
			endif
			break

		elseif action ==# 'inc_left'
			call s:Resize('h', g:resize_width)
		elseif action ==# 'inc_right'
			call s:Resize('l', g:resize_width)
		elseif action ==# 'inc_down'
			call s:Resize('j', g:resize_height)
		elseif action ==# 'inc_up'
			call s:Resize('k', g:resize_height)

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

	if !empty(l:session) && filereadable(l:session)
		call delete(l:session)
	endif
	let &hlsearch = l:hlsearch
	redraw!
	echo ''
	echon "\r"
endfunction

if !empty(g:resize_enter)
	execute 'nnoremap <silent>' g:resize_enter ':call <SID>Main()<CR>'
endif
command! -bar PaneResize call s:Main()