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
    -- Get visual selection range (Lines)
    local start_mark = vim.fn.getpos("'<")
    local end_mark = vim.fn.getpos("'>")
    if start_mark[2] == 0 or end_mark[2] == 0 then
        return
    end

    -- Clear previous box overlays
    vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)

    local srow = start_mark[2] - 1
    local erow = end_mark[2] - 1

    -- Get virtual/display columns (Solves virtualedit & tab issues)
    local vcol1 = vim.fn.virtcol("'<") - 1
    local vcol2 = vim.fn.virtcol("'>") - 1

    -- Normalize direction
    if srow > erow then
        srow, erow = erow, srow
    end
    local scol_v = math.min(vcol1, vcol2)
    local ecol_v = math.max(vcol1, vcol2)

    -- Handle case where ecol_v is very large (e.g. selection to end of line)
    local max_buf_len = 0
    for r = srow, erow do
        local line = vim.api.nvim_buf_get_lines(0, r, r + 1, false)[1] or ""
        local len = vim.fn.strdisplaywidth(line)
        if len > max_buf_len then
            max_buf_len = len
        end
    end
    if ecol_v > max_buf_len + 100 then
        ecol_v = max_buf_len + 1
    end

    -- Extend boundaries by 1 in all directions
    local orig_srow, orig_erow = srow, erow
    srow = math.max(0, srow - 1)
    scol_v = math.max(0, scol_v - 1)
    ecol_v = ecol_v + 1

    -- Prevent exceeding buffer length
    local max_row = vim.api.nvim_buf_line_count(0) - 1
    erow = math.min(max_row, erow + 1)

    local width = math.max(0, ecol_v - scol_v - 1)
    local top_border = "┌" .. string.rep("─", width) .. "┐"
    local bot_border = "└" .. string.rep("─", width) .. "┘"

    for row = srow, erow do
        local line_str = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
        local line_len = #line_str

        if row == srow then
            -- Top border overlay
            local b_idx, vcol = get_byte_idx_for_vcol(line_str, scol_v)
            local pad = string.rep(" ", scol_v - vcol)
            local vpos = b_idx >= line_len and "eol" or "overlay"

            vim.api.nvim_buf_set_extmark(0, ns_id, row, b_idx, {
                virt_text = { { pad .. top_border, "BoxBorderHL" } },
                virt_text_pos = vpos,
            })
        elseif row == erow then
            -- Bottom border overlay
            local b_idx, vcol = get_byte_idx_for_vcol(line_str, scol_v)
            local pad = string.rep(" ", scol_v - vcol)
            local vpos = b_idx >= line_len and "eol" or "overlay"

            vim.api.nvim_buf_set_extmark(0, ns_id, row, b_idx, {
                virt_text = { { pad .. bot_border, "BoxBorderHL" } },
                virt_text_pos = vpos,
            })
        else
            -- Side borders overlay
            local b_idx_left, vcol_left = get_byte_idx_for_vcol(line_str, scol_v)
            local b_idx_right, vcol_right = get_byte_idx_for_vcol(line_str, ecol_v)

            -- If both fall at the end of a short line, combine them into one overlay string
            if b_idx_left == b_idx_right then
                local pad = string.rep(" ", scol_v - vcol_left)
                local mid_pad = string.rep(" ", math.max(0, ecol_v - scol_v - 1))
                local vpos = b_idx_left >= line_len and "eol" or "overlay"
                vim.api.nvim_buf_set_extmark(0, ns_id, row, b_idx_left, {
                    virt_text = { { pad .. "│" .. mid_pad .. "│", "BoxBorderHL" } },
                    virt_text_pos = vpos,
                })
            else
                local pad_left = string.rep(" ", scol_v - vcol_left)
                local vpos_left = b_idx_left >= line_len and "eol" or "overlay"
                vim.api.nvim_buf_set_extmark(0, ns_id, row, b_idx_left, {
                    virt_text = { { pad_left .. "│", "BoxBorderHL" } },
                    virt_text_pos = vpos_left,
                })

                local pad_right = string.rep(" ", ecol_v - vcol_right)
                local vpos_right = b_idx_right >= line_len and "eol" or "overlay"
                vim.api.nvim_buf_set_extmark(0, ns_id, row, b_idx_right, {
                    virt_text = { { pad_right .. "│", "BoxBorderHL" } },
                    virt_text_pos = vpos_right,
                })
            end
        end
    end
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
