; Assignment 3, bonus part
; Contributors Group 1:
; Romy Blankendaal (10680233, romy.blankendaal@gmail.com)
; Maartje ter Hoeve (10190015, maartje.terhoeve@student.uva.nl)
; Suzanne Tolmeijer (10680403, suzanne.tolmeijer@gmail.com)

; UVA/VU - Multi-Agent Systems
; Lecturers: T. Bosse & M.C.A. Klein
; Lab assistants: D. Formolo & L. Medeiros


; --- Settable variables ---
; The following settable variables are given as part of the 'Interface' (hence, these variables do not need to be declared in the code):
;
; 1) dirt_pct: this variable represents the percentage of dirty cells in the environment.
; For instance, if dirt_pct = 5, initially 5% of all the patches should contain dirt (and should be cleaned by your smart vacuum cleaner).
; 2) max_garbage: this variable represents the number of garbage pieces a vacuum can carry at a time.

; --- Global variables ---
; The following global variables are given.
;
; 1) total_dirty: this variable represents the amount of dirty cells in the environment.
; 2) time: the total simulation time.
;
; The following variables are added.
;
; 3) x_end
; 4) y_end
; 6) desire to clean_all
; 7) dirt_locations
; 8) coordinate
; 9) int_x
; 10) int_y
; 11) check_int_x
; 12) check_int_y
; 13) intention clean_dirt
; 14) intention move_to_bin
; 15) intention move_to_dirt
; 16) intention empty_bag --> we have created a fourth intention because if we have move to dirt and clean dirt, we also liked to have a move to bin and an empty bag
; 17) pos_bin
globals [total_dirty time x_end y_end clean_to_max dirt_locations coord_label int_x int_y check_int_x check_int_y clean_dirt move_to_bin move_to_dirt empty_bag pos_bin battery_level loc_in_reach i]
; clean_to_max is added instead of clean_all, to express the idea that the desire of the agent is not to clean all dirt, but to clean as much as it can


; --- Agents ---
; The following types of agent (called 'breeds' in NetLogo) are given. (Note: in Assignment 3.3, you could implement the garbage can as an agent as well.)
;
; 1) vacuums: vacuum cleaner agents.
breed [vacuums vacuum]
breed [bins bin] ; added for part 3


; --- Local variables ---
; The following local variables are given. (Note: you might need additional local variables (e.g., to keep track of how many pieces of dirt are in the bag in Assignment 3.3).
; You could represent this as another belief, but it this is inconvenient you may also use another name for it.)
;
; 1) beliefs: the agent's belief base about locations that contain dirt
; 2) desire: the agent's current desire
; 3) intention: the agent's current intention
vacuums-own [beliefs desire intention dirt_in_bag] ; added dirt in bag to have a variable that stores how much dirt the vacuum cleaner has in its bag


; --- Setup ---
to setup
  clear-all
  set time 0
  set x_end max-pxcor
  set y_end max-pycor
  set total_dirty floor(count patches * dirt_pct / 100)
  set clean_to_max true    ; create the desire for the vacuum to clean or not
  set dirt_locations [] ; create an empty list which stores all the dirt locations (the beliefs)
  set move_to_bin []    ; create an empty list which stores the coordinates of the bin
  set move_to_dirt []   ; create an empty list which stores the coordinates of the dirt where the vacuum goes to
  set loc_in_reach []
  set empty_bag "empty_bag"
  set clean_dirt "clean_dirt"
  set battery_level max_battery
  setup-patches
  setup-vacuums
  setup-bins
  setup-ticks
  setup-beliefs
  setup-desires
end


; --- Main processing cycle ---
to go
  ; This method executes the main processing cycle of an agent.
  ; For Assignment 3, this involves updating desires, beliefs and intentions, and executing actions (and advancing the tick counter).
  update-beliefs
  update-desires
  update-intentions
  ; If the vacuum does not believe there is anything left to clean and does not have the desire or intention to clean anymore, we can stop.
  ; But, if the battery of the vacuum is 0, we also stop.

  execute-actions
  if battery_level > 0 and dirt_locations != [] [tick
  ]
  set time ticks

  ask vacuums [
    if beliefs = [] and desire = false and intention = [] [
      output-print "everything is clean!"
      stop
    ]
    if battery_level <= 0 [
      output-print "out of battery!"
      stop
    ]
  ]
end


; --- Setup patches ---
to setup-patches
  ; Patches that are dirty will get the color grey, white ones are clean
  clear-patches
  ask patches [set pcolor white]
  ask n-of total_dirty patches with [pcolor = white] [set pcolor grey]
  ask patches with [pcolor = grey] [
    set plabel 1 + random (dirt_value - 1 )
  ] ; sets the value of the dirt to a random number between 1 and the max dirt value
end

; --- Setup bins ---
to setup-bins
  ; One bin is initialized at a random location, where the vacuum cleaner can empty its garbage bag
  create-bins 1
  ask bins [
    setxy random-xcor random-ycor
    set shape "house"
    set color blue
    set move_to_bin list xcor ycor
  ]
