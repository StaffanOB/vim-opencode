" autoload/opencode/util.vim - Utility Functions
" Shared helper functions for the plugin

" Health check command
def opencode#util#health_check(): void
  echo 'Opencode Plugin Health Check'
  echo '=============================='
  echo ''
  
  echo 'Plugin Status: ' .. (exists('g:loaded_opencode') ? 'Loaded' : 'Not loaded')
  echo 'Vim Version: ' .. v:version
  echo ''
  
  echo 'Configuration:'
  echo '  Server: ' .. g:opencode_host .. ':' .. g:opencode_port
  echo '  Model: ' .. (empty(g:opencode_model) ? '(default)' : g:opencode_model)
  echo '  Session Reuse: ' .. (g:opencode_reuse_session ? 'Yes' : 'No')
  echo ''
  
  echo 'Testing connection to Opencode server...'
  let result = opencode#api#is_connected()
  
  if result
    let server_info = opencode#api#get_server_info()
    echo '  Status: ONLINE'
    echo '  Version: ' .. server_info.version
    echo '  URL: ' .. server_info.url
    echo ''
    
    echo 'Models:'
    let models = opencode#models#get_all()
    if len(models) > 0
      echo '  Available: ' .. len(models) .. ' models'
      echo '  Selected: ' .. opencode#models#get_active()
    else
      echo '  Run :OpencodeConnect first'
    endif
  else
    echo '  Status: OFFLINE'
    echo ''
    echo 'Troubleshooting:'
    echo '  1. Start Opencode server: opencode serve'
    echo '  2. Check server is running on port ' .. g:opencode_port
    echo '  3. Try: curl http://' .. g:opencode_host .. ':' .. g:opencode_port .. '/global/health'
  endif
  
  echo ''
  echo 'Commands:'
  echo '  :OpencodeConnect - Test connection'
  echo '  :OpencodeModels  - Select model'
  echo '  :OpencodeChat    - Open chat'
  echo '  :OpencodeComplete - Trigger completion'
  echo '  :OpencodeReview  - Review code'
enddef

" Connection check
def opencode#util#connect_check(): void
  echo 'Connecting to Opencode server...'
  
  let result = opencode#api#is_connected()
  
  if result
    let server_info = opencode#api#get_server_info()
    echo 'Connected to ' .. server_info.url
    echo 'Version: ' .. server_info.version
    echo ''
    
    let models = opencode#models#get_all()
    echo 'Available models: ' .. len(models)
    
    if len(models) > 0 && empty(g:opencode_model)
      echo 'Use :OpencodeModels to select a model,'
      echo 'or let Opencode choose by default.'
    endif
  else
    echoerr 'Failed to connect to Opencode server at ' .. g:opencode_host .. ':' .. g:opencode_port
    echo 'Start the server with: opencode serve'
  endif
enddef

" Reload the plugin
def opencode#util#reload(): void
  echo 'Reloading Opencode plugin...'
  
  " Clear caches
  call opencode#api#clear_cache()
  
  " Reload autoload files
  for file in split(globpath(&rtp, 'autoload/opencode/*.vim'), '\n')
    exec 'source ' .. file
  endfor
  
  " Reload plugin
  let plugin_file = fnamemodify(resolve(expand('<sfile>')), ':h:h') .. '/plugin/opencode.vim'
  if filereadable(plugin_file)
    exec 'source ' .. plugin_file
  endif
  
  echo 'Opencode plugin reloaded!'
  call opencode#util#health_check()
enddef

" Get current code context around cursor
def opencode#util#get_context(extra_lines: number = 5): string
  let start = max([1, line('.') - extra_lines])
  let end = min([line('$'), line('.') + extra_lines])
  let lines = getline(start, end)
  return join(lines, "\n")
enddef

" Log debug message
def opencode#util#log(msg: string): void
  if exists('g:opencode_debug') && g:opencode_debug
    echo '[Opencode] ' .. a:msg
  endif
enddef

" Show notification
def opencode#util#notify(msg: string, level: string = 'info'): void
  if exists('*vim.notify')
    call vim.notify('[Opencode] ' .. a:msg, level)
  else
    if level == 'error'
      echoerr '[Opencode] ' .. a:msg
    elseif level == 'warning'
      echohl WarningMsg | echo '[Opencode] ' .. a:msg | echohl None
    else
      echo '[Opencode] ' .. a:msg
    endif
  endif
enddef

" Format API error
def opencode#util#format_error(error: string, context: string = ''): string
  let msg = '[Opencode Error] ' .. error
  if !empty(context)
    msg ..= '\nContext: ' .. context
  endif
  return msg
enddef

" Get selected code from visual mode
def opencode#util#get_selection(): string
  let reg = getreg('"')
  let regtype = getregtype('"')
  
  normal! gv"ay
  
  let selected = getreg('"')
  
  call setreg('"', reg, regtype)
  
  return selected
enddef

" Check if we're in a code buffer
def opencode#util#is_code_buffer(): bool
  let filetype = &filetype
  
  " Exclude non-code filetypes
  let excluded = ['help', 'qf', 'nerdtree', 'fugitive', 'git', 'markdown', 'txt', 'html', 'css']
  
  for type in excluded
    if filetype =~# type
      return v:false
    endif
  endfor
  
  return v:true
enddef

" Debounce function calls
def opencode#util#debounce(func: func, delay: number): func
  let timer = 0
  
  def debounced(...): any
    if timer != 0
      call timer_stop(timer)
    endif
    let timer = timer_start(a:delay, { -> call(a:func, a:000) })
    return ''
  enddef
  
  return debounced
enddef

" Get plugin version
def opencode#util#get_version(): string
  return '0.1.0'
enddef
