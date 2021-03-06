; FINAL ASSIGNMENT
; Contributors Group 1:
; Romy Blankendaal (10680233, romy.blankendaal@gmail.com)
; Maartje ter Hoeve (10190015, maartje.terhoeve@student.uva.nl)
; Suzanne Tolmeijer (10680403, suzanne.tolmeijer@gmail.com)



; TO DO
; BDI framework
; Save doors to rooms
; Cops: follow thieves
; Thieves: get item, escape
; communcation
; customers should move a bit --> for example random sample moves 1 forward in a random direction per tick
; update seen thieves so that it can work with thieves that move
; cops can still walk through the wall


; DONE
; Setup floor
; All patches belong to room, including doors
; Thieves in environment
; Cops in environment
; Cops and thieves have vision radius
; Cops: find thieves in vision radius
; Cops: moves around randomly when no thieves observed --> doesn't walk through wall, doesn't walk through customers
; update vision radius while moving
; cops send messages containing position of thieves to other cops


extensions [table]


; --- Global variables ---
; The following global variables are given.

globals [time
         room_dict
         x
         y
         stealable_item]

; time: the time elapsed during the simulation
; room_dict: a dictionary with all the rooms, and which patches belong to it
; x: ?
; y: ?
; stealable_item: boolean whether or not an item is stealable by thieves


; --- Agents ---
; The following types of agent (called 'breeds' in NetLogo) are given.
;
breed [cops cop]
breed [thieves thief]
breed [customers customer]


; --- Local variables ---
; The following local variables are given.

customers-own [ move_around ]
; move_around: every customer will have the intention to move around

cops-own [beliefs desire intention view vision_radius strength speed radius
  move_around observe_environment inform_colleague receive_message
  chase_thief catch_thief escort_thief look_for_thief
  belief_seeing_thief belief_room belief_outside_door seen_thieves
  messages sent_messages]
; view: how many patches forward
; vision_radius: all patches he can see

thieves-own [ belief_seeing_cop belief_room belief_outside_door belief_items desire intention strength speed radius items steal flight
  move_around observe_environment move_to_item steal_item drop_item escape view vision_radius seen_cops item_x item_y check_item_x check_item_y]




; --- Setup ---
to setup
  clear-all
  set time 0
  setup-patches
  setup-rooms
  setup-customers
  setup-ticks
end

to setup-customers
  create-customers num_customers
  ask customers [
    set shape "person"
    set color red
    move-to one-of patches with [pcolor != black and not any? customers-on self]
    ; customers have only one intention
    set move_around "move_around"
  ]
end

to setup-thieves
  ask thieves [
    ; beliefs

    ; desires
    set steal "steal"
    set flight "flight"

    ; intentions
    set move_around "move_around"
    set observe_environment "observe_environment"
    set steal_item "steal_item"
    set drop_item "drop_item"
    set escape "escape"
  ]
end

to setup-cops
  ask cops [
    ; beliefs


    ; desires
    set look_for_thief "look_for_thief"
    set catch_thief "catch_thief"

    ; intentions
    set move_around "move_around"
    set observe_environment "observe_environment"
    set inform_colleague "inform_colleague"
    set receive_message "receive_message"
    set chase_thief "chase_thief"
    set catch_thief "catch_thief"
    set escort_thief "escort_thief"
  ]
end



; --- Main processing cycle ---
to go
  ; This method executes the main processing cycle of an agent.
  if ticks = 0 [
    setup-thieves
    setup-cops
  ]
  update-desires
  update-beliefs
  update-intentions-cops
  ; update-intentions-thieves
  execute-actions-cops
  ;execute-actions-thieves
  tick
end




to place-item-manually
  if mouse-down?
  [
    ask patch round mouse-xcor round mouse-ycor [
    set stealable_item "yes" ;patches cannot have a 'shape', therefor the items are just a orange square
    set pcolor orange
  ]
  stop
]
end