end

; --- Setup vacuums ---
to setup-vacuums
  ; One pretty yellow vacuum cleaner is initialized at a random location with a random orientation.
  create-vacuums 1
  ask vacuums [
    setxy random-xcor random-ycor
    set color yellow
    facexy random-xcor random-ycor
    set dirt_in_bag 0
  ]
end


; --- Setup ticks ---
to setup-ticks
  reset-ticks
end


; --- Setup beliefs ---
to setup-beliefs
  ; for all patches, if grey, then add to belief list --> these need to be cleaned
  ask patches [
    if pcolor = grey [
      set coord_label (list pxcor pycor plabel)           ; first create a list, coord_label, which stores the coordinates of the patch and the dirt value of the label
      set dirt_locations lput coord_label dirt_locations  ; place this coordinate list into the list which stores all the coordinates
    ]
  ]

  ask vacuums [
    set dirt_locations sort-by [ ( (item 2 ?1) - (distancexy item 0 ?1 item 1 ?1) > (item 2 ?2) - (distancexy item 0 ?2 item 1 ?2) ) ] dirt_locations ; optimal strategy: go to spot with high dirt value that is nearby
    set beliefs dirt_locations
    print "before check loc"
    check-loc-dirt
    print "loc in reach"
    print loc_in_reach
    set move_to_dirt item 0 loc_in_reach
  ]
end

; --- Setup desires ---
to setup-desires
  ; at the start the vacuum will want to clean as much as possible, given its battery.
  ; it has an empty garbage bag, so it will not desire to empty its bin
  ask vacuums [
    set desire clean_to_max
  ]
end


; --- Update desires ---
to update-desires
  ; If the vacuum still beliefs there are dirty spots somewhere, it will keep the desire to clean everything.
  ; If it believes there are no more dirty spots, it will no longer have the desire to clean.

  ask vacuums [
    ifelse beliefs != [] and  battery_level > 0 [ ; battery level should not be 0
      set clean_to_max true
      set desire clean_to_max
    ]
    [
      set clean_to_max false
      set desire false
    ]
  ]
end


; --- Update beliefs ---
to update-beliefs
 ; You should update your agent's beliefs here.
 ; At the beginning your agent will receive global information about where all the dirty locations are.
 ; This belief set needs to be updated frequently according to the cleaning actions: if you clean dirt, you do not believe anymore there is a dirt at that location.
 ; In Assignment 3.3, your agent also needs to know where is the garbage can.
 ;
 ; When the vacuum believes there is no more dirt, it's belief will have an empty list, since there is only one belief: the locations of the dirt.

 ask vacuums [
   ifelse dirt_locations != [] [
     set dirt_locations sort-by [ ( (item 2 ?1) - (distancexy item 0 ?1 item 1 ?1) > (item 2 ?2) - (distancexy item 0 ?2 item 1 ?2) ) ] dirt_locations ; optimal strategy: go to spot with high dirt value that is nearby
     set beliefs dirt_locations
     check-loc-dirt
     if loc_in_reach != [] [
       set move_to_dirt item 0 loc_in_reach
     ]
   ][
     set beliefs dirt_locations
   ]
 ]
end

; --- Update intentions ---
to update-intentions
  ; Here the intention of the vacuum is updated.
  ask vacuums [
    ifelse desire = clean_to_max and beliefs != [] and battery_level > 0 [
      ifelse dirt_in_bag < max_garbage and loc_in_reach != [] [ ; if it's garbage bag is not full yet and it's not at the first one of the belief list and it still has battery --> intention is move to dirt
        ifelse distancexy (item 0 item 0 loc_in_reach) (item 1 item 0 loc_in_reach) > 0.5 [
          print "DISTANCE"
          print  distancexy (item 0 item 0 loc_in_reach) (item 1 item 0 loc_in_reach)
          set intention move_to_dirt
          print "intention:"
          set int_x item 0 intention
          print int_x
          set int_y item 1 intention
          print int_y
          facexy int_x int_y
          print "changed facing direction to new dirt"
        ][
          set intention clean_dirt ] ; if it's at the spot with dirt and it's battery level is not low --> inention is to clean the dirt
      ][
        ifelse distancexy item 0 move_to_bin item 1 move_to_bin > 0.5 [
          set intention move_to_bin ; if it's garbage bag is full but it's not at a bin yet --> move to bin
          set int_x item 0 intention
          set int_y item 1 intention
          facexy int_x int_y
          print "changed facing direction to bin"
        ][
          set intention empty_bag ; --> if it's garbage bag is full and it's at the bin --> empty the bag in the bin
        ]
      ]
    ][
      set intention []
    ]
  ]
end


; --- Execute actions ---
to execute-actions
  ; If the vacuum has the desire to empty its garbage bag and is at a bin, it will empty the bag
  ; If the vacuum has the desire to clean it will try to clean the spot where its at if it is dirty.
  ; If the vacuum still has some intention to get somewhere, it will keep moving.
  ask vacuums [
    if intention = empty_bag [
      empty-bag-in-bin
    ]
    if intention = clean_dirt [
      clean-dirt
    ]
    if intention = move_to_dirt or intention = move_to_bin [
      move
    ]
  ]
