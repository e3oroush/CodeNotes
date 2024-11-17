local api = vim.api
local M = {}
local Path = require("plenary.path")
local Scan = require("plenary.scandir")
local Utils = require("codenotes.utils")

M.config = { cache_path = ".codenotes", extension = ".note" }
M.sign_cache = {}

function M.setup(opts)
	for key, value in pairs(opts) do
		M.config[key] = value
	end
end

local function get_cach_dir(main_buf)
	-- Get cache dir given main buffer. It's a hidden directory at next to the opened file at the buffer
	local path = Path:new(api.nvim_buf_get_name(main_buf))
	local dir = path:parent():joinpath(M.config.cache_path)
	return dir
end
local function get_buffer_filename(main_buf)
	local fname = Utils.get_filename(api.nvim_buf_get_name(main_buf))
	return fname
end
local function get_notes_path(line_number, main_buf)
	-- get the path for the notes file
	local fname = get_buffer_filename(main_buf)
	local dir = get_cach_dir(main_buf)
	local note_path = dir:joinpath(fname .. line_number .. M.config.extension)
	return note_path
end
local function save_buffer(buf, line_number, main_buf)
	-- save the code note buffer to a file
	local note_path = get_notes_path(line_number, main_buf)
	local content = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
	note_path:write(content, "w")
end
local function create_float_note_window(title)
	local buf = api.nvim_create_buf(false, true)
	local width = 60
	local height = 10
	api.nvim_open_win(buf, true, {
		relative = "cursor",
		width = width,
		height = height,
		row = 1,
		col = 1,
		style = "minimal",
		border = "rounded",
		title = title,
	})

	api.nvim_set_option_value("modifiable", true, { buf = buf })
	return buf
end
local function create_code_note(read_note)
	-- create or open a code note file and show it in a floating buffer window
	local current_buf = api.nvim_get_current_buf()
	local line, _ = unpack(api.nvim_win_get_cursor(0))
	local note_path = get_notes_path(line, current_buf)
	local code_note_buf = create_float_note_window("Save and exit by pressing <Esc><Enter>")
	if note_path:exists() then
		local content = note_path:read()
		api.nvim_buf_set_lines(code_note_buf, 0, -1, false, vim.split(content, "\n"))
	elseif read_note then
		vim.cmd("quit!")
		vim.notify("no note to read in this line", vim.log.levels.WARN)
		return
	end

	-- start in insert mode creating a new code note
	if read_note == nil then
		vim.cmd("startinsert")
	end
	vim.keymap.set("n", "<CR>", "<cmd>quit!<cr>", { buffer = code_note_buf })
	local group = api.nvim_create_augroup("CodeNoteWindow", { clear = true })
	api.nvim_create_autocmd("BufLeave", {
		group = group,
		buffer = code_note_buf,
		callback = function()
			save_buffer(code_note_buf, line, current_buf)
		end,
	})
end

function M.read_code_note()
	create_code_note(true)
end

function M.register_code_note()
	local line_number, _ = unpack(vim.api.nvim_win_get_cursor(0))
	Utils.mark_sign_line(line_number)
	create_code_note()
end

function M.refresh_code_notes()
	local main_buf = api.nvim_get_current_buf()
	local cache_dir = get_cach_dir(main_buf)
	cache_dir:mkdir()
	local caches = Scan.scan_dir(cache_dir:make_relative())
	if #caches == 0 then
		return
	end
	local current_fname = Utils.get_filename(vim.fn.expand("%"))
	for _, fname in ipairs(caches) do
		if string.find(fname, current_fname) then
			fname = Utils.get_filename(fname)
			fname = string.gsub(fname, current_fname, "")
			local line_number = vim.split(fname, M.config.extension, { trimempty = true })
			if #line_number == 1 then
				Utils.mark_sign_line(tonumber(line_number[1]))
			end
		end
	end
end

function M.delete_code_note()
	-- Handles deleting a code note at the current cursor
	local line_number, _ = unpack(api.nvim_win_get_cursor(0))
	-- delete the sign
	Utils.delete_sign_at_line(line_number)
	local note_path = get_notes_path(line_number, api.nvim_get_current_buf())
	-- delete the note file
	note_path:rm()
end

local agroup = api.nvim_create_augroup("CodeNotes", { clear = true })
api.nvim_create_autocmd("BufReadPost", {
	group = agroup,
	callback = function()
		-- Check if the buffer is a terminal or unnamed (empty name)
		if vim.fn.bufname() == "" or vim.bo.buftype == "terminal" then
			return
		end
		M.refresh_code_notes()
	end,
})

api.nvim_create_user_command("CodeNoteRegister", M.register_code_note, {})
api.nvim_create_user_command("CodeNoteRead", M.read_code_note, {})
api.nvim_create_user_command("CodeNoteRefresh", M.refresh_code_notes, {})
api.nvim_create_user_command("CodeNoteDelete", M.delete_code_note, {})

return M
