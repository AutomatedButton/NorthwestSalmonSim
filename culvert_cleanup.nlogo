;; Culvert Barrier Removal Educational Tool
;; Developed by Ben Pomeroy and Philip Murphy 2021
;; This Version -- an XX == Out of synch == version by Philip 9/10/2021
extensions [Sound]
globals[
  money ;; int representing how much money (funds) the player has to spend on fixing culverts
  current-culvert ;; the currently selected culvert
  notes ;; string representing any notes about the game while it is being played
  time ;; int representing how many ticks have passed in this simulation
  salmon-lifespan ;; int representing how many ticks a salmon can live at maximum

  ;; patch agentsets
  node ;; agentset containing patches that are nodes?

  ;; landscape constants
  con_pycor_coast  ; the y cooridinate that defines the transition of estuary to sea - below which if you are in the water, you are at sea

  ;; constants
  ;; life cycle stages enums  Note - life cycles and times are roughly based on the life cycle of female coho salmon.  See https://www.nps.gov/olym/learn/nature/the-salmon-life-cycle.htm
  enum_lcs_fry ;; fry life cycle stage -- after hatching from its egg, the small fish feeds in the river system
  enum_lcs_smolt ;; smolt life cycle stage -- fish transitions from fresh water to salt water and heads out to sea
  enum_lcs_adult ; adult life cycle stage  -- fish fattens up at sea
  enum_lcs_spawner; ; spawner life cycle stage  -- fish turns red, leaves ocean and heads back up the stream system to spawn
  enum_lcs_postspawner;  post-spawner life cycle stage  -- after spawning, the fish survives breifly before dying.
  ;; Transition ages enums.  a tic in NetLogo time is about 1 week in the world
  enum_smolt_start ; age in tics that fry transition to smolt
  ;;enum_adult_start ; age in tics that smolt transition to adults - not set, as soon as smolt reach the ocean, they automatically become adults
  enum_spawner_start ; age in tics when adults transition to spawners and return to natal streams to spawn
  ;;enum_post_spawner_start ; age in tics when spawners become post spawners -- not set, as happens automatically when they spawn
  ;; life cycle stage colors
  enum_lcs_fry_col ;; = yellow
  enum_lcs_smolt_col ;; cyan
  enum_lcs_adult_col ;; = brown
  enum_lcs_spawner_col ;;  red
  enum_lcs_postspawner_col  ;;=grey
  ;; fish pop constants
  fish_max_age ; max age for fish in tics -- at or around that, they die
  fish_per_spawn ; number of fry that spawn for each adult spawner (In reality, alevins, with yoke sacs emerge, which they consume and when emerge from gravel, are considered fry.)

  ;; Initial Population
  con_start_pop_adult ; number of adults at start
  con_start_pop_spawner ; number of spawners at start

  ;; budgets
  con_budget_total  ;; total budegt available over the years
  con_budget_annual ;; budget newly availabke each year
  budget_total_spent ;; cumulative total spent over te years
  budget_this_year ;; adjusted to keep money let than total
  budget_exhausted ;; 1=true/0=false

  ;; culverts
  culverts_total  ;; Total number of culverts in a  level
  culverts_fixed ;; Number of culverts fixed so far

  ;; end condition
  game_over ;; 0 false/1 true  -- set to true if an end condition is reached
  fish_population_win  ;; if fish population reaches this number, the palyer has won
  end_out_of_time;; number of ticks where we ll the game over -- population has died but hasn't reached target either
]

turtles-own[
  age ;; int representing the number of ticks this salmon has been alive
  stage-life-cycle ;; int representing the stage of the salmon's life cycle
  is-laying-eggs ;; bool representing if a salmon is currently laying eggs
  personal-timer ;; int representing how many ticks this salmon has left until the next stage of its life
]

patches-own[
  depth ;; int representing depth in the system?
  max-fish ;; int representing how many salmon can be in this part of the river at any given time
  current-eggs ;; int representing how many salmon eggs are currently here
  max-eggs ;; int representing how many salmon eggs can be stored in this piece of water
  current-fish ;; int representing how many salmon are currently in this piece of water
  culvert? ;; bool that is true iff there is an unfixed culvert in this piece of water
  price-to-fix ;; int that represents how much it would cost to fix this particular culvert
  accessable? ;; bool that is true iff the salmon can access this piece of water via the river network
]