end

; --- check whether location is in reach: bag is not too full to add this amount of dirt
to check-loc-dirt
  set loc_in_reach []
  foreach beliefs [
    if item 2 ? + dirt_in_bag <= max_garbage [
      set loc_in_reach lput ? loc_in_reach ; put all reachable locations in a new list
    ]
  ]
end

to empty-bag-in-bin
  ask vacuums [
    set dirt_in_bag 0
    output-print "bag was emptied"
  ]
end

to clean-dirt
  if pcolor = grey [
    set pcolor white
    set total_dirty total_dirty - 1
    set dirt_in_bag dirt_in_bag + plabel
    output-print "cleaned dirt"

    if beliefs != [] [
      set i 0
      foreach beliefs [
        if item 0 ? = pxcor and item 1 ? = pycor [
          set dirt_locations remove-item i dirt_locations
        ]
        set i i + 1
      ]
    ]
  ]
end

to move
  if xcor != int_x and ycor != int_y [
    forward 1
    set battery_level battery_level - 1
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
719
10
1106
418
12
12
15.1
1
10
1
1
1
0
0
0
1
-12
12
-12
12
1
1
1
ticks
30.0

SLIDER
11
49
705
82
dirt_pct
dirt_pct
0
100
4
1
1
NIL
HORIZONTAL

BUTTON
11
17
366
50
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
364
17
705
50
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
13
116
705
161
Number of dirty cells left.
total_dirty
17
1
11

BUTTON
11
82
705
115
NIL
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
12
160
705
205
The agent's current desire.
[desire] of vacuum 0
17
1
11

MONITOR
12
205
705
250
The agent's current belief base.
[beliefs] of vacuum 0
1000
1
11

MONITOR
12
295
705
340
Total simulation time.
time
17
1
11

MONITOR
12
250
705
295
The agent's current intention.
[intention] of vacuum 0
17
1
11

SLIDER
12
340
705
373
max_garbage
max_garbage
0
100
5
1
1
NIL
HORIZONTAL

MONITOR
11
372
705
417
Dirt in Bag
[dirt_in_bag] of vacuum 0
17
1
11

SLIDER
10
416
705
449
max_battery
max_battery
0
10000
1132
1
1
NIL
HORIZONTAL

MONITOR
11
447
705
500
battery level of vacuum cleaner
[battery_level] of vacuum 0
17
1
13

SLIDER
10
496
705
529
dirt_value
dirt_value
0
10
4
1
1
NIL
HORIZONTAL

OUTPUT
719
430
950
457
13

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

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

garbage-can
false
0
Polygon -16777216 false false 60 240 66 257 90 285 134 299 164 299 209 284 234 259 240 240
Rectangle -7500403 true true 60 75 240 240
Polygon -7500403 true true 60 238 66 256 90 283 135 298 165 298 210 283 235 256 240 238
Polygon -7500403 true true 60 75 66 57 90 30 135 15 165 15 210 30 235 57 240 75
Polygon -7500403 true true 60 75 66 93 90 120 135 135 165 135 210 120 235 93 240 75
Polygon -16777216 false false 59 75 66 57 89 30 134 15 164 15 209 30 234 56 239 75 235 91 209 120 164 135 134 135 89 120 64 90
Line -16777216 false 210 120 210 285
Line -16777216 false 90 120 90 285
Line -16777216 false 125 131 125 296
Line -16777216 false 65 93 65 258
Line -16777216 false 175 131 175 296
Line -16777216 false 235 93 235 258
Polygon -16777216 false false 112 52 112 66 127 51 162 64 170 87 185 85 192 71 180 54 155 39 127 36

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

ufo top
false
0
Circle -1 true false 15 15 270
Circle -16777216 false false 15 15 270
Circle -7500403 true true 75 75 150
Circle -16777216 false false 75 75 150
Circle -7500403 true true 60 60 30
Circle -7500403 true true 135 30 30
Circle -7500403 true true 210 60 30
Circle -7500403 true true 240 135 30
Circle -7500403 true true 210 210 30
Circle -7500403 true true 135 240 30
Circle -7500403 true true 60 210 30
Circle -7500403 true true 30 135 30
Circle -16777216 false false 30 135 30
Circle -16777216 false false 60 210 30
Circle -16777216 false false 135 240 30
Circle -16777216 false false 210 210 30
Circle -16777216 false false 240 135 30
Circle -16777216 false false 210 60 30
Circle -16777216 false false 135 30 30
Circle -16777216 false false 60 60 30

vacuum-cleaner
true
0
Polygon -2674135 true false 75 90 105 150 165 150 135 135 105 135 90 90 75 90
Circle -2674135 true false 105 135 30
Rectangle -2674135 true false 75 105 90 120

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
NetLogo 5.3
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