to place-cop-manually
  if mouse-down?
  [
    create-cops 1 [
      setxy floor(mouse-xcor) floor(mouse-ycor)
      set color black
      set shape "person"
      set heading 0 ; delete, this is just for debugging
      set view 90
      set seen_thieves []
      set messages []
      set sent_messages []
      set vision_radius []
      set-vision-radii-cops who
      setup-beliefs-cops who
      setup-desires-cops who
      ]
    stop
  ]
end

to place-thief-manually
  if mouse-down?
  [
    create-thieves 1 [
      setxy floor(mouse-xcor)  floor(mouse-ycor)
      set color green
      set shape "person"

      set view 90
      set seen_cops []
      set vision_radius []
      set-vision-radii-thieves who
      setup-beliefs-thieves who
      setup-desires-thieves who
      ]
    stop
  ]
end

; NOTE: we do have some questionable vision radii every now and then...
to set-vision-radii-cops [c]
  ; set up radius cops
  ask cop c [

    ; remove current vision radius
    foreach vision_radius [
       let clean_x item 0 ?
       let clean_y item 1 ?
       ask patches with [pxcor = clean_x and pycor = clean_y] [
         set pcolor white
       ]
    ]

    set vision_radius [] ; empty this thing here
    let cop_room table:get room_dict list floor(xcor) floor(ycor) ; floor because you can be on a continuous value

    ask patches in-cone radius-cops view [
      let patch_coord list pxcor pycor
      let room_patch table:get room_dict patch_coord

      if room_patch = cop_room and pcolor != black [
        ask cop c [
          set vision_radius lput (patch_coord) vision_radius
        ]
        set pcolor 99 ;light blue
      ]
    ]
  ]
end

to set-vision-radii-thieves [t]
  ; set up vision radius thieves

  ask thief t [

    ; remove current vision radius
    foreach vision_radius [
       let clean_x item 0 ?
       let clean_y item 1 ?
       ask patches with [pxcor = clean_x and pycor = clean_y] [
         set pcolor white
       ]
    ]

    set vision_radius [] ; empty this thing here
    let thief_room table:get room_dict list floor(xcor) floor(ycor) ; floor because you can be on a continuous value

    ask patches in-cone radius-thieves view [
      let patch_coord list pxcor pycor
      let room_patch table:get room_dict patch_coord

      if room_patch = thief_room and pcolor != black [
        ask thief t [
          set vision_radius lput (patch_coord) vision_radius
        ]
        set pcolor 69 ;light green
      ]
    ]
  ]
end


; --- Setup ticks ---
to setup-ticks
  ; In this method you may start the tick counter.
  reset-ticks
end

; --- Setup beliefs ---
to setup-beliefs-cops [c]
  ask cop c [
    set belief_seeing_thief []
    ;print "setted up beliefs"
    ;print belief_seeing_thief
    set belief_room [] ; what's this exactly?
    set belief_outside_door []
  ]
end

to setup-beliefs-thieves [t]
  ask thief t [
     set belief_seeing_cop []
     set belief_room []
     set belief_outside_door []
     set belief_items [] ;belief about the items that can be stolen
  ]
end

; --- Setup desires ---
to setup-desires-cops [c]
  ask cop c [
    set desire look_for_thief
  ]
end

to setup-desires-thieves [t]
  ask thief t [
    set desire steal_item
  ]
end

; --- Setup intentions ---
to setup-intentions
  ask cops [
    set intention []
  ]

  ask thieves [
    set intention []
  ]
end

; --- Update desires ---
to update-desires
  ; You should update your agent's desires here.
  ask cops [

  ]

  ask thieves [
    ;if the thief has an item or has an items and sees a cop, the thief will flight.
    ifelse belief_items != [] [
      ifelse belief_seeing_cop != [] [
          set desire flight
        ]
        [
          set desire flight
        ]
      ]
    [
      set desire steal_item
    ]
    ]
end