to setup
  clear-all;
  set-default-shape turtles "fish"
  set-patch-size 14;
  resize-world -20 20 -20 20;
  setup-globals
  setup-patches
  setup-constants
  ask node with [pycor = -7 and pxcor = 2][become-current]    ;; current when game opens
  ;; Create all of the turtles
  create-turtles con_start_pop_spawner [
    setup-fish-spawner
  ]
  create-turtles con_start_pop_adult [
    setup-fish-adult
    ;;set stage-life-cycle enum_lcs_smolt
  ]
  print node
  reset-ticks

end

to go
  if game_over = 1 [stop]
  choose-current
  if time mod 52 = 0
  [  ;; annual budget increase
    if budget_exhausted = 0  ; Not yet exhausted
    [
      set budget_this_year con_budget_annual;
      sound:play-sound "mixkit-clinking-coins-1993.wav"
      if budget_total_spent + budget_this_year >= con_budget_total
        [
        set budget_this_year  con_budget_total - budget_total_spent;
        set notes (word notes "total budget of " con_budget_total  " is exhausted on week #" time  ". Lets hope we have done enough.\n");  ;; impose total budget
        set budget_exhausted 1; ; Budget officially exhausted for this game
        ]
      ; Check cash in hand -- this can exceed Total budget if the user doesn't fix any culverts, and  budget_total_spent + budget_this_year < con_budget_total
      ifelse money + budget_this_year > con_budget_total
        [set money con_budget_total]
        [set money money + budget_this_year]
    ] ;; is budget exhausted
  ] ;; is time to add annual budget
  ;;set money money + 1;
  set time time + 1;
  ask turtles[ move-fish ];
  ask turtles[ if age > fish_max_age [ die ] ]  ;; die at 4 years
  ask turtles[ fish-predation ]
 ;;Trying to get this working, need some way of getting a list containing each turtle
  (foreach filter [ x -> [is-laying-eggs = true] of x] [self] of turtles
    [ x ->
      create-turtles fish_per_spawn [
        set age 0;
        set stage-life-cycle enum_lcs_fry;
        set is-laying-eggs false;
        set color enum_lcs_fry_col;
        move-to [patch-here] of x
      ]
  ] )
  ask turtles[
    set is-laying-eggs false
    if personal-timer != -1 [ set personal-timer personal-timer - 1 ] ]
    if time mod 53 = 0  [
                          if count turtles = 0
                            [
                               set notes (word notes "Game Over: All the fish have died.  You did your best. \n");
                               set game_over 1  ;; game will stop at next call to go procedure
                            ]
                          if count turtles >= fish_population_win
                            [
                               set notes (word notes "Game Over! Fish population has reached a sustainable population of " fish_population_win ". Well done!  \n");
                               set game_over 1  ;; game will stop at next call to go procedure
                            ]
                            if time >= end_out_of_time
                            [
                               set notes (word notes "Game Over: Reached time limit of " end_out_of_time " weeks.  You kept them alive! \n");
                               set game_over 1  ;; game will stop at next call to go procedure
                            ]
                          output-print notes;
                          set notes "";
                        ]
  tick
end

to setup-globals
  clear-all
  set con_pycor_coast -9 ; below this you are at sea
  set money 0;
  set culverts_fixed 0;
  set budget_total_spent 0;
  set budget_exhausted 0;
  set notes "\n";
  set game_over 0;
end

