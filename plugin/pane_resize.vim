if exists('g:pane_resize')
	finish
endif
let g:pane_resize = 1

" Configurable keys (change these in your vimrc if you want)
let g:resize_enter 	= get(g:, 'resize_enter',	'<C-e>')
let g:resize_width 	= get(g:, 'resize_width',	5)   	" columns
let g:resize_height = get(g:, 'resize_height',	2)		" lines
let g:resize_leave 	= get(g:, 'resize_leave',  	1)   	" 1 = Esc also finishes

" Start mapping
if !empty(g:resize_enter)
	execute 'nnoremap' g:resize_enter ':call <SID>Resize()<CR>'
endif

command! Resize call s:Resize()

function! s:Resize() abort
	if winnr('$') == 1
		echo 'Only one window – nothing to resize'
		return
	endif

	" Capture the exact restore command *now*
	let l:restore = winrestcmd()
	let l:hlsearch = &hlsearch
	set nohlsearch

	echo '[resize mode]  h/j/k/l = resize   = = equalise   Enter = keep   q/Esc = cancel'

	while 1
		let c = getchar()

		" Finish (keep current sizes)
		if c == 13                                   " <CR>
			break

		" Cancel (restore original layout)
		elseif c == 113                              " q
					\ || (g:resize_leave && c == 27)  " Esc
			execute l:restore
			break

		" Resize
		elseif c == 104                              " h
			execute 'vertical resize -' . g:resize_width
		elseif c == 108                              " l
			execute 'vertical resize +' . g:resize_width
		elseif c == 106                              " j
			execute 'resize +' . g:resize_height
		elseif c == 107                              " k
			execute 'resize -' . g:resize_height

		" Optional extras
		elseif c == 61                               " =
			wincmd =
		elseif c == 95                               " _
			wincmd _
		elseif c == 124                              " |
			wincmd |
		endif

		" Re-echo the prompt so the message stays visible
		echo '[resize mode]  h/j/k/l = resize   = = equalise   Enter = keep   q/Esc = cancel'
	endwhile

	let &hlsearch = l:hlsearch
	echo ''
endfunction