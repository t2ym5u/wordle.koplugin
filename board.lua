local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

-- ---------------------------------------------------------------------------
-- Word lists
-- ---------------------------------------------------------------------------

-- FR: loaded lazily from words_fr.lua (5884 words, CC0)
local _fr_words = nil
local function loadFrWords()
    if not _fr_words then
        local path = _dir .. "words_fr.lua"
        local fn = loadfile(path)
        _fr_words = fn and fn() or {}
        -- build lookup set for validation
        _fr_words._set = {}
        for _, w in ipairs(_fr_words) do _fr_words._set[w] = true end
    end
    return _fr_words
end

-- Bundled 5-letter word lists per language
local WORDS = {
    en = {
        "ABOUT","ABOVE","ABUSE","ACUTE","ADMIT","ADOPT","ADULT","AFTER","AGAIN",
        "AGENT","AGREE","AHEAD","ALARM","ALBUM","ALERT","ALIEN","ALIGN","ALIVE",
        "ALLEY","ALLOW","ALONE","ALONG","ALTER","AMONG","ANGEL","ANGER","ANGLE",
        "ANGRY","ANIME","ANNEX","APART","APPLE","APPLY","ARENA","ARGUE","ARISE",
        "ARMOR","ARRAY","ARROW","ASIDE","ASSET","ATLAS","ATTIC","AUDIO","AUDIT",
        "AVOID","AWARE","AWFUL","BAKER","BASES","BASIC","BASIS","BEACH","BEARD",
        "BEAST","BEGIN","BEING","BELOW","BENCH","BIBLE","BLACK","BLADE","BLAME",
        "BLAND","BLANK","BLAST","BLAZE","BLEED","BLEND","BLIND","BLOCK","BLOOD",
        "BLOOM","BLOWN","BOARD","BONUS","BOOST","BOOTH","BOUND","BOXER","BRAIN",
        "BRAND","BRAVE","BREAD","BREAK","BRIDE","BRIEF","BRING","BROAD","BROOK",
        "BROWN","BUILD","BUILT","BURST","BUYER","CABIN","CAMEL","CANDY","CARGO",
        "CARRY","CATCH","CAUSE","CHAIN","CHAIR","CHALK","CHARM","CHART","CHASE",
        "CHEAP","CHECK","CHEEK","CHEER","CHESS","CHEST","CHICK","CHIEF","CHILD",
        "CHINA","CHIPS","CIVIL","CLAIM","CLASS","CLEAN","CLEAR","CLIMB","CLOCK",
        "CLONE","CLOSE","CLOUD","COACH","COAST","COBRA","CODED","COMET","COMIC",
        "COMMA","CORAL","COUNT","COURT","COVER","CRACK","CRAFT","CRANE","CRASH",
        "CRAZY","CREAM","CRIME","CRISP","CROSS","CROWD","CROWN","CRUSH","CRYPT",
        "CURVE","CYCLE","DAILY","DANCE","DARTS","DATED","DEATH","DEBUT","DECOY",
        "DELAY","DENSE","DEPOT","DEPTH","DERBY","DEVIL","DIARY","DISCO","DODGE",
        "DOING","DOUBT","DOUGH","DRAFT","DRAIN","DRAMA","DRANK","DRAWL","DRAWN",
        "DREAM","DRESS","DRIFT","DRINK","DRIVE","DRONE","DROWN","DRYER","DYING",
        "EAGLE","EARLY","EARTH","EIGHT","ELITE","EMAIL","EMBER","EMPTY","ENEMY",
        "ENJOY","ENTER","ENTRY","EQUAL","ESSAY","EVADE","EVENT","EVERY","EXACT",
        "EXALT","EXAM","EXILE","EXIST","EXTRA","FABLE","FAITH","FANCY","FAULT",
        "FEAST","FENCE","FERAL","FEVER","FIBER","FIELD","FIFTH","FIFTY","FIGHT",
        "FINAL","FIRST","FIXED","FLAME","FLASH","FLASK","FLEET","FLESH","FLICK",
        "FLOCK","FLOOD","FLOOR","FLOUR","FLOWN","FLUID","FLUSH","FOCUS","FORCE",
        "FORGE","FORTH","FOUND","FRAME","FRANK","FRAUD","FRESH","FRONT","FROST",
        "FRUIT","FULLY","FUNKY","FUNNY","GAINS","GAUGE","GHOST","GIANT","GIVEN",
        "GLAND","GLASS","GLOBE","GLOOM","GLORY","GLOSS","GLOVE","GOING","GRACE",
        "GRADE","GRAIN","GRAND","GRANT","GRAPE","GRASP","GRASS","GRAVE","GREAT",
        "GREED","GREEN","GREET","GRIEF","GRILL","GRIND","GROAN","GROVE","GROWN",
        "GUARD","GUESS","GUILD","GUILE","GUISE","GUSTO","HABIT","HAIKU","HANDS",
        "HAPPY","HARSH","HASTE","HATCH","HEART","HEDGE","HENCE","HERTZ","HINGE",
        "HOBBY","HOLLY","HONOR","HORSE","HOTEL","HOTEL","HOUSE","HUMAN","HUMID",
        "HUMOR","HURRY","IMAGE","IMPLY","INFER","INNER","INPUT","INTER","INTRO",
        "ISSUE","IVORY","JAPAN","JEWEL","JOINT","JOKER","JOLLY","JUDGE","JUICE",
        "JUICY","JUMBO","KARMA","KAYAK","KNACK","KNEEL","KNIFE","KNOCK","KNOWN",
        "LABEL","LARGE","LASER","LATCH","LATER","LEARN","LEASE","LEAST","LEAVE",
        "LEVEL","LIGHT","LIMIT","LINER","LIVER","LOCAL","LODGE","LOGIC","LOOSE",
        "LOWER","LUCKY","LUNAR","LUNCH","MAGIC","MAKER","MANOR","MAPLE","MARCH",
        "MATCH","MAYOR","MEDIA","MERCY","MERGE","MERIT","METAL","MIGHT","MINOR",
        "MINUS","MIXER","MODAL","MODEL","MONEY","MONTH","MORAL","MOUND","MOUNT",
        "MOUSE","MOVED","MOVIE","MUSIC","NAVAL","NERVE","NEVER","NIGHT","NOBLE",
        "NORTH","NOTCH","NOTED","NOVEL","NURSE","NYMPH","OCEAN","OFFER","OFTEN",
        "OLIVE","ONION","ONSET","OPERA","ORBIT","ORDER","OTHER","OUTER","OWNED",
        "OWNER","OXIDE","OZONE","PAINT","PANEL","PANIC","PAPER","PATCH","PAUSE",
        "PEACE","PEACH","PEARL","PEDAL","PENNY","PHASE","PIANO","PILOT","PINCH",
        "PIXEL","PIZZA","PLACE","PLAIN","PLANE","PLANT","PLATE","PLAZA","PLEAD",
        "PLUCK","POINT","POLAR","PORCH","POWER","PRESS","PRICE","PRIDE","PRIME",
        "PRINT","PRIZE","PROBE","PRONE","PROOF","PROSE","PROUD","PRUNE","PULSE",
        "PUPIL","QUEEN","QUERY","QUEST","QUEUE","QUICK","QUIET","QUOTA","QUOTE",
        "RADAR","RADIO","RAISE","RALLY","RANGE","RAPID","RATIO","REACH","REACT",
        "READY","REALM","REBEL","REFER","REIGN","RELAX","REMIX","RENAL","REPAY",
        "REPEL","REPLY","RETRO","RIDER","RIDGE","RIFLE","RIGID","RISKY","RIVAL",
        "RIVER","ROBOT","ROCKY","RODEO","ROUGE","ROUGH","ROUND","ROUTE","RUGBY",
        "RULER","RURAL","RUSTY","SADLY","SAINT","SAUCE","SCALE","SCENE","SCORE",
        "SCOUT","SEIZE","SENSE","SERVE","SETUP","SEVEN","SHAFT","SHAKE","SHALL",
        "SHAME","SHAPE","SHARE","SHARK","SHARP","SHELF","SHELL","SHIFT","SHINE",
        "SHIRT","SHOCK","SHORE","SHORT","SHOUT","SIGHT","SINCE","SIXTH","SIXTY",
        "SKILL","SKULL","SLATE","SLAVE","SLEEP","SLICE","SLIDE","SLOPE","SMART",
        "SMELL","SMILE","SMOKE","SNAKE","SOLAR","SOLVE","SOUTH","SPACE","SPARE",
        "SPARK","SPEAK","SPEED","SPEND","SPINE","SPITE","SPLIT","SPOKE","SPOON",
        "SQUAD","STAGE","STAKE","STALE","STALK","STAND","STARK","START","STATE",
        "STEAL","STEAM","STEEL","STEEP","STEER","STERN","STICK","STIFF","STILL",
        "STOCK","STONE","STORE","STORM","STORY","STOVE","STRAP","STRAY","STRIP",
        "STUDY","STYLE","SUITE","SUPER","SURGE","SWAMP","SWEAR","SWEEP","SWEET",
        "SWIFT","SWORD","TABLE","TAKEN","TASTE","TEACH","TEETH","TENSE","TENTH",
        "TERMS","THEFT","THEME","THERE","THICK","THING","THINK","THIRD","THORN",
        "THREE","THREW","THROW","THUMB","TIGER","TIGHT","TIMER","TIRED","TITLE",
        "TODAY","TOKEN","TORCH","TOTAL","TOUCH","TOUGH","TRACE","TRACK","TRADE",
        "TRAIL","TRAIN","TRAIT","TRAMP","TRASH","TRIAL","TRIBE","TRICK","TRIED",
        "TROOP","TRUCK","TRUMP","TRUNK","TRUST","TRUTH","TUMOR","TUNED","TWEAK",
        "TWICE","TWIST","TYPED","ULCER","ULTRA","UNCLE","UNDER","UNIFY","UNION",
        "UNITE","UNITY","UNTIL","UPPER","UPSET","URBAN","USAGE","USHER","USUAL",
        "VALVE","VALUE","VENUE","VIDEO","VIGOR","VIRAL","VIRUS","VITAL","VOCAL",
        "VODKA","VOICE","VOTER","VAGUE","WASTE","WATCH","WATER","WEAVE","WEEDY",
        "WEIRD","WHOLE","WIDER","WIDOW","WINDY","WITCH","WORLD","WORRY","WORSE",
        "WORST","WOULD","WOUND","WOVEN","WRITE","WRONG","YACHT","YEARN","YIELD",
        "YOUNG","YOUTH","ZEBRA","ZESTY","ZONES","ZOOMS",
    },
    fr = {
        "ABORD","ABRIS","ACIER","ACTES","ADIEU","AIMER","AINSI","AJOUTER","ALBUM",
        "ALLÉE","ALLEZ","ALORS","ARBRE","ARDEUR","ARGENT","ARMES","ARRÊT","ASPECT",
        "AVION","AVOIR","BATEAU","BELLE","BLANC","BOIRE","BOITE","BRAVO","BRISE",
        "CALME","CASER","CAUSE","CERNE","CHAMP","CHARS","CHOIX","CIBLE","CITER",
        "COEUR","CONTE","CORPS","COUDE","COUP","COURT","CUIRE","DANSE","DATES",
        "DÉBUT","DENSE","DÉSIR","DETTE","DIVIN","DONNÉ","DOUZE","DROIT","DURER",
        "ÉCRAN","ÉGALE","ÉLÈVE","ENFIN","ENTRE","ENVIE","ÉPOUX","ESCALE","ÉTAPE",
        "ÉTUDE","EXAMEN","FAÇON","FAIRE","FATAL","FEMME","FENTE","FIÈRE","FLEUR",
        "FOLIE","FORCE","FORUM","FOYER","FRANC","FRUIT","FUTUR","GARDE","GENRE",
        "GLACE","GLOIRE","GOLFE","GRÂCE","GRAIN","GRAND","GRÈVE","GUIDE","HASARD",
        "HERBE","HONTE","HOTEL","HUILE","HUMAIN","IDÉAL","IMAGE","IMPÔT","INTIME",
        "IRAIT","JETON","JOUER","JOUER","LAPIN","LARGE","LASER","LEVER","LIBRE",
        "LIGNE","LINGE","LISTE","LOCAL","LONGS","LOUER","LUTTE","MAGIE","MAIN",
        "MASSE","MATCH","MONDE","MONTE","MORAL","MOTIF","MOULE","MOYEN","MURER",
        "NAPPE","NŒUD","NUAGE","NOBLE","NORME","NOTER","NOUER","OFFRE","OLIVE",
        "ORDRE","PALIER","PÂLE","PAIRE","PAIX","PASSE","PAYÉ","PENTE","PERTE",
        "PIÈCE","PLAGE","PLEIN","POIDS","POINT","PORTE","POSER","PRÊT","PRIME",
        "PRISE","PROIE","PROSE","QUEUE","QUÊTE","RÉELS","RÈGLE","REINE","RÊVER",
        "ROUTE","ROYAL","SABLE","SALLE","SAULE","SAVOIR","SIGNE","SINGE","SOBRE",
        "SONGE","SUITE","SUJET","SÛRETÉ","TABLE","TACHE","TAILLE","TEINT","TENIR",
        "TERME","TEXTE","TITRE","TOILE","TONNE","TOTAL","TOURS","TRACE","TRAIN",
        "TRAIT","TRAME","TRÔNE","ULTRA","UNION","UNITÉ","USURE","VAGUE","VALEUR",
        "VEILLE","VITRE","VIVRE","VŒUX","VOTER","VOULOIR","ZONES",
    },
}

