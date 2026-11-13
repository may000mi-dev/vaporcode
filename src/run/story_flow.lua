-- story_flow.lua: transiciones de capítulo, checkpoints y cierre de campaña.
local Data = require("src.run.data")
local Save = require("src.run.save")
local Floor = require("src.run.floor")
local StoryUI = require("src.run.story_ui")
local Audio = require("src.utils.audio")
local State = require("src.estados")

local StoryFlow = {}

function StoryFlow.startStoryScene(run, sceneId, onDone)
  return StoryUI.start(run, sceneId, onDone)
end

function StoryFlow.saveStoryCheckpoint(run)
  if run.mode ~= "story" or run.sandbox or not run.storyChapterId then
    return false
  end
  return Save.setStoryCheckpoint(run.storyChapterId, Floor.capture(run))
end

function StoryFlow.advanceStoryChapter(run)
  local chapter = run.storyChapter
  if not chapter or not chapter.nextChapter then
    return StoryFlow.finishStory(run)
  end

  local nextChapter = Data.story.chapterById[chapter.nextChapter]
  if not nextChapter then
    return StoryFlow.finishStory(run)
  end

  run.storyChapterId = nextChapter.id
  run.storyChapter = nextChapter
  run.def = Data.dungeonById[nextChapter.dungeonId] or run.def
  run.depth = nextChapter.startDepth
  run.seed = run.seed + 104729
  run.hp = math.min(
    run.stats.maxHp,
    run.hp + math.floor(run.stats.maxHp * Data.player.nextLevelHealPercent)
  )
  run.overlay = nil
  run.storyScene = nil
  run.storySceneIndex = nil
  run.storySceneDone = nil
  run.storyPendingIntroScene = nextChapter.introScene
  run:enterLevel()
end

function StoryFlow.finishStory(run)
  Save.completeStory()
  Audio.stopMusic()
  run.over = true
  run.paused = false
  run.overlay = nil
  run.storyScene = nil
  run.storySceneIndex = nil
  run.storySceneDone = nil
  State.switch("menu")
end

return StoryFlow
