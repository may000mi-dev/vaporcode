-- historia.lua: entrada al Modo Historia con personaje global sincronizado.
local Data = require("src.run.data")
local Save = require("src.run.save")
local Fonts = require("src.utils.fonts")
local Util = require("src.utils.util")
local Screen = require("src.utils.screen")
local TextCache = require("src.utils.textcache")
local State = require("src.estados")
local Themes = require("src.data.themes")
local Audio = require("src.utils.audio")
local CharacterSelect = require("src.ui.character_select")

local Historia = {
  rects = {},
  confirmNew = false,
  message = nil,
  messageTimer = 0,
  selector = nil,
}

local function currentChapter()
  local story = Save.getStory()
  if not story or not story.active or not story.chapterId then return nil end
  return Data.story.chapterById[story.chapterId]
end

local function startNew()
  local cid = Save.getSelectedCharacter()
  Save.resetStory(cid)
  State.switch("run", "cripta", cid, nil, { mode = "story", chapterId = "cripta" })
end

local function continueStory()
  local story = Save.getStory()
  local chapter = currentChapter()
  if not chapter then
    Historia.message = "No hay una historia en curso para este personaje."
    Historia.messageTimer = 2.4
    return
  end
  local characterId = story.characterId
  if not Data.characters[characterId] or not Save.isCharacterUnlocked(characterId) then
    characterId = Save.getSelectedCharacter()
  end
  State.switch("run", chapter.dungeonId, characterId, nil, { resume = true })
end

local function requestNew()
  local cid = Save.getSelectedCharacter()
  if Save.hasStoryCheckpoint(cid) or Save.isStoryCompleted(cid) then
    Historia.confirmNew = true
  else
    startNew()
  end
end

function Historia.layout()
  local width = math.min(Screen.width - 60, 820)
  local height = math.min(Screen.height - 24, 500)
  local x = (Screen.width - width) * 0.5
  local y = (Screen.height - height) * 0.5
  Historia.panel = { x = x, y = y, w = width, h = height }
  Historia.selectorPanel = { x = x, y = y, w = width, cardY = 72, cardH = 48, screenW = Screen.width, screenH = Screen.height }
  if Historia.selector then Historia.selector:layout(Historia.selectorPanel) end

  local hasContinue = Save.hasStoryCheckpoint() and currentChapter() ~= nil
  local buttonX = x + 40
  local buttonWide = width - 80
  Historia.rects.continue = hasContinue
    and { x = buttonX, y = y + 230, w = buttonWide, h = 52 }
    or nil
  Historia.rects.new = {
    x = buttonX,
    y = hasContinue and y + 294 or y + 230,
    w = buttonWide,
    h = 52,
  }
  Historia.rects.back = { x = x + width - 220, y = y + height - 54, w = 180, h = 38 }

  local modalW, modalH = 460, 190
  local modalX = (Screen.width - modalW) * 0.5
  local modalY = (Screen.height - modalH) * 0.5
  Historia.modal = {
    x = modalX, y = modalY, w = modalW, h = modalH,
    yes = { x = modalX + 30, y = modalY + 122, w = 180, h = 42 },
    no = { x = modalX + modalW - 210, y = modalY + 122, w = 180, h = 42 },
  }
end

function Historia.enter()
  Historia.confirmNew = false
  Historia.message = nil
  Historia.messageTimer = 0
  Historia.selector = CharacterSelect.new({ getZone = function() return "menu" end })
  Historia.layout()
  Audio.playZone("menu", Save.getSelectedCharacter())
end

function Historia.update(dt)
  if Historia.messageTimer > 0 then
    Historia.messageTimer = math.max(0, Historia.messageTimer - dt)
    if Historia.messageTimer == 0 then Historia.message = nil end
  end
end

function Historia.keypressed(key, isrepeat)
  if isrepeat then return end
  if Historia.confirmNew then
    if key == "escape" or key == "backspace" then Historia.confirmNew = false
    elseif key == "return" or key == "space" then Historia.confirmNew = false; startNew() end
    return
  end
  if Historia.selector and Historia.selector:keypressed(key) then return end
  if key == "escape" or key == "backspace" then State.switch("menu")
  elseif key == "return" or key == "space" then
    if Save.hasStoryCheckpoint() then continueStory() else requestNew() end
  elseif key == "n" then requestNew() end
end

function Historia.pressed(x, y)
  Historia.layout()
  if Historia.confirmNew then
    if Util.inside(x, y, Historia.modal.yes) then Historia.confirmNew = false; startNew()
    elseif Util.inside(x, y, Historia.modal.no) then Historia.confirmNew = false end
    return
  end
  if Historia.selector and Historia.selector:pressed(x, y) then return end
  if Historia.selector and Historia.selector.confirm then return end
  if Historia.rects.continue and Util.inside(x, y, Historia.rects.continue) then continueStory(); return end
  if Util.inside(x, y, Historia.rects.new) then requestNew(); return end
  if Util.inside(x, y, Historia.rects.back) then State.switch("menu") end
