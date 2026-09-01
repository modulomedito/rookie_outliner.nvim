local M = {}

function M.setup()
    vim.keymap.set("x", "<leader>o", "<Cmd>RkOutlinerDraw<CR>", {
        silent = true,
        desc = "rookie_outliner: draw",
    })

    vim.keymap.set(
        "n",
        "<leader>o<BS>",
        ":RkOutlinerClear<CR>",
        { silent = true, desc = "rookie_outliner: clear" }
    )
end

return M
