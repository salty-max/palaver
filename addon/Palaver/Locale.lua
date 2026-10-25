-- The reader's language. The client loads its own Text_<locale>.lua next (the
-- TOCs name Text_[TextLocale].lua; scripts/locales.ts writes them from
-- i18n/), which hands its words to ns.translate: English stays wherever it
-- says nothing. The game's own text (what an NPC says, a quest's) comes from
-- the game in the client's language and is never translated here.
local _, ns = ...
local K = ns.kit

-- (the kit's: the language's plural rule, every word through it)
function ns.translate(t) K.translate(t) end

-- The game's own names in the reader's language (its Text file, from
-- wow-data's databases: the quests' kinds), by id, every language's whole.
ns.questTypes = {}
function ns.names(t)
  for id, name in pairs(t.questTypes or {}) do
    ns.questTypes[id] = name
  end
end

-- (the game this is, ns.forever and ns.tbc: the kit says it)
