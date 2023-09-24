local defaults = {
	auto_pull = false,
	auto_push = false,
	auto_commit = true,
	commit_prompt = true,
}

local add_defaults = function(t)
	for _, v in ipairs(t) do
		v[1] = vim.fn.expand(v[1])
		for default, default_value in pairs(defaults) do
			if v[default] == nil then
				v[default] = default_value
			end
		end
	end
end
local M = {}

--@doc config is a list of directories,
-- {
-- 	dir = '~/notes',
-- 	auto_pull = false,
-- 	auto_push = false,
-- 	auto_commit = true,
-- 	commit_prompt = true,
-- 	branches? = { list of branches to apply it on }
-- }

M._config = {}

M.setup = function(config)
	add_defaults(config)
	M._config = {}
	for _, v in ipairs(config) do
		M._config[v[1]] = v
		M.create_auto_command(v)
	end
end

M.auto_commit = function(dir, filename)
	local Job = require("plenary.job")
	local msg = ''
	if M._config[dir].commit_prompt then
		msg = vim.fn.input("Commit Message\n")
		else
		msg = 'git-auto-commit: '..filename
	end
	return Job:new({
		command = "git",
		args = { "commit", "-m", msg },
		on_stdout = function(err, data, j)
			vim.print(data)
		end,
		on_stderr = function(err, data, j)
			error(data)
		end,
		cwd = dir,
	})
end
M.auto_add = function(dir, filename)
	local Job = require("plenary.job")
	return Job:new({
		command = "git",
		args = { "add", filename },
		cwd = dir,
		on_start = function()
			vim.print("starting add job")
		end,
		on_stderr = function(err, data, j)
			error(data)
		end,
		on_stdout = function(err, data, j)
			vim.print(data)
		end,
	})
end
M.auto_push = function(dir)
	local job = require("plenary.job")

	return job:new({
		command = "git",
		args = { "push", "origin" },
		cwd = dir,
		on_stderr = function(err, data, j)
			error(data)
		end,
		on_stdout = function(err, data, j)
			print(data)
		end,
		on_exit = function(j, return_val)
			if return_val ~= 0 then
				vim.print("Exited with code " .. return_val)
			end
		end,
	})
end

M.handle_file_save = function(dir, filename)
	local conf = M._config[dir]
	if conf.auto_commit then
		local jobs = {
			M.auto_add(dir, filename),
			M.auto_commit(dir, filename),
		}
		if conf.auto_push then
			table.insert(jobs, M.auto_push(dir))
		end
		local job = require("plenary.job")
		local up = unpack
		if table.unpack then
			up = table.unpack
		end
		job.chain(up(jobs))
	end
end

M.create_auto_command = function(opts)
	local git_group = vim.api.nvim_create_augroup("AutoSync_" .. opts[1], { clear = true })
	vim.api.nvim_create_autocmd({ "BufWritePost" }, {
		pattern = opts[1] .. "/*",
		callback = function()
			M.handle_file_save(opts[1], vim.fn.bufname("%"))
		end,
		group = git_group,
	})
end

return M