to setup-constants
  ;; initial populations
  set con_start_pop_adult 10 ; number of adults at start
  set con_start_pop_spawner 5 ; number of spawners at start
  ;; life cycle stages
  set enum_lcs_fry 0;
  set enum_lcs_smolt 1;
  set enum_lcs_adult 2;
  set enum_lcs_spawner 3;
  set enum_lcs_postspawner 4;
  set enum_smolt_start 10;  for coho this is about 50 weeks
  set enum_spawner_start 80 ; for coho this is about 80 weeks
  set fish_max_age 200; about 4 years life span
  set  fish_per_spawn 5; number of fry that spawn for each adult spawner (In reality, alevins, with yoke sacs emerge, which they consume and when emerge from gravel, are considered fry.)
  set enum_lcs_fry_col yellow
  set enum_lcs_smolt_col  cyan
  set enum_lcs_adult_col brown
  set enum_lcs_spawner_col red
  set enum_lcs_postspawner_col   grey
  set con_budget_total 100;  ;; total budegt available over the years
  set con_budget_annual 50; ;; funds newly available each year
  set fish_population_win 100 ;; winning condition - if population reaches 100 then its deemed sustainable
  set end_out_of_time 2080;; 20 years -- number of ticks where we ll the game over -- population has died but hasn't reached target either
end

to setup-patches
  ;; Setting the background to green
  ask patches [
    set pcolor green;
  ]

  ;; Set which tiles are nodes - draws the river network
  set node patches with [
    ;;(pycor >= -10 and pycor <= -5 and pxcor = 0)  ;; A
    (pycor >= -5 and pycor <= -3 and pxcor = 1)  ;; A
    or (pycor >= -3 and pycor <= 1 and pxcor = 0)  ;; A
    or (pycor >= 1 and pycor <= 3 and pxcor = -1)  ;; A* added to left of A
    ;;or (pxcor = 1 and (pycor = -7 or pycor = -7))  ;; B - remobed 1 pixel
    or (pxcor = 2 and (pycor = -7 or pycor = -6)) ;; C
    or (pycor = -5 and (pxcor >= -2 and pxcor <= 1))
    or (pxcor = 2 and pycor >= -1 and pycor <= 1) ;; D
    or (pxcor = 3 and pycor >= 1 and pycor <= 3)  ;; E
    or (pxcor = 2 and pycor >= 3 and pycor <= 5)  ;; E offset ext
    or (pxcor = 3 and pycor >= -6 and pycor <= -2) ;; F
    or (pxcor >= 2 and pxcor <= 5 and pycor = -5) ;; G
   ;; or (pxcor >= 1 and pxcor <= 2 and pycor = -2) ;; H
    or (pxcor >= 2 and pxcor <= 2 and pycor = -2) ;; H disconnected loop
    or (pxcor <= -1 and pxcor >= -2 and pycor = -5) ;; J
    or (pxcor = 6 and pycor >= -1 and pycor <= 0) ;; K
    or (pxcor = 7 and pycor >= 0 and pycor <= 2) ;; L
    or (pxcor >= 7 and pxcor <= 9 and pycor = 2) ;; L  -- extended L to right
    or (pxcor <= -2 and pxcor >= -3 and pycor = -4) ;; M
    or (pxcor = -3 and pycor >= -3 and pycor <= -1) ;; N
    or (pxcor = -4 or pxcor = -3 and pycor = -1) ;; O  shortened
    or (pxcor <= -4 and pxcor >= -5 and pycor = 0) ;; P
    or (pxcor <= -5 and pxcor >= -6 and pycor = 1) ;; Q
    or (pxcor = -7 and pycor >= 1 and pycor <= 3) ;; R shifeted to left 3 and up 3
    or ((pxcor = -8 or pxcor = -9) and pycor = 1) ;; R New reach to the left of R
     or (pxcor = -8 and pycor >= 3 and pycor <= 5) ;; R shifeted to left 3 and up 3
    or (pxcor <= 15 and pxcor >= -15 and pycor <  con_pycor_coast)  ;; The Ocean
    or (pxcor = 5 and pycor >= -4 and pycor <= 5) ;; T
     or (pxcor = 6 and pycor >= 5 and pycor <= 6) ;; T extended
    or (pxcor <= 6 and pxcor >= 5 and pycor = 7) ;; T extended - twist to left
    or (pycor = -8 and (pxcor <= 0 and pxcor >= -3))
    or (pycor = -8 and (pxcor <= 2 and pxcor >= 1))
    or (pycor = -7 and (pxcor <= -2 and pxcor >= -4))
    or (pycor = -6 and (pxcor <= -4 and pxcor >= -6))
    or (pycor = -5 and (pxcor <= -6 and pxcor >= -9))
    or (pycor = -4 and (pxcor <= -9 and pxcor >= -11))
    or (pxcor = -11 and (pycor <= -4 and pycor >= -5))
    or (pycor = con_pycor_coast and (pxcor <= 1 and pxcor >= -4) ; Estuary
    )
  ]

  ;; Setting up baselines for every node
  ask node [
    set pcolor blue;
    set accessable? true;
    set current-fish 0;
    set current-eggs 0;
    set max-eggs 0;
    set max-fish 10;
    set culvert? false;
    set price-to-fix 0;
    set depth pycor + 10;
  ]
  ask node with [ pycor > -10] [
    set accessable? false;
  ]
  set-particular-nodes

  ;; Setting all culvert nodes brown
  ask node with [culvert? = true][
    set pcolor 35; brown
    set accessable? false;
  ]

  ;; Setting up more difficult culverts
  ask node with [(pycor = -4 and pxcor = -3) or (pycor = -4 and pxcor = 3)][
    set price-to-fix 30; black
    set pcolor 32]
