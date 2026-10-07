return {
    ["Not in word list!"]                 = { fr = "Absent de la liste de mots !", es = "¡No está en la lista de palabras!", de = "Nicht in der Wortliste!", it = "Non è nell'elenco di parole!" },
    ["Word too short!"]                   = { fr = "Mot trop court !", es = "¡Palabra demasiado corta!", de = "Wort zu kurz!", it = "Parola troppo corta!" },
    ["Try %1/%2: %3"]                     = { fr = "Tentative %1/%2 : %3", es = "Intento %1/%2: %3", de = "Versuch %1/%2: %3", it = "Tentativo %1/%2: %3" },
    ["Try %1/%2  W:%3 L:%4"]             = { fr = "Tentative %1/%2  V:%3 D:%4", es = "Intento %1/%2  V:%3 D:%4", de = "Versuch %1/%2  S:%3 N:%4", it = "Tentativo %1/%2  V:%3 S:%4" },
    ["Solved in %1! Streak: %2"]              = { fr = "Résolu en %1 ! Série : %2", es = "¡Resuelto en %1! Racha: %2", de = "Gelöst in %1! Serie: %2", it = "Risolto in %1! Serie: %2" },
    ["Guess the hidden word in 6 tries. Letter hints guide each attempt."] = { fr = "Devinez le mot caché en 6 essais. Les indices de lettres guident chaque tentative.", es = "Adivina la palabra oculta en 6 intentos. Las pistas de letras guían cada intento.", de = "Errate das versteckte Wort in 6 Versuchen. Buchstabenhinweise leiten jeden Versuch.", it = "Indovina la parola nascosta in 6 tentativi. Gli indizi sulle lettere guidano ogni tentativo." },
    ["Wordle"]                                 = { fr = "Wordle", es = "Wordle", de = "Wordle", it = "Wordle" },
    -- Rules text (screen.lua GAME_RULES_EN); the key must match it exactly.
    [ [[
Wordle — Rules

Guess the secret 5-letter word in 6 attempts.

After each guess:
• Green tile — the letter is in the correct position.
• Yellow tile — the letter is in the word but in the wrong position.
• Grey tile — the letter is not in the word.

Use the on-screen keyboard to enter letters. Press ↵ to submit a guess, ⌫ to delete.
The keyboard shows the status of each letter used so far.
]] ] = { it = [[
Wordle — Regole

Indovina la parola segreta di 5 lettere in 6 tentativi.

Dopo ogni tentativo:
• Casella verde — la lettera è nella posizione giusta.
• Casella gialla — la lettera è nella parola ma in un'altra posizione.
• Casella grigia — la lettera non è nella parola.

Usa la tastiera sullo schermo per inserire le lettere. Premi ↵ per confermare, ⌫ per cancellare.
La tastiera mostra lo stato di ogni lettera già usata.
]] },
}
