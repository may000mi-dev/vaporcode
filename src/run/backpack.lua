-- backpack.lua: interacción de la mochila; 5 activos y 15 guardados.
-- Activar pasivas/mascotas usa un hueco libre o pide intercambio; las
-- habilidades se asignan a A1/A2 directamente desde los guardados.
local Data = require("src.run.data")
local Util = require("src.utils.util")
local View = require("src.run.backpack_view")

local Backpack = {
  panel = View.panel,
  closeButton = View.closeButton,
  cancelButton = View.cancelButton,
  activeRect = View.activeRect,
  storageRect = View.storageRect,
  actionRect = View.actionRect,
  draw = View.draw,
  layout = View.layout,
}

local function slotAt(first, last, rectFn, x, y)
  for index = first, last do
    if Util.inside(x, y, rectFn(index)) then
      return index
    end
  end
  return nil
end

function Backpack.pressed(run, x, y)
  View.layout()
  if Util.inside(x, y, Backpack.closeButton) then
    run.overlay = nil
    run.pendingStorageIndex = nil
    return true
  end

  if run.pendingStorageIndex then
    if Util.inside(x, y, Backpack.cancelButton) then
      run.pendingStorageIndex = nil
      return true
    end
    local activeIndex = slotAt(1, Data.inventory.maxActive, Backpack.activeRect, x, y)
    if activeIndex then
      run:swapActiveForStored(activeIndex, run.pendingStorageIndex)
      run.pendingStorageIndex = nil
      run.selectionSection = "active"
      run.selectedInventory = activeIndex
      return true
    end
    return Util.inside(x, y, Backpack.panel)
  end

  local activeIndex = slotAt(1, Data.inventory.maxActive, Backpack.activeRect, x, y)
  if activeIndex then
    run.selectionSection = "active"
    run.selectedInventory = activeIndex
    return true
  end

  local storageIndex = slotAt(1, Data.inventory.maxInactive, Backpack.storageRect, x, y)
  if storageIndex then
    run.selectionSection = "inactive"
    run.selectedStorage = storageIndex
    return true
  end

  local section, index, slot, def = run:selectedSlot()
  if def then
    if Util.inside(x, y, Backpack.actionRect(1)) then
      if section == "active" then
        if run:storeActive(index) == "full" then
          run:notify("Guardados llenos", { 1.00, 0.45, 0.35 })
        end
      elseif run:activateStored(index) == "needs_swap" then
        run.pendingStorageIndex = index
      end
      return true
    elseif Util.inside(x, y, Backpack.actionRect(2)) then
      if section == "inactive" then run:equipStoredAbility(index, 1) end
      return true
    elseif Util.inside(x, y, Backpack.actionRect(3)) then
      if section == "inactive" then run:equipStoredAbility(index, 2) end
      return true
    elseif Util.inside(x, y, Backpack.actionRect(4)) then
      run:removeItemAt(section, index)
      return true
    end
  elseif slot then
    return true
  end

  return Util.inside(x, y, Backpack.panel)
end

return Backpack