end

function Historia.mousepressed(x, y, button) if button == 1 then Historia.pressed(x, y) end end
function Historia.touchpressed(id, x, y) Historia.pressed(x, y) end
function Historia.mousemoved() end
function Historia.mousereleased() end
function Historia.touchmoved() end
function Historia.touchreleased() end
function Historia.focus(focused) if focused then Audio.resumeMusic() end end

local function drawButton(rect, label, sub, accent, selected, theme)
  local bg = selected and theme.buttonSelected or theme.button
  love.graphics.setColor(bg[1], bg[2], bg[3], 0.98)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setColor(accent[1], accent[2], accent[3])
  love.graphics.setLineWidth(selected and 3 or 2)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setLineWidth(1)
  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf(label, rect.x + 10, rect.y + (sub and 6 or 14), rect.w - 20, "center")
  if sub then
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
    love.graphics.printf(sub, rect.x + 8, rect.y + rect.h - 18, rect.w - 16, "center")
  end
end

function Historia.draw()
  Historia.layout()
  local theme = Themes.current()
  local panel = Historia.panel

  love.graphics.setColor(theme.bg[1], theme.bg[2], theme.bg[3])
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.05)
  love.graphics.circle("fill", 30, Screen.height - 20, 150)

  love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.98)
  love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 12, 12)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.printf("MODO HISTORIA", panel.x, panel.y + 14, panel.w, "center")
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.printf("La última nota · campaña con personaje global", panel.x, panel.y + 48, panel.w, "center")

  local selectorPanel = {
    x = panel.x, y = panel.y, w = panel.w,
    cardY = 72, cardH = 48, screenW = Screen.width, screenH = Screen.height,
  }
  if Historia.selector then Historia.selector:draw(selectorPanel) end

  local chapter = currentChapter()
  local selected = Data.characters[Save.getSelectedCharacter()]
  local story = Save.getStory(selected.id)
  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  if chapter then
    love.graphics.printf(TextCache.format("historia-progress", "%s · piso %d · %s",
      chapter.name, story.depth, Data.characters[story.characterId].name),
      panel.x + 40, panel.y + 140, panel.w - 80, "center")
  else
    local done = Save.isStoryCompleted(selected.id)
    local msg = done and ("Historia completada con " .. selected.name .. ".")
      or "Rescata a la familia antes de que el tiempo se detenga."
    love.graphics.printf(msg, panel.x + 40, panel.y + 140, panel.w - 80, "center")
  end
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.printf(TextCache.format("historia-count",
    "%d/%d historias completadas · usa las tarjetas para cambiar personaje",
    Save.storyCompletionCount(), #Data.characterOrder),
    panel.x + 40, panel.y + 166, panel.w - 80, "center")

  if Historia.rects.continue then
    drawButton(Historia.rects.continue, "CONTINUAR HISTORIA",
      "Retoma desde el inicio del último piso guardado", theme.accent, true, theme)
  end
  local cid = Save.getSelectedCharacter()
  local newLabel = (Save.isStoryCompleted(cid) or Save.hasStoryCheckpoint(cid)) and "NUEVA HISTORIA" or "COMENZAR HISTORIA"
  drawButton(Historia.rects.new, newLabel,
    "Campaña de " .. selected.name .. " · mejoras y monedas se conservan",
    theme.secondary, false, theme)
  drawButton(Historia.rects.back, "VOLVER", nil, theme.border, false, theme)

  if Historia.message and Historia.messageTimer > 0 then
    love.graphics.setFont(Fonts.body)
    love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
    love.graphics.printf(Historia.message, 0, panel.y + panel.h - 88, Screen.width, "center")
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
  love.graphics.printf("Enter continuar · N nueva historia · Esc volver",
    0, panel.y + panel.h - 22, Screen.width, "center")

  if Historia.confirmNew then
    love.graphics.setColor(0, 0, 0, 0.62)
    love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)
    local modal = Historia.modal
    love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.99)
    love.graphics.rectangle("fill", modal.x, modal.y, modal.w, modal.h, 10, 10)
    love.graphics.setColor(0.85, 0.55, 0.55)
    love.graphics.rectangle("line", modal.x, modal.y, modal.w, modal.h, 10, 10)
    love.graphics.setFont(Fonts.button)
    love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
    love.graphics.printf("¿REINICIAR LA HISTORIA?", modal.x, modal.y + 18, modal.w, "center")
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
    love.graphics.printf(
      TextCache.format("historia-reset-warning",
        "Se borrará el checkpoint de %s. Los demás personajes, las historias completadas, mejoras y monedas se conservan.",
        selected.name),
      modal.x + 30, modal.y + 58, modal.w - 60, "center")
    drawButton(modal.yes, "REINICIAR", nil, {0.95,0.45,0.40}, false, theme)
    drawButton(modal.no, "CANCELAR", nil, theme.accent, false, theme)
  end

  if Historia.selector then Historia.selector:drawConfirm(selectorPanel) end
end

return Historia