end



to setup-fish-spawner
  set age enum_spawner_start + random 20;
  set stage-life-cycle enum_lcs_spawner;
  set is-laying-eggs false;
  set color enum_lcs_spawner_col;
  put-on-empty-node
end

to setup-fish-adult
  set age enum_smolt_start + random 20;
  set stage-life-cycle enum_lcs_adult;
  set is-laying-eggs false;
  set color enum_lcs_adult_col;
  put-on-empty-node
end

to set-particular-nodes
;; Culverts
  set culverts_total 9;
  ask node with [
    (pycor = -7 and pxcor = 2)
  or (pycor = -4 and pxcor = 3)
  or (pycor = 0 and pxcor = 0)
  or (pycor = -4 and pxcor = 1)
  or (pycor = -5 and pxcor = 0) ;; moved off confluence
  or (pycor = -3 and pxcor = 5)
  or (pycor = -5 and pxcor = 5)
  or (pycor = -4 and pxcor = -3)
  or (pycor = 2 and pxcor = -7)][
    set culvert? true;
    set price-to-fix 15;
  ]
  ;; Spawning habitat
  ask node with [
    (pycor = 1 and pxcor = 0)
    or (pycor = 3 and pxcor = 5)
    or (pycor = 1 and pxcor = -6)
    or (pycor = 3 and pxcor = 3)
    or (pycor = 2 and pxcor = -2)
    or (pycor = 2 and pxcor = 7)
    or (pycor = 0 and pxcor = 2)
    or (pycor = -5 and pxcor = -7)
  ][
    set max-eggs 10;
    set pcolor yellow
  ]

end

