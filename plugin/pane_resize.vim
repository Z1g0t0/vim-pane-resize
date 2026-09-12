if exists('g:pane_resize')
	finish
endif
let g:pane_resize = 1

" ── User configuration ────────────────────────────────────────────────
let g:resize_enter = get(g:, 'resize_enter', '<C-r>')

let g:resize_keys = get(g:, 'resize_keys', {
	\ 'inc_left'        : 'h',
	\ 'inc_down'        : 'j',
	\ 'inc_up'          : 'k',
	\ 'inc_right'       : 'l',
	\ 'conquer_left'  	: '<C-h>',
	\ 'conquer_down'  	: '<C-j>',
	\ 'conquer_up'    	: '<C-k>',
	\ 'conquer_right' 	: '<C-l>',
	\ 'focus_left'    	: 'H',
	\ 'focus_down'    	: 'J',
	\ 'focus_up'      	: 'K',
	\ 'focus_right'   	: 'L',
	\ 'fair_share'		: '=',
	\ 'max_height'    	: '|',
	\ 'max_width'     	: '_',
	\ 'finish'        	: '<CR>',
	\ 'cancel'        	: 'q',
	\ 'cancel_esc'    	: '<Esc>',
	\ })

let g:resize_width  = get(g:, 'resize_width',  1)
let g:resize_height = get(g:, 'resize_height', 1)
let g:resize_leave  = get(g:, 'resize_leave',  1)   " honour <Esc> as cancel

" ── Internal helpers ──────────────────────────────────────────────────
" Convert a Vim key notation to the value getchar() actually returns.
function! s:Key2Char(key) abort
	" Prefer getcharstr() path when available (Vim 8.2.2957+ / Neovim)
	if exists('*getcharstr')
		" Create a temporary mapping so we can read the raw character
		execute 'nnoremap <silent> <Plug>(PaneResizeTmp) ' . a:key
		let char = ''
		" We use a small trick: feed the key and capture it
		" (fallback to classic numeric codes for maximum compatibility)
	endif

	" Classic numeric / string table (works everywhere)
	let map = {
		\ 'h'     : 104,
		\ 'j'     : 106,
		\ 'k'     : 107,
		\ 'l'     : 108,
		\ 'H'     : 72,
		\ 'J'     : 74,
		\ 'K'     : 75,
		\ 'L'     : 76,
		\ '='     : 61,
		\ '_'     : 95,
		\ '|'     : 124,
		\ 'q'     : 113,
		\ '<CR>'  : 13,
		\ '<Esc>' : 27,
		\ '<C-h>' : 8,
		\ '<C-j>' : 10,
		\ '<C-k>' : 11,
		\ '<C-l>' : 12,
		\ }

	return get(map, a:key, a:key)
endfunction

" Build the reverse lookup once
function! s:BuildKeymap() abort
	let s:keymap = {}
	for [action, key] in items(g:resize_keys)
		let char = s:Key2Char(key)
		let s:keymap[char] = action
	endfor
endfunction

call s:BuildKeymap()

function! s:IsEdge(dir) abort
	let cur = winnr()
	noautocmd execute 'wincmd' a:dir
	let edge = (cur == winnr())
	if !edge
		noautocmd execute cur 'wincmd w'
	endif
	return edge
endfunction

function! s:DoResize(dir, amount) abort
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
	if winnr('$') == 1 | return | endif
	execute 'wincmd' a:dir

	if a:dir ==# 'H' || a:dir ==# 'L'
		let target = max([1, &columns / 2])
		execute 'vertical resize' target
	else
		let usable = &lines - &cmdheight
					\ - (&laststatus  ? 1 : 0)
					\ - (&showtabline ? 1 : 0)
		let target = max([1, usable / 2])
		execute 'resize' target
	endif
endfunction

function! s:Resize() abort
	if winnr('$') == 1
		echo '[PaneResize]: Only one window.'
		return
	endif

	let l:restore  = winrestcmd()
	let l:hlsearch = &hlsearch
	set nohlsearch

	while 1
		redraw!
		echohl ModeMsg
		echo '<-RESIZE-MODE-ON->'
		echohl None

		let c = getchar()
		let action = get(s:keymap, c, '')

		if action ==# 'finish'
			break
		elseif action ==# 'cancel' || (action ==# 'cancel_esc' && g:resize_leave)
			execute l:restore
			break

		elseif action ==# 'inc_left'
			call s:DoResize('h', g:resize_width)
		elseif action ==# 'inc_right'
			call s:DoResize('l', g:resize_width)
		elseif action ==# 'inc_down'
			call s:DoResize('j', g:resize_height)
		elseif action ==# 'inc_up'
			call s:DoResize('k', g:resize_height)

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

		elseif action ==# 'equal'
			wincmd =
		elseif action ==# 'max_height'
			wincmd _
		elseif action ==# 'max_width'
			wincmd |
		endif
	endwhile

	let &hlsearch = l:hlsearch
	redraw!
	echo ''
	echon "\r"
endfunction

if !empty(g:resize_enter)
	execute 'nnoremap' g:resize_enter ':call <SID>Resize()<CR>'
endif
command! Resize call s:Resize()