; --- Update beliefs ---
to update-beliefs
 ; You should update your agent's beliefs here.
 let t 0
 ask thieves [
   set belief_seeing_cop seen_cops
   set belief_seeing_cop sort-by [(distancexy item 0 ?1 item 1 ?1 < distancexy item 0 ?2 item 1 ?2)] belief_seeing_cop
   ;should the belief not contain strength, speed and coordinates instead of a string?

   ;if seeing cop: store cop with speed, strength and location (for number of ticks)

   ;store room (and door?)

   ;if outside door, store it

   ; delete item that the thief has already stolen from belief_items and sort the list (just in case there are more than 1 items in sight, the thief will catch the closest item)
  if belief_items != [] [
      let check_items item 0 belief_items
      set check_item_x item 0 check_items
      set check_item_y item 1 check_items
      ask patch check_item_x check_item_y [
        if pcolor = white [
          ask thief t [
            if belief_items != [] [
              set belief_items remove-item 0 belief_items
            ]
          ]
       ]
      ]
    ]

  set t t + 1
 ]

 ;print "updating beliefs"

 ;
 ask cops [
   set belief_seeing_thief seen_thieves
   set belief_seeing_thief sort-by [(distancexy item 0 ?1 item 1 ?1 < distancexy item 0 ?2 item 1 ?2)] belief_seeing_thief
   ;NOTE: now it's sorted on distance only, might want to take doors and rooms into account

 ]


   ; update which door belongs to which room

   ; do we want to have a belief about which room you're in, as a 'real belief'?





end

; --- Update intentions ---
to update-intentions-thieves
  ; You should update your agent's intentions here.
  ; The agent's intentions should be dependent on its beliefs and desires
  ask thieves [
    ifelse intention = observe_environment and belief_seeing_cop = [] [
      set intention move_around
    ]
    [
    if belief_items != [] [
        ifelse distancexy (item 0 item 0 beliefs) (item 1 item 0 beliefs) > 0.5 [
          ifelse intention = move_to_item [
            set intention observe_environment ]  ; you need to do this to make sure it's checking out its environment as well while running around

          [ set move_to_item item 0 beliefs
            set intention move_to_item
            set item_x item 0 intention
            set item_y item 1 intention
            facexy item_x item_y
         ]
        ]
        [ set intention steal_item ]
      ]


      ifelse desire = steal_item [

        ;if the thief sees no agent (note: perhaps adjust later to: or has seen agent but while ago)
        if belief_seeing_cop = [] [
          set intention move_around

        ]

        ifelse desire = flight [

        ][

        ]


      ]
      []
    ]

  ]

end

to update-intentions-cops
  ask cops [
    ifelse belief_seeing_thief = [] [ ; hasn't seen thief
      ifelse intention = observe_environment [
        set intention move_around
      ]
      [ set intention observe_environment ]
    ]
    ; has seen thief
    [ ifelse messages != [] [
        set intention inform_colleague
      ]
      [ let thief_coord item 0 belief_seeing_thief ; now you just go after the first thief you've seen
        let thief_x item 0 thief_coord
        let thief_y item 1 thief_coord

        print thief_x
        print thief_y

        ifelse floor(xcor) = thief_x and floor(ycor) = thief_y [
          set intention catch_thief
        ]
        [ set intention chase_thief ] ; now we don't look around anymore once seen a thief, but change this
      ]
    ]
  ;print "intention cop"
  ;print intention
  ]

  ask thieves [
    if intention = move_around [
      move-around-thief who
    ]

    if intention = move_to_item [
      move-to-item who
    ]

    if intention = observe_environment [
      observe-environment-thieves who
    ]

    if intention = steal_item [
      steal-item who
    ]

    if intention = escape [
      escape-now who
    ]
  ]
end




; --- Execute actions ---
to execute-actions-thieves
  ; Here you should put the code related to the actions performed by your agent

end


to execute-actions-cops
  ask cops [
    if intention = inform_colleague [
      send-message who
    ]

    if intention = move_around [
      move-around who
    ]

    if intention = observe_environment [
      observe-environment-cops who
    ]

    if intention = chase_thief [
      chase-thief who
    ]

    if intention = catch_thief [
      catch-thief who
    ]
  ]
end

to send-message [c]
  foreach messages [
    ask cops [
      if who != c [
        if (member? ? seen_thieves = false) [
          set seen_thieves lput(?) seen_thieves
        ]
      ]
    ]
  ]
end


