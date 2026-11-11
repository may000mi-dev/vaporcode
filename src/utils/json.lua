-- json.lua: codificador/decodificador JSON mínimo para el guardado.
-- Soporta objetos, arreglos, cadenas, números, booleanos y null.
local Json = {}

local function escapeString(value)
  local out = {}
  for i = 1, #value do
    local byte = string.byte(value, i)
    if byte == 34 then
      out[#out + 1] = '\\"'
    elseif byte == 92 then
      out[#out + 1] = "\\\\"
    elseif byte == 10 then
      out[#out + 1] = "\\n"
    elseif byte == 13 then
      out[#out + 1] = "\\r"
    elseif byte == 9 then
      out[#out + 1] = "\\t"
    elseif byte < 32 then
      out[#out + 1] = string.format("\\u%04x", byte)
    else
      out[#out + 1] = string.char(byte)
    end
  end
  return table.concat(out)
end

local function encodeValue(value, out)
  local valueType = type(value)

  if valueType == "nil" then
    out[#out + 1] = "null"
  elseif valueType == "boolean" then
    out[#out + 1] = tostring(value)
  elseif valueType == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      out[#out + 1] = "null"
    else
      out[#out + 1] = tostring(value)
    end
  elseif valueType == "string" then
    out[#out + 1] = '"' .. escapeString(value) .. '"'
  elseif valueType == "table" then
    local count = 0
    local isArray = true

    for key in pairs(value) do
      count = count + 1
      if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
        isArray = false
      end
    end

    if isArray then
      for i = 1, count do
        if value[i] == nil then
          isArray = false
          break
        end
      end
    end

    if isArray then
      out[#out + 1] = "["
      for i = 1, count do
        if i > 1 then out[#out + 1] = "," end
        encodeValue(value[i], out)
      end
      out[#out + 1] = "]"
    else
      out[#out + 1] = "{"
      local first = true
      for key, item in pairs(value) do
        if type(key) == "string" then
          if not first then out[#out + 1] = "," end
          first = false
          out[#out + 1] = '"' .. escapeString(key) .. '":'
          encodeValue(item, out)
        end
      end
      out[#out + 1] = "}"
    end
  else
    error("JSON: tipo no soportado: " .. valueType)
  end
end

function Json.encode(value)
  local out = {}
  encodeValue(value, out)
  return table.concat(out)
end

function Json.decode(text)
  local pos = 1
  local length = #text
  local parseValue

  local function skipWhitespace()
    while pos <= length do
      local char = string.sub(text, pos, pos)
      if char == " " or char == "\n" or char == "\r" or char == "\t" then
        pos = pos + 1
      else
        break
      end
    end
  end

  local function parseString()
    pos = pos + 1
    local out = {}

    while pos <= length do
      local char = string.sub(text, pos, pos)

      if char == '"' then
        pos = pos + 1
        return table.concat(out)
      elseif char == "\\" then
        pos = pos + 1
        local escape = string.sub(text, pos, pos)

        if escape == '"' or escape == "\\" or escape == "/" then
          out[#out + 1] = escape
          pos = pos + 1
        elseif escape == "b" then
          out[#out + 1] = "\b"
          pos = pos + 1
        elseif escape == "f" then
          out[#out + 1] = "\f"
          pos = pos + 1
        elseif escape == "n" then
          out[#out + 1] = "\n"
          pos = pos + 1
        elseif escape == "r" then
          out[#out + 1] = "\r"
          pos = pos + 1
        elseif escape == "t" then
          out[#out + 1] = "\t"
          pos = pos + 1
        elseif escape == "u" then
          local hex = string.sub(text, pos + 1, pos + 4)
          local code = tonumber(hex, 16)
          if not code then
            error("JSON: unicode inválido")
          end

          if code < 128 then
            out[#out + 1] = string.char(code)
          elseif code < 2048 then
            out[#out + 1] = string.char(
              192 + math.floor(code / 64),
              128 + code % 64
            )
          else
            out[#out + 1] = string.char(
              224 + math.floor(code / 4096),
              128 + math.floor(code / 64) % 64,
              128 + code % 64
            )
          end
          pos = pos + 5
        else
          error("JSON: escape inválido")
        end
      else
        out[#out + 1] = char
        pos = pos + 1
      end
    end

    error("JSON: cadena sin cerrar")
  end

  local function parseNumber()
    local startPos = pos

    while pos <= length do
      local char = string.sub(text, pos, pos)
      if string.match(char, "[%d%.eE%+%-]") then
        pos = pos + 1
      else
        break
      end
    end

    local number = tonumber(string.sub(text, startPos, pos - 1))
    if not number then
      error("JSON: número inválido")
    end
    return number
  end

  local function parseObject()
    pos = pos + 1
    local object = {}
    skipWhitespace()

    if string.sub(text, pos, pos) == "}" then
      pos = pos + 1
      return object
    end

    while true do
      skipWhitespace()
      if string.sub(text, pos, pos) ~= '"' then
        error("JSON: clave esperada")
      end

      local key = parseString()
      skipWhitespace()

      if string.sub(text, pos, pos) ~= ":" then
        error("JSON: ':' esperado")
      end
      pos = pos + 1

      object[key] = parseValue()
      skipWhitespace()

      local separator = string.sub(text, pos, pos)
      if separator == "," then
        pos = pos + 1
      elseif separator == "}" then
        pos = pos + 1
        break
      else
        error("JSON: ',' o '}' esperado")
      end
    end

    return object
  end

  local function parseArray()
    pos = pos + 1
    local array = {}
    skipWhitespace()

    if string.sub(text, pos, pos) == "]" then
      pos = pos + 1
      return array
    end

    while true do
      array[#array + 1] = parseValue()
      skipWhitespace()

      local separator = string.sub(text, pos, pos)
      if separator == "," then
        pos = pos + 1
      elseif separator == "]" then
        pos = pos + 1
        break
      else
        error("JSON: ',' o ']' esperado")
      end
    end

    return array
  end

  parseValue = function()
    skipWhitespace()

    if pos > length then
      error("JSON: fin inesperado")
    end

    local char = string.sub(text, pos, pos)
    if char == "{" then
      return parseObject()
    elseif char == "[" then
      return parseArray()
    elseif char == '"' then
      return parseString()
    elseif char == "t" then
      if string.sub(text, pos, pos + 3) == "true" then
        pos = pos + 4
        return true
      end
      error("JSON: literal inválido")
    elseif char == "f" then
      if string.sub(text, pos, pos + 4) == "false" then
        pos = pos + 5
        return false
      end
      error("JSON: literal inválido")
    elseif char == "n" then
      if string.sub(text, pos, pos + 3) == "null" then
        pos = pos + 4
        return nil
      end
      error("JSON: literal inválido")
    end

    return parseNumber()
  end

  local result = parseValue()
  skipWhitespace()
  if pos <= length then
    error("JSON: datos extra después del valor")
  end
  return result
end

return Json
