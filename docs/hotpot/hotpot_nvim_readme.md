<!-- panvimdoc-ignore-start -->

# 🍲 Hotpot ![Github Tag Badge](https://img.shields.io/github/v/tag/rktjmp/hotpot.nvim) ![LuaRocks Release Badge](https://img.shields.io/luarocks/v/soup/hotpot.nvim)

> 把它带回家，扔进锅里，加入一些高汤和 Neovim……宝贝，你就有一锅炖好了！
>
> —— Fennel 程序员（大概）

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment

```
dP     dP             dP                       dP
88     88             88                       88
88aaaaa88a .d8888b. d8888P 88d888b. .d8888b. d8888P
88     88  88'  `88   88   88'  `88 88'  `88   88
88     88  88.  .88   88   88.  .88 88.  .88   88
dP     dP  `88888P'   dP   88Y888P' `88888P'   dP
                           88
                           dP

You take this home, throw it in a pot, add some
broth, some neovim...  baby, you got a stew going!

                   ~ Fennel Programmers (probably)
```

# Hotpot

-->

Hotpot 是一个 [Fennel](https://fennel-lang.org/) 编译器插件，用于 Neovim，
允许你使用 Fennel 编写 Neovim 的配置与插件。

# 版本 2

!!! important
  Hotpot 2 的配置与 1（亦即旧的 0 版本）不兼容。对于大多数用户，迁移过程应当比较简单，详见 [从版本 1 迁移](#migrating-from-version-1)。

  **对所有用户来说最显著的变化是：所有宏文件必须使用 `.fnlm` 扩展名。**

  如果你无法或不打算更新配置，可以将插件管理器固定在 `v1.0.0` 版本。

  2.x 简化了配置，改进了对诸如 `lsp` 等目录的支持，并增强了在多个项目目录中使用独立配置的能力。

  参见 [从版本 1 的更改](#changes-from-version-1)

!!! warning
  再次声明：对所有用户来说最显著的变化是 **所有宏文件必须使用 `.fnlm` 扩展名。**

# 要求

- 运行 Hotpot 需要 Neovim 0.11.6 及以上版本。
  - 编译后的输出可以在任何与你的代码兼容的 Neovim 版本上运行。
- ~~对括号的狂热崇拜（玩笑）~~

你可能还希望使用一个 LSP `$/progress` 通知渲染器，例如用于事件通知的 [fidget.nvim](https://github.com/j-hui/fidget.nvim)，或者启用 `verbose` 模式以获得更多输出信息。

# 安装

## 使用 `vim.pack` 安装

```lua
-- init.lua
vim.pack.add({
  {src = "https://github.com/rktjmp/hotpot.nvim",
   version = vim.version.range("^2.0.0")}
})
require("hotpot")
-- 大多数用户随后会 require 存放在类似 `fnl/config/init.fnl` 的配置模块...
require("config")
```

除非你只是用于插件开发，否则不要对 Hotpot 使用懒加载。Hotpot 在内部仅按需执行最小量的工作。希望通过 `vim.pack.add` 的选项表定制其行为的用户，请查看 [高级 `vim.pack` 配置](advanced-vim-pack-add-configuration.md)。**大多数用户应按上文所示安装。**

## 使用 Lazy.nvim 安装

<details>
<summary>Lazy.nvim</summary>

```lua
-- init.lua
local function ensure_installed(plugin, branch)
  local user, repo = string.match(plugin, "(.+)/(.+)")
  local repo_path = vim.fn.stdpath("data") .. "/lazy/" .. repo
  if not (vim.uv or vim.loop).fs_stat(repo_path) then
    vim.notify("Installing " .. plugin .. " " .. branch)
    local repo_url = "https://github.com/" .. plugin .. ".git"
    local out = vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "--branch=" .. branch,
      repo_url,
      repo_path
    })
    if vim.v.shell_error ~= 0 then
      vim.api.nvim_echo({
        { "克隆插件失败: " .. plugin .. ":\n", "ErrorMsg" },
        { out, "WarningMsg" },
        { "\n按任意键退出..." },
      }, true, {})
      vim.fn.getchar()
      os.exit(1)
    end
  end
  return repo_path
end

-- 以与 lazy.nvim 相同的方式安装 hotpot 到 Lazy 的插件目录。
local lazy_path = ensure_installed("folke/lazy.nvim", "stable")
local hotpot_path = ensure_installed("rktjmp/hotpot.nvim", "v2.0.0")
-- 按照 Lazy 的安装说明，但同时将 hotpot 加入 runtimepath。
vim.opt.runtimepath:prepend({hotpot_path, lazy_path})

-- 重要！使用 Lazy.nvim 时，必须在加载 Lazy.nvim 之前先 require hotpot 模块，
-- 以确保 hotpot 在 lazy.nvim 修改 Neovim 行为前已加载到内存中。
require("hotpot")

-- 大多数用户随后会 require 存放在类似 `fnl/config/init.fnl` 的配置模块...
require("config")
```

你还必须在 Lazy.nvim 的插件清单中包含 Hotpot，以便正确管理更新。建议不要对 Hotpot 使用懒加载。

```fennel
;; fnl/config/init.fnl

(let [lazy (require :lazy)
      api (require :hotpot.api)
      context (assert (api.context (vim.fn.stdpath :config)))]
  (lazy.setup
    ;; 在此定义你的包规范，这里只是一个示例。
    ;; 确保包含 hotpot：调用 `lazy.setup` 会影响 Lua 模块加载，可能导致 hotpot 在按需加载自身其他部分时出问题。
    {:spec [{:url "https://github.com/folke/lazy.nvim" :branch :stable}
            {:url "https://github.com/rktjmp/hotpot.nvim" :version "^2.0.0"}]
     ;; 必须在 `performance.rtp.paths` 中包含 hotpot 的输出目录！
     :performance {:rtp {:paths [(context.locate :destination)]}}}))

```

</details>

# 使用

## `~/.config/nvim`

就像任何 Lua 代码可以放在 `lua/**/*.lua` 中一样，你现在可以在
`fnl/**/*.fnl` 中放置 Fennel 代码并使用 `require` 加载。你可以按需添加
少量或大量的 Fennel。已有的 `lua/**/*.lua` 代码会照常工作，Lua 与 Fennel
模块可互操作。

你也可以将 `.fnl` 文件放在任何标准运行时目录中，例如 `lsp/`、`plugin/`
或 `ftplugin/`。

保存任何 `.fnl` 文件时，Hotpot 会同步生成或更新对应的 `.lua` 文件。

```fennel
;; ~/.config/nvim/fnl/my-config/hello.fnl
(print :hello)
```

```fennel
;; ~/.config/nvim/lsp/my-lang.fnl
(print :setup-some-lsp)
```

Hotpot 针对 Neovim 配置目录的默认设置会将编译生成的 `.lua` 文件存放在
单独位置以保持目录整洁，因此你通常不会在配置树中看到这些 `.lua` 文件。

有一个例外：**`.config/nvim/init.fnl` 始终会编译为 `.config/nvim/init.lua`。**

以上就是用 Fennel 编写配置所需了解的全部内容。你也可以查看 [命令]
(#commands) 以了解如何评估或编译 Fennel 片段（参见 `:Fnl`）或如何与
Hotpot 交互（参见 `:Hotpot`）。

如需调整 Hotpot 的行为（例如通知的呈现方式、是否将 `.lua` 文件
放回配置树、忽略某些文件或配置 Fennel 编译器），请参阅
[configuration](#configuration)。

要从自定义命令、按键或函数中与 Hotpot 交互，请参阅 [API](#api)。

<!-- panvimdoc-ignore-start -->

## 使用 `.fnlm` 扩展名作为宏文件

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment

## Macros

-->

!!! important
  Hotpot 要求用于 `import-macros` 的 Fennel 宏文件 **必须** 使用现代的
  `.fnlm` 扩展名。常规的 Fennel 模块（通过 `require` 加载）应使用 `.fnl`。

## 插件

要为插件启用 Fennel 的编译，你必须在插件目录根放置一个 `.hotpot.fnl`
文件。至少需要在该文件中指定 `schema` 和 `target` 键，如下所示。

```fennel
;; projects/my-plugin/.hotpot.fnl
{:schema :hotpot/2
 ;; 插件必须向用户分发 `.lua` 代码。
 ;; 将 `target` 设置为 `colocate` 会将生成的 `.lua` 文件保存在源码树中。
 ;; 对于插件，将 `target` 设置为 `cache` 是错误的。
 :target :colocate}
```

!!! tip
  在保存对 `.hotpot.fnl` 的修改前，可以考虑先运行 `:trust`，以避免
  以后被重复提示确认。

创建 `.hotpot.fnl` 文件后，打开任意 `.fnl` 文件并保存以触发构建，或使用
`sync` 命令手动触发构建（参见 [commands](#commands)）。

有关自定义 Hotpot 行为、忽略 `.fnl`/`.lua` 文件或配置 Fennel 编译器的
详细信息，请参阅 [configuration](#configuration)。

# 命令

使用 [`:Hotpot`](#hotpot) 与 Hotpot 交互，使用 [`:Fnl`](#fnl) 及其相关命令从缓冲区或命令行评估或编译 Fennel 代码。

## `:Hotpot`

`:Hotpot` 命令提供以下子命令：

- [`sync`](#hotpot-sync)：手动触发一次编译与清理循环。
- [`locate`](#hotpot-locate)：查找或打开文件的 `.lua` 或 `.fnl` 对应文件。
- [`watch`](#hotpot-watch)：启用或禁用保存时自动编译。
- [`fennel`](#hotpot-fennel)：将内置的 `fennel.lua` 更新为来自 [fennel-lang.org](https://fennel-lang.org) 的最新版本，或回滚到随 Hotpot 一起发布的版本。

### `:Hotpot sync`

同步给定上下文的 `.fnl` 与 `.lua` 文件。这与保存 `.fnl` 或 `.fnlm` 文件时触发的操作相同。

支持以下参数：

- `context=<path>`：设置命令的上下文，若未提供则使用当前工作目录。
- `force`：强制编译上下文中的所有文件，即便对应的 `.lua` 已是最新。
- `atomic`：允许在部分文件编译失败时仍写入已成功编译的文件。
- `verbose`：输出更多编译信息。

另请参阅由 [API](#api) 提供的 [context.sync](#context-sync-options-nil) 函数。

### `:Hotpot locate`

查找或打开对应文件，支持以下调用形式：

**`:Hotpot locate <path> -- <commands ...>`**

查找 `<path>` 的对应路径并将其追加到 `<commands ...>`，例如 `:Hotpot locate fnl/my-file.fnl -- vnew` 会在 `vnew` 窗口中打开对应的 `.lua` 文件。对于需要引用路径的命令（例如 `echo '%%'`），可以使用 `%%` 来替换为定位到的路径。

若未提供路径，则使用当前缓冲区路径，例如 `:Hotpot locate -- <commands ...>` 等同于 `:Hotpot locate % -- <commands ...>`。

**`:Hotpot locate <path>`**

打印对应路径；同样地，若未提供 `<path>`，则使用当前缓冲区路径。

另请参阅由 [API](#api) 提供的 [context.locate](#context-locate-string) 函数。

### `:Hotpot watch`

启用或禁用保存时自动编译行为。

支持以下（互斥）参数：

- `enable`：启用本次会话中所有上下文的保存时同步。
- `disable`：禁用本次会话中所有上下文的保存时同步。

### `:Hotpot fennel`

更新或回滚 `fennel.lua` 到来自 [fennel-lang.org](https://fennel-lang.org) 的最新版本或回退到随 Hotpot 发布的版本。

需要系统中安装 `curl`。

!!! important
  运行此操作存在一定风险：更新后的 Fennel 版本可能与 Hotpot 不兼容。除非 Fennel 的评估或编译 API 有重大变动，否则这种情况不太可能发生。如果某次发布仅增加新的语法形式（例如 `(accumulate ...)`），通常是安全的。

提供以下子命令：

#### `:Hotpot fennel version`

报告当前加载并使用的 Fennel 版本。

#### `:Hotpot fennel update`

支持以下参数：

- `url=<url>`：使用指定 URL 而不是自动从 [fennel-lang.org](https://fennel-lang.org) 查找最新版本。
- `force`：不询问是否更新，直接强制更新。

#### `:Hotpot fennel rollback`

删除下载的 Fennel 文件并改用 Hotpot 自带的版本。

## `:Fnl`

对命令行中提供的 Fennel 代码或当前缓冲区的范围执行操作，范围可通过命令行参数或选区指定。

你可以提供一个 `range`（例如 `:'<,'>Fnl`、`:%Fnl`）或 `source` 字符串（例如 `:Fnl (+ 1 1)`）；若同时提供，则以 `range` 优先。

该命令类似于 Neovim 内置的 `:lua` 命令，支持以下标志：

**`:Fnl`**

评估输入的范围或字符串。除非源代码本身有输出，否则不会输出任何内容。

**`:Fnl=`**

评估输入的范围或字符串，并用 `vim.print` 输出表达式的结果。

**`:Fnl-`**

将输入的范围或字符串编译并用 `vim.print` 输出编译结果。

注意：通过 `:Fnl-` 编译源码时 `allowedGlobals = false`，因为该命令常用于编译用于检查的小片段，在此场景下引用范围外变量很常见。与常规编译相比，这会导致对拼写错误或未知变量的警告减少。

## `:FnlEval`

` :Fnl=` 的别名。

## `:FnlCompile`

`:Fnl-` 的别名。

## `:Fnlfile {file.fnl}`

评估指定文件；同样支持 `:Fnlfile= file`（输出评估）和 `:Fnlfile- file`（输出编译）。

## `:source {file.fnl}`

对给定的 `.fnl` 文件执行 source 操作。参见 `:h :source`。

# 配置

Hotpot 的大部分行为以及 Fennel 编译器的配置通过放置在配置或插件根目录下的
`.hotpot.fnl` 文件来完成。Hotpot 与 Neovim 之间的一些特定集成可以通过
调用 `setup()` 函数来配置。

!!! tip
  对于大多数仅想用 Fennel 编写配置的用户，可以忽略本节并使用默认设置。

## `.hotpot.fnl`

Hotpot 的行为及 Fennel 编译器通过位于配置或插件目录根的 `.hotpot.fnl` 文件来
进行配置。

这些文件为该目录树内的操作定义了一个 `context`。各个上下文之间相互独立，仅
影响它们各自所在的树。

如果在你的 Neovim 配置目录中没有 `.hotpot.fnl` 文件，则会加载默认配置。插件
不同：插件必须包含 `.hotpot.fnl` 文件。

!!! tip
  在保存对 `.hotpot.fnl` 的更改前，可考虑先运行 `:trust`，以避免后续被频繁提示确认。

```fennel
;; .hotpot.fnl
{
 ;; 必需，字符串，有效值：hotpot/2
 ;; 描述表的预期 schema。
 :schema :hotpot/2

 ;; 必需，字符串，有效值：cache|colocate
 ;; 描述 lua 文件的目标位置。`cache` 将 lua 文件放在可被 neovim 加载的树外目录，
 ;; `colocate` 将 lua 文件放在源码树中，与对应的 fennel 文件并列。
 ;;
 ;; 当配置目录中不存在 `.hotpot.fnl` 时，目标默认为 :cache。你也可以通过添加
 ;; `.hotpot.fnl` 将其设置为 :colocate。
 ;; 注意：在切换目标时，用户有责任删除之前生成的 lua 文件。
 ;;
 ;; 对于插件，唯一有效的值是 `colocate`。
 :target :cache

 ;; 其余键均为可选。

 ;; 可选，布尔值
 ;; 如果为 true（默认），任何一次编译错误都会阻止写入更改。
 :atomic? true

 ;; 可选，布尔值
 ;; 如果为 true（默认：false），在每次成功编译后也输出消息，而不仅在出错时输出。
 :verbose? true

 ;; 可选，函数
 ;; 如果提供，所有已编译的 fennel 源会连同其相对于 `.hotpot.fnl` 的路径一并传入该函数，
 ;; 函数必须返回修改后的源代码。
 ;; 在使用编译与评估 API 时不会自动调用 transform。
 :transform (fn [src path] src)

 ;; 可选，字符串列表
 ;; 在执行编译与清理操作时要忽略的 glob 模式，相对于 `.hotpot.fnl` 文件。
 ;;
 ;; 与 `.lua` 模式匹配的文件永远不会被视为孤立文件并被删除。
 ;; 与 `.fnl` 模式匹配的文件永远不会被编译。
 ;; 与 `.fnlm` 模式匹配的文件在进行过时检查时不会被考虑。
 :ignore [:some/lib/**/*.lua :junk/*.fnl]

 ;; 可选，表
 ;; Fennel 编译器选项，直接传递给 `fennel.compile-string`。
 ;;
 ;; Hotpot 默认启用了严格的全局检查以防止引用未知或拼写错误的变量。要恢复
 ;; Fennel 的默认行为，可以将 `allowedGlobals` 设置为 `false`。
 ;;
 ;; 如果希望在宏中引用 `vim`，请设置 `:extra-compiler-env {: vim}`。
 ;;
 ;; 注意：`error-pinpoint` 始终被强制为 false，并且 `filename` 始终设置为正确的值。
 ;;
 ;; 详情请参阅 Fennel 官方 API 文档及其帮助信息。
 :compiler {:allowedGlobals (icollect [k _ (pairs _G)] k)
            :extra-compiler-env {: vim}
            :error-pinpoint false}
}
```

## `setup()`

在 require Hotpot 后调用 `setup({...})` 可以启用一些高级配置选项。如果你对默认
行为满意，则**无需**调用 `setup()`。

注意：你可以使用 `fennel-style` 或 `lua_style` 的键名风格。

**`sync-report-handler`**

用于覆盖默认 `sync` 事件上报器的函数。

*如果你提供该函数，则由你负责正确地输出编译错误信息。*

该函数接收 3 个参数：一个 `context` 对象、`report` 表与 `invocation-metadata` 表。
查看 `report` 表以了解可用字段。`invocation-metadata` 包含 `reason`，其可能值为
`command`、`autocommand` 或 `api`，表示触发 `sync` 事件的来源。

默认的处理器会优先生成 LSP 的 `$/progress` 消息；当 `verbose? = true` 时，会使用
`nvim_echo` 输出信息。

# API

Hotpot 提供了一组 API，用于编译和评估任意的 Fennel 代码，以及在项目中编译文件。所有交互均通过 `context` 对象完成。

## `context(path|nil)`

创建一个 `context` 对象。返回 `context` 或 `nil, error`。

其他所有的 API 操作都是通过该 `context` 对象执行的。

```fennel
(let [api (require :hotpot.api)
      ctx (api.context (vim.fn.stdpath :config))]
  (ctx.eval "(+ 1 1)"))
```

`path` 可以是：

- 包含 `.hotpot.fnl` 的文件或目录的路径，
- 你的 Neovim 配置目录（即便该目录没有 `.hotpot.fnl` 文件），
- 或 `nil`。

如果提供了有效路径，则加载并返回该路径对应的 `context`。如果传入 `nil`，则会创建一个默认的 “api” 上下文，该上下文不支持某些需要磁盘路径的操作（例如 `sync`）。

## `context.compile(string, compiler-options)`

使用上下文的编译器选项编译给定字符串。返回 `true, compiled string` 或 `false, error`。

此方法不会自动应用 `context` 配置中指定的 transform。如果定义了 transform，可以手动调用 `context.transform`。

## `context.eval(string, compiler-options)`

使用上下文的编译器选项评估给定字符串。返回 `true, ...evaluated values` 或 `false, error`。

此方法同样不会自动应用上下文中的 transform；如需应用，请调用 `context.transform`。

## `context.sync(options|nil)`

通过编译上下文中的文件来同步上下文。返回 `report` 表。

支持以下选项：

- `force?`：强制编译上下文中的所有文件，即使对应的 `.lua` 已是最新。
- `atomic?`：允许在部分文件编译失败时仍写入已成功编译的文件。
- `verbose?`：输出更多编译信息。
- `compiler`：额外的 Fennel 编译器选项。

该方法不适用于 “api” 上下文（例如那些在未提供路径时创建的上下文）。

## `context.transform(string, filename|nil)`

对字符串应用上下文中 `.hotpot.fnl` 定义的 transform。

如果未定义 `transform`，则不可用。

## `context.locate(string)`

将给定路径转换为其对应路径，例如：给定上下文源中的 `.fnl` 文件路径，转换为该上下文目标中的 `.lua` 文件路径。

接受 `.fnl` 或 `.lua` 路径；对于不存在的文件也可以构造期望的对应路径。

该方法同样不适用于 “api” 上下文（例如那些在未提供路径时创建的上下文）。

## `context.metadata()`

返回与给定上下文相关的元数据表。