to move-around [i]
  ; to check if turtle reaches a wall --> only works for cops now (for clarity we can also decide to make two move-arounds; one for cops and one for thiefs
  ask patch-ahead 1 [
    ifelse pcolor = black [
      if [breed] of turtle i = cops [ ; FOR THIEF: ask thief if breed is thief
        ask cop i [ ; when you reach a wall, turn, forward 1 and make a new random turn --> only this avoid going through a wall
          lt 180
          forward 1
          lt random 90
          set-vision-radii-cops i
        ]
      ]
    ]
    [ ifelse not any? customers-on self and [breed] of turtle i = cops [
        ask cop i [
          forward 1
          set-vision-radii-cops i
        ]
    ]
    [ if [breed] of turtle i = cops [
        ask cop i [
          lt 90
          set-vision-radii-cops i
        ]
       ]
    ]
    ]

 ]
end

to move-around-thief [i]
  ; to check if turtle reaches a wall
  ask patch-ahead 1 [
    ifelse pcolor = black [
      if [breed] of turtle i = thieves [
        ask thief i [ ; when you reach a wall, turn, forward 1 and make a new random turn --> only this avoid going through a wall
          lt 180
          forward 1
          lt random 90
          set-vision-radii-thieves i
        ]
      ]
    ]
    [ ifelse not any? customers-on self and [breed] of turtle i = thieves [
        ask thief i [
          forward 1
          set-vision-radii-thieves i
        ]
    ]
    [ if [breed] of turtle i = thieves [
        ask cop i [
          lt 90
          set-vision-radii-thieves i
        ]
       ]
    ]
    ]

 ]
end

to observe-environment-cops [c]

  ; check whether you see at thief
   foreach vision_radius [
     let x_cor item 0 ?
     let y_cor item 1 ?
     ask patches with [pxcor = x_cor and pycor = y_cor and any? other turtles-here] [
       ask turtles with [xcor = x_cor and ycor = y_cor] [
          if breed = thieves [
            ask cop c [
              if (member? (list x_cor y_cor) seen_thieves = false) [ ; check whether not in belief base already
                set seen_thieves lput(list x_cor y_cor) seen_thieves ; add coordinates of thief to belief base
              ]
            ] ; this list is sorted later on

          ]
       ]
     ]
   ]

   foreach seen_thieves [
     if (member? ? sent_messages = false) [
       set messages seen_thieves
     ]
   ]



end

to observe-environment-thieves [t]

  ; check whether you see an agent
   foreach vision_radius [
     let x_cor item 0 ?
     let y_cor item 1 ?
     ask patches with [pxcor = x_cor and pycor = y_cor and any? other turtles-here] [
       ask turtles with [xcor = x_cor and ycor = y_cor] [
          if breed = cops [
            ask thief t [
              if (member? (list x_cor y_cor) seen_cops = false) [ ; check whether not in belief base already
                set seen_cops lput(list x_cor y_cor) seen_cops ; add coordinates of thief to belief base
              ]
            ] ; this list is sorted later on

          ]
       ]
     ; if item is orange = item --> catch it. Adding here?
     ]
   ]

   foreach seen_cops [
     if (member? ? sent_messages = false) [
       set messages seen_cops
     ]
   ]



end


to chase-thief [c]
  let my_pos list floor(xcor) floor(ycor)
  let follow_pos item 0 belief_seeing_thief
  new-pos my_pos follow_pos

  ask patch-ahead 1 [
    ifelse not any? customers-on self [
      ask cop c [
        forward 1
      ]
    ]
    [ ask cop c [
        lt 90
        forward 1
      ]
    ]
  ]
end

to catch-thief [c] ; sometimes this doesn't seem to work, but I don't know when exactly --> guess when the one cop already caught the thief --> send message that the thief has been caught
  let x_cor floor(xcor)
  let y_cor floor(ycor)
  ask thieves with [xcor = x_cor and ycor = y_cor] [die] ; this might be a bit of a severe punishment ;)
end