to choose-current
  if mouse-down? [
    let x-mouse mouse-xcor
    let y-mouse mouse-ycor
    let just-fixed false
    if current-culvert = min-one-of node [distancexy x-mouse y-mouse]  [
      fix-culvert
      ask current-culvert [
      ask patch-at -1 1 [ set plabel "" ] ;; unlabel the current intersection (because we've chosen a new one)
      ifelse culvert? [ set pcolor brown ][ set pcolor blue ]
    ]
      set current-culvert no-patches;
      set just-fixed true
      ;;set current-culvert = min-one-of node [distancexy x-mouse y-mouse] ;; Working on getting it to select new culvert.
    ]
    ask current-culvert [
      ask patch-at -1 1 [ set plabel "" ] ;; unlabel the current intersection (because we've chosen a new one)
      ifelse culvert? [ set pcolor brown ][ set pcolor blue ]
    ]
    if not just-fixed [
    ask min-one-of node [ distancexy x-mouse y-mouse ] [
      become-current
    ] ]
    display
  ]
end

to become-current ;; patch procedure
  set current-culvert self
  set pcolor red
  ask patch-at -1 1 [
    set plabel-color black
    set plabel "current"
  ]
end

to fix-culvert ;; patch procedure
  ask current-culvert [
    ifelse money >= price-to-fix [
      set pcolor blue
      set culvert? false
      set notes (word notes "culvert on " pycor "," pxcor " fixed on tick #" time " at a cost of " price-to-fix "\n")
      set money money - price-to-fix
      set culverts_fixed culverts_fixed + 1
      set budget_total_spent budget_total_spent + price-to-fix
      set price-to-fix 0
    ][
      sound:play-sound "mixkit-game-show-buzz-in-3090.wav"
    ]
  ]
end

to move-fish ;; turtle procedure
  ;; Handles fish that have just been spawned
  (ifelse stage-life-cycle = enum_lcs_fry [
    ask self[ move-random ]
    if age > enum_smolt_start [
      set stage-life-cycle enum_lcs_smolt
      set color enum_lcs_smolt_col;
    ]
  ]
    ;; Movement rules for a fish going to to the base of the river system - smolt
  stage-life-cycle = enum_lcs_smolt [
      ask self [ move-downstream ]
      if [depth] of patch-here = -5 ; when a smolt reaches the sea + 5 below, it turns into an adult
      [
        set stage-life-cycle enum_lcs_adult
        set color enum_lcs_adult_col;
      ]
  ]
      ;; Movement rules for a fish swimming around the ocean and fattening up - adult
  stage-life-cycle = enum_lcs_adult [
      ask self[ move-random ]
      if age > enum_spawner_start ; time to return home and spawn
      [
        set stage-life-cycle enum_lcs_spawner
        set color enum_lcs_spawner_col;
      ]
  ]

    ;; Movement rules for a fish going back up stream to try to find a spawning area to lay eggs - Spawner
  stage-life-cycle = enum_lcs_spawner [
      ifelse pycor < con_pycor_coast ; if  still swimming in ocean,
        [ask self [move-fromseatoEstuary]]  ;;  head for the estuary
        [ask self [ move-upstream ]]  ; fish is in the estuary -- move up stream
      if [current-eggs] of patch-here < [max-eggs] of patch-here [
        set is-laying-eggs true
        set stage-life-cycle enum_lcs_postspawner
        set color enum_lcs_postspawner_col;
      ]
  ]
    ;; Movement rules for a fish going to live the rest of its life after laying eggs
  stage-life-cycle = enum_lcs_postspawner [
      ask self [ move-random ]
      (ifelse personal-timer = -1 [ set personal-timer 3 ]
        personal-timer = 0 [ die ])
  ])
  set age age + 1
end

to move-upstream ;; turtle procedure
  let depth-here [depth] of patch-here
  let suitable-neighbors neighbors4 with [depth-here <= depth]
  carefully [
     move-to one-of suitable-neighbors with [member? self node and [culvert?] of self = false]
     ] [ask self[ move-random ] ]
end

to move-fromseatoEstuary
  let headinghome towardsxy 0 con_pycor_coast  ; heading to the estuary
  if pycor < con_pycor_coast [
    set heading headinghome
    fd 1
  ]
end

to move-downstream ;; turtle procedure
  let depth-here [depth] of patch-here
  let suitable-neighbors neighbors4 with [depth-here >= depth]
  carefully [
  move-to one-of suitable-neighbors with [member? self node and [culvert?] of self = false]
  ] [ask self[ move-random ] ]

end

;; This function lets the salmon move around aimlessly
to move-random ;; turtle procedure
  let x random 4
  (ifelse x = 0 [
    carefully [
      ;print member? patch-at 0 1 node
      if not member? patch-at 0 1 node or ([culvert?] of patch-at 0 1 = true) [
        error "The patch this fish is trying to move to cannot be moved to"
      ]
      move-to patch-at 0 1
    ] [ ask self[ move-random ]
    ]
  ]
  x = 1 [
    carefully [
      if not member? patch-at 1 0 node or ([culvert?] of patch-at 1 0 = true) [
        error "The patch this fish is trying to move to cannot be moved to"
      ]
      move-to patch-at 1 0
    ] [ ask self[ move-random ] ]
  ]
  x = 2 [
    carefully [
      if not member? patch-at 0 -1 node or ([culvert?] of patch-at 0 -1 = true)[
        error "The patch this fish is trying to move to cannot be moved to"
      ]
      move-to patch-at 0 -1
    ] [ ask self[ move-random ] ]
  ]
  x = 3 [
    carefully [
      if not member? patch-at -1 0 node or ([culvert?] of patch-at -1 0 = true)[
        error "The patch this fish is trying to move to cannot be moved to"
      ]
      move-to patch-at -1 0
    ] [ ask self[ move-random ] ]
  ])

end

to lay-eggs ;; turtle procedure

end

to fish-predation
  let rng random 100 ; 1 in 100 chance of being predated at each tic
  ifelse stage-life-cycle = 1 and [depth = 0] of patch-here = true [
    if rng <= 1 [die]
  ] [ if rng = 0 [ die ] ]
end

to put-on-empty-node ;; Maybe just move-to a specific node (the base node)
  move-to one-of node with [accessable? and (current-fish < max-fish)]
end
@#$#@#$#@
GRAPHICS-WINDOW
142
10
724
593
-1
-1
14.0
1
10
1
1
1
0
1
1
1
-20
20
-20
20
0
0
1
ticks
1.0

BUTTON
15
23
126
56
Setup  Habitat
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
33
690
108
735
node count
count node
17
1
11

MONITOR
1233
41
1344
86
Available Budget
money
17
1
11

BUTTON
17
70
135
103
Start Simulation
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
1226
478
1363
523
Total Salmon Population
count turtles
17
1
11

BUTTON
8
198
123
231
Select a Culvert
choose-current
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
5
150
147
195
Price to Fix Current Culvert
[price-to-fix] of current-culvert
17
1
11

BUTTON
9
240
122
273
Fix the Culvert
fix-culvert
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
1224
551
1362
596
# Post-Spawners (LC=3)
count turtles with [stage-life-cycle = 3]
17
1
11

MONITOR
1225
600
1363
645
# Spawners (LC=2)
count turtles with [stage-life-cycle = 2]
17
1
11

MONITOR
1224
650
1362
695
#Smolt (LC=1)
count turtles with [stage-life-cycle = 1]
17
1
11

PLOT
751
375
1214
744
Salmon Population
Weeks
Salmon Population
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Total" 1.0 0 -16777216 true "" "plot count turtles"
"Younglings" 1.0 0 -11085214 true "" "plot count turtles with [stage-life-cycle = 0]"
"Smolt" 1.0 0 -13345367 true "" "plot count turtles with [stage-life-cycle = 1]"
"Spawners" 1.0 0 -2674135 true "" "plot count turtles with [stage-life-cycle = 2]"
"Post-Spawners" 1.0 0 -7500403 true "" "plot count turtles with [stage-life-cycle = 3]"
"Sustainable population" 1.0 0 -1184463 true "" "plot fish_population_win"

OUTPUT
142
597
732
740
11

PLOT
752
41
1215
333
Available Budget
weeks
available budget
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot money"

MONITOR
1224
699
1362
744
# Younglings (LC=0)
count turtles with [stage-life-cycle = 0]
0
1
11

TEXTBOX
9
123
159
141
Culverts
14
0.0
1

MONITOR
1231
202
1342
247
Total Spent to date
budget_total_spent
17
1
11

MONITOR
1232
253
1340
298
NIL
budget_exhausted
17
1
11

MONITOR
1232
97
1343
142
Total Budget
con_budget_total
17
1
11

MONITOR
1231
152
1342
197
NIL
budget_this_year
17
1
11

MONITOR
1227
396
1365
445
Sustainable Population
fish_population_win
17
1
12

TEXTBOX
755
15
936
55
Budget and Spending
16
0.0
1

TEXTBOX
753
348
903
368
Salmon Population
16
0.0
1

TEXTBOX
1229
370
1379
388
Target
14
0.0
1

TEXTBOX
1230
457
1361
475
Current
14
0.0
1

@#$#@#$#@
## WHAT IS IT?

This model is to show how removing culverts that are blocking fish passage can help restore salmon populations.

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
