```
" ============================================
" ~/.vimrc (Programming + Shell/Config focused)
" - No relative number
" - Syntax highlight + filetype plugins enabled
" ============================================

" ---------- 基本模式 ----------
set nocompatible              " 用 Vim 的現代行為，不相容舊 vi（避免怪異預設）
set encoding=utf-8            " Vim 內部用 UTF-8（中文/符號不亂碼）
set fileencoding=utf-8        " 寫出檔案用 UTF-8（跨平台比較穩）

set hidden                    " 允許切 buffer 不強制存檔（寫程式很常用）
set autoread                  " 外部檔案有變動時自動偵測（配合 git/生成檔）
set updatetime=300            " 觸發 CursorHold 等事件更快（對某些插件/提示有幫助）

" ---------- 顯示/視覺（偏程式碼閱讀） ----------
set number                    " 顯示行號（debug/看錯誤行很必要）
set cursorline                " 高亮目前行（長檔案不容易看錯行）
set showcmd                   " 顯示你正在按的指令（減少誤操作）
set ruler                     " 顯示游標位置（行/列）
set laststatus=2              " 永遠顯示狀態列（看檔名、格式、位置）

set nowrap                    " 不自動折行（程式碼保持原樣，避免視覺誤判）
set scrolloff=5               " 游標上下保留 5 行緩衝（閱讀更舒服）
set sidescrolloff=3           " 左右捲動保留緩衝（長行 config 有用）

" 顏色：不指定主題，但告訴 Vim 可用更多色（若終端支援）
set termguicolors             " 24-bit color（有支援就更好看；不支援也通常沒事）

" ---------- 語法/檔案型態（你指定要開） ----------
syntax on                     " 語法上色（寫程式必開）
filetype plugin indent on     " 依檔案類型啟用：
                              " - plugin：檔案型態小功能（例如 ftplugin）
                              " - indent：使用該語言的縮排規則

" ---------- Colorscheme (traditional) ----------
set termguicolors          " 若終端支援，顏色更平滑；不支援也沒事
colorscheme desert

" ---------- 搜尋（寫程式常用） ----------
set ignorecase                " 預設搜尋不分大小寫（打更快）
set smartcase                 " 但若你輸入大寫，就改成分大小寫（更精準）
set incsearch                 " 邊打邊找（更快定位）
set hlsearch                  " 高亮搜尋結果（看清楚命中）
nnoremap <silent> <Esc><Esc> :nohlsearch<CR>  " 連按 ESC 清掉高亮（不刺眼）

" ---------- 縮排/空白（偏 shell/config 友善） ----------
set expandtab                 " Tab 轉空白：避免不同環境 Tab 寬度不一致
set tabstop=2                 " 顯示 Tab 等同 2 格（符合很多 config/yaml 風格）
set shiftwidth=2              " >> 或自動縮排一次用 2 格
set softtabstop=2             " 按 Tab 的編輯手感也是 2 格
set autoindent                " 新行延續前一行縮排（寫程式必備）
set smartindent               " 對 C-like 語言做更聰明縮排（有些語言有效）
set shiftround                " 縮排對齊到 shiftwidth 的倍數（更整齊）

set list                      " 顯示不可見字元（寫 config 抓尾端空白很重要）
set listchars=tab:»·,trail:·,extends:>,precedes:<  " tab/尾空白/長行提示符

set formatoptions-=cro        " 取消自動加註解/自動換行（寫程式避免被 Vim 自作主張）

" ---------- 括號/結構（寫程式很需要） ----------
set showmatch                 " 括號配對提示（括號多的語言很有用）
set matchtime=1               " 配對提示停留時間（短一點，不干擾）

" ---------- 介面與操作（偏效率、但不花俏） ----------
set wildmenu                  " 命令列補全選單（:e :b :set 很順）
set wildmode=longest:full,full " 補全策略：先補到最長共同，再列出選單

set backspace=indent,eol,start " backspace 可正常跨縮排/行尾/行首（符合現代直覺）
set confirm                   " 關檔/改檔遇到未存會詢問（防呆）

" ---------- 剪貼簿（桌面 Linux 很好用） ----------
" 若你在圖形桌面，這行可讓 Vim 跟系統剪貼簿互通（複製貼上不麻煩）
" 若你常在純 SSH、沒有剪貼簿，可註解掉避免某些環境怪異
set clipboard=unnamedplus

" ---------- Undo（救命功能：關 Vim 也能復原） ----------
set undofile                  " 開啟 persistent undo（強烈建議）
set undodir=~/.vim/undo        " undo 檔案集中放（乾淨、可管理）
if !isdirectory(expand("~/.vim/undo"))
  silent !mkdir -p ~/.vim/undo
endif

" ---------- 備份/交換檔（寫 config 時避免產生一堆 ~ 檔） ----------
set nobackup                  " 不生成 file~
set nowritebackup             " 寫入時不做額外備份檔（避免某些服務讀到半成品）
set noswapfile                " 不建立 swap（若你很怕 crash 可改回 set swapfile）
                              " 註：你寫系統設定檔多、也常 sudo 編輯時，
                              "     swap 檔有時會造成權限/殘留困擾，所以這裡偏保守關掉

" ---------- Shell / Config 友善：快速重新載入 vimrc ----------
nnoremap <silent> <F5> :source $MYVIMRC<CR>:echo "vimrc reloaded"<CR>

" ---------- 建議的「寫 shell」品質提升（不強迫） ----------
" shell script 常見錯：Tab/尾空白/混雜 CRLF，list 模式已幫你抓
" 如果你想更嚴格：打開以下兩行（會讓一些文件更嚴格但更乾淨）
" set textwidth=0            " 不自動硬折行（程式碼/設定檔更安全）
" set colorcolumn=80         " 80 欄提示（寫 code 有用，但會多一條線）

" ---------- 最後：確保不使用相對行號 ----------
set norelativenumber

" ============================================
" End of ~/.vimrc
" ============================================
```