; note: the belief base of the cop needs to be updated by the new position of the thief all the time
to new-pos [my_pos follow_pos] ; function gets the position to be followed and the position of the

  let my_room_patch table:get room_dict my_pos
  let follow_room_patch table:get room_dict follow_pos

  if my_room_patch = follow_room_patch [ ; if you're at the same room, you can simply move towards the position
    let x_ item 0 follow_pos
    let y_ item 1 follow_pos
    facexy x_ y_
  ]

  ; else --> check whether you know that where the door is --> move to the door
end

to move-to-item [t]
 if xcor != item_x and ycor != item_y [
    forward 1
    set-vision-radii-thieves t
  ]

end

to steal-item [t]
  ; if you found an item, steal it
  if pcolor != white [
    set pcolor white
    ]
end

to escape-now [t]
  ; to check if turtle reaches a wall
  ifelse intention = escape ;no door in sight (now just rubish for debugging)

  [
    ask patch-ahead 1 [
      ifelse pcolor = black [
        if [breed] of turtle t = thieves [
          ask thief t [ ; when you reach a wall, turn, forward 1 and make a new random turn --> only this avoid going through a wall
            lt 180
            forward 1
            lt random 90
            set-vision-radii-thieves t
          ]
        ]
      ]
      [ ifelse not any? customers-on self and [breed] of turtle t = thieves [
          ask thief t [
            forward 1
            set-vision-radii-thieves t
          ]
      ]
      [ if [breed] of turtle t = thieves [
          ask cop t [
            lt 90
            set-vision-radii-thieves t
          ]
         ]
      ]
      ]

   ]
  ]
  [ ;if a door is in sight, go to this door

  ]
end

to setup-rooms

  ; room 1 (left lower corner)
  ask patches with [pxcor > min-pxcor and pxcor < (max-pxcor - min-pxcor) / 2 - 3 and pycor > min-pycor and pycor < (max-pycor - min-pycor) / 2 ] [
    table:put room_dict list pxcor pycor 1
  ]

  ; room 2 (path)
  ask patches with [pxcor > (max-pxcor - min-pxcor) / 2 - 3 and pxcor < (max-pxcor - min-pxcor) / 2 + 3 and pycor > min-pycor and pycor < max-pycor] [
    table:put room_dict list pxcor pycor 2
  ]

  ; room 3 (right lower corner)
  ask patches with [pxcor > (max-pxcor - min-pxcor) / 2 + 3 and pxcor < max-pxcor and pycor > min-pycor and pycor < (max-pycor - min-pycor) / 2 - 5] [
    table:put room_dict list pxcor pycor 3
  ]

  ; room 4 (right middle)
  ask patches with [pxcor > (max-pxcor - min-pxcor) / 2 + 3 and pxcor < max-pxcor and pycor > (max-pycor - min-pycor) / 2 - 5 and pycor < (max-pycor - min-pycor) / 2 + 5] [
    table:put room_dict list pxcor pycor 4
  ]

  ; room 5 (right upper corner)
  ask patches with [pxcor > (max-pxcor - min-pxcor) / 2 + 3 and pxcor < max-pxcor and pycor > (max-pycor - min-pycor) / 2 + 5 and pycor < max-pycor] [
    table:put room_dict list pxcor pycor 5
  ]

  ; room 6 (left middle)
  ask patches with [pxcor > min-pxcor and pxcor < (max-pxcor - min-pxcor) / 2 - 3 and pycor > (max-pycor - min-pycor) / 2 and pycor < (max-pycor - min-pycor) / 2 + 12 ] [
    table:put room_dict list pxcor pycor 6
  ]

  ; room 7 (left upper corner)
  ask patches with [pxcor > min-pxcor and pxcor < (max-pxcor - min-pxcor) / 2 - 3 and pycor > (max-pycor - min-pycor) / 2 + 12 and pycor < max-pycor] [
    table:put room_dict list pxcor pycor 7
  ]
end