-- Filter to exact word_len
local function filterWords(list, len)
    local out = {}
    for _, w in ipairs(list) do
        if #w == len then out[#out + 1] = w end
    end
    return out
end

-- Get word list for lang (returns array)
local function getWordList(lang, len)
    if lang == "fr" then
        local fr = loadFrWords()
        return filterWords(fr, len)
    end
    return filterWords(WORDS[lang] or WORDS["en"], len)
end

-- Check if a word is valid for the current lang
local function isValidWord(lang, word)
    if lang == "fr" then
        local fr = loadFrWords()
        return fr._set[word] == true
    end
    -- EN: accept any string (no exhaustive list)
    local list = WORDS["en"]
    for _, w in ipairs(list) do
        if w == word then return true end
    end
    return true  -- EN is permissive
end

local WORD_LEN   = 5
local MAX_TRIES  = 6
local LANG_ORDER = { "en", "fr" }

-- Cell result states
local STATE_EMPTY   = 0
local STATE_TBD     = 1   -- typed but not submitted
local STATE_CORRECT = 2   -- right letter, right position
local STATE_PRESENT = 3   -- right letter, wrong position
local STATE_ABSENT  = 4   -- letter not in word

-- ---------------------------------------------------------------------------
-- WordleBoard
-- ---------------------------------------------------------------------------

