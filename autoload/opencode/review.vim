" autoload/opencode/review.vim - Code Review Module
" Uses Agent.Review for AI-powered code review

let s:review_buffer = -1
let s:review_window = -1

" Initialize review module
def opencode#review#init(): void
enddef

" Review current file
def opencode#review#review_file(): void
  let filepath = expand('%:p')
  
  if empty(filepath)
    echoerr 'No file to review'
    return
  endif
  
  let content = join(getline(1, '$'), '\n')
  
  call s:request_review('Review this entire file:', content, filepath)
enddef

" Review code under cursor (selected lines)
def opencode#review#review_selection(): void
  let selected = s:get_selected_text()
  
  if empty(selected)
    echo 'No code selected. Select lines in visual mode and try again.'
    return
  endif
  
  call s:request_review('Review this code selection:', selected, 'selection')
enddef

" Review function under cursor
def opencode#review#review_function(): void
  let func_name = s:get_function_under_cursor()
  
  if empty(func_name)
    echo 'No function found under cursor'
    return
  endif
  
  let content = 'Review this function:\n\n' .. func_name
  
  call s:request_review('Review this function:', content, 'function')
enddef

" Request review from Opencode
def s:request_review(context: string, code: string, label: string): void
  " Ensure we have a session
  if empty(opencode#api#get_session_id())
    let result = opencode#api#create_session('Vim Review')
    if !result.success
      echoerr 'Failed to create session: ' .. result.error
      return
    endif
  endif
  
  let model = opencode#models#get_active()
  let session_id = opencode#api#get_session_id()
  
  let prompt = context .. "\n\n```\n" .. code .. "\n```\n\nProvide a code review with:\n1. Summary of what the code does\n2. Potential issues or bugs\n3. Suggestions for improvement\n4. Code quality score (1-10)"
  
  echo 'Requesting code review...'
  
  let result = opencode#api#send_message(session_id, prompt, 'Agent.Review', model)
  
  if result.success
    call s:show_review_result(result.parts, label)
  else
    echoerr 'Review failed: ' .. result.error
  endif
enddef

" Show review results in a new window
def s:show_review_result(parts: list<dict<any>>, label: string): void
  " Create review buffer
  if bufexists(s:review_buffer)
    exec s:review_buffer .. 'bw!'
  endif
  
  vertical topleft new
  setlocal buftype=nofile
  setlocal bufhidden=delete
  setlocal noswapfile
  setlocal nowrap
  setlocal modifiable
  
  let s:review_buffer = bufnr('%')
  let s:review_window = win_getid()
  
  setlocal filetype=opencode-review
  setlocal nonumber
  setlocal norelativenumber
  
  if exists('&winbar')
    set winbar=Opencode\ Review
  endif
  
  " Parse response
  let review_text = ''
  for part in parts
    if get(part, 'type', '') ==# 'text'
      let review_text ..= get(part, 'text', '')
    endif
  endfor
  
  " Format output
  call append('$', 'Code Review: ' .. label)
  call append('$', '═' .. repeat('═', strdisplaywidth(label) + 13))
  call append('$', '')
  call append('$', review_text)
  call append('$', '')
  call append('$', '─' .. repeat('─', 60))
  call append('$', 'Press q or <Esc> to close')
  
  normal! G$
  
  " Setup mappings
  nnoremap <buffer> <Esc> :bw!<CR>
  nnoremap <buffer> q :bw!<CR>
  
  setlocal nomodifiable
enddef

" Get selected text in visual mode
def s:get_selected_text(): string
  let reg = getreg('"')
  let regtype = getregtype('"')
  
  normal! gv"ay
  
  let selected = getreg('"')
  
  call setreg('"', reg, regtype)
  
  return selected
enddef

" Get function under cursor
def s:get_function_under_cursor(): string
  let line_num = line('.')
  let lines = getline(1, '$')
  
  " Find function start
  let func_start = line_num
  while func_start > 1
    let line = lines[func_start - 1]
    if line =~# '^\s*\(function\|def\|func\)\s'
      break
    endif
    let func_start -= 1
  endwhile
  
  " Find function end
  let func_end = line_num
  while func_end < len(lines)
    let line = lines[func_end - 1]
    if line =~# '^\s*endfunction\|enddef\|}$'
      break
    endif
    let func_end += 1
  endwhile
  
  if func_start >= func_end
    return ''
  endif
  
  return join(lines[func_start - 1 : func_end - 1], '\n')
enddef

" Review recent changes (git diff)
def opencode#review#review_changes(): void
  let temp = tempname()
  
  call system('git diff --no-color > ' .. temp)
  
  if !filereadable(temp)
    echoerr 'No git changes found'
    return
  endif
  
  let diff_content = join(readfile(temp), '\n')
  
  if empty(diff_content)
    echo 'No changes to review'
    return
  endif
  
  call s:request_review('Review these git changes:', diff_content, 'git diff')
enddef
