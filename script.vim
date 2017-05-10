augroup quick_search
  autocmd CursorMoved,InsertLeave,ColorScheme * call s:highlight_search()
augroup END

let s:so = &so " Scroll number, used for fixing a bug

" Called every time a movement is made
function! s:highlight_search()
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    " Handle unhighlighting on every movement
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    if !exists('s:ids_to_unhighlight')
        let s:ids_to_unhighlight = []
    endif
    call s:unhighlight_line(s:ids_to_unhighlight)
    let s:ids_to_unhighlight = []
    let l:curr_line = line('.')

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    " Take care of current cursor position to top of screen
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    let l:first_visible_line = line("w0")
    let s:patt_dict_to_top = {}
    call s:get_patterns_from_cursor_to_beginning() " Don't highlight to beginning of first line
    for line_num in reverse(range(l:first_visible_line, l:curr_line-1))
        let l:reversed_line = s:reverse_string(getline(line_num))
        let [s:patt_dict_to_top, l:line_patts] = s:get_search_patterns(l:reversed_line, s:patt_dict_to_top)
        let l:reversed_list = []
        " Reverse every result
        for line_patt in l:line_patts
            call add(l:reversed_list, s:reverse_string(line_patt))
        endfor
        call s:apply_highlights(line_num, l:reversed_list)
    endfor

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    " Take care of current cursor position to bottom of screen
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    let s:patt_dict_to_bottom = {}
    call s:get_patterns_from_cursor_to_end() " Don't highlight to end of first line
    if l:curr_line > line('w$') " Solves a bug on fast scrolls down. This shouldn't be needed 
        let l:last_visible_line = l:curr_line + s:so
    else
        let l:last_visible_line = line('w$')
    endif
    for line_num in range(l:curr_line+1, l:last_visible_line)
        let [s:patt_dict_to_bottom, l:line_patts] = s:get_search_patterns(getline(line_num), s:patt_dict_to_bottom)
        call s:apply_highlights(line_num, l:line_patts)
    endfor
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Reverse a string
function! s:reverse_string(string)
    return join(reverse(split(a:string, '.\zs')), '')
endfunction

function! s:get_patterns_from_cursor_to_beginning()
    let l:rev_line_slice = s:reverse_string(getline(line('.'))[:col('.')-2])
    let [s:patt_dict_to_top, line_patts] = s:get_search_patterns(l:rev_line_slice, s:patt_dict_to_top)
endfunction

function! s:get_patterns_from_cursor_to_end()
    let [s:patt_dict_to_bottom, line_patts] = s:get_search_patterns(getline(line('.'))[col('.'):], s:patt_dict_to_bottom)
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Pattern algorithms
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Given a list of words split by white space and a dict of patterns,
" find the minimal substrings of each word that don't match any
" of the patterns in dict, and add them to the dict
function! s:get_search_patterns(line_string, patt_dict)
    let substrings = []
    let patt_dict = a:patt_dict
    let line = split(a:line_string)
    for word in line
        let [slice_min, min_len, patt_dict] = s:get_word_patterns(word, patt_dict, '', 1/0)
        call add(substrings, slice_min)
    endfor
    return [patt_dict, substrings]
endfunction

" This should be an optimal way of getting patterns from words.
" At least, algorithmically optimal, maybe not syntactically
function! s:get_word_patterns(word, patt_dict, ...)
    let min_string = a:1
    let min_len = a:2
    if empty(a:word)
        return [min_string, min_len, a:patt_dict]
    endif
    if !has_key(a:patt_dict, a:word)
        let a:patt_dict[a:word] = 1
        if len(a:word) < min_len
            let min_len = len(a:word)
            let min_string = a:word
        endif
        let [min_string1, min_len1, dict1] = s:get_word_patterns(a:word[1:], a:patt_dict, min_string, min_len)
        let [min_string2, min_len2, dict2] = s:get_word_patterns(a:word[:-2], a:patt_dict, min_string, min_len)
        if min_len1 < min_len2 " Return the smaller string's related values
            return [min_string1, min_len1, dict1]
        else
            return [min_string2, min_len2, dict2]
        endif
    endif
    return [min_string, min_len, a:patt_dict]
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Colors
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Unhighlight the search patterns
function! s:unhighlight_line(match_ids)
    for id in a:match_ids
        call matchdelete(id)
    endfor
endfunction

" Simplified version of quickscope's similar function
function! s:set_default_color(co_gui, co_256, co_16)
  let term = s:get_term()
  if term ==# 'gui'
    let color = a:co_gui
  else
    if &t_Co > 255
      let color = a:co_256
    else
      let color = a:co_16
    endif
  endif
  return color
endfunction

" Detect if the running instance of Vim acts as a GUI or terminal.
function! s:get_term()
  if has('gui_running') || (has('nvim') && $NVIM_TUI_ENABLE_TRUE_COLOR)
    let term = 'gui'
  else
    let term ='cterm'
  endif

  return term
endfunction

" Set or append to a custom highlight group.
function! s:add_to_highlight_group(group, attr, color)
  if a:color != -1 && a:color != ""
    execute printf("highlight %s %s%s=%s", a:group, s:get_term(), a:attr, a:color)
  endif     
endfunction

" Set the colors used for highlighting.
function! s:set_highlight_colors()
  " Priority for overruling other highlight matches.
  let s:priority = 1

  " Highlight group marking first appearance of characters in a line.
  let s:hi_group_primary = 'QuickSearchPrimary'
  let s:hi_group_cursor = 'QuickSearchCursor'

  " Set primary color to lime green
  let s:primary_highlight_color = s:set_default_color('#afff5f', 155, 10)

  call s:add_to_highlight_group(s:hi_group_primary, '', 'underline')
  call s:add_to_highlight_group(s:hi_group_primary, 'fg', s:primary_highlight_color)
  execute printf("highlight link %s Cursor", s:hi_group_cursor)
endfunction
call s:set_highlight_colors()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Main drawing function
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:apply_highlights(line_num, line_patts)
  for line_patt in a:line_patts
    if !empty(line_patt)
      let unmatch_id = matchadd(s:hi_group_primary, '\V\%' . a:line_num . 'l\^\.\{-}\zs' . line_patt, s:priority)
      call add(s:ids_to_unhighlight, unmatch_id)
    endif
  endfor
endfunction

" " Given a list of words split by white space and a dict of patterns,
" " find the minimal substrings of each word that don't match any
" " of the patterns in dict, and add them to the dict
" function! s:get_line_search_patterns(line_num, patt_dict)
"     let substrings = []
"     let line = split(getline(a:line_num))
"     for word in line
"         let word_len = 1/0 " This is the highest int value in vimscript LOL
"         let slice_min = ''
"         for ind_start in range(len(word))
"             for ind_end in range(ind_start+1, len(word))
"                 let word_slice = word[ind_start:ind_end-1]
"                 if !has_key(a:patt_dict, word_slice)
"                     let a:patt_dict[word_slice] = 1
"                     if len(word_slice) < word_len
"                         let slice_min = word_slice
"                         let word_len = len(word_slice)
"                     endif
"                 endif
"             endfor
"         endfor
"         call add(substrings, slice_min)
"     endfor
"     return [a:patt_dict, substrings]
" endfunction
