if exists('g:pane_resize')
	finish
endif
let g:pane_resize = 1

" Configurable
let g:resize_enter  = get(g:, 'resize_enter',  '<C-r>')
let g:resize_width  = get(g:, 'resize_width',  1)   " columns
let g:resize_height = get(g:, 'resize_height', 1)   " lines
let g:resize_leave  = get(g:, 'resize_leave',  1)   " 1 = Esc cancels

if !empty(g:resize_enter)
	execute 'nnoremap' g:resize_enter ':call <SID>Resize()<CR>'
endif
command! Resize call s:Resize()

" ── helper: conquer (move to edge + take half the screen) ──────────────
function! s:Conquer(dir) abort
	" dir is 'H', 'J', 'K' or 'L'
	if winnr('$') == 1
		return
	endif

	" Move current window to the requested edge
	execute 'wincmd' a:dir

	if a:dir ==# 'H' || a:dir ==# 'L'
		" half of the full width
		let target = max([1, &columns / 2])
		execute 'vertical resize' target
	else
		" half of the *usable* height (exclude cmdheight + status/tab line)
		let usable = &lines - &cmdheight
					\ - (&laststatus  ? 1 : 0)
					\ - (&showtabline ? 1 : 0)
		let target = max([1, usable / 2])
		execute 'resize' target
	endif
endfunction

function! s:Resize() abort
	if winnr('$') == 1
		echo 'PaneResize: Only one window – nothing to resize'
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

		" ── finish / cancel ────────────────────────────────────────
		if c == 13                                          " <CR> = Confirm
			break
		elseif c == 113 || (g:resize_leave && c == 27)      " q or Esc = Cancel
			execute l:restore
			break

		" ── incremental resize ─────────────────────────────────────
		elseif c == 104                                     " h
			execute 'vertical resize -' . g:resize_width
		elseif c == 108                                     " l
			execute 'vertical resize +' . g:resize_width
		elseif c == 106                                     " j
			execute 'resize +' . g:resize_height
		elseif c == 107                                     " k
			execute 'resize -' . g:resize_height

		elseif c == 72                                      " <C-h>
			wincmd h                                               
		elseif c == 74                                      " <C-j>
			wincmd j                                               
		elseif c == 75                                      " <C-k>
			wincmd k                                               
		elseif c == 76                                      " <C-l>
			wincmd l

		elseif c == 8                                       
			call s:Conquer('H')
		elseif c == 10                                      
			call s:Conquer('J')
		elseif c == 11                                      
			call s:Conquer('K')
		elseif c == 12                                      
			call s:Conquer('L')

		elseif c == 61                                      " =
			wincmd =
		elseif c == 95                                      " _
			wincmd _
		elseif c == 124                                     " |
			wincmd |
		endif
	endwhile

	let &hlsearch = l:hlsearch
	redraw!
	echo ''
	echon "\r"
endfunction