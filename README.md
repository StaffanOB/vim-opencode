# Opencode for VIM

AI-powered code completion, chat, and code review for Vim 9.0+. Connects to a running Opencode server to access 75+ LLM providers.

## Features

- **Intelligent Code Completion** - Uses `Agent.Complete` for context-aware suggestions
- **Interactive Chat** - Persistent sessions with conversation history
- **AI Code Review** - Uses `Agent.Review` for comprehensive code analysis
- **Model Selection** - Browse and select from Opencode's configured models
- **Git Integration** - Review changes, diff views for accepting suggestions

## Requirements

- Vim 9.0 or later
- curl command-line tool
- Opencode server running on port 4096

## Installation

### 1. Install Opencode CLI

```bash
# Install Opencode
curl -L https://opencode.ai/install | sh
```

### 2. Configure Providers

Start Opencode and configure your AI providers:

```bash
opencode
```

In the Opencode TUI:
```
/connect anthropic   # Connect to Anthropic (or any provider)
/models              # Browse and select models
/quit                # Exit TUI
```

### 3. Start Opencode Server

```bash
# Start the HTTP server (runs on port 4096 by default)
opencode serve
```

### 4. Install Vim Plugin

Using vim-plug in your `.vimrc`:

```vim
Plug 'anomalyco/opencode.vim'
```

Then run `:PlugInstall`

Using packadd:

```bash
mkdir -p ~/.vim/pack/opencode/start
cd ~/.vim/pack/opencode/start
git clone https://github.com/anomalyco/opencode.vim.git
```

Add to `.vimrc`:

```vim
packadd! opencode.vim
```

Manual installation:

```bash
cp -r autoload plugin doc ~/.vim/
vim -u NONE -c "helptags doc/" -c "qa!"
```

## Configuration

Add to your `.vimrc`:

```vim
" Server connection (default: 127.0.0.1:4096)
let g:opencode_host = '127.0.0.1'
let g:opencode_port = 4096

" Model selection (empty = use Opencode's default)
let g:opencode_model = ''

" Reuse sessions (default: 1)
let g:opencode_reuse_session = 1

" Key mappings
let g:opencode_completion_key = '<Tab>'
let g:opencode_chat_key = '<C-x>'
let g:opencode_review_key = '<Leader>cr'

" Debug mode
let g:opencode_debug = 0
```

## Usage

### Model Selection

Browse and select from your configured models:

```vim
:OpencodeModels
```

This shows a completion picker with all available models. Your selection is saved to vimrc automatically.

To use Opencode's default model, leave `g:opencode_model` empty.

### Code Completion

1. Start typing code in any buffer
2. Press `<Tab>` to trigger AI completion
3. Select from the dropdown menu
4. Press `<Enter>` to accept

Manual trigger:

```vim
:OpencodeComplete
```

### Chat Interface

Open an interactive chat session:

```vim
:OpencodeChat
```

In the chat buffer:
- `<Enter>` - Send message
- `<C-Enter>` - Send with selected code context
- `q` or `<Esc>` - Close chat

### Code Review

Review the current file:

```vim
:OpencodeReview
```

Review selected code (visual mode):
```vim
:OpencodeReviewSelection
```

Review shows:
- Summary of code functionality
- Potential issues or bugs
- Suggestions for improvement
- Code quality score (1-10)

### Health Check

Verify your setup:

```vim
:OpencodeHealth
:OpencodeConnect
```

### Reload Plugin

During development:

```vim
:OpencodeReload
```

## Key Mappings

| Mapping | Action |
|---------|--------|
| `<Tab>` | Trigger code completion |
| `<C-x>` | Open chat interface |
| `<Leader>cr` | Review current file |

Custom mappings:

```vim
" Change completion key
let g:opencode_completion_key = '<C-Space>'
imap <C-Space> <Plug>(opencode-completion)

" Change chat key
nmap <M-c> <Plug>(opencode-chat)
imap <M-c> <Plug>(opencode-chat)
```

## Running Tests

### Run All Tests

```bash
vim -u NONE -c "set rtp+=." -c "source test/run.vim" -c "qa!"
```

### Run Single Test

```bash
vim -u NONE -c "set rtp+=." -c "source test/run.vim" -c "TestOne test/api.vimspec" -c "qa!"
```

### Lint Vim Script

```bash
vint .
```

## Project Structure

```
vim-opencode/
├── autoload/opencode/
│   ├── api.vim       # HTTP client, session management
│   ├── models.vim    # Model listing and selection
│   ├── completion.vim # Omnifunc, Agent.Complete
│   ├── chat.vim      # Chat interface, sessions
│   ├── review.vim    # Code review, Agent.Review
│   └── util.vim      # Utilities, health check
├── plugin/
│   └── opencode.vim  # Plugin initialization
├── doc/
│   └── opencode.txt  # Vim help documentation
├── test/
│   ├── run.vim       # Test runner
│   ├── completion.vimspec
│   └── api.vimspec
├── .opencode/
│   └── AGENTS.md     # Developer documentation
└── README.md         # This file
```

## Troubleshooting

### Plugin Not Loading

```vim
:echo g:loaded_opencode
" Should output 1
:OpencodeHealth
```

### Server Connection Failed

```bash
# Check server is running
curl http://127.0.0.1:4096/global/health
# Should return: {"healthy":true,"version":"..."}

# Start server if needed
opencode serve
```

### No Models Available

1. Configure providers in Opencode: `opencode` then `/connect`
2. Select models: `/models`
3. Refresh plugin: `:OpencodeReload`

### Completion Not Working

- Ensure you're in a code file (not help or empty buffer)
- Check `:OpencodeHealth` for diagnostics
- Verify curl is available: `which curl`

### Slow Responses

- Check your Opencode server and API provider latency
- Try a faster model in Opencode: `/models`

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Vim (Client)                             │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │ Completion  │  │ Chat Buffer  │  │ Model Selector     │  │
│  │ (Agent)     │  │ (Session)    │  │ (writes to vimrc)  │  │
│  └──────┬──────┘  └──────┬───────┘  └─────────┬──────────┘  │
│         │                │                    │              │
│         └────────────────┼────────────────────┘              │
│                          │                                   │
│              ┌───────────▼───────────┐                      │
│              │  autoload/opencode/   │                      │
│              │    api.vim            │                      │
│              │  (HTTP + Sessions)    │                      │
│              └───────────┬───────────┘                      │
│                          │                                   │
│              ┌───────────▼───────────┐                      │
│              │  Opencode Server      │                      │
│              │  (port 4096)          │                      │
│              │  - Agents: Complete   │                      │
│              │  - Agents: Review     │                      │
│              └───────────────────────┘                      │
└─────────────────────────────────────────────────────────────┘
```

## API Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/global/health` | GET | Check server status |
| `/config/providers` | GET | List configured models |
| `/session` | POST | Create new session |
| `/session/:id/init` | POST | Initialize with model |
| `/session/:id/message` | POST | Send message (completion/chat) |

## Development

### Quick Start

```bash
# Start Opencode server
opencode serve

# Edit plugin files
vim -O autoload/opencode/api.vim plugin/opencode.vim

# Reload and test
:OpencodeReload
:OpencodeHealth
```

### Running Tests

```bash
vim -u NONE -c "set rtp+=." -c "source test/run.vim" -c "qa!"
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Run lint and tests
5. Submit pull request

## Support

- Issues: https://github.com/anomalyco/opencode.vim/issues
- Wiki: https://github.com/anomalyco/opencode.vim/wiki
