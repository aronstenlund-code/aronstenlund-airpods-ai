"""O64: två nya påhittade hållout-prov för omtestet efter K66, skrivna av Oscar (QA) 2026-11-14. Aldrig elevtext.
Ett engelskt (D182: frågor och svar på engelska) och ett fysikprov med siffror och formler (K66 punkt 4: visningstext).
Samma format som materials_holdout.H. Ligger utanför exams.json.
"""

H4 = {}

H4["h4-en-lighthouse"] = dict(
    subject="Engelska", grade="åk 9", grade_ok=["åk 9", "åk9", "årskurs 9"], max_q=None, topic="Short story and opinion text",
    pages=[
        "English 9 – Test on chapter 4: The Lighthouse Keeper\nThe story is set on a small island off the coast of "
        "Scotland in 1952. Thomas, a fifteen-year-old boy, lives with his grandfather, who keeps the lighthouse. His "
        "parents died in a storm when he was six, so he is afraid of the sea.",
        "The plot\nOne night the electricity fails during a storm and the light goes out. A fishing boat is heading "
        "for the rocks. Thomas's grandfather has hurt his leg, so Thomas has to climb the 120 steps and light the old "
        "oil lamp himself. Because he faces his fear, the boat and its crew of four are saved.",
        "Themes and language\nThe main theme is courage: being brave does not mean having no fear, but acting in "
        "spite of it. The writer uses the storm as a symbol of Thomas's fear. The story is told in the first person, "
        "so we only know what Thomas thinks and feels.",
        "Words to learn\nkeeper – a person who looks after something\nto fail – to stop working\nin spite of – "
        "even though something is there\nthe crew – the people who work on a boat",
        "Writing task\nIn the test you will also write a short opinion text: Should young people take on adult "
        "responsibilities? Give at least two reasons and use linking words like firstly, however and in conclusion.",
    ],
    formats=[("pdf", [0, 1, 2, 3, 4])],
    goals=[
        ("G1", "Setting and characters", ["scotland", "1952", "thomas", "grandfather", "island"]),
        ("G2", "Why Thomas is afraid of the sea", ["parents", "storm", "afraid"]),
        ("G3", "The plot: the light fails and Thomas lights the lamp", ["electricity", "lamp", "120", "steps", "boat"]),
        ("G4", "Theme: courage in spite of fear", ["courage", "brave", "in spite of"]),
        ("G5", "Symbol and first-person narrator", ["symbol", "first person", "first-person"]),
        ("G6", "Words and the opinion text", ["crew", "keeper", "linking", "firstly", "opinion"]),
    ],
    outside=["shakespeare", "london", "mother survived", "dog", "radio"],
)

H4["h4-fy-hastighet"] = dict(
    subject="Fysik", grade="åk 8", grade_ok=["åk 8", "åk8", "årskurs 8"], max_q=None, topic="Hastighet, kraft och tryck",
    pages=[
        "Fysik åk 8 – Rörelse och krafter\nHastighet är hur lång sträcka något färdas per tidsenhet: v = s / t. "
        "En cyklist som cyklar 18 km på 1,5 timmar har medelhastigheten 12 km/h. 1 m/s är samma sak som 3,6 km/h.",
        "Kraft\nKraft mäts i newton (N). Tyngdkraften på ett föremål är F = m · g, där g ≈ 9,8 N/kg på jorden. "
        "En väska på 5 kg dras alltså mot jorden med ungefär 49 N. På månen är g bara 1,6 N/kg, så samma väska "
        "väger mindre där, men massan är fortfarande 5 kg.",
        "Friktion\nFriktion är en kraft som bromsar rörelse mellan två ytor. På is är friktionen liten, därför är det "
        "lätt att halka. Däck har mönster för att öka friktionen mot vägen när det är blött.",
        "Tryck\nTryck är kraft per area: p = F / A, och mäts i pascal (Pa). Samma kraft på en mindre yta ger större "
        "tryck. Därför sjunker man ner i snön med vanliga skor men inte med snöskor, som har en större yta. "
        "Lufttrycket vid havsytan är ungefär 101 300 Pa.",
    ],
    formats=[("photo", [0, 1, 2, 3])],
    goals=[
        ("G1", "Hastighet och v = s / t", ["hastighet", "sträcka", "12", "km/h"]),
        ("G2", "Omvandla m/s och km/h", ["3,6", "m/s"]),
        ("G3", "Tyngdkraft F = m · g och månen", ["newton", "9,8", "49", "månen", "massa"]),
        ("G4", "Friktion", ["friktion", "is", "däck"]),
        ("G5", "Tryck p = F / A och snöskor", ["tryck", "pascal", "area", "snöskor"]),
    ],
    outside=["acceleration", "newtons tredje lag", "arkimedes", "energi", "effekt"],
)
