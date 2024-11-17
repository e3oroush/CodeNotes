local fn = vim.fn

M = {}
M.sign_cache = {}
function M.get_filename(file_path)
	return fn.fnamemodify(file_path, ":t")
end

function M.delete_sign_at_line(line_number)
	-- Get all signs in the current buffer
	local signs = fn.sign_getplaced("", { group = "", buffer = 0 })[1].signs

	-- Loop through the signs and find the ones placed at the specified line
	for _, sign in ipairs(signs) do
		if sign.lnum == line_number then
			-- Delete the sign by its ID
			print(fn.sign_unplace("", { id = sign.id, buffer = vim.api.nvim_get_current_buf() }))
			print("Deleted sign with ID " .. sign.id .. " at line " .. line_number)
			return
		end
	end

	-- If no sign was found at the given line number
	print("No sign found at line " .. line_number)
end
function M.mark_sign_line(line_number)
	-- place a marker sign at the give line number
	local buf = vim.api.nvim_get_current_buf()
	local priority = 10
	local text = "c"
	local sign_name = "Marks_" .. text
	local group = ""
	local id = 0
	if not M.sign_cache[sign_name] then
		M.sign_cache[sign_name] = true
		vim.fn.sign_define(sign_name, {
			text = text,
			texthl = "MarkSignHL",
			numhl = "MarkSignNumHL",
		})
	end
	vim.fn.sign_place(id, group, sign_name, buf, { lnum = line_number, priority = priority })
end
return M
