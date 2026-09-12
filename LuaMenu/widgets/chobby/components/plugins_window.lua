

local json = json or VFS.Include and VFS.Include("libs/json.lua") or nil

PluginsWindow = LCS.class{}


local DEFAULT_CDN = {
    base          = "https://widget-hub.beyondallreason.dev",
    manifest      = "/manifests.json",
    resources     = "/sites/%s",
    distributions = "/distributions/%s.zip",
}

local gitRepoInfo      = nil
local sourceWidgetDirs = {}
local sourceWidgetFiles= {}
local sourceManifestPending = { count = 0, done = 0, failed = 0 }
local sourceInstalls   = {}
local trackedFileInstalls = {}
local gitWidgetDirs        = {}
local gitWidgetManifests   = {}
local sourceWidgetFileLists= {}

local function parseHubValue(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    local text = value:gsub("%s+", ""):gsub("/+$", "")
    local function asGitRepo(gitOwner, gitRepo, branch)
        local explicit = branch ~= nil
        branch = branch or "main"
        return {
            base = "https://raw.githubusercontent.com/" .. gitOwner .. "/" .. gitRepo .. "/" .. branch,
            gitOwner = gitOwner,
            gitRepo = gitRepo,
            branch = branch,
            explicitBranch = explicit,
        }
    end

    if string.match(text, "^https?://") then
        local norm = text:gsub("^https?://www%.github%.com/", "https://github.com/")
        local ghOwner, ghRepo, ghBranch = string.match(norm, "^https?://github%.com/([%w%.%-_]+)/([%w%.%-_]+)/tree/([%w%.%-_/]+)$")
        if not ghOwner then
            ghOwner, ghRepo = string.match(norm, "^https?://github%.com/([%w%.%-_]+)/([%w%.%-_]+)$")
        end
        if ghOwner then
            return asGitRepo(ghOwner, ghRepo, ghBranch)
        end
        return { base = text }
    end

    local owner, repo, branch = string.match(text, "^([%w%.%-_]+)/([%w%.%-_]+)@([%w%.%-_]+)$")
    if not owner then
        owner, repo = string.match(text, "^([%w%.%-_]+)/([%w%.%-_]+)$")
    end
    if owner then
        return asGitRepo(owner, repo, branch)
    end
    return nil
end

local function applyGitRepoInfo(parsed)
    local sameRepo = gitRepoInfo
        and gitRepoInfo.gitOwner == parsed.gitOwner
        and gitRepoInfo.gitRepo == parsed.gitRepo
    local branch = parsed.branch
    if not parsed.explicitBranch and sameRepo and gitRepoInfo.branch then
        branch = gitRepoInfo.branch
    end
    return {
        gitOwner = parsed.gitOwner,
        gitRepo = parsed.gitRepo,
        branch = branch,
        explicitBranch = parsed.explicitBranch,
    }
end

local function getConfiguredCdn()
    local cdn = {}
    for key, value in pairs(DEFAULT_CDN) do
        cdn[key] = value
    end

    local Configuration = WG.Chobby and WG.Chobby.Configuration
    local configured = Configuration
        and (Configuration.pluginsCdnUrl
            or (Configuration.gameConfig and Configuration.gameConfig.pluginsCdnUrl))

    if type(configured) == "string" then
        local parsed = parseHubValue(configured)
        if parsed then
            if parsed.gitOwner then
                gitRepoInfo = applyGitRepoInfo(parsed)
            end
            cdn.base = parsed.base
        end
    elseif type(configured) == "table" then
        if type(configured.base) == "string" and configured.base ~= "" then
            local parsed = parseHubValue(configured.base)
            if parsed then
                if parsed.gitOwner then
                    gitRepoInfo = applyGitRepoInfo(parsed)
                end
                cdn.base = parsed.base
            end
        end
        for _, key in ipairs({ "manifest", "resources", "distributions" }) do
            if type(configured[key]) == "string" and configured[key] ~= "" then
                cdn[key] = configured[key]
            end
        end
    end

    if gitRepoInfo and gitRepoInfo.gitOwner then
        cdn.base = "https://raw.githubusercontent.com/" .. gitRepoInfo.gitOwner .. "/" .. gitRepoInfo.gitRepo .. "/" .. (gitRepoInfo.branch or "main")
    end

    cdn.base = cdn.base:gsub("%s+", ""):gsub("/+$", "")
    return cdn
end

local function resetGitHubState()
    gitRepoInfo = nil
    sourceWidgetDirs = {}
    sourceWidgetFiles = {}
    sourceManifestPending = { count = 0, done = 0, failed = 0 }
    sourceInstalls = {}
local trackedFileInstalls = {}
    gitWidgetDirs = {}
    gitWidgetManifests = {}
    sourceWidgetFileLists = {}
end

local function getManifestUrl()
    local cdn = getConfiguredCdn()
    return cdn.base .. cdn.manifest
end

local MANIFEST_DEST    = "LuaUI/Widgets/manifests.json"
local MANIFEST_NAME    = "plugin_manifest"

local GIT_TREE_NAME    = "git_repo_tree"
local GIT_TREE_DEST    = "LuaUI/Widgets/git_repo_tree.json"
local GIT_SRC_MANIFEST_PREFIX = "git_widget_manifest_"
local GIT_SRC_MANIFESTS_DIR   = "LuaUI/Widgets/git_source_manifests/"

local PLUGINS_DIR         = "plugins/"
local IMG_FALLBACK_LARGE  = "LuaMenu/images/load_img_512.png"
local IMG_FALLBACK_MEDIUM = "LuaMenu/images/load_img_128.png"
local IMG_SOURCE          = "LuaMenu/images/source.png"
local IMG_DISCORD         = "LuaMenu/images/Discord-Symbol-White.png"

local ITEM_MIN_WIDTH   = 300
local ITEM_HEIGHT      = 240
local ITEMS_PER_PAGE   = 10
local HEADER_HEIGHT    = 48
local HEADER_ROW_GAP   = 4
local HEADER_TOTAL_HEIGHT = HEADER_HEIGHT * 2 + HEADER_ROW_GAP
local PAGINATION_HEIGHT = 40

local STATE_LOADING    = "loading"
local STATE_LOADED     = "loaded"
local STATE_ERROR      = "error"


local widgetsList      = {}
local widgetPanelCache = {}
local currentFilter    = ""
local currentPage      = 1
local loadState        = STATE_LOADING
local loadError        = nil

local mainGrid         = nil
local scrollPanel      = nil
local pageLabel        = nil
local statusLabel      = nil
local detailWindow     = nil
local searchBox        = nil
local detailReadmeBox  = nil
local detailCoverImage = nil
local detailWidgetId   = nil
local updateAllButton  = nil
local hubButton        = nil

local installingWidgets = {}
local installedWidgets  = {}
local upgradeBackups    = {}
local installedLastUpdatedCache = {}

local downloadToWidgetId = {}
local cardImageRefs      = {}
local refreshPending     = false


local function containsText(haystack, needle)
    if not haystack or not needle or needle == "" then return true end
    return string.find(string.lower(haystack), string.lower(needle), 1, true) ~= nil
end


local function clamp(val, lo, hi)
    if val < lo then return lo end
    if val > hi then return hi end
    return val
end


local function hasLink(url)
    return type(url) == "string" and url ~= ""
end


local function compareTimestamps(t1, t2)
    if not t1 and not t2 then return 0 end
    if not t1 then return -1 end
    if not t2 then return 1 end
    if t1 == t2 then return 0 end
    if t1 < t2 then return -1 end
    return 1
end


local function getThumbnailPath(widgetId)
    return PLUGINS_DIR .. widgetId .. "_325x100.png"
end

local function getCoverPath(widgetId)
    return PLUGINS_DIR .. widgetId .. "_460x300.png"
end

local function getReadmePath(widgetId)
    return PLUGINS_DIR .. widgetId .. "_README.md"
end

local function getDistributionUrl(widgetId)
    local cdn = getConfiguredCdn()
    return cdn.base .. cdn.distributions:gsub("%%s", function() return widgetId end)
end

local function getInstallPath(widgetId)
    return "LuaUI/Widgets/" .. widgetId
end

local function getWidgetDisplayName(widgetId)
    for _, widget in ipairs(widgetsList) do
        if widget.id == widgetId then
            return widget.display_name or widget.name or widgetId
        end
    end
    return widgetId
end


local function isWidgetInstalled(widgetId)
    if installedWidgets[widgetId] then return true end
    local installDir = getInstallPath(widgetId) .. "/"
    local files = VFS.DirList(installDir)
    if files and #files > 0 then
        installedWidgets[widgetId] = true
        return true
    end
    return false
end


local function createDirForFile(filePath)
    local dir = string.match(filePath, "^(.+)/[^/]+$")
    if not dir or dir == "" then return end
    local prefix = ""
    for part in string.gmatch(dir, "[^/]+") do
        prefix = prefix == "" and part or (prefix .. "/" .. part)
        Spring.CreateDir(prefix)
    end
end

local function queueSourceWidgetFiles(widget, kind)
    local widgetId = widget.id
    local files = widget._srcFiles or (sourceWidgetFiles and sourceWidgetFiles[widgetId])
    local widgetDir = widget._srcDir or (sourceWidgetDirs and sourceWidgetDirs[widgetId])
    if not files or #files == 0 or not widgetDir then
        return false
    end
    if not (WG.DownloadHandler and WG.DownloadHandler.QueueDownload) then
        return false
    end
    local installDir = getInstallPath(widgetId)
    local base = getConfiguredCdn().base
    trackedFileInstalls[widgetId] = { kind = kind, total = #files, done = 0 }
    for i, relPath in ipairs(files) do
        local relToWidget = string.sub(relPath, #widgetDir + 2)
        local destFile = installDir .. "/" .. relToWidget
        Spring.CreateDir(installDir)
        createDirForFile(destFile)
        local downloadName = (kind == "upgrade" and "srcup_" or "srcinst_") .. widgetId .. "_" .. i
        sourceInstalls[downloadName] = widgetId
        WG.DownloadHandler.QueueDownload(downloadName, "resource", -1, 0, {
            url = base .. "/" .. relPath,
            destination = destFile,
            extract = false,
        })
    end
    return true
end

local function installWidget(widget)
    local widgetId = widget.id or widget.name or "unknown"
    if installingWidgets[widgetId] then return end

    installingWidgets[widgetId] = true

    if widget._srcDir or (sourceWidgetDirs and sourceWidgetDirs[widgetId]) then
        if not queueSourceWidgetFiles(widget, "install") then
            installingWidgets[widgetId] = nil
            Spring.Echo("[PluginsWindow] Cannot install git-sourced widget (no files known): " .. widgetId)
        end
        return
    end

    local installDir = getInstallPath(widgetId)

    local downloadName = "install_" .. widgetId
    local url = getDistributionUrl(widgetId)

    if WG.DownloadHandler and WG.DownloadHandler.QueueDownload then
        WG.DownloadHandler.QueueDownload(downloadName, "resource", -1, 0, {
            url = url,
            destination = installDir,
            extract = true,
        })
        Spring.Echo("[PluginsWindow] Installing widget: " .. widgetId)
    else
        installingWidgets[widgetId] = nil
        Spring.Echo("[PluginsWindow] Cannot install: DownloadHandler not available")
    end
end

local INSTALL_DISCLAIMER_PREF_KEY = "pluginsInstallDisclaimerAccepted"

local function confirmAndInstall(widget, afterInstall)
    local function doInstall()
        installWidget(widget)
        if afterInstall then afterInstall() end
    end

    local Configuration = WG.Chobby and WG.Chobby.Configuration
    if Configuration and Configuration[INSTALL_DISCLAIMER_PREF_KEY] then
        doInstall()
    elseif WG.Chobby and WG.Chobby.ConfirmationPopup then
        WG.Chobby.ConfirmationPopup(
            doInstall,
            i18n("plugins_install_disclaimer"),
            INSTALL_DISCLAIMER_PREF_KEY,
            440,
            280,
            "plugins_install",
            "cancel"
        )
    else
        doInstall()
    end
end


local function getInstalledLastUpdated(widgetId)
    local manifestPath = getInstallPath(widgetId) .. "/manifest.json"
    local content = VFS.LoadFile(manifestPath)
    if not content then
        local f = io.open(manifestPath, "r")
        if f then
            content = f:read("*all")
            f:close()
        end
    end
    if not content then return nil end
    if not json then VFS.Include("libs/json.lua") end
    local ok, data = pcall(function() return json.decode(content) end)
    if ok and type(data) == "table" then
        return data.last_updated
    end
    return nil
end

local function getInstalledLastUpdatedCached(widgetId)
    local cached = installedLastUpdatedCache[widgetId]
    if cached ~= nil then
        return cached or nil
    end
    local value = getInstalledLastUpdated(widgetId)
    installedLastUpdatedCache[widgetId] = value or false
    return value
end

local function isUpgradeAvailable(widget)
    local widgetId = widget and widget.id
    if not (widgetId and widget.last_updated and isWidgetInstalled(widgetId)) then
        return false
    end
    return compareTimestamps(getInstalledLastUpdatedCached(widgetId), widget.last_updated) < 0
end

local function getUpgradableWidgets()
    local upgradable = {}
    for _, widget in ipairs(widgetsList) do
        if isUpgradeAvailable(widget) and not installingWidgets[widget.id] then
            upgradable[#upgradable + 1] = widget
        end
    end
    return upgradable
end

local function updateUpdateAllButton()
    if not updateAllButton then return end
    local upgradable = getUpgradableWidgets()
    if #upgradable > 0 then
        local lines = { i18n("plugins_update_all_tooltip") }
        for i, widget in ipairs(upgradable) do
            lines[i + 1] = "- " .. getWidgetDisplayName(widget.id)
        end
        updateAllButton.tooltip = table.concat(lines, "\n")
    end
    updateAllButton:SetVisibility(#upgradable > 0)
end

local function renameLuaFilesRecursive(dirPath)
    local dir = dirPath
    if string.sub(dir, -1) ~= "/" then dir = dir .. "/" end
    local luaFiles = VFS.DirList(dir, "*.lua")
    if luaFiles then
        for _, luaFile in ipairs(luaFiles) do
            os.rename(luaFile, luaFile .. ".backup")
        end
    end
    local subDirs = VFS.SubDirs(dir)
    if subDirs then
        for _, subDir in ipairs(subDirs) do
            renameLuaFilesRecursive(subDir)
        end
    end
end

local function backupDirectory(dirPath)
    local cleanPath = dirPath
    if string.sub(cleanPath, -1) == "/" then
        cleanPath = string.sub(cleanPath, 1, -2)
    end
    local stamp = os.date("%Y%m%d_%H%M%S")
    local backupPath = cleanPath .. "_backup_" .. stamp
    local ok, err = os.rename(cleanPath, backupPath)
    if ok then
        Spring.Echo("[PluginsWindow] Backed up directory: " .. cleanPath .. " -> " .. backupPath)
        renameLuaFilesRecursive(backupPath)
    else
        Spring.Echo("[PluginsWindow] Failed to backup directory: " .. tostring(cleanPath) .. " - " .. tostring(err))
    end
    return ok, backupPath
end

local function upgradeWidget(widget)
    local widgetId = widget.id
    if installingWidgets[widgetId] then
        Spring.Echo("[PluginsWindow] Upgrade already in progress for " .. widgetId .. ", skipping")
        return
    end
    Spring.Echo("[PluginsWindow] Upgrading " .. widgetId .. " (installed: " .. tostring(getInstalledLastUpdatedCached(widgetId)) .. ", available: " .. tostring(widget.last_updated) .. ")")

    local installDir = getInstallPath(widgetId)
    local ok, backupPath = backupDirectory(installDir)
    if not ok then
        Spring.Echo("[PluginsWindow] Cannot upgrade " .. widgetId .. ": failed to backup existing install")
        return
    end

    installingWidgets[widgetId] = true
    upgradeBackups[widgetId] = backupPath

    if widget._srcDir or (sourceWidgetDirs and sourceWidgetDirs[widgetId]) then
        if not queueSourceWidgetFiles(widget, "upgrade") then
            os.rename(backupPath, installDir)
            installingWidgets[widgetId] = nil
            upgradeBackups[widgetId] = nil
            Spring.Echo("[PluginsWindow] Cannot upgrade git-sourced widget (no files known): " .. widgetId)
        end
        return
    end

    local downloadName = "upgrade_" .. widgetId
    local url = getDistributionUrl(widgetId) .. "?t=" .. os.time()

    if WG.DownloadHandler and WG.DownloadHandler.QueueDownload then
        WG.DownloadHandler.QueueDownload(downloadName, "resource", -1, 0, {
            url = url,
            destination = installDir,
            extract = true,
        })
        Spring.Echo("[PluginsWindow] Queued upgrade download to: " .. installDir)
    else
        os.rename(backupPath, installDir)
        installingWidgets[widgetId] = nil
        upgradeBackups[widgetId] = nil
        Spring.Echo("[PluginsWindow] Cannot upgrade: DownloadHandler not available")
    end
end

local function checkForUpgrades()
    if #widgetsList == 0 then return end

    local upgradable = getUpgradableWidgets()
    if #upgradable == 0 then return end

    local Configuration = WG.Chobby and WG.Chobby.Configuration
    if Configuration and not Configuration.autoUpdateWidgets then
        local body
        if #upgradable == 1 then
            body = i18n("plugins_update_available_notification", { name = getWidgetDisplayName(upgradable[1].id) })
        else
            body = i18n("plugins_updates_available_notification", { count = #upgradable })
        end
        Chotify:Post({
            title = i18n("plugins_title"),
            body = body,
            time = 10,
        })
        return
    end

    for _, widget in ipairs(upgradable) do
        upgradeWidget(widget)
    end
end


local function ensureDirectoryExists(filePath)
    local dir = string.match(filePath, "^(.+)/[^/]+$")
    if dir then Spring.CreateDir(dir) end
end

local ASSET_PRIORITY_CURRENT = 3
local ASSET_PRIORITY_PREFETCH = 1

local function downloadAsset(downloadName, cdnPath, localPath, priority)
    if VFS.FileExists(localPath) then
        return localPath
    end

    ensureDirectoryExists(localPath)

    local url = getConfiguredCdn().base .. cdnPath
    if WG.DownloadHandler and WG.DownloadHandler.MaybeDownloadArchive then
        WG.DownloadHandler.MaybeDownloadArchive(downloadName, "resource", priority or ASSET_PRIORITY_CURRENT, {
            url = url,
            destination = localPath,
            extract = false,
            hidden = true,
        })
    end
    return nil
end

local function ensureThumbnail(widget, priority)
    local id = widget.id or "unknown"
    local localPath = getThumbnailPath(id)
    local cdn = getConfiguredCdn()
    local cdnPath
    if widget._srcDir then
        cdnPath = "/" .. widget._srcDir .. "/cover.png"
    else
        cdnPath = cdn.resources:gsub("%%s", function() return id end) .. "/" .. id .. "_325x100.png"
    end
    local result = downloadAsset(id .. "_thumb", cdnPath, localPath, priority)
    return result or IMG_FALLBACK_MEDIUM
end

local function ensureCover(widget, priority)
    local id = widget.id or "unknown"
    local localPath = getCoverPath(id)
    local cdn = getConfiguredCdn()
    local cdnPath
    if widget._srcDir then
        cdnPath = "/" .. widget._srcDir .. "/cover.png"
    else
        cdnPath = cdn.resources:gsub("%%s", function() return id end) .. "/" .. id .. "_460x300.png"
    end
    local result = downloadAsset(id .. "_cover", cdnPath, localPath, priority)
    return result or IMG_FALLBACK_LARGE
end

local function ensureReadme(widget, priority)
    local id = widget.id or "unknown"
    local localPath = getReadmePath(id)
    local cdn = getConfiguredCdn()
    local cdnPath
    if widget._srcDir then
        cdnPath = "/" .. widget._srcDir .. "/README.md"
    else
        cdnPath = cdn.resources:gsub("%%s", function() return id end) .. "/" .. id .. ".md"
    end
    downloadAsset(id .. "_readme", cdnPath, localPath, priority)
    return localPath
end


local function matchesFilter(widget, filter)
    if not filter or filter == "" then return true end
    if containsText(widget.name, filter) then return true end
    if containsText(widget.author, filter) then return true end
    if containsText(widget.description, filter) then return true end
    if widget.tags then
        for _, tag in ipairs(widget.tags) do
            if containsText(tag, filter) then return true end
        end
    end
    return false
end

local function getFilteredWidgets()
    if currentFilter == "" then
        return widgetsList
    end
    local results = {}
    for _, widget in ipairs(widgetsList) do
        if matchesFilter(widget, currentFilter) then
            results[#results + 1] = widget
        end
    end
    return results
end


local function getTotalPages(filteredCount)
    if filteredCount <= 0 then return 1 end
    return math.ceil(filteredCount / ITEMS_PER_PAGE)
end

local function getPageSlice(filteredList, page)
    local startIdx = (page - 1) * ITEMS_PER_PAGE + 1
    local endIdx = math.min(startIdx + ITEMS_PER_PAGE - 1, #filteredList)
    local slice = {}
    for i = startIdx, endIdx do
        slice[#slice + 1] = filteredList[i]
    end
    return slice
end


local function closeDetail()
    if detailWindow then
        detailWindow:Dispose()
        detailWindow = nil
        detailReadmeBox = nil
        detailCoverImage = nil
        detailWidgetId = nil
    end
end

local function openDetail(widget)
    closeDetail()

    local coverPath = ensureCover(widget)
    local readmePath = ensureReadme(widget)
    local readmeContent = VFS.LoadFile(readmePath) or i18n("plugins_readme_loading")
    local widgetId = widget.id or widget.name or "unknown"
    detailWidgetId = widgetId

    detailWindow = Window:New {
        x = "15%",
        y = "10%",
        right = "15%",
        bottom = "10%",
        caption = "",
        resizable = false,
        draggable = false,
        parent = WG.Chobby.lobbyInterfaceHolder,
        classname = "main_window",
        OnDispose = {
            function()
                detailWindow = nil
            end
        },
    }

    Label:New {
        caption = widget.name or i18n("plugins_unknown_widget"),
        x = 15,
        y = 8,
        right = 100,
        height = 30,
        objectOverrideFont = WG.Chobby.Configuration:GetFont(4),
        valign = "center",
        parent = detailWindow,
    }

    Button:New {
        right = 8,
        y = 5,
        width = 80,
        height = 40,
        caption = i18n("close"),
        objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
        classname = "negative_button",
        OnClick = { function() closeDetail() end },
        parent = detailWindow,
    }

    local metaY = 40
    Label:New {
        caption = i18n("plugins_by_author", { author = widget.author or i18n("plugins_unknown_author") }),
        x = 15,
        y = metaY,
        width = 300,
        height = 22,
        objectOverrideFont = WG.Chobby.Configuration:GetFont(2),
        parent = detailWindow,
    }

    if widget.version then
        Label:New {
            caption = "v" .. widget.version,
            x = 250,
            y = metaY,
            width = 100,
            height = 22,
            objectOverrideFont = WG.Chobby.Configuration:GetFont(2),
            parent = detailWindow,
        }
    end

    if widget.tags and #widget.tags > 0 then
        local tagStr = table.concat(widget.tags, ", ")
        Label:New {
            caption = i18n("plugins_tags", { tags = tagStr }),
            x = 15,
            y = metaY + 22,
            right = 15,
            height = 20,
            fontSize = 12,
            parent = detailWindow,
        }
    end

    local contentY = metaY + 48

    ScrollPanel:New {
        x = 10,
        y = contentY,
        width = "58%",
        bottom = 15,
        horizontalScrollbar = false,
        borderColor = {0, 0, 0, 0},
        parent = detailWindow,
        children = {
            (function()
                local tb = TextBox:New {
                    x = 5,
                    y = 5,
                    right = 5,
                    bottom = 5,
                    text = readmeContent,
                    objectOverrideFont = WG.Chobby.Configuration:GetFont(2),
                }
                detailReadmeBox = tb
                return tb
            end)(),
        },
    }

    local rightX = "62%"

    do
        local img = Image:New {
            x = rightX,
            y = contentY,
            right = 10,
            height = "40%",
            keepAspect = true,
            checkFileExists = true,
            file = coverPath,
            fallbackFile = IMG_FALLBACK_LARGE,
            parent = detailWindow,
        }
        detailCoverImage = img
    end

    local actionBottom = 15
    local function nextActionBottom()
        local value = actionBottom
        actionBottom = actionBottom + 55
        return value
    end

    if hasLink(widget.discord_link) then
        Button:New {
            caption = i18n("plugins_discord"),
            x = rightX,
            bottom = nextActionBottom(),
            right = 10,
            height = 45,
            objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
            OnClick = {
                function()
                    WG.WrapperLoopback.OpenUrl(widget.discord_link)
                end
            },
            parent = detailWindow,
        }
    end

    if hasLink(widget.github_link) then
        Button:New {
            caption = i18n("plugins_source"),
            x = rightX,
            bottom = nextActionBottom(),
            right = 10,
            height = 45,
            objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
            OnClick = {
                function()
                    WG.WrapperLoopback.OpenUrl(widget.github_link)
                end
            },
            parent = detailWindow,
        }
    end

    if hasLink(widget.homepage) then
        Button:New {
            caption = i18n("plugins_homepage"),
            x = rightX,
            bottom = nextActionBottom(),
            right = 10,
            height = 45,
            objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
            OnClick = {
                function()
                    WG.WrapperLoopback.OpenUrl(widget.homepage)
                end
            },
            parent = detailWindow,
        }
    end

    local upgradeAvailable = isUpgradeAvailable(widget)
    Button:New {
        caption = (installingWidgets[widgetId] and i18n("plugins_installing"))
            or (upgradeAvailable and i18n("plugins_update"))
            or (isWidgetInstalled(widgetId) and i18n("plugins_installed"))
            or i18n("plugins_install"),
        x = rightX,
        bottom = nextActionBottom(),
        right = 10,
        height = 45,
        objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
        classname = (isWidgetInstalled(widgetId) and not upgradeAvailable) and "option_button" or "action_button",
        OnClick = {
            function()
                if installingWidgets[widgetId] then
                    return
                end
                if isUpgradeAvailable(widget) then
                    upgradeWidget(widget)
                    updateUpdateAllButton()
                elseif not isWidgetInstalled(widgetId) then
                    confirmAndInstall(widget)
                end
            end
        },
        parent = detailWindow,
    }

    PriorityPopup(detailWindow, closeDetail, nil, nil, nil, true)
end


local scheduleRefresh
local fetchManifest

local function createWidgetCard(widget, itemWidth)
    local id = widget.id
    if id and widgetPanelCache[id] then
        return widgetPanelCache[id]
    end

    local thumbPath = ensureThumbnail(widget)

    local thumbImage = Image:New {
        file = thumbPath,
        x = 0,
        y = 0,
        width = "100%",
        height = 100,
        keepAspect = true,
        checkFileExists = true,
        fallbackFile = IMG_FALLBACK_MEDIUM,
    }
    if id then
        cardImageRefs[id] = thumbImage
    end

    local cardHeight = ITEM_HEIGHT
    local card = Panel:New {
        width = itemWidth,
        height = cardHeight,
        padding = {4, 4, 4, 4},
        children = {
            thumbImage,
            Label:New {
                caption = widget.name or i18n("plugins_unnamed_widget"),
                x = 8,
                y = 105,
                right = 8,
                height = 40,
                fontSize = 16,
                autosize = false,
                wordwrap = true,
            },
            Label:New {
                caption = i18n("plugins_by_author", { author = widget.author or i18n("plugins_unknown_author") }),
                x = 8,
                y = 135,
                right = 8,
                height = 20,
                fontSize = 12,
                autosize = false,
            },
            Label:New {
                caption = widget.description or "",
                x = 8,
                y = 150,
                right = 8,
                height = 40,
                fontSize = 14,
                autosize = false,
                wordwrap = true,
            },
            Button:New {
                caption = (installingWidgets[id] and i18n("plugins_installing"))
                    or (isUpgradeAvailable(widget) and i18n("plugins_update"))
                    or (isWidgetInstalled(id) and i18n("plugins_installed"))
                    or i18n("plugins_install"),
                right = 85,
                bottom = 4,
                width = 75,
                height = 28,
                fontSize = 12,
                classname = (isWidgetInstalled(id) and not isUpgradeAvailable(widget)) and "option_button" or "action_button",
                OnClick = {
                    function()
                        if installingWidgets[id] then
                            return
                        end
                        if isUpgradeAvailable(widget) then
                            upgradeWidget(widget)
                            updateUpdateAllButton()
                            widgetPanelCache[id] = nil
                            scheduleRefresh()
                        elseif not isWidgetInstalled(id) then
                            confirmAndInstall(widget, function()
                                widgetPanelCache[id] = nil
                                scheduleRefresh()
                            end)
                        end
                    end
                },
            },
            Button:New {
                caption = i18n("plugins_details"),
                right = 4,
                bottom = 4,
                width = 75,
                height = 28,
                fontSize = 12,
                OnClick = {
                    function()
                        openDetail(widget)
                    end
                },
            },
        },
    }

    local linkIconX = 4
    local function addLinkIcon(iconFile, url, tooltip)
        Button:New {
            x = linkIconX,
            caption = "",
            bottom = 4,
            width = 28,
            height = 28,
            padding = {0, 0, 0, 0},
            tooltip = tooltip,
            OnClick = { function() WG.WrapperLoopback.OpenUrl(url) end },
            parent = card,
            children = {
                Image:New {
                    x = 4,
                    y = 4,
                    right = 4,
                    bottom = 4,
                    keepAspect = true,
                    file = iconFile,
                },
            },
        }
        linkIconX = linkIconX + 32
    end
    if hasLink(widget.github_link) then
        addLinkIcon(IMG_SOURCE, widget.github_link, i18n("plugins_source_tooltip"))
    end
    if hasLink(widget.discord_link) then
        addLinkIcon(IMG_DISCORD, widget.discord_link, i18n("plugins_discord_tooltip"))
    end

    card.pluginId = id
    if id then
        widgetPanelCache[id] = card
    end
    return card
end


local function refreshGrid()
    if not mainGrid then return end

    mainGrid:ClearChildren()

    if loadState == STATE_LOADING then
        if statusLabel then
            statusLabel:SetCaption(i18n("plugins_loading"))
            statusLabel:SetVisibility(true)
        end
        if pageLabel then pageLabel:SetCaption("") end
        return
    end

    if loadState == STATE_ERROR then
        if statusLabel then
            statusLabel:SetCaption(i18n("plugins_load_failed", { error = loadError or i18n("plugins_unknown_error") }))
            statusLabel:SetVisibility(true)
        end
        if pageLabel then pageLabel:SetCaption("") end
        return
    end

    local filtered = getFilteredWidgets()
    local totalPages = getTotalPages(#filtered)
    currentPage = clamp(currentPage, 1, totalPages)
    local pageSlice = getPageSlice(filtered, currentPage)

    if #filtered == 0 then
        if statusLabel then
            if currentFilter ~= "" then
                statusLabel:SetCaption(i18n("plugins_no_match"))
            else
                statusLabel:SetCaption(i18n("plugins_none_available"))
            end
            statusLabel:SetVisibility(true)
        end
        if pageLabel then pageLabel:SetCaption("") end
        return
    end

    if statusLabel then statusLabel:SetVisibility(false) end

    local margin = 8
    local containerWidth = scrollPanel and scrollPanel.clientWidth or 0
    if containerWidth <= 0 then
        WG.Delay(function() refreshGrid() end, 0.05)
        return
    end
    local columns = math.max(1, math.floor((containerWidth + margin) / (ITEM_MIN_WIDTH + margin)))
    local itemWidth = math.floor((containerWidth - margin * (columns + 1)) / columns)
    local rows = math.ceil(#pageSlice / columns)

    local index = 0
    for _, widget in ipairs(pageSlice) do
        if widget.id then
            local col = index % columns
            local row = math.floor(index / columns)
            local x = margin + col * (itemWidth + margin)
            local y = row * ITEM_HEIGHT
            local card = createWidgetCard(widget, itemWidth)
            card:SetPos(x, y, itemWidth, ITEM_HEIGHT)
            mainGrid:AddChild(card)
            index = index + 1
        end
    end

    mainGrid:SetPos(nil, nil, nil, math.max(rows, 1) * ITEM_HEIGHT)
    mainGrid:UpdateLayout()

    if pageLabel then
        pageLabel:SetCaption(i18n("plugins_page_status", { page = currentPage, total = totalPages, count = #filtered }))
    end

    local nextPage = currentPage + 1
    if nextPage <= totalPages then
        local nextSlice = getPageSlice(filtered, nextPage)
        for _, w in ipairs(nextSlice) do
            if w.id then ensureThumbnail(w, ASSET_PRIORITY_PREFETCH) end
        end
    end
end

scheduleRefresh = function()
    if refreshPending then return end
    refreshPending = true
    WG.Delay(function()
        refreshPending = false
        refreshGrid()
    end, 0.15)
end


local function reloadWidgets()
    widgetPanelCache = {}
    cardImageRefs = {}
    widgetsList = {}
    downloadToWidgetId = {}
    installedLastUpdatedCache = {}
    resetGitHubState()
    currentPage = 1
    fetchManifest()
    refreshGrid()
end

local function getConfiguredHubValue()
    local Configuration = WG.Chobby and WG.Chobby.Configuration
    local value = Configuration
        and (Configuration.pluginsCdnUrl
            or (Configuration.gameConfig and Configuration.gameConfig.pluginsCdnUrl))
    if type(value) == "string" then
        return value
    end
    if type(value) == "table" and type(value.base) == "string" and value.base ~= "" then
        return value.base
    end
    return DEFAULT_CDN.base
end

local function isValidHubValue(value)
    if value == "" then
        return true
    end
    if string.match(value, "^https?://%S+$") then
        return true
    end
    return string.match(value, "^[%w%.%-_]+/[%w%.%-_]+(@[%w%.%-_]+)?$") ~= nil
end

local function openHubUrlPopup()
    if not (WG.TextEntryWindow and WG.TextEntryWindow.CreateTextEntryWindow) then
        return
    end

    local Configuration = WG.Chobby and WG.Chobby.Configuration
    WG.TextEntryWindow.CreateTextEntryWindow({
        defaultValue = getConfiguredHubValue(),
        caption = i18n("plugins_hub_caption"),
        labelCaption = i18n("plugins_hub_label"),
        hint = i18n("plugins_hub_hint"),
        height = 300,
        width = 560,
        oklabel = i18n("plugins_hub_save"),
        OnAccepted = function(value)
            local newUrl = (value or ""):gsub("%s+", ""):gsub("/+$", "")
            if not isValidHubValue(newUrl) then
                if Chotify then
                    Chotify:Post({
                        title = i18n("plugins_title"),
                        body = i18n("plugins_hub_invalid"),
                        time = 6,
                    })
                end
                return
            end
            if Configuration then
                Configuration:SetConfigValue("pluginsCdnUrl", newUrl ~= "" and newUrl or nil)
            end
            if hubButton then
                hubButton.tooltip = i18n("plugins_hub_tooltip", { url = getConfiguredHubValue() })
            end
            reloadWidgets()
        end
    })
end

local function parseManifest(rawJson)
    if not json then
        VFS.Include("libs/json.lua")
    end
    local ok, data = pcall(function()
        return json.decode(rawJson)
    end)

    if not ok or type(data) ~= "table" then
        loadState = STATE_ERROR
        loadError = i18n("plugins_error_invalid_manifest")
        Spring.Echo("[PluginsWindow] Failed to parse manifest JSON: " .. tostring(data))
        return
    end

    widgetsList = {}
    downloadToWidgetId = {}
    for _, entry in ipairs(data) do
        if entry.display_name and (not entry.name or entry.name == "") then
            entry.name = entry.display_name
        end
        if type(entry.tags) ~= "table" then
            entry.tags = {}
        end
        widgetsList[#widgetsList + 1] = entry
        if entry.id then
            downloadToWidgetId[entry.id .. "_thumb"] = entry.id
            downloadToWidgetId[entry.id .. "_cover"] = entry.id
            downloadToWidgetId[entry.id .. "_readme"] = entry.id
        end
    end

    Spring.Echo("[PluginsWindow] Loaded " .. #widgetsList .. " widgets from manifest")
    loadState = STATE_LOADED
    loadError = nil
    currentPage = 1
end


local function queueDownloadFile(downloadName, url, destPath)
    if not (WG.DownloadHandler and WG.DownloadHandler.QueueDownload) then
        return false
    end
    ensureDirectoryExists(destPath)
    WG.DownloadHandler.QueueDownload(downloadName, "resource", -1, 0, {
        url = url,
        destination = destPath,
        extract = false,
    })
    return true
end

local function readJsonFile(path)
    if not json then VFS.Include("libs/json.lua") end
    local f = io.open(path, "r")
    local content
    if f then
        content = f:read("*all")
        f:close()
    end
    if not content then
        content = VFS.LoadFile(path)
    end
    if not content then return nil end
    local ok, data = pcall(function() return json.decode(content) end)
    if ok then
        return data
    end
    return nil
end

local function tryFetchManifest()
    local url = getManifestUrl() .. "?t=" .. os.time()
    if queueDownloadFile(MANIFEST_NAME, url, MANIFEST_DEST) then
        return
    end
    loadState = STATE_ERROR
    loadError = i18n("plugins_error_no_handler")
    refreshGrid()
end

local function fetchRepoTrees()
    if not (gitRepoInfo and gitRepoInfo.gitOwner) then return end
    local branch = gitRepoInfo.branch or "main"
    if not gitRepoInfo.explicitBranch then
        gitRepoInfo.branch = branch
    end
    local treeUrl = "https://api.github.com/repos/" .. gitRepoInfo.gitOwner .. "/" .. gitRepoInfo.gitRepo .. "/git/trees/" .. branch .. "?recursive=1"
    if not queueDownloadFile(GIT_TREE_NAME, treeUrl, GIT_TREE_DEST) then
        loadState = STATE_ERROR
        loadError = i18n("plugins_error_no_handler")
        refreshGrid()
    end
end

local function isNestedWidgetDir(dir, dirSet)
    local walk = dir
    while walk do
        walk = string.match(walk, "^(.*)/[^/]+$")
        if walk and dirSet[walk] then
            return true
        end
    end
    return false
end

local function onGitTreeLoaded()
    local data = readJsonFile(GIT_TREE_DEST)
    if type(data) ~= "table" or type(data.tree) ~= "table" then
        loadState = STATE_ERROR
        loadError = i18n("plugins_error_repo_layout")
        refreshGrid()
        return
    end

    local hasSourceManifests = false
    for _, blob in ipairs(data.tree) do
        if blob.type == "blob" and type(blob.path) == "string" and string.match(blob.path, "/manifest%.json$") then
            hasSourceManifests = true
            break
        end
    end

    if not hasSourceManifests then
        loadState = STATE_ERROR
        loadError = i18n("plugins_error_repo_no_widgets")
        refreshGrid()
        return
    end

    local manifestPaths = {}
    for _, blob in ipairs(data.tree) do
        if blob.type == "blob" and type(blob.path) == "string" then
            if string.match(blob.path, "/manifest%.json$") then
                manifestPaths[#manifestPaths + 1] = blob.path
            end
        end
    end

    local dirSet = {}
    for _, path in ipairs(manifestPaths) do
        local dir = string.match(path, "^(.*)/[^/]+$")
        if dir and dir ~= "." and not dirSet[dir] then
            dirSet[dir] = true
        end
    end

    gitWidgetDirs = {}
    for dir in pairs(dirSet) do
        if not isNestedWidgetDir(dir, dirSet) then
            gitWidgetDirs[#gitWidgetDirs + 1] = dir
        end
    end
    table.sort(gitWidgetDirs)

    if #gitWidgetDirs == 0 then
        loadState = STATE_ERROR
        loadError = i18n("plugins_error_repo_no_widgets")
        refreshGrid()
        return
    end

    sourceWidgetFileLists = {}
    local prefixes = {}
    for i, dir in ipairs(gitWidgetDirs) do
        prefixes[i] = dir .. "/"
        sourceWidgetFileLists[i] = {}
    end
    for _, blob in ipairs(data.tree) do
        if blob.type == "blob" and type(blob.path) == "string" then
            for i, prefix in ipairs(prefixes) do
                if string.sub(blob.path, 1, #prefix) == prefix then
                    sourceWidgetFileLists[i][#sourceWidgetFileLists[i] + 1] = blob.path
                    break
                end
            end
        end
    end

    sourceManifestPending = { count = #gitWidgetDirs, done = 0, failed = 0 }
    gitWidgetManifests = {}
    local base = getConfiguredCdn().base
    for i, dir in ipairs(gitWidgetDirs) do
        local destPath = GIT_SRC_MANIFESTS_DIR .. i .. ".json"
        local url = base .. "/" .. dir .. "/manifest.json?t=" .. os.time()
        if not queueDownloadFile(GIT_SRC_MANIFEST_PREFIX .. i, url, destPath) then
            sourceManifestPending.failed = sourceManifestPending.failed + 1
        end
    end

    Spring.Echo("[PluginsWindow] Discovered " .. #gitWidgetDirs .. " widget folders in repository " .. (gitRepoInfo and (gitRepoInfo.gitOwner .. "/" .. gitRepoInfo.gitRepo) or "?"))
end

local function assembleSourceCatalog()
    local merged = {}
    for i = 1, sourceManifestPending.count do
        local entry = gitWidgetManifests[i]
        local dir = gitWidgetDirs[i]
        if type(entry) == "table" and type(dir) == "string" and type(entry.id) == "string" and entry.id ~= "" then
            local files = sourceWidgetFileLists[i] or {}
            entry._srcDir = dir
            entry._srcFiles = files
            sourceWidgetDirs[entry.id] = dir
            sourceWidgetFiles[entry.id] = files
            merged[#merged + 1] = entry
        end
    end

    if #merged == 0 then
        loadState = STATE_ERROR
        loadError = i18n("plugins_error_repo_no_widgets")
        refreshGrid()
        return
    end

    local ok, encoded = pcall(function() return json.encode(merged) end)
    if not ok or not encoded then
        loadState = STATE_ERROR
        loadError = i18n("plugins_error_invalid_manifest")
        refreshGrid()
        return
    end

    parseManifest(encoded)
    if loadState == STATE_LOADED then
        checkForUpgrades()
    end
    updateUpdateAllButton()
    refreshGrid()
    Spring.Echo("[PluginsWindow] Assembled git-source catalog with " .. #merged .. " widgets")
end

local function onGitWidgetManifestFinished(index)
    local destPath = GIT_SRC_MANIFESTS_DIR .. index .. ".json"
    local data = readJsonFile(destPath)
    if type(data) == "table" then
        gitWidgetManifests[index] = data
        sourceManifestPending.done = sourceManifestPending.done + 1
    else
        Spring.Echo("[PluginsWindow] Failed to parse source manifest #" .. index)
        sourceManifestPending.failed = sourceManifestPending.failed + 1
    end
    if sourceManifestPending.done + sourceManifestPending.failed >= sourceManifestPending.count then
        assembleSourceCatalog()
    end
end

local function onDownloadFinished(listener, downloadID, downloadName, downloadFileType)
    if downloadName == MANIFEST_NAME then
        local f = io.open(MANIFEST_DEST, "r")
        if f then
            local content = f:read("*all")
            f:close()
            parseManifest(content)
        else
            local content = VFS.LoadFile(MANIFEST_DEST)
            if content then
                parseManifest(content)
            else
                loadState = STATE_ERROR
                loadError = i18n("plugins_error_read_manifest")
                Spring.Echo("[PluginsWindow] Could not open manifest file at: " .. MANIFEST_DEST)
            end
        end
        if loadState == STATE_LOADED then
            checkForUpgrades()
        end
        updateUpdateAllButton()
        refreshGrid()
        return
    end

    if downloadName == GIT_TREE_NAME then
        onGitTreeLoaded()
        return
    end

    local gitSrcIndex = string.match(downloadName, "^" .. GIT_SRC_MANIFEST_PREFIX .. "(%d+)$")
    if gitSrcIndex then
        onGitWidgetManifestFinished(tonumber(gitSrcIndex))
        return
    end

    local srcFileWidgetId = sourceInstalls[downloadName]
    if srcFileWidgetId then
        sourceInstalls[downloadName] = nil
        local track = trackedFileInstalls[srcFileWidgetId]
        if track then
            track.done = track.done + 1
            if track.done >= track.total then
                trackedFileInstalls[srcFileWidgetId] = nil
                if track.kind == "upgrade" then
                    installingWidgets[srcFileWidgetId] = nil
                    installedWidgets[srcFileWidgetId] = true
                    upgradeBackups[srcFileWidgetId] = nil
                    widgetPanelCache[srcFileWidgetId] = nil
                    installedLastUpdatedCache[srcFileWidgetId] = nil
                    updateUpdateAllButton()
                    Spring.Echo("[PluginsWindow] Widget upgraded: " .. srcFileWidgetId)
                    Chotify:Post({
                        title = i18n("plugins_title"),
                        body = i18n("plugins_upgraded_notification", { name = getWidgetDisplayName(srcFileWidgetId) }),
                        time = 10,
                    })
                else
                    installingWidgets[srcFileWidgetId] = nil
                    installedWidgets[srcFileWidgetId] = true
                    widgetPanelCache[srcFileWidgetId] = nil
                    installedLastUpdatedCache[srcFileWidgetId] = nil
                    Spring.Echo("[PluginsWindow] Widget installed: " .. srcFileWidgetId)
                    Chotify:Post({
                        title = i18n("plugins_title"),
                        body = i18n("plugins_installed_notification", { name = getWidgetDisplayName(srcFileWidgetId) }),
                        time = 10,
                    })
                end
                refreshGrid()
            end
        end
        return
    end

    if string.find(downloadName, "^upgrade_") then
        local widgetId = string.sub(downloadName, 9)
        installingWidgets[widgetId] = nil
        installedWidgets[widgetId] = true
        upgradeBackups[widgetId] = nil
        widgetPanelCache[widgetId] = nil
        installedLastUpdatedCache[widgetId] = nil
        updateUpdateAllButton()
        Spring.Echo("[PluginsWindow] Widget upgraded: " .. widgetId)
        Chotify:Post({
            title = i18n("plugins_title"),
            body = i18n("plugins_upgraded_notification", { name = getWidgetDisplayName(widgetId) }),
            time = 10,
        })
        refreshGrid()
        return
    end

    if string.find(downloadName, "^install_") then
        local widgetId = string.sub(downloadName, 9)
        installingWidgets[widgetId] = nil
        installedWidgets[widgetId] = true
        widgetPanelCache[widgetId] = nil
        installedLastUpdatedCache[widgetId] = nil
        Spring.Echo("[PluginsWindow] Widget installed: " .. widgetId)
        Chotify:Post({
            title = i18n("plugins_title"),
            body = i18n("plugins_installed_notification", { name = getWidgetDisplayName(widgetId) }),
            time = 10,
        })
        refreshGrid()
        return
    end

    local widgetId = downloadToWidgetId[downloadName]
    if widgetId then
        if string.find(downloadName, "_thumb", 1, true) then
            local imageRef = cardImageRefs[widgetId]
            if imageRef then
                local thumbPath = getThumbnailPath(widgetId)
                if VFS.FileExists(thumbPath) then
                    imageRef.file = thumbPath
                    if type(imageRef.Invalidate) == "function" then
                        imageRef:Invalidate()
                    end
                end
            else
                widgetPanelCache[widgetId] = nil
            end
        end

        if detailWidgetId == widgetId then
            if string.find(downloadName, "_readme", 1, true) then
                local readmePath = getReadmePath(widgetId)
                if VFS.FileExists(readmePath) and detailReadmeBox then
                    local content = VFS.LoadFile(readmePath) or ""
                    if type(detailReadmeBox.SetText) == "function" then
                        detailReadmeBox:SetText(content)
                    else
                        detailReadmeBox.text = content
                    end
                end
            end
            if string.find(downloadName, "_cover", 1, true) and detailCoverImage then
                local coverPath = getCoverPath(widgetId)
                if VFS.FileExists(coverPath) then
                    detailCoverImage.file = coverPath
                end
                if type(detailCoverImage.Invalidate) == "function" then
                    detailCoverImage:Invalidate()
                end
            end
        end

        scheduleRefresh()
        return
    end

    scheduleRefresh()
end

local function onDownloadFailed(listener, downloadID, errorID, downloadName, downloadFileType)
    if downloadName == MANIFEST_NAME then
        loadState = STATE_ERROR
        loadError = i18n("plugins_error_network", { code = tostring(errorID) })
        Spring.Echo("[PluginsWindow] Manifest download failed: " .. tostring(errorID))
        refreshGrid()
        return
    end

    if downloadName == GIT_TREE_NAME then
        if gitRepoInfo and not gitRepoInfo.explicitBranch and gitRepoInfo.branch ~= "master" then
            gitRepoInfo.branch = "master"
            fetchRepoTrees()
            return
        end
        loadState = STATE_ERROR
        loadError = i18n("plugins_error_repo_layout")
        Spring.Echo("[PluginsWindow] Failed to read repository layout: " .. tostring(errorID))
        refreshGrid()
        return
    end

    local gitSrcIndex = string.match(downloadName, "^" .. GIT_SRC_MANIFEST_PREFIX .. "(%d+)$")
    if gitSrcIndex then
        Spring.Echo("[PluginsWindow] Source manifest download failed: " .. tostring(downloadName) .. " (error " .. tostring(errorID) .. ")")
        sourceManifestPending.failed = sourceManifestPending.failed + 1
        if sourceManifestPending.done + sourceManifestPending.failed >= sourceManifestPending.count then
            assembleSourceCatalog()
        end
        return
    end

    local srcFileWidgetId = sourceInstalls[downloadName]
    if srcFileWidgetId then
        sourceInstalls[downloadName] = nil
        local track = trackedFileInstalls[srcFileWidgetId]
        trackedFileInstalls[srcFileWidgetId] = nil
        Spring.Echo("[PluginsWindow] Widget " .. ((track and track.kind) or "install") .. " failed: " .. srcFileWidgetId .. " (error " .. tostring(errorID) .. ")")
        if track and track.kind == "upgrade" then
            local backupPath = upgradeBackups[srcFileWidgetId]
            if backupPath then
                local installDir = getInstallPath(srcFileWidgetId)
                Spring.Echo("[PluginsWindow] Restoring backup after failed upgrade: " .. backupPath .. " -> " .. installDir)
                os.rename(backupPath, installDir)
            end
        end
        installingWidgets[srcFileWidgetId] = nil
        upgradeBackups[srcFileWidgetId] = nil
        widgetPanelCache[srcFileWidgetId] = nil
        updateUpdateAllButton()
        refreshGrid()
        return
    end

    if string.find(downloadName, "^upgrade_") then
        local widgetId = string.sub(downloadName, 9)
        local backupPath = upgradeBackups[widgetId]
        if backupPath then
            local installDir = getInstallPath(widgetId)
            Spring.Echo("[PluginsWindow] Restoring backup after failed upgrade: " .. backupPath .. " -> " .. installDir)
            os.rename(backupPath, installDir)
        end
        installingWidgets[widgetId] = nil
        upgradeBackups[widgetId] = nil
        widgetPanelCache[widgetId] = nil
        Spring.Echo("[PluginsWindow] Widget upgrade failed: " .. widgetId .. " (error " .. tostring(errorID) .. ")")
        updateUpdateAllButton()
        refreshGrid()
        return
    end

    if string.find(downloadName, "^install_") then
        local widgetId = string.sub(downloadName, 9)
        installingWidgets[widgetId] = nil
        widgetPanelCache[widgetId] = nil
        Spring.Echo("[PluginsWindow] Widget install failed: " .. widgetId .. " (error " .. tostring(errorID) .. ")")
        refreshGrid()
    end
end

fetchManifest = function()
    loadState = STATE_LOADING
    loadError = nil

    for _, path in ipairs({ MANIFEST_DEST, GIT_TREE_DEST }) do
        if VFS.FileExists(path) then
            local ok, err = os.remove(path)
            if not ok then
                Spring.Echo("[PluginsWindow] Failed to remove stale file " .. path .. ": " .. tostring(err))
            end
        end
    end
    local staleSrcManifests = VFS.DirList(GIT_SRC_MANIFESTS_DIR)
    if staleSrcManifests then
        for _, path in ipairs(staleSrcManifests) do
            pcall(os.remove, path)
        end
    end

    resetGitHubState()
    getConfiguredCdn()

    if gitRepoInfo and gitRepoInfo.gitOwner then
        fetchRepoTrees()
        return
    end

    tryFetchManifest()
end


local function onSearchChanged(newText)
    local text = newText or ""
    if text == currentFilter then return end
    currentFilter = text
    currentPage = 1
    widgetPanelCache = {}
    cardImageRefs = {}
    refreshGrid()
end


local function goToPage(page)
    local filtered = getFilteredWidgets()
    local totalPages = getTotalPages(#filtered)
    local newPage = clamp(page, 1, totalPages)
    if newPage ~= currentPage then
        currentPage = newPage
        widgetPanelCache = {}
        cardImageRefs = {}
        refreshGrid()
        if scrollPanel and type(scrollPanel.SetScrollPos) == "function" then
            scrollPanel:SetScrollPos(0, 0, false, false)
        end
    end
end

local function prevPage()
    goToPage(currentPage - 1)
end

local function nextPage()
    goToPage(currentPage + 1)
end

local function firstPage()
    goToPage(1)
end

local function lastPage()
    local filtered = getFilteredWidgets()
    goToPage(getTotalPages(#filtered))
end


function PluginsWindow:init(parent)
    if WG.DownloadHandler and WG.DownloadHandler.AddListener then
        WG.DownloadHandler.AddListener("DownloadFinished", onDownloadFinished)
        WG.DownloadHandler.AddListener("DownloadFailed", onDownloadFailed)
    else
        Spring.Echo("[PluginsWindow] WARNING: DownloadHandler not available for event registration")
    end

    local parentWidth = (parent and parent.width) or 1300
    local usableWidth = parentWidth - 40
    local columns = math.max(1, math.floor((usableWidth + 8) / (ITEM_MIN_WIDTH + 8)))
    local itemWidth = math.floor(usableWidth / columns)

    self.window = Control:New {
        x = 0,
        right = 0,
        y = 0,
        bottom = 0,
        padding = {20, 17, 20, 0},
        parent = parent,
        resizable = false,
        draggable = false,
    }

    self.window.OnDispose = self.window.OnDispose or {}
    self.window.OnDispose[#self.window.OnDispose + 1] = function()
        self:cleanup()
    end


    local btnW = 110
    local btnH = 28
    local btnFont = 12
    local row1Y = 0
    local row2Y = HEADER_HEIGHT + HEADER_ROW_GAP

    Label:New {
        objectOverrideFont = WG.Chobby.Configuration:GetFont(4),
        caption = i18n("plugins_title"),
        x = 0,
        y = row1Y,
        width = 110,
        height = HEADER_HEIGHT,
        valign = "center",
        parent = self.window,
    }

    Label:New {
        caption = i18n("plugins_disclaimer"),
        x = 120,
        right = 0,
        y = row1Y,
        height = HEADER_HEIGHT,
        autosize = false,
        valign = "center",
        fontSize = 12,
        parent = self.window,
    }

    local btnY = row2Y + 6
    local btnGap = 8
    local btnFont = 12
    local headerX = 0
    local function addHeaderButton(config)
        local btn = Button:New {
            x = headerX,
            y = btnY,
            width = config.width,
            height = btnH,
            fontSize = btnFont,
            caption = config.caption,
            tooltip = config.tooltip,
            classname = config.classname,
            OnClick = config.OnClick,
            parent = self.window,
        }
        headerX = headerX + config.width + btnGap
        return btn
    end
    addHeaderButton {
        caption = i18n("plugins_folder"),
        tooltip = i18n("plugins_folder_tooltip"),
        width = btnW,
        OnClick = { function() if WG.Connector and WG.Connector.writePath then WG.WrapperLoopback.OpenFolder(WG.Connector.writePath .. "/LuaUI/Widgets") end end },
    }
    addHeaderButton {
        caption = i18n("plugins_contribute"),
        tooltip = i18n("plugins_contribute_tooltip"),
        width = btnW - 10,
        OnClick = { function() WG.WrapperLoopback.OpenUrl("https://github.com/beyond-all-reason/BAR-widgets#how-to-contribute-a-new-widget") end },
    }
    hubButton = addHeaderButton {
        caption = i18n("plugins_hub"),
        tooltip = i18n("plugins_hub_tooltip", { url = getConfiguredCdn().base }),
        width = btnW,
        OnClick = { openHubUrlPopup },
    }
    addHeaderButton {
        caption = i18n("plugins_refresh"),
        tooltip = i18n("plugins_refresh_tooltip"),
        width = btnW - 20,
        OnClick = { reloadWidgets },
    }
    updateAllButton = addHeaderButton {
        caption = i18n("plugins_update_all"),
        tooltip = i18n("plugins_update_all_tooltip"),
        width = btnW - 10,
        classname = "action_button",
        OnClick = { function()
            for _, widget in ipairs(getUpgradableWidgets()) do
                upgradeWidget(widget)
                if widget.id then
                    widgetPanelCache[widget.id] = nil
                end
            end
            updateUpdateAllButton()
            refreshGrid()
        end },
    }
    updateUpdateAllButton()

    searchBox = EditBox:New {
        text = "",
        right = 0,
        y = btnY,
        width = 180,
        height = btnH,
        hint = i18n("plugins_search_hint"),
        objectOverrideFont = WG.Chobby.Configuration:GetFont(2),
        objectOverrideHintFont = WG.Chobby.Configuration:GetFont(2),
        OnKeyPress = {
            function(obj, key)
                WG.Delay(function()
                    if obj and obj.text then
                        onSearchChanged(obj.text)
                    end
                end, 0.05)
            end
        },
        parent = self.window,
    }


    local paginationY = HEADER_TOTAL_HEIGHT + 2

    local pagBtnW = 40
    local pagBtnH = 30
    local pagFont = 13
    local pagPad = 10
    local pagBtnGap = 8

    Button:New {
        caption = "<<",
        x = 0,
        y = paginationY,
        width = pagBtnW,
        height = pagBtnH,
        fontSize = pagFont,
        OnClick = { function() firstPage() end },
        parent = self.window,
    }

    Button:New {
        caption = "<",
        x = pagBtnW + pagBtnGap,
        y = paginationY,
        width = pagBtnW,
        height = pagBtnH,
        fontSize = pagFont,
        OnClick = { function() prevPage() end },
        parent = self.window,
    }

    pageLabel = Label:New {
        caption = i18n("plugins_loading_short"),
        x = (pagBtnW + pagBtnGap) * 2,
        right = (pagBtnW + pagBtnGap) * 2,
        y = paginationY,
        height = pagBtnH,
        valign = "center",
        autosize = false,
        fontSize = 14,
        align = "center",
        parent = self.window,
    }

    Button:New {
        caption = ">",
        right = pagBtnW + pagBtnGap,
        y = paginationY,
        width = pagBtnW,
        height = pagBtnH,
        fontSize = pagFont,
        OnClick = { function() nextPage() end },
        parent = self.window,
    }

    Button:New {
        caption = ">>",
        right = 0,
        y = paginationY,
        width = pagBtnW,
        height = pagBtnH,
        fontSize = pagFont,
        OnClick = { function() lastPage() end },
        parent = self.window,
    }


    local contentY = paginationY + PAGINATION_HEIGHT + 5

    statusLabel = Label:New {
        caption = i18n("plugins_loading"),
        x = 0,
        y = contentY + 40,
        right = 0,
        height = 40,
        autosize = false,
        align = "center",
        objectOverrideFont = WG.Chobby.Configuration:GetFont(3),
        parent = self.window,
    }


    mainGrid = Control:New {
        width = "100%",
        height = ITEM_HEIGHT,
        padding = {0, 0, 0, 0},
        resizable = false,
        draggable = false,
        children = {},
    }
    mainGrid.itemWidth = itemWidth

    scrollPanel = ScrollPanel:New {
        x = 0,
        right = 0,
        y = contentY,
        bottom = 15,
        horizontalScrollbar = false,
        borderColor = {0, 0, 0, 0},
        padding = {0, 0, 0, 0},
        parent = self.window,
        children = { mainGrid },
        OnResize = {
            function()
                refreshGrid()
            end
        },
    }


    fetchManifest()

    WG.Delay(function() refreshGrid() end, 0.1)

    Spring.Echo("[PluginsWindow] Initialized")
end


function PluginsWindow:cleanup()
    closeDetail()
    if WG.DownloadHandler and WG.DownloadHandler.RemoveListener then
        WG.DownloadHandler.RemoveListener("DownloadFinished", onDownloadFinished)
        WG.DownloadHandler.RemoveListener("DownloadFailed", onDownloadFailed)
    end
    mainGrid = nil
    scrollPanel = nil
    pageLabel = nil
    statusLabel = nil
    searchBox = nil
    updateAllButton = nil
    hubButton = nil
    widgetPanelCache = {}
    installingWidgets = {}
    upgradeBackups = {}
    installedLastUpdatedCache = {}
    downloadToWidgetId = {}
    cardImageRefs = {}
    refreshPending = false
    resetGitHubState()
    Spring.Echo("[PluginsWindow] Cleaned up")
end
