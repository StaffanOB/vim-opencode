" autoload/opencode/api.vim - Opencode HTTP API Client
" Communicates with Opencode server (default port 4096)

let s:base_url = ''
let s:session_id = ''
let s:models_cache = []
let s:last_error = ''
let s:server_version = ''

" Initialize API module
def opencode#api#init(): void
  s:base_url = 'http://' .. g:opencode_host .. ':' .. g:opencode_port
  call s:detect_server()
enddef

" Detect server availability
def s:detect_server(): dict<any>
  let response = s:http_get('/global/health')
  if response.success
    let s:server_version = get(response.data, 'version', 'unknown')
    return {'success': v:true, 'version': s:server_version}
  endif
  return {'success': v:false, 'error': 'Opencode server not found at ' .. s:base_url}
enddef

" Check if server is running
def opencode#api#is_connected(): bool
  let response = s:http_get('/global/health')
  return response.success
enddef

" Get server info
def opencode#api#get_server_info(): dict<any>
  return {
    'url': s:base_url,
    'version': s:server_version,
    'connected': opencode#api#is_connected()
  }
enddef

" Get list of configured models from Opencode
def opencode#api#get_models(): list<dict<any>>
  if len(s:models_cache) > 0
    return s:models_cache
  endif

  let response = s:http_get('/config/providers')
  if !response.success
    let s:last_error = response.error
    return []
  endif

  let models = []
  let providers = get(response.data, 'providers', {})
  
  for provider_id in keys(providers)
    let provider = providers[provider_id]
    let provider_models = get(provider, 'models', {})
    let provider_name = get(provider, 'name', provider_id)
    
    for model_id in keys(provider_models)
      let model_config = provider_models[model_id]
      let model_name = get(model_config, 'name', model_id)
      
      add(models, {
        'id': provider_id .. '/' .. model_id,
        'provider': provider_id,
        'provider_name': provider_name,
        'model_id': model_id,
        'name': model_name,
        'limit': get(model_config, 'limit', {})
      })
    endfor
  endfor

  let s:models_cache = models
  return models
enddef

" Create a new session
def opencode#api#create_session(title: string = ''): dict<any>
  let payload = {}
  if !empty(title)
    let payload.title = title
  endif

  let response = s:http_post('/session', payload)
  if response.success
    let s:session_id = get(response.data, 'id', '')
    return {'success': v:true, 'session_id': s:session_id}
  endif
  
  let s:last_error = get(response, 'error', 'Failed to create session')
  return {'success': v:false, 'error': s:last_error}
enddef

" Initialize session with optional model
def opencode#api#init_session(session_id: string, message_id: string = '', provider_id: string = '', model_id: string = ''): dict<any>
  let payload = {}
  if !empty(message_id)
    let payload.messageID = message_id
  endif
  if !empty(provider_id)
    let payload.providerID = provider_id
  endif
  if !empty(model_id)
    let payload.modelID = model_id
  endif

  let url = '/session/' .. session_id .. '/init'
  let response = s:http_post(url, payload)
  
  if response.success
    return {'success': v:true, 'data': response.data}
  endif
  
  return {'success': v:false, 'error': get(response, 'error', 'Init failed')}
enddef

" Send message to session
def opencode#api#send_message(session_id: string, message: string, agent: string = '', model: string = ''): dict<any>
  let parts = [{'type': 'text', 'text': message}]
  
  let payload = {'parts': parts}
  
  if !empty(agent)
    let payload.agent = agent
  endif
  
  if !empty(model)
    let payload.model = model
  endif

  let url = '/session/' .. session_id .. '/message'
  let response = s:http_post(url, payload)
  
  if response.success
    return {
      'success': v:true,
      'message': get(response.data, 'info', {}),
      'parts': get(response.data, 'parts', [])
    }
  endif
  
  let s:last_error = get(response, 'error', 'Message failed')
  return {'success': v:false, 'error': s:last_error}
enddef

