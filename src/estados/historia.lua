-- historia.lua: entrada al Modo Historia, selección de personaje y checkpoints.
local Data = require("src.run.data")
local Save = require("src.run.save")
local Fonts = require("src.utils.fonts")
local Util = require("src.utils.util")
local Screen = require("src.utils.screen")
local TextCache = require("src.utils.textcache")
local State = require("src.estados")

local shortDescription = {
  amado = "Precisión y marca",
  mar = "Golpe y dash",
  amileth = "Cadena y escudo",
}

local completedSubKeys = {
  amado = "historia-completed-amado",
  mar = "historia-completed-mar",
  amileth = "historia-completed-amileth",
}

local Historia = {
  rects = {},
  characterRects = {},
  characterId = "amado",
  confirmNew = false,
  message = nil,
  messageTimer = 0,
}

local function characterList()
  local list = {}
  for _, id in ipairs(Data.characterOrder) do
    if Save.isCharacterUnlocked(id) then
      list[#list + 1] = id
    end
  end
  return list
end

local function currentChapter()
  local story = Save.data.story
  if not story or not story.active or not story.chapterId then return nil end
  return Data.story.chapterById[story.chapterId]
end

local function selectCharacter(id)
  if Data.characters[id] and Save.isCharacterUnlocked(id) then
    Historia.characterId = id
  end
end

local function startNew()
  Save.resetStory()
  State.switch(
    "run",
    "cripta",
    Historia.characterId,
    nil,
    { mode = "story", chapterId = "cripta" }
  )
end

local function continueStory()
  local story = Save.data.story
  local chapter = currentChapter()
  if not chapter then
    Historia.confirmNew = false
    Historia.message = "No hay una historia en curso."
    Historia.messageTimer = 2.4
    return
  end
  local characterId = story.characterId
  if not Data.characters[characterId] or not Save.isCharacterUnlocked(characterId) then
    characterId = Historia.characterId
  end
  State.switch(
    "run",
    chapter.dungeonId,
    characterId,
    nil,
    { resume = true }
  )
end

local function requestNew()
  if Save.hasStoryCheckpoint() or Save.isStoryCompleted(Historia.characterId) then
    Historia.confirmNew = true
  else
    startNew()
  end
end

function Historia.say(text)
  Historia.message = text
  Historia.messageTimer = 2.4
end

function Historia.layout()
  local width = math.min(Screen.width - 80, 780)
  local height = math.min(Screen.height - 40, 480)
  local x = (Screen.width - width) * 0.5
  local y = (Screen.height - height) * 0.5
  Historia.panel = { x = x, y = y, w = width, h = height }

  local list = characterList()
  local gap = 14
  local total = width - 80
  local buttonW = math.floor((total - gap * (#list - 1)) / math.max(1, #list))
  Historia.characterRects = {}
  for index, id in ipairs(list) do
    Historia.characterRects[#Historia.characterRects + 1] = {
      x = x + 40 + (index - 1) * (buttonW + gap),
      y = y + 170,
      w = buttonW,
      h = 52,
      id = id,
    }
  end

  local hasContinue = Save.hasStoryCheckpoint() and currentChapter() ~= nil
  local buttonX = x + 40
  local buttonWide = width - 80
  Historia.rects.continue = hasContinue
    and { x = buttonX, y = y + 250, w = buttonWide, h = 52 }
    or nil
  Historia.rects.new = {
    x = buttonX,
    y = hasContinue and y + 316 or y + 250,
    w = buttonWide,
    h = 52,
  }
  Historia.rects.back = {
    x = x + width - 220,
    y = y + height - 58,
    w = 180,
    h = 40,
  }

  local modalW, modalH = 460, 190
  local modalX = (Screen.width - modalW) * 0.5
  local modalY = (Screen.height - modalH) * 0.5
  Historia.modal = {
    x = modalX,
    y = modalY,
    w = modalW,
    h = modalH,
    yes = { x = modalX + 30, y = modalY + 122, w = 180, h = 42 },
    no = { x = modalX + modalW - 210, y = modalY + 122, w = 180, h = 42 },
  }
end

function Historia.enter(characterId)
  Historia.confirmNew = false
  Historia.message = nil
  Historia.messageTimer = 0
  if characterId
    and Data.characters[characterId]
    and Save.isCharacterUnlocked(characterId) then
    Historia.characterId = characterId
  elseif not Save.isCharacterUnlocked(Historia.characterId) then
    Historia.characterId = "amado"
  end
  Historia.layout()
end

function Historia.update(dt)
  if Historia.messageTimer > 0 then
    Historia.messageTimer = math.max(0, Historia.messageTimer - dt)
    if Historia.messageTimer == 0 then
      Historia.message = nil
    end
  end
end

function Historia.keypressed(key, isrepeat)
  if isrepeat then return end
  if Historia.confirmNew then
    if key == "escape" or key == "backspace" then
      Historia.confirmNew = false
    elseif key == "return" or key == "space" then
      Historia.confirmNew = false
      startNew()
    end
    return
  end

  if key == "escape" or key == "backspace" then
    State.switch("menu")
  elseif key == "return" or key == "space" then
    if Save.hasStoryCheckpoint() then
      continueStory()
    else
      requestNew()
    end
  elseif key == "n" then
    requestNew()
  elseif key == "1" then
    selectCharacter(Data.characterOrder[1])
  elseif key == "2" then
    selectCharacter(Data.characterOrder[2])
  elseif key == "3" then
    selectCharacter(Data.characterOrder[3])
  end
end

function Historia.pressed(x, y)
  Historia.layout()
  if Historia.confirmNew then
    if Util.inside(x, y, Historia.modal.yes) then
      Historia.confirmNew = false
      startNew()
    elseif Util.inside(x, y, Historia.modal.no) then
      Historia.confirmNew = false
    end
    return
  end

  for _, rect in ipairs(Historia.characterRects) do
    if Util.inside(x, y, rect) then
      Historia.characterId = rect.id
      return
    end
  end

  if Historia.rects.continue and Util.inside(x, y, Historia.rects.continue) then
    continueStory()
    return
  end
  if Util.inside(x, y, Historia.rects.new) then
    requestNew()
    return
  end
  if Util.inside(x, y, Historia.rects.back) then
    State.switch("menu")
  end
end

function Historia.mousepressed(x, y, button)
  if button == 1 then Historia.pressed(x, y) end
end

function Historia.touchpressed(id, x, y)
  Historia.pressed(x, y)
end

function Historia.mousemoved(x, y) end
function Historia.mousereleased(x, y) end
function Historia.touchmoved(id, x, y) end
function Historia.touchreleased(id, x, y) end
function Historia.focus(focused) end

local function drawButton(rect, label, sub, accent, selected)
  love.graphics.setColor(
    selected and 0.20 or 0.09,
    selected and 0.14 or 0.13,
    selected and 0.24 or 0.18,
    0.98
  )
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setColor(accent[1], accent[2], accent[3])
  love.graphics.setLineWidth(selected and 3 or 2)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setLineWidth(1)
  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf(label, rect.x + 10, rect.y + 6, rect.w - 20, "center")
  if sub then
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(0.72, 0.78, 0.86)
    love.graphics.printf(sub, rect.x + 8, rect.y + rect.h - 18, rect.w - 16, "center")
  end
end

function Historia.draw()
  Historia.layout()
  local panel = Historia.panel

  love.graphics.setColor(0.04, 0.05, 0.07)
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)
  love.graphics.setColor(0.08, 0.05, 0.10)
  love.graphics.circle("fill", 30, Screen.height - 20, 150)
  love.graphics.setColor(0.06, 0.08, 0.11)
  love.graphics.circle("fill", Screen.width - 20, 30, 180)

  love.graphics.setColor(0.05, 0.06, 0.10, 0.98)
  love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 12, 12)
  love.graphics.setColor(0.40, 0.32, 0.55)
  love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(0.78, 0.64, 1.00)
  love.graphics.printf("MODO HISTORIA", panel.x, panel.y + 16, panel.w, "center")

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.62, 0.68, 0.78)
  love.graphics.printf(
    "La última nota · una campaña en tres actos",
    panel.x,
    panel.y + 54,
    panel.w,
    "center"
  )

  local chapter = currentChapter()
  local story = Save.data.story
  local selected = Data.characters[Historia.characterId]
  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(0.86, 0.90, 0.95)
  if chapter then
    love.graphics.printf(
      TextCache.format(
        "historia-progress",
        "%s · piso %d · %s",
        chapter.name,
        story.depth,
        Data.characters[story.characterId].name
      ),
      panel.x + 40,
      panel.y + 92,
      panel.w - 80,
      "center"
    )
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(0.72, 0.78, 0.86)
    love.graphics.printf(
      "La misma torre cambia según quién sostenga el prototipo.",
      panel.x + 40,
      panel.y + 118,
      panel.w - 80,
      "center"
    )
  elseif Save.isStoryCompleted(Historia.characterId) then
    love.graphics.printf(
      "Historia completada con " .. selected.name .. ".",
      panel.x + 40,
      panel.y + 98,
      panel.w - 80,
      "center"
    )
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(0.72, 0.78, 0.86)
    love.graphics.printf(
      TextCache.format(
        "historia-completed-count",
        "%d/%d historias completadas · la Torre se abre con las tres.",
        Save.storyCompletionCount(),
        #Data.characterOrder
      ),
      panel.x + 40,
      panel.y + 124,
      panel.w - 80,
      "center"
    )
  else
    love.graphics.printf(
      "Rescata a la familia antes de que el tiempo se detenga.",
      panel.x + 40,
      panel.y + 98,
      panel.w - 80,
      "center"
    )
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(0.72, 0.78, 0.86)
    love.graphics.printf(
      TextCache.format(
        "historia-count",
        "%d/%d historias completadas · elige una perspectiva",
        Save.storyCompletionCount(),
        #Data.characterOrder
      ),
      panel.x + 40,
      panel.y + 124,
      panel.w - 80,
      "center"
    )
  end

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(0.70, 0.86, 1.00)
  love.graphics.print("Elige tu personaje", panel.x + 40, panel.y + 144)

  for _, rect in ipairs(Historia.characterRects) do
    local def = Data.characters[rect.id]
    local sub = shortDescription[rect.id] or def.desc
    if Save.isStoryCompleted(rect.id) then
      sub = TextCache.format(completedSubKeys[rect.id], "%s · completada", sub)
    end
    drawButton(
      rect,
      def.name,
      sub,
      def.color,
      Historia.characterId == rect.id
    )
  end

  if Historia.rects.continue then
    drawButton(
      Historia.rects.continue,
      "CONTINUAR HISTORIA",
      "Retoma desde el inicio del último piso guardado",
      { 0.55, 0.90, 1.00 },
      true
    )
  end

  local newLabel = (
    Save.isStoryCompleted(Historia.characterId) or Save.hasStoryCheckpoint()
  ) and "NUEVA HISTORIA" or "COMENZAR HISTORIA"
  drawButton(
    Historia.rects.new,
    newLabel,
    TextCache.format(
      "historia-new-sub",
      "Campaña de %s · mejoras y monedas se conservan",
      Data.characters[Historia.characterId].name
    ),
    { 0.78, 0.64, 1.00 },
    false
  )

  drawButton(
    Historia.rects.back,
    "VOLVER",
    nil,
    { 0.55, 0.68, 0.78 },
    false
  )

  if Historia.message and Historia.messageTimer > 0 then
    love.graphics.setFont(Fonts.body)
    love.graphics.setColor(1.00, 0.90, 0.50)
    love.graphics.printf(Historia.message, 0, panel.y + panel.h - 92, Screen.width, "center")
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.55, 0.60, 0.68)
  love.graphics.printf(
    "Teclado: 1-3 personaje · Enter continuar · N nueva historia · Esc volver",
    0,
    panel.y + panel.h - 26,
    Screen.width,
    "center"
  )

  if Historia.confirmNew then
    love.graphics.setColor(0, 0, 0, 0.62)
    love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)
    local modal = Historia.modal
    love.graphics.setColor(0.10, 0.07, 0.13, 0.99)
    love.graphics.rectangle("fill", modal.x, modal.y, modal.w, modal.h, 10, 10)
    love.graphics.setColor(0.85, 0.55, 0.55)
    love.graphics.rectangle("line", modal.x, modal.y, modal.w, modal.h, 10, 10)

    love.graphics.setFont(Fonts.button)
    love.graphics.setColor(1.00, 0.82, 0.72)
    love.graphics.printf("¿REINICIAR LA HISTORIA?", modal.x, modal.y + 18, modal.w, "center")
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(0.78, 0.82, 0.88)
    love.graphics.printf(
      "Se borrará el checkpoint en curso. Las historias completadas, mejoras y monedas se conservan.",
      modal.x + 30,
      modal.y + 58,
      modal.w - 60,
      "center"
    )

    drawButton(modal.yes, "REINICIAR", nil, { 0.95, 0.45, 0.40 }, false)
    drawButton(modal.no, "CANCELAR", nil, { 0.55, 0.85, 0.95 }, false)
  end
end

return Historia
