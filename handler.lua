-- This software is copyright Kong Inc. and its licensors.
-- Use of the software is subject to the agreement between your organization
-- and Kong Inc. If there is no such agreement, use is governed by and
-- subject to the terms of the Kong Master Software License Agreement found
-- at https://konghq.com/enterprisesoftwarelicense/.
-- [ END OF LICENSE 0867164ffc95e54f04670b5169c09574bdbd9bba ]

-- Copyright (C) Kong Inc.
require "kong.tools.utils" -- ffi.cdefs
local kong_meta = require "kong.meta"


local ffi = require "ffi"
local cjson = require "cjson"
local system_constants = require "lua_system_constants"
local sandbox = require "kong.tools.sandbox".sandbox


local kong = kong


local O_CREAT = system_constants.O_CREAT()
local O_WRONLY = system_constants.O_WRONLY()
local O_APPEND = system_constants.O_APPEND()
local S_IRUSR = system_constants.S_IRUSR()
local S_IWUSR = system_constants.S_IWUSR()
local S_IRGRP = system_constants.S_IRGRP()
local S_IROTH = system_constants.S_IROTH()


local oflags = bit.bor(O_WRONLY, O_CREAT, O_APPEND)
local mode = ffi.new("int", bit.bor(S_IRUSR, S_IWUSR, S_IRGRP, S_IROTH))


local sandbox_opts = { env = { kong = kong, ngx = ngx } }


local C = ffi.C


-- fd tracking utility functions
local file_descriptors = {}

-- Log to a file.
-- @param `conf`     Configuration table, holds http endpoint details
-- @param `message`  Message to be logged
local function log(conf, message)
  local msg = cjson.encode(message) .. "\n"
  local fd = file_descriptors[conf.path]

  if fd and conf.reopen then
    -- close fd, we do this here, to make sure a previously cached fd also
    -- gets closed upon dynamic changes of the configuration
    C.close(fd)
    file_descriptors[conf.path] = nil
    fd = nil
  end

  if not fd then
    fd = C.open(conf.path, oflags, mode)
    if fd < 0 then
      local errno = ffi.errno()
      kong.log.err("failed to open the file: ", ffi.string(C.strerror(errno)))

    else
      file_descriptors[conf.path] = fd
    end
  end

  C.write(fd, msg, #msg)
end


local FileLogHandler = {
  PRIORITY = 9,
  VERSION = kong_meta.core_version,
}

function FileLogHandler:access(conf)
    kong.service.request.enable_buffering()
    kong.ctx.plugin.req_body = kong.request.get_raw_body()
end

function FileLogHandler:log(conf)
  if conf.custom_fields_by_lua then
    local set_serialize_value = kong.log.set_serialize_value
    for key, expression in pairs(conf.custom_fields_by_lua) do
      set_serialize_value(key, sandbox(expression, sandbox_opts)())
    end
  end

  local message = kong.log.serialize()
  if kong.ctx.plugin.req_body then
    message.request.body = kong.ctx.plugin.req_body
  end
  if  kong.service.response.get_raw_body() then
    message.response.body = kong.service.response.get_raw_body()
  end
  log(conf, message)
end


return FileLogHandler