local WordleBoard = {}
WordleBoard.__index = WordleBoard

function WordleBoard:new(opts)
    opts = opts or {}
    local obj = setmetatable({
        lang      = opts.lang     or "en",
        word_len  = opts.word_len or WORD_LEN,
        max_tries = MAX_TRIES,
        secret    = "",
        guesses   = {},   -- array of { letters={}, states={} }
        current   = {},   -- current row letters (array of chars)
        row       = 1,    -- current attempt (1-indexed)
        won       = false,
        lost      = false,
        -- keyboard state per letter
        key_state = {},
        wins      = 0,
        losses    = 0,
        streak    = 0,
    }, self)
    obj:_newWord()
    return obj
end

function WordleBoard:_newWord()
    local list = getWordList(self.lang, self.word_len)
    if #list == 0 then list = filterWords(WORDS["en"], self.word_len) end
    self.secret = list[math.random(#list)]
end

function WordleBoard:newGame()
    self:_newWord()
    self.guesses  = {}
    self.current  = {}
    self.row      = 1
    self.won      = false
    self.lost     = false
    self.key_state = {}
end

-- Type a letter
function WordleBoard:typeLetter(letter)
    if self.won or self.lost then return end
    if #self.current >= self.word_len then return end
    self.current[#self.current + 1] = letter:upper()
end

-- Delete last letter
function WordleBoard:deleteLetter()
    if self.won or self.lost then return end
    if #self.current == 0 then return end
    table.remove(self.current)
end

-- Submit current guess. Returns "short", "invalid", "win", "lose", "ok"
function WordleBoard:submit()
    if self.won or self.lost then return "done" end
    if #self.current < self.word_len then return "short" end

    local guess_str = table.concat(self.current)
    if not isValidWord(self.lang, guess_str) then return "invalid" end
    local states    = self:_evaluate(guess_str)
    self.guesses[#self.guesses + 1] = {
        letters = { table.unpack(self.current) },
        states  = states,
    }

    -- Update keyboard states
    for i, letter in ipairs(self.current) do
        local st = states[i]
        local existing = self.key_state[letter]
        -- CORRECT > PRESENT > ABSENT > nil
        if not existing
                or (st == STATE_CORRECT)
                or (st == STATE_PRESENT and existing ~= STATE_CORRECT) then
            self.key_state[letter] = st
        end
    end

    self.current = {}
    self.row     = self.row + 1

    if guess_str == self.secret then
        self.won    = true
        self.wins   = self.wins + 1
        self.streak = self.streak + 1
        return "win"
    elseif self.row > self.max_tries then
        self.lost   = true
        self.losses = self.losses + 1
        self.streak = 0
        return "lose"
    end
    return "ok"
end

function WordleBoard:_evaluate(guess)
    local states  = {}
    local secret  = self.secret
    local used    = {}  -- secret letter positions already matched

    -- First pass: correct positions
    for i = 1, self.word_len do
        if guess:sub(i,i) == secret:sub(i,i) then
            states[i] = STATE_CORRECT
            used[i]   = true
        else
            states[i] = STATE_ABSENT
        end
    end

    -- Second pass: present but wrong position
    for i = 1, self.word_len do
        if states[i] ~= STATE_CORRECT then
            local ch = guess:sub(i, i)
            for j = 1, self.word_len do
                if not used[j] and secret:sub(j,j) == ch then
                    states[i] = STATE_PRESENT
                    used[j]   = true
                    break
                end
            end
        end
    end

    return states
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

function WordleBoard:serialize()
    return {
        lang      = self.lang,
        word_len  = self.word_len,
        secret    = self.secret,
        guesses   = self.guesses,
        current   = self.current,
        row       = self.row,
        won       = self.won,
        lost      = self.lost,
        key_state = self.key_state,
        wins      = self.wins,
        losses    = self.losses,
        streak    = self.streak,
    }
end

function WordleBoard:load(data)
    if type(data) ~= "table" or not data.secret then return false end
    self.lang      = data.lang      or "en"
    self.word_len  = data.word_len  or WORD_LEN
    self.secret    = data.secret    or ""
    self.guesses   = data.guesses   or {}
    self.current   = data.current   or {}
    self.row       = data.row       or 1
    self.won       = data.won       or false
    self.lost      = data.lost      or false
    self.key_state = data.key_state or {}
    self.wins      = data.wins      or 0
    self.losses    = data.losses    or 0
    self.streak    = data.streak    or 0
    return true
end

WordleBoard.STATE_EMPTY   = STATE_EMPTY
WordleBoard.STATE_TBD     = STATE_TBD
WordleBoard.STATE_CORRECT = STATE_CORRECT
WordleBoard.STATE_PRESENT = STATE_PRESENT
WordleBoard.STATE_ABSENT  = STATE_ABSENT
WordleBoard.LANG_ORDER    = LANG_ORDER
WordleBoard.WORD_LEN      = WORD_LEN
WordleBoard.MAX_TRIES     = MAX_TRIES

return WordleBoard
