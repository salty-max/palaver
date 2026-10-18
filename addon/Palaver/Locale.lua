-- The reader's language. The client loads its own Text_<locale>.lua next (the
-- TOCs name Text_[TextLocale].lua; scripts/locales.ts writes them from
-- i18n/), which hands its words to ns.translate: English stays wherever it
-- says nothing. The game's own text (what an NPC says, a quest's) comes from
-- the game in the client's language and is never translated here.
local _, ns = ...
local K = ns.kit

-- (is n the "one" form? English, German, Spanish: 1; French: 0 and 1)
local PLURALS = {
  one = function(n) return n == 1 end,
  fr = function(n) return n == 0 or n == 1 end,
  none = function() return false end,
}

function ns.translate(t)
  for english, word in pairs(t.words or {}) do
    K.L[english] = word
  end
  if t.plural and PLURALS[t.plural] then K.isOne = PLURALS[t.plural] end
end

-- The game this is: Forever's client is a modern one (interface 1.60, 16001).
local build = select(4, GetBuildInfo())
ns.forever = build >= 16000 and build < 17000
ns.tbc = build >= 20000 and build < 30000
