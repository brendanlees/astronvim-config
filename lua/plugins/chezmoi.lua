return {
  {
    "alker0/chezmoi.vim",
    lazy = false,
    init = function()
      vim.g["chezmoi#use_tmp_buffer"] = true

      vim.filetype.add {
        extension = {
          tmpl = function(path, bufnr)
            local filename = vim.fn.fnamemodify(path, ":t:r")
            if filename:match "^dot_zshrc" then return "zsh" end
            if filename:match "^dot_bashrc" then return "bash" end
            if filename:match "^dot_bash_profile" then return "bash" end
            local ext = vim.fn.fnamemodify(filename, ":e")
            if ext ~= "" then return ext end
            return "conf"
          end,
        },
      }
    end,
    config = function()
      local chezmoi_source = vim.fn.system("chezmoi source-path"):gsub("\n", "")

      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        group = vim.api.nvim_create_augroup("chezmoi_auto_edit", { clear = true }),
        callback = function(ev)
          if vim.startswith(ev.file, chezmoi_source) or ev.file == "" then return end
          local source = vim.fn.system("chezmoi source-path " .. vim.fn.shellescape(ev.file)):gsub("\n", "")
          if vim.v.shell_error == 0 and source ~= "" and source ~= ev.file then
            vim.schedule(function()
              vim.api.nvim_buf_delete(ev.buf, { force = true })
              vim.cmd("edit " .. vim.fn.fnameescape(source))
            end)
          end
        end,
      })

      -- Proper syntax highlighting for Go templates
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "zsh", "bash", "sh" },
        group = vim.api.nvim_create_augroup("chezmoi_template_syntax", { clear = true }),
        callback = function(ev)
          local filename = vim.fn.expand "%:t"
          if filename:match "%.tmpl$" then
            vim.cmd [[
              syntax region chezmoiTemplate start=/{{-\?[~]\?/ end=/[~]\?-\?}}/ contains=chezmoiComment,chezmoiKeyword,chezmoiFunction
              syntax match chezmoiComment /{{\/\*\_.\{-}\*\/}}/
              syntax keyword chezmoiKeyword if else end range with define template block contained
              syntax keyword chezmoiFunction eq ne lt le gt ge and or not contained
              highlight link chezmoiTemplate Special
              highlight link chezmoiComment Comment
              highlight link chezmoiKeyword Keyword
              highlight link chezmoiFunction Function
            ]]
          end
        end,
      })

      -- Disable diagnostics for template files (non-deprecated method)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "zsh", "bash", "sh" },
        group = vim.api.nvim_create_augroup("chezmoi_disable_diagnostics", { clear = true }),
        callback = function(ev)
          local filename = vim.fn.expand "%:t"
          if filename:match "%.tmpl$" then
            -- Use vim.diagnostic.enable with false parameter (new API)
            vim.diagnostic.enable(false, { bufnr = ev.buf })
          end
        end,
      })
    end,
  },
}
