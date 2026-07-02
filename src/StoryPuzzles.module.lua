local StoryPuzzles = {}

StoryPuzzles.OrderedIds = { "Keys", "Symbols", "Statues", "Candles", "Sounds" }

StoryPuzzles.Definitions = {
    Keys = {
        Id = "Keys",
        Label = "المفاتيح",
        Total = 5,
    },
    Symbols = {
        Id = "Symbols",
        Label = "لغز الرموز",
        Total = 4,
        Sequence = { "1", "3", "2", "4" },
    },
    Statues = {
        Id = "Statues",
        Label = "لغز التماثيل",
        Total = 3,
        Targets = { 90, 180, 270 },
    },
    Candles = {
        Id = "Candles",
        Label = "لغز الشموع",
        Total = 4,
        Sequence = { 3, 1, 4, 2 },
    },
    Sounds = {
        Id = "Sounds",
        Label = "لغز الأصوات",
        Total = 3,
        Sequence = { 1, 3, 2 },
    },
}

function StoryPuzzles.getOrderedDefinitions()
    local list = {}
    for _, id in ipairs(StoryPuzzles.OrderedIds) do
        table.insert(list, StoryPuzzles.Definitions[id])
    end
    return list
end

function StoryPuzzles.getDefinition(puzzleId: string)
    return StoryPuzzles.Definitions[puzzleId]
end

return StoryPuzzles
