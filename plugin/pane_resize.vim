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

function! s:Resize() abort
	if winnr('$') == 1
		echo 'Only one window – nothing to resize'
		return
	endif

	let l:restore  = winrestcmd()
	let l:hlsearch = &hlsearch
	set nohlsearch

	while 1
		" Force a clean redraw *before* showing the message.
		" This prevents the cmdline from accumulating lines and
		" clears border artifacts from the previous resize.
		redraw
		echohl ModeMsg
		echo '[Resize]'
		echohl None

		let c = getchar()

		" Keep current sizes
		if c == 13                          " <CR>
			break

		" Restore original layout
		elseif c == 113 || (g:resize_leave && c == 27)   " q or Esc
			execute l:restore
			break

		" Resize current window
		elseif c == 104                     " h
			execute 'vertical resize -' . g:resize_width
		elseif c == 108                     " l
			execute 'vertical resize +' . g:resize_width
		elseif c == 106                     " j
			execute 'resize +' . g:resize_height
		elseif c == 107                     " k
			execute 'resize -' . g:resize_height

		" Convenience
		elseif c == 61                      " =
			wincmd =
		elseif c == 95                      " _
			wincmd _
		elseif c == 124                     " |
			wincmd |
		endif
	endwhile

	" Clean exit: restore hlsearch and clear the mode message
	let &hlsearch = l:hlsearch
	redraw
	echo ''
endfunction