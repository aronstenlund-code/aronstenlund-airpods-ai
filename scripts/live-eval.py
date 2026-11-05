import json,urllib.request,time,sys
U="https://xjczbzfkmbjdebwlccki.supabase.co"; K="sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"
def post(path,body,tok=None):
    h={"apikey":K,"content-type":"application/json"}
    if tok: h["Authorization"]="Bearer "+tok
    return urllib.request.urlopen(urllib.request.Request(U+path,data=json.dumps(body).encode(),headers=h),timeout=60)
T=json.load(post("/auth/v1/signup",{}))["access_token"]
def ask(frag,hist,mode="text",persona=None):
    b={"fragment":frag,"mode":mode,"language":"sv","context":{"recent_qa":hist[-3:]}}
    if persona: b["persona"]=persona
    t0=time.time();txt="";first=None;sug=None
    with post("/functions/v1/answer",b,T) as r:
        ev=None
        for l in r:
            l=l.decode().rstrip("\n")
            if l.startswith("event: "): ev=l[7:]
            elif l.startswith("data: "):
                d=json.loads(l[6:])
                if "text" in d:
                    txt+=d["text"]; first=first or time.time()-t0
                if ev=="suggestions": sug=d
    return txt or json.dumps(sug,ensure_ascii=False), int((first or time.time()-t0)*1000)
convs=[
 ["vad är en mol"],["15 procent av 80","och 30 procent?"],["andra världskriget","varför började det","kortare"],
 ["hur gör man pannkakor"],["ångest inför prov"],["vad betyder cringe"],["mitokondrien"],["Gustav Vasa"],
 ["pythagoras sats","exempel"],["tiotusen genom fyra hundra"],["vem vann senaste fotbolls VM"],
 ["jag har tappat nycklarna"],["engelska: jag längtar efter dig"],["skillnad virus bakterie"],
 ["e=mc2"],["vad är klockan i tokyo när den är tolv här"],["Kalle sa att jag är tråkig vad säger jag"],
 ["fotosyntes","i natten då"],["svensk riksdag antal ledamöter"],["kemisk formel för koksalt","och socker"],
]
for c in convs:
    h=[]
    for q in c:
        a,ms=ask(q,h); h.append({"q":q,"a":a[:380]})
        print(f"[{ms}ms] {q} -> {a}\n")