" Get messages from session
def opencode#api#get_messages(session_id: string, limit: number = 50): dict<any>
  let url = '/session/' .. session_id .. '/message?limit=' .. limit
  let response = s:http_get(url)
  
  if response.success
    return {'success': v:true, 'messages': get(response.data, 'info', [])}
  endif
  
  return {'success': v:false, 'error': get(response, 'error', 'Failed to get messages')}
enddef

" Get session diff (for viewing changes)
def opencode#api#get_session_diff(session_id: string, message_id: string = ''): dict<any>
  let url = '/session/' .. session_id .. '/diff'
  if !empty(message_id)
    url ..= '?messageID=' .. message_id
  endif
  
  let response = s:http_get(url)
  
  if response.success
    return {'success': v:true, 'diff': get(response.data, 'info', [])}
  endif
  
  return {'success': v:false, 'error': get(response, 'error', 'Failed to get diff')}
enddef

" Abort running session
def opencode#api#abort_session(session_id: string): dict<any>
  let url = '/session/' .. session_id .. '/abort'
  let response = s:http_post(url, {})
  
  return {'success': response.success}
enddef

" Get current session ID
def opencode#api#get_session_id(): string
  return s:session_id
enddef

" Set session ID (for reconnection)
def opencode#api#set_session_id(session_id: string): void
  let s:session_id = session_id
enddef

" Clear cached models (force refresh)
def opencode#api#clear_cache(): void
  let s:models_cache = []
enddef

" Get last error
def opencode#api#get_last_error(): string
  return s:last_error
enddef

" HTTP helper functions
def s:http_get(endpoint: string): dict<any>
  let url = s:base_url .. endpoint
  let temp = tempname()
  
  let cmd = ['curl', '-s', '-m', '10', '-o', temp, '-w', '%{http_code}', url]
  
  call job_start(cmd, {
    'close_cb': { ch -> s:on_curl_complete(ch, temp, v:none) }
  })
  
  sleep 100m
  
  if filereadable(temp)
    let body = join(readfile(temp), '')
    let status = str2nr(join(readfile(temp), ''))
    
    try
      let data = json_decode(body)
      return {'success': v:true, 'data': data, 'status': status}
    catch
      return {'success': v:false, 'error': 'JSON parse error', 'body': body}
    endtry
  endif
  
  return {'success': v:false, 'error': 'Request failed'}
enddef

def s:http_post(endpoint: string, payload: dict<any>): dict<any>
  let url = s:base_url .. endpoint
  let temp = tempname()
  let json_payload = json_encode(payload)
  
  let cmd = [
    'curl', '-s', '-m', '30',
    '-X', 'POST',
    '-H', 'Content-Type: application/json',
    '-d', json_payload,
    '-o', temp,
    '-w', '%{http_code}',
    url
  ]
  
  call job_start(cmd, {
    'close_cb': { ch -> s:on_curl_complete(ch, temp, v:none) }
  })
  
  sleep 150m
  
  if filereadable(temp)
    let lines = readfile(temp)
    if len(lines) > 0
      let status = str2nr(lines[-1])
      let body = join(lines[0:-2], '')
    else
      let status = 0
      let body = ''
    endif
    
    if status >= 200 && status < 300
      if empty(body)
        return {'success': v:true, 'data': {}, 'status': status}
      endif
      try
        let data = json_decode(body)
        return {'success': v:true, 'data': data, 'status': status}
      catch
        return {'success': v:true, 'data': {}, 'status': status}
      endtry
    else
      return {'success': v:false, 'error': 'HTTP ' .. status, 'status': status}
    endif
  endif
  
  return {'success': v:false, 'error': 'Request timeout'}
enddef

def s:on_curl_complete(ch: channel, temp: string, callback: any): void
enddef

" Async message sending with callback
def opencode#api#send_message_async(session_id: string, message: string, callback: func, agent: string = ''): void
  let result = opencode#api#send_message(session_id, message, agent)
  if result.success
    call call(callback, [result])
  endif
enddef