; --- Setup patches ---
to setup-patches
  ; In this method you may create the environment (patches), using colors to define dirty and cleaned cells.
  ; This might be another way how to do it witout hard coding: http://ccl.northwestern.edu/netlogo/models/community/maze-maker-2004

  set room_dict table:make
  ask patches [
    table:put room_dict list pxcor pycor 0
  ]

  ask patches [
    set pcolor white
  ]

  ; outer borders
  ask patches with [pxcor = min-pxcor or pxcor = max-pxcor or pycor = min-pycor or pycor = max-pycor] [
    set pcolor black
  ]

  ; middle path
  ask patches with [pxcor = (max-pxcor - min-pxcor) / 2 - 3 or pxcor = (max-pxcor - min-pxcor) / 2 + 3] [
    set pcolor black
  ]

  ; left rooms
  ask patches with [pycor = (max-pycor - min-pycor) / 2 - 5 or pycor = (max-pycor - min-pycor) / 2 + 5 and ( pxcor > (max-pxcor - min-pxcor) / 2 + 3)] [
    set pcolor black
  ]

  ; right rooms
  ask patches with [pycor = (max-pycor - min-pycor) / 2 or pycor = (max-pycor - min-pycor) / 2 + 12 and ( pxcor < (max-pxcor - min-pxcor) / 2 - 3)] [
    set pcolor black
  ]

  ; doors outside
  ask patches with [pxcor =  (max-pxcor - min-pxcor) / 2 and (pycor = max-pycor or pycor = min-pycor)] [
    set pcolor red
    table:put room_dict list pxcor pycor 2 ; in this version these two doors belong to the hall way
  ]

  ; doors in environment - right side
  ask patches with [pxcor = (max-pxcor - min-pxcor) / 2 + 3 and (pycor = (max-pycor - min-pycor) / 2 or pycor = (max-pycor - min-pycor) / 2 + 10 or pycor = (max-pycor - min-pycor) / 2 - 10) ] [
    let i 0
    set pcolor blue
    ; assign door patches to rooms
    if i = 0 [
      table:put room_dict list pxcor pycor 5 ]
    if i = 1 [
      table:put room_dict list pxcor pycor 4 ]
    if i = 2 [
      table:put room_dict list pxcor pycor 3 ]
    set i i + 1
  ]

  ; doors in environment - left side
  ask patches with [pxcor = (max-pxcor - min-pxcor) / 2 - 3 and (pycor = (max-pycor - min-pycor) / 2 + 3 or pycor = (max-pycor - min-pycor) / 2 + 14 or pycor = (max-pycor - min-pycor) / 2 - 10) ] [
    set pcolor blue
    ; assign door patches to rooms
    let j 0
    if j = 0 [
      table:put room_dict list pxcor pycor 6 ]
    if j = 1 [
      table:put room_dict list pxcor pycor 7 ]
    if j = 2 [
      table:put room_dict list pxcor pycor 1 ]
    set j j + 1
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
624
10
1167
574
-1
-1
13.0
1
10
1
1
1
0
1
1
1
0
40
0
40
1
1
1
ticks
30.0

BUTTON
8
15
75
48
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

SLIDER
7
169
179
202
num_customers
num_customers
0
300
111
1
1
NIL
HORIZONTAL

BUTTON
8
54
75
88
start
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

BUTTON
78
15
243
48
NIL
place-item-manually
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
78
55
244
88
NIL
place-cop-manually
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
80
95
244
128
NIL
place-thief-manually
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
10
232
160
250
Setup thieves
11
0.0
1

SLIDER
9
251
181
284
max-speed-thieves
max-speed-thieves
0
10
5
1
1
NIL
HORIZONTAL

SLIDER
185
252
357
285
max-strength-thieves
max-strength-thieves
0
10
5
1
1
NIL
HORIZONTAL

SLIDER
359
253
531
286
radius-thieves
radius-thieves
0
10
5
1
1
NIL
HORIZONTAL

TEXTBOX
8
295
158
313
Setup cops
11
0.0
1

SLIDER
9
315
181
348
max-speed-cops
max-speed-cops
0
10
5
1
1
NIL
HORIZONTAL

SLIDER
185
317
357
350
max-strength-cops
max-strength-cops
0
10
5
1
1
NIL
HORIZONTAL

SLIDER
363
318
535
351
radius-cops
radius-cops
0
10
5
1
1
NIL
HORIZONTAL

BUTTON
359
60
422
93
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
