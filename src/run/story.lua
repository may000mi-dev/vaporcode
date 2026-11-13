-- story.lua: reglas puras de la campaña narrativa.
local StoryData = require("src.data.story")

local Story = {}

function Story.chapter(id)
  return StoryData.chapterById[id]
end

function Story.act(chapter)
  return chapter and StoryData.actById[chapter.act] or nil
end

function Story.isStory(run)
  return run.mode == "story" and StoryData.chapterById[run.storyChapterId] ~= nil
end

function Story.isLastFloor(run)
  local chapter = StoryData.chapterById[run.storyChapterId]
  return chapter ~= nil and run.depth >= chapter.endDepth
end

function Story.exitKind(run)
  if not Story.isStory(run) then return "normal" end
  if not Story.isLastFloor(run) then return "normal" end
  local chapter = StoryData.chapterById[run.storyChapterId]
  return chapter.nextChapter and "portal" or "ending"
end

function Story.nextChapter(run)
  local chapter = StoryData.chapterById[run.storyChapterId]
  if not chapter or not chapter.nextChapter then return nil end
  return StoryData.chapterById[chapter.nextChapter]
end

function Story.floorIndex(run)
  local chapter = StoryData.chapterById[run.storyChapterId]
  if not chapter then return 0, 0 end
  return run.depth - chapter.startDepth + 1,
    chapter.endDepth - chapter.startDepth + 1
end

function Story.scene(id)
  return StoryData.scenes[id]
end

return Story
