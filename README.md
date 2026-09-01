# rookie_outliner.nvim

A box outliner for visual block selected text

```lua
vim.keymap.set("x", "<leader>o", ":<C-u>RkOutlinerDraw<CR>", {
    silent = true,
    desc = "rookie_outliner: draw",
})

vim.keymap.set(
    "n",
    "<leader>o<BS>",
    ":RkOutlinerClear<CR>",
    { silent = true, desc = "rookie_outliner: clear" }
)
```
