if exists('g:resize_enter_mapped') && !empty(g:resize_enter_mapped)
	silent! execute 'nunmap' g:resize_enter_mapped
endif

let g:pane_resize = 1
let g:resize_enter  = get(g:, 'resize_enter',  '<C-r>')
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

" ── Key translation ───────────────────────────────────────────────────
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
	let keys = extend(copy(s:default_keys), get(g:, 'resize_keys', {}))
	let s:keymap = {}
	for [action, key] in items(keys)
		let s:keymap[s:Key2Char(key)] = action
	endfor
endfunction

call s:BuildKeymap()

function! s:CharKey(c) abort
	return type(a:c) == type(0) ? string(a:c) : a:c
endfunction

" ── Layout snapshot ───────────────────────────────────────────────────
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

function! s:RefreshHighlight() abort
	" Session source with eventignore skips FileType/Syntax autocommands.
	if exists('g:syntax_on') && g:syntax_on
		silent! syntax enable
	endif
	let cur = win_getid()
	for w in range(1, winnr('$'))
		let id = win_getid(w)
		call win_execute(id, 'if !empty(&filetype) | silent! doautocmd <nomodeline> FileType | endif')
	endfor
	call win_gotoid(cur)
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
	call s:RefreshHighlight()
endfunction

function! s:LayoutSig() abort
	return string(winlayout())
endfunction

" Keep the command-line from being eaten by a greedy :resize.
function! s:FixCmdline(cmdheight) abort
	if &cmdheight != a:cmdheight
		let &cmdheight = a:cmdheight
	endif
endfunction

function! s:UsableHeight() abort
	let tab = 0
	if &showtabline == 2 || (&showtabline == 1 && tabpagenr('$') > 1)
		let tab = 1
	endif
	let stl = (&laststatus == 0) ? 0 : 1
	return max([1, &lines - &cmdheight - stl - tab])
endfunction

" ── Incremental resize ────────────────────────────────────────────────
" ALWAYS resize the current window. Never wincmd to a neighbour — that is
" what made a different pane change size.
"   H = narrower   L = wider   J = taller   K = shorter
function! s:IncResize(dir, amount) abort
	if a:dir ==# 'h'
		execute 'vertical resize -' . a:amount
	elseif a:dir ==# 'l'
		execute 'vertical resize +' . a:amount
	elseif a:dir ==# 'j'
		execute 'resize +' . a:amount
	elseif a:dir ==# 'k'
		execute 'resize -' . a:amount
	endif
endfunction

" Back-compat: old maps called <SID>Resize() with 0 args, or (dir, amount).
function! s:Resize(...) abort
	if a:0 >= 2
		call s:IncResize(a:1, a:2)
	else
		call s:Main()
	endif
endfunction

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
	let l:cmdheight   = max([1, &cmdheight])
	let l:ea          = &equalalways

	set nohlsearch
	set noequalalways

	while 1
		call s:FixCmdline(l:cmdheight)
		redraw!
		echohl ModeMsg
		echo ' <-RESIZE-MODE-> [Enter/Esc] '
		echohl None

		let c = getchar()
		let action = get(s:keymap, s:CharKey(c), '')

		if action ==# 'confirm'
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

	if !empty(l:session) && filereadable(l:session)
		call delete(l:session)
	endif
	let &hlsearch = l:hlsearch
	let &equalalways = l:ea
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
command! -bar PaneResize call s:Main()
command! -bar Resize call s:Main()

nnoremap <silent> <Plug>(PaneResize) :PaneResize<CR>

if !empty(g:resize_enter)
	execute 'nmap <silent>' g:resize_enter '<Plug>(PaneResize)'
	let g:resize_enter_mapped = g:resize_enter
endif