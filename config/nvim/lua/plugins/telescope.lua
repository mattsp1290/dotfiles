-- Telescope Configuration
-- DEV-003: Editor Configuration - File Navigation and Search

return {
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      "nvim-telescope/telescope-ui-select.nvim",
      "nvim-telescope/telescope-live-grep-args.nvim",
    },
    cmd = "Telescope",
    keys = {
      -- File and buffer navigation
      { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
      { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
      { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Find buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help tags" },
      { "<leader>fm", "<cmd>Telescope marks<CR>", desc = "Find marks" },
      { "<leader>fk", "<cmd>Telescope keymaps<CR>", desc = "Find keymaps" },
      { "<leader>fc", "<cmd>Telescope commands<CR>", desc = "Find commands" },
      { "<leader>fo", "<cmd>Telescope vim_options<CR>", desc = "Vim options" },

      -- Search functionality
      { "<leader>sg", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
      { "<leader>sw", "<cmd>Telescope grep_string<CR>", desc = "Search word under cursor" },
      { "<leader>ss", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Search in current buffer" },
      { "<leader>sr", "<cmd>Telescope resume<CR>", desc = "Resume last search" },
      { "<leader>sq", "<cmd>Telescope quickfix<CR>", desc = "Quickfix list" },
      { "<leader>sl", "<cmd>Telescope loclist<CR>", desc = "Location list" },

      -- Git integration
      { "<leader>gf", "<cmd>Telescope git_files<CR>", desc = "Git files" },
      { "<leader>gc", "<cmd>Telescope git_commits<CR>", desc = "Git commits" },
      { "<leader>gb", "<cmd>Telescope git_branches<CR>", desc = "Git branches" },
      { "<leader>gs", "<cmd>Telescope git_status<CR>", desc = "Git status" },
      { "<leader>gt", "<cmd>Telescope git_stash<CR>", desc = "Git stash" },

      -- LSP integration (will be overridden by LSP config if available)
      { "<leader>lr", "<cmd>Telescope lsp_references<CR>", desc = "LSP references" },
      { "<leader>ld", "<cmd>Telescope lsp_definitions<CR>", desc = "LSP definitions" },
      { "<leader>li", "<cmd>Telescope lsp_implementations<CR>", desc = "LSP implementations" },
      { "<leader>lt", "<cmd>Telescope lsp_type_definitions<CR>", desc = "LSP type definitions" },
      { "<leader>ls", "<cmd>Telescope lsp_document_symbols<CR>", desc = "Document symbols" },
      { "<leader>lw", "<cmd>Telescope lsp_workspace_symbols<CR>", desc = "Workspace symbols" },
      { "<leader>le", "<cmd>Telescope diagnostics<CR>", desc = "Diagnostics" },

      -- Project and workspace
      { "<leader>pp", "<cmd>Telescope project<CR>", desc = "Find project" },
      { "<leader>pw", "<cmd>Telescope grep_string search_dirs={vim.fn.expand('%:p:h')}<CR>", desc = "Search in project" },
    },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")

      telescope.setup({
        defaults = {
          prompt_prefix = " ",
          selection_caret = " ",
          entry_prefix = "  ",
          multi_icon = "<>",
          path_display = { "truncate" },
          winblend = 0,
          border = {},
          borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
          color_devicons = true,
          use_less = true,
          set_env = { ["COLORTERM"] = "truecolor" },
          file_sorter = require("telescope.sorters").get_fuzzy_file,
          file_ignore_patterns = {
            "%.git/",
            "node_modules/",
            "%.DS_Store",
            "%.class",
            "%.pdf",
            "%.mkv",
            "%.mp4",
            "%.zip",
          },
          generic_sorter = require("telescope.sorters").get_generic_fuzzy_sorter,
          file_previewer = require("telescope.previewers").vim_buffer_cat.new,
          grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
          qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
          buffer_previewer_maker = require("telescope.previewers").buffer_previewer_maker,
          mappings = {
            i = {
              ["<C-n>"] = actions.cycle_history_next,
              ["<C-p>"] = actions.cycle_history_prev,
              ["<C-j>"] = actions.move_selection_next,
              ["<C-k>"] = actions.move_selection_previous,
              ["<C-c>"] = actions.close,
              ["<Down>"] = actions.move_selection_next,
              ["<Up>"] = actions.move_selection_previous,
              ["<CR>"] = actions.select_default,
              ["<C-x>"] = actions.select_horizontal,
              ["<C-v>"] = actions.select_vertical,
              ["<C-t>"] = actions.select_tab,
              ["<C-u>"] = actions.preview_scrolling_up,
              ["<C-d>"] = actions.preview_scrolling_down,
              ["<PageUp>"] = actions.results_scrolling_up,
              ["<PageDown>"] = actions.results_scrolling_down,
              ["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
              ["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
              ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
              ["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
              ["<C-l>"] = actions.complete_tag,
              ["<C-_>"] = actions.which_key,
            },
            n = {
              ["<esc>"] = actions.close,
              ["<CR>"] = actions.select_default,
              ["<C-x>"] = actions.select_horizontal,
              ["<C-v>"] = actions.select_vertical,
              ["<C-t>"] = actions.select_tab,
              ["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
              ["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
              ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
              ["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
              ["j"] = actions.move_selection_next,
              ["k"] = actions.move_selection_previous,
              ["H"] = actions.move_to_top,
              ["M"] = actions.move_to_middle,
              ["L"] = actions.move_to_bottom,
              ["<Down>"] = actions.move_selection_next,
              ["<Up>"] = actions.move_selection_previous,
              ["gg"] = actions.move_to_top,
              ["G"] = actions.move_to_bottom,
              ["<C-u>"] = actions.preview_scrolling_up,
              ["<C-d>"] = actions.preview_scrolling_down,
              ["<PageUp>"] = actions.results_scrolling_up,
              ["<PageDown>"] = actions.results_scrolling_down,
              ["?"] = actions.which_key,
            },
          },
        },
        pickers = {
          find_files = {
            find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
            layout_config = {
              height = 0.70,
            },
          },
          live_grep = {
            additional_args = function()
              return { "--hidden" }
            end,
          },
          grep_string = {
            additional_args = function()
              return { "--hidden" }
            end,
          },
          buffers = {
            theme = "dropdown",
            previewer = false,
            sort_lastused = true,
            sort_mru = true,
            mappings = {
              i = {
                ["<c-d>"] = actions.delete_buffer,
              },
              n = {
                ["dd"] = actions.delete_buffer,
              },
            },
          },
          oldfiles = {
            theme = "dropdown",
            previewer = false,
          },
          lsp_references = {
            theme = "dropdown",
            layout_config = {
              height = 0.70,
            },
          },
          lsp_definitions = {
            theme = "dropdown",
            layout_config = {
              height = 0.70,
            },
          },
          lsp_implementations = {
            theme = "dropdown",
            layout_config = {
              height = 0.70,
            },
          },
        },
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
          },
          ["ui-select"] = {
            require("telescope.themes").get_dropdown({
              winblend = 10,
              width = 0.5,
              height = 0.4,
            }),
          },
          live_grep_args = {
            auto_quoting = true,
            mappings = {
              i = {
                ["<C-k>"] = require("telescope-live-grep-args.actions").quote_prompt(),
                ["<C-i>"] = require("telescope-live-grep-args.actions").quote_prompt({ postfix = " --iglob " }),
              },
            },
          },
        },
      })

      -- Load extensions
      telescope.load_extension("fzf")
      telescope.load_extension("ui-select")
      
      -- Load live_grep_args if available
      pcall(telescope.load_extension, "live_grep_args")
      
      -- Load project extension if available
      pcall(telescope.load_extension, "project")
    end,
  },

  -- Project management
  {
    "ahmedkhalf/project.nvim",
    config = function()
      require("project_nvim").setup({
        detection_methods = { "lsp", "pattern" },
        patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "Makefile", "package.json" },
        ignore_lsp = {},
        exclude_dirs = {},
        show_hidden = false,
        silent_chdir = true,
        scope_chdir = "global",
        datapath = vim.fn.stdpath("data"),
      })
    end,
  },
} 