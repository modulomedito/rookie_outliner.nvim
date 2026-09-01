local M = {}

local ns_id = vim.api.nvim_create_namespace("box_outline")

-- Helper: Converts a target display column to the closest valid byte index.
-- It also returns the actual display column at that byte so we can pad missing spaces.
local function get_byte_idx_for_vcol(line_str, target_vcol)
    if target_vcol <= 0 then
        return 0, 0
    end
    if line_str == "" then
        return 0, 0
    end

    local current_vcol = 0
    local current_byte = 0
    local char_len = vim.fn.strchars(line_str)

    for i = 0, char_len - 1 do
        local char = vim.fn.strcharpart(line_str, i, 1)
        local w = vim.fn.strdisplaywidth(char, current_vcol)

        -- Stop if adding this char exceeds our target column
        if current_vcol + w > target_vcol then
            break
        end

        current_vcol = current_vcol + w
        current_byte = current_byte + #char
    end

    return current_byte, current_vcol
end

local function draw_virtual_box()
    -- Detect mode to use correct marks
    local mode = vim.api.nvim_get_mode().mode
    local is_visual = mode:find("[vV\22]")

    -- Get selection range
    local start_mark = vim.fn.getpos(is_visual and "v" or "'<")
    local end_mark = vim.fn.getpos(is_visual and "." or "'>")
    if start_mark[2] == 0 or end_mark[2] == 0 then
        vim.notify("rookie_outliner: No visual selection found", vim.log.levels.WARN)
        return
    end

    -- Clear previous box overlays
    vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)

    local srow = start_mark[2] - 1
    local erow = end_mark[2] - 1

    -- Get virtual/display columns
    local vcol1 = vim.fn.virtcol(is_visual and "v" or "'<") - 1
    local vcol2 = vim.fn.virtcol(is_visual and "." or "'>") - 1

    -- Normalize
    if srow > erow then srow, erow = erow, srow end
    local scol_v = math.min(vcol1, vcol2)
    local ecol_v = math.max(vcol1, vcol2)

    -- Handle large ecol_v (selection to $)
    local max_buf_len = 0
    for r = srow, erow do
        local line = vim.api.nvim_buf_get_lines(0, r, r + 1, false)[1] or ""
        max_buf_len = math.max(max_buf_len, vim.fn.strdisplaywidth(line))
    end
    if ecol_v > max_buf_len + 100 then
        ecol_v = max_buf_len + 1
    end

    -- Boundary adjustments for the box (surrounding the selection)
    local box_scol = math.max(0, scol_v - 1)
    local box_ecol = ecol_v + 1
    local width = math.max(0, box_ecol - box_scol - 1)

    local top_str = "┌" .. string.rep("─", width) .. "┐"
    local bot_str = "└" .. string.rep("─", width) .. "┘"

    -- Helper to add side borders
    local function add_side_borders(row)
        local line_str = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
        local line_len = #line_str

        local b_idx_l, vcol_l = get_byte_idx_for_vcol(line_str, box_scol)
        local b_idx_r, vcol_r = get_byte_idx_for_vcol(line_str, box_ecol)

        if b_idx_l == b_idx_r then
            -- Short line, both borders at the end
            local pad = string.rep(" ", box_scol - vcol_l)
            local mid = string.rep(" ", width)
            vim.api.nvim_buf_set_extmark(0, ns_id, row, b_idx_l, {
                virt_text = { { pad .. "│" .. mid .. "│", "BoxBorderHL" } },
                virt_text_pos = b_idx_l >= line_len and "eol" or "overlay",
            })
        else
            -- Left border
            local pad_l = string.rep(" ", box_scol - vcol_l)
            vim.api.nvim_buf_set_extmark(0, ns_id, row, b_idx_l, {
                virt_text = { { pad_l .. "│", "BoxBorderHL" } },
                virt_text_pos = b_idx_l >= line_len and "eol" or "overlay",
            })
            -- Right border
            local pad_r = string.rep(" ", box_ecol - vcol_r)
            vim.api.nvim_buf_set_extmark(0, ns_id, row, b_idx_r, {
                virt_text = { { pad_r .. "│", "BoxBorderHL" } },
                virt_text_pos = b_idx_r >= line_len and "eol" or "overlay",
            })
        end
    end

    -- 1. Top Border (using virt_lines for zero-impact on text)
    local top_pad = string.rep(" ", box_scol)
    vim.api.nvim_buf_set_extmark(0, ns_id, srow, 0, {
        virt_lines = { { { top_pad .. top_str, "BoxBorderHL" } } },
        virt_lines_above = true,
    })

    -- 2. Side Borders
    for row = srow, erow do
        add_side_borders(row)
    end

    -- 3. Bottom Border
    local bot_pad = string.rep(" ", box_scol)
    vim.api.nvim_buf_set_extmark(0, ns_id, erow, 0, {
        virt_lines = { { { bot_pad .. bot_str, "BoxBorderHL" } } },
        virt_lines_above = false,
    })

    vim.notify("rookie_outliner: Box drawn", vim.log.levels.INFO)
end

-- Clear boxes command
local function clear_virtual_box()
    vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
end

function M.setup()
    -- Create custom highlight for the border overlay
    vim.api.nvim_set_hl(0, "BoxBorderHL", { fg = "#7aa2f7", bold = true, default = true })

    -- RkOutlinerDraw
    vim.api.nvim_create_user_command("RkOutlinerDraw", function()
        draw_virtual_box()
    end, {
        range = true,
        desc = "rookie_outliner: outline block selection with virtual border",
    })

    -- RkOutlinerClear
    vim.api.nvim_create_user_command("RkOutlinerClear", function()
        clear_virtual_box()
    end, { desc = "rookie_outliner: clear virtual border outline" })
end

return M
