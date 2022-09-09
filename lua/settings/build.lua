local util = require("settings.util")
local Schema = require("settings.schema")

local M = {}

---@param schema LspSchema
function M.get_schema(schema)
  local json = util.json_decode(util.fetch(schema.settings_url or schema.package_url)) or {}
  local config = json.contributes and json.contributes.configuration or json.properties and json

  local properties = {}

  if vim.tbl_islist(config) then
    for _, c in pairs(config) do
      vim.list_extend(properties, c.properties)
    end
  elseif config.properties then
    properties = config.properties
  end

  if schema.settings_prefix then
    local props = {}
    for key, value in pairs(properties) do
      props[schema.settings_prefix .. key] = value
    end
    local function fixref(node)
      if type(node) == "table" then
        for k, v in pairs(node) do
          if k == "$ref" then
            node[k] = v:gsub("#/properties/", "#/properties/" .. schema.settings_prefix)
          end
          fixref(v)
        end
      end
      return node
    end
    properties = fixref(props)
  end

  return {
    ["$schema"] = "http://json-schema.org/draft-07/schema#",
    description = json.description,
    properties = properties,
  }
end

function M.clean()
  ---@diagnostic disable-next-line: param-type-mismatch
  for _, f in pairs(vim.fn.expand("schemas/*.json", false, true)) do
    vim.loop.fs_unlink(f)
  end
end

function M.update_index()
  local url = "https://gist.githubusercontent.com/williamboman/a01c3ce1884d4b57cc93422e7eae7702/raw/lsp-packages.json"
  local index = util.fetch(url)
  util.write_file(
    "lua/settings/schema/lsp.lua",
    "--- auto generated from " .. url .. "\nreturn " .. vim.inspect(util.json_decode(index))
  )
end

function M.update_schemas()
  for name, s in pairs(Schema.get_lsp_schemas()) do
    print(("Generating schema for %s"):format(name))

    if not (util.exists(s.settings_file) and os.time() - util.mtime(s.settings_file) < 3600) then
      local schema = M.get_schema(s)
      util.write_file(s.settings_file, vim.fn.json_encode(schema))
    end
  end
end

function M.build()
  -- M.clean()
  M.update_index()
  M.update_schemas()
end

M.build()

return M