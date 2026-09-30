theme = {}

theme.name = "BarGlass"

local defaultSkin = "BarGlass"

theme.skin = {
  general = {
    skinName = defaultSkin,
  },

  imagelistview = {
  },

  icons = {
  },
}

function theme.GetDefaultSkin(class)
  local skinName

  repeat
    skinName = theme.skin[class.classname].skinName
    class = class.inherited
  until ((skinName)and(SkinHandler.IsValidSkin(skinName)))or(not class);

  if (not skinName)or(not SkinHandler.IsValidSkin(skinName)) then
    skinName = theme.skin.general.skinName
  end

  if (not skinName)or(not SkinHandler.IsValidSkin(skinName)) then
    skinName = "default"
  end

  return skinName
end

function theme.LoadThemeDefaults(control)
  if (theme.skin[control.classname])
    then table.merge(control,theme.skin[control.classname]) end
  table.merge(control,theme.skin.general)
end
