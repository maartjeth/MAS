; FINAL ASSIGNMENT - SMART COPS
; Contributors Group 1:
; Romy Blankendaal (10680233, romy.blankendaal@gmail.com)
; Maartje ter Hoeve (10190015, maartje.terhoeve@student.uva.nl)
; Suzanne Tolmeijer (10680403, suzanne.tolmeijer@gmail.com)


extensions [table]

; --- Global variables ---
; The following global variables are given.

globals [time
         room_dict                  ; table with which patch belongs to which room
         number_cops
         number_thieves
         cop1 cop2 thief1 thief2    ; this is used to update the monitors correctly, no matter which order you place agents in
         escape_dict                ; contains different routes for getting to the exit
         chase_thief_dict           ; contains different routes for getting to other rooms, assumed to be general knowledge (the agent knows its work environment)
         coord_1                    ; these are all the hardcoded coordinates of the doors
         coord_2_1
         coord_2_2
         coord_3
         coord_4
         coord_5
         coord_6
         coord_7
         thieves_active             ; number of thieves still active, used to stop the simulation
         num_thieves_in_prison      ; counters used for monitors
         num_stolen_items
         num_escaped]

; --- Agents ---
; The following breeds are given.
;
breed [cops cop]
breed [thieves thief]
breed [customers customer]

; --- Local variables ---
; The following local variables are given.

customers-own [ move_around ]       ; move_around: every customer will have the intention to move around

cops-own [
  desire
  intention
  view                      ; angle of the vision radius
  vision_radius             ; length of the vision radius
  move_around               ; intentions & desires & beliefs
  observe_environment
  inform_colleague
  chase_thief
  catch_thief
  escort_thief
  look_for_thief
  belief_thieves
  escort_thief_outside
  seen_thieves              ; observed thieves (both observed by yourself and by others through messages)
  messages
  current_room
  escape_routes_cops        ; contains different routes for escaping, assumed to be general knowledge (the thief canvassed the area)
  caught_thief              ; boolean if a cop caught a thief
  route_outside             ; current route to use to get outside, based on escape_routes_cops
  from_two                  ; helper variable to see if you came from the hallway
  ]

thieves-own [
  desire
  intention
  view                      ; angle of the vision radius
  vision_radius             ; length of the vision radius
  belief_seeing_cop         ; intentions & desires & beliefs
  belief_items
  items
  steal
  flight
  move_around
  observe_environment
  move_to_item
  steal_item
  escape
  seen_cops                 ; observed cops
  current_room
  escaped                   ; boolean to see whether thieves escaped
  escape_routes_thieves     ; contains different routes for escaping, assumed to be general knowledge (the cops know their work environment)
  route_outside             ; current route to use to get outside, based on escape_routes_thieves
  ]

; --- Setup ---

to setup
  clear-all
  set time 0
  set escape_dict table:make
  set chase_thief_dict table:make
  set thieves_active 0
  set num_stolen_items 0
  set num_thieves_in_prison 0
  set num_escaped 0

  setup-patches
  setup-rooms
  setup-customers
  setup-ticks
end

to setup-customers                                ; customers have only one possible intention, and no desires or beliefs
  create-customers num_customers
  ask customers [
    set shape "person"
    set color red
    move-to one-of patches with [pcolor != black and not any? customers-on self]
    set move_around "move_around"
  ]
end

to setup-thieves
  ask thieves [
    ; items
    set items false

    ; desires
    set steal "steal"
    set flight "flight"

    ; intentions
    set move_around "move_around"
    set observe_environment "observe_environment"
    set steal_item "steal_item"
    set escape "escape"

    set intention []

  ]
end

to setup-cops
  ask cops [
    ; desires
    set look_for_thief "look_for_thief"
    set catch_thief "catch_thief"
    set escort_thief_outside "escort_thief_outside"

    ; intentions
    set move_around "move_around"
    set observe_environment "observe_environment"
    set inform_colleague "inform_colleague"
    set chase_thief "chase_thief"
    set catch_thief "catch_thief"
    set escort_thief "escort_thief"

    set caught_thief false
    set from_two false
  ]
end

; --- Main processing cycle ---
to go
  ; This method executes the main processing cycle of an agent. This method starts when the user clicks on the start button or one tick button.
  if ticks = 0 [                      ; this only happens during the first tick of the simulation
    setup-thieves
    setup-cops
    update-beliefs
    update-desires
    update-intentions-cops
    update-intentions-thieves
  ]

  ; execute actions
  execute-actions-cops
  execute-actions-thieves
  ask customers [
    execute-actions-customers who
  ]

  ; update BDI
  update-beliefs
  update-desires
  update-intentions-cops
  update-intentions-thieves

  ; if there are no active thieves on the grid anymore, stop the simulation
  ; this requires that you put thieves on the grid, before running
  if thieves_active = 0 [
    stop
  ]

  tick
end

; --- Setup ---

; the user can place items to steal by the thief manually
to place-item-manually
  if mouse-down?
  [
    ask patch round mouse-xcor round mouse-ycor [
    set pcolor orange          ;patches cannot have a 'shape', therefor the items are just an orange square
  ]
  stop
]
end

; the user can place cops manually in the simulation
to place-cop-manually
  if mouse-down?
  [
    create-cops 1 [
      setxy floor(mouse-xcor) floor(mouse-ycor)
      set color black
      set shape "person"
      set view 90
      set seen_thieves []
      set messages []
      set vision_radius []
      set route_outside []
      set escape_routes_cops escape_dict

      set-vision-radii-cops who
      setup-beliefs-cops who
      setup-desires-cops who
      set number_cops number_cops + 1
      ; the first to cops made can be followed with the monitors
      if number_cops = 1 [
        set cop1 self
      ]
      if number_cops = 2 [
        set cop2 self
      ]
      ]
    stop
  ]
end

; the user can place thieves manually in the simulation
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
      set number_thieves number_thieves + 1

      set escaped false
      set escape_routes_thieves escape_dict
      set thieves_active thieves_active + 1

      ; the first to thieves made can be followed with the monitors
      if number_thieves = 1 [
        set thief1 self
      ]
      if number_thieves = 2 [
        set thief2 self
      ]
      ]
    stop
  ]
end

to set-vision-radii-cops [c]
  ; set up radius cops
  ask cop c [

    clear-vision-radius c

    let cop_room 0
    ifelse pcolor = red [  ;if you are near an exit, you are in the hallway
      set cop_room 2
    ][
      if floor(ycor) != -1 [
        set cop_room table:get room_dict list floor(xcor) floor(ycor) ; floor because you can be on a continuous value, you want it rounded to the nearest patch center
      ]
    ]

    let my_xcor xcor
    let my_ycor ycor
    let dir heading

    ;create updated vision radius
    ask patches in-cone radius-cops view [
      let patch_coord list pxcor pycor
      let room_patch table:get room_dict patch_coord
      if room_patch = cop_room and pcolor != black and pcolor != red and pcolor != blue and ((pycor > my_ycor and (dir > 270 or dir < 90)) or (pycor < my_ycor and (dir < 270 and dir > 90))) [  ;ROMY: CHANGED
        ask cop c [
          set vision_radius lput (patch_coord) vision_radius
        ]
        if pcolor != orange[
          set pcolor 99 ;light blue
        ]
      ]
    ]
  ]
end

to set-vision-radii-thieves [t]
  ; set up vision radius thieves

  ask thief t [

    clear-vision-radius t

    let thief_room 0
    ifelse pcolor = red [
      set thief_room 2
    ][
      set thief_room table:get room_dict list floor(xcor) floor(ycor)
    ]

    let my_xcor xcor
    let my_ycor ycor
    let dir heading

    ;create updated vision radius
    ask patches in-cone radius-thieves view [
      let patch_coord list pxcor pycor
      let room_patch table:get room_dict patch_coord

      if room_patch = thief_room and pcolor != black and pcolor != red and pcolor != blue and ((pycor > my_ycor and (dir > 270 or dir < 90)) or (pycor < my_ycor and (dir < 270 and dir > 90))) [  ;ROMY: CHANGED
        ask thief t [
          set vision_radius lput (patch_coord) vision_radius
        ]
        if pcolor != orange[
          set pcolor 69 ;light green
        ]
      ]
    ]
  ]
end


; --- Setup ticks ---
to setup-ticks
  reset-ticks
end


; --- Setup beliefs ---
to setup-beliefs-cops [c]
  ask cop c [
    set belief_thieves []
  ]
end

to setup-beliefs-thieves [t]
  ask thief t [
     set belief_seeing_cop []
     set belief_items []
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
    set desire steal
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

; --- Update BDI ---

; --- Update beliefs ---
to update-beliefs

 ; update belief thieves
 ask thieves [
   let t who
   set belief_seeing_cop seen_cops
   set belief_seeing_cop sort-by [(distancexy item 0 ?1 item 1 ?1 < distancexy item 0 ?2 item 1 ?2)] belief_seeing_cop

   ;update belief about in which room the thief is
   if floor(ycor) != -1 [
     let new_room table:get room_dict list floor(xcor) floor(ycor)
     if new_room = 0 [
       set new_room table:get room_dict list ceiling(xcor) ceiling(ycor)
     ]
     if new_room = 0 [
       set new_room table:get room_dict list floor(xcor) ceiling(ycor)
     ]
     if new_room = 0 [
       set new_room table:get room_dict list ceiling(xcor) floor(ycor)
     ]

     if current_room != new_room[
       set current_room new_room
     ]
   ]

   ; delete item that the thief has already stolen from belief_items and sort the list
   ; (just in case there are more than 1 items in sight, the thief will catch the closest item)
   if belief_items != [] [
      let check_items item 0 belief_items
      let check_item_x item 0 check_items
      let check_item_y item 1 check_items
      ask patches with [pxcor = check_item_x and pycor = check_item_y] [
        if pcolor = white [
          ask turtle t [
            if breed = thieves [
              if belief_items != [] [
                set belief_items remove-item 0 belief_items
              ]
            ]
          ]
        ]
      ]
    ]
 ]


 ; update beliefs cops
 ask cops [

  ; for each seen thief, update your belief when necessary
  foreach seen_thieves[
  print ?
  let thief_x item 0 ?
  let thief_y item 1 ?
  let thief_ID item 2 ?
  let thief_status item 3 ?
  let thief_cop item 4 ?

  ; if you know the thief, find the index for it in your belief list
  let index_thief -1
  if thief_ID != -1[
    let i 0
    foreach belief_thieves[
      if item 2 ? = thief_ID[
        set index_thief i
      ]
      set i i + 1
    ]
  ]

  ; if you don't know the thief yet, add it to your beliefs
  ifelse index_thief = -1 and (thief_status = "chasing" or thief_status = "catching") [
    set belief_thieves lput ? belief_thieves
  ][

    ; implementation of status hierarchy, when do you update your belief based on what was observed?
    ; if a thief is in prison, you always update your belief to prison, and don't change it anymore
    ; if a thief is being escorted, if it was not in prison already, update your belief to escorting
    ; if a thief is being caught, if it was not being escorted or in prison yet, update your belief to catching
    ; if a thief is being chased, if it was not yet being chased, check if the information is valid, else update your belief to chasing
    ; if a thief's location is unknown, update it when there is no other valid information about the thief.
    ; generally: unknown < chasing < catching < escorting < prison

    ifelse thief_status = "prison"[
      let old_thief_ID 100
      foreach belief_thieves[
        if item 4 ? = thief_cop[
           set old_thief_ID item 2 ?
        ]
      ]
      set index_thief -1
      let k 0
      foreach belief_thieves[
        if item 2 ? = old_thief_ID[
          set index_thief k
        ]
        set k k + 1
      ]
      set belief_thieves replace-item index_thief belief_thieves (list 0 0 old_thief_ID thief_status thief_cop)
      ; update location to 0.0 since the thief is in jail, keep the old ID, update the status and cop
    ][
      ifelse thief_status = "escorting"[
        ; for escorting messages there are 2 options: first time escorting after catching, or was escorting before

        ; if you believed someone was escorting before, get thief_ID from last belief
        let belief_thief_ID 100
        let index_belief -1
        foreach belief_thieves[
          set index_belief index_belief + 1
          if item 4 ? = thief_cop and item 3 ? = "escorting"[ ; this implies you did not think the thief was in prison, for the hierarchy update
              set belief_thief_ID item 2 ?
              set index_thief index_belief
              set belief_thieves replace-item index_thief belief_thieves (list thief_x thief_y belief_thief_ID "escorting" thief_cop)
          ]
        ]
        ; if you get escorting the first time, get thief_ID from catching message
        ; --> cheating because of delayed messages update because of BDI update, else it does not work in the current setting
        let message_thief_ID 100
        let index_message -1
        foreach seen_thieves[
          set index_message index_message + 1
          if item 4 ? = thief_cop and item 3 ? = "catching"[
            set message_thief_ID item 2 ?
            set index_thief -1
            let j 0
            foreach belief_thieves[
              if item 2 ? = message_thief_ID[
                set index_thief j
              ]
              set j j + 1
            ]
            set belief_thieves replace-item index_thief belief_thieves (list thief_x thief_y message_thief_ID "escorting" thief_cop)
          ]
        ]
      ][
        ifelse thief_status = "catching"[
          if item 3 item index_thief belief_thieves != "prison" and item 3 item index_thief belief_thieves != "escorting"[
            set belief_thieves replace-item index_thief belief_thieves ?  ; update belief to catching
          ]
        ][
          ifelse thief_status = "chasing"[
            ; if belief status is unknown
            ifelse item 3 item index_thief belief_thieves = "unknown"[
              print "chasing, belief status is unknown"
              if thief_x != item 0 item index_thief belief_thieves and thief_y != item 1 item index_thief belief_thieves[
                print "update unknown to chasing"
                set belief_thieves replace-item index_thief belief_thieves ?  ; update belief to chasing
              ]
            ][ ; else belief status is chasing
              if item 3 item index_thief belief_thieves = "chasing"[ ; if chasing is already happening
                let current_cops item 4 item index_thief belief_thieves
                ifelse current_cops = [-1][ ; if you had no one in your beliefs, you can update it (note: could be you update it to -1 again)
                  set belief_thieves replace-item index_thief belief_thieves (list thief_x thief_y thief_ID "chasing" thief_cop)
                ][ ; if you had someone in your belief, you do not want to forget
                  ifelse thief_cop = [-1][ ; if you got no new ID, you just keep the old one and only update the location
                    set belief_thieves replace-item index_thief belief_thieves (list thief_x thief_y thief_ID "chasing" current_cops)
                  ][ ; if the ID is a person, you want to add it to your current personlist
                    let new_cops current_cops
                    if not member? item 0 thief_cop new_cops[
                      set new_cops lput item 0 thief_cop new_cops
                    ]
                    set belief_thieves replace-item index_thief belief_thieves (list thief_x thief_y thief_ID "chasing" new_cops)
                  ]
                ]
              ]
            ]
          ][; last else statement, so status is unknown
              set belief_thieves replace-item index_thief belief_thieves (list 0 0 thief_ID "unknown" [-1])
            ]
          ]
        ]
      ]
    ]
  ]

   set belief_thieves sort-by [(distancexy item 0 ?1 item 1 ?1 > distancexy item 0 ?2 item 1 ?2)] belief_thieves
   ; this is sorted on distance only, rooms and doors are not taken into account for the distance

   set seen_thieves [] ; after you updated you beliefs, you reset this for new input

   ifelse (floor(xcor) = -1 or floor(ycor) = -1 or floor(xcor) = max-pxcor or floor(ycor) = max-pycor) [
     ; now you're outside, so obviously no room
     set current_room 0
   ]

   [ ;note in which room you are
     let new_room table:get room_dict list floor(xcor) floor(ycor)
     if new_room = 0 [
       set new_room table:get room_dict list ceiling(xcor) ceiling(ycor)
     ]
     if new_room = 0 [
       set new_room table:get room_dict list floor(xcor) ceiling(ycor)
     ]
     if new_room = 0 [
       set new_room table:get room_dict list ceiling(xcor) floor(ycor)
     ]

     if current_room != new_room [
       set current_room new_room
     ]
   ]
 ]

end

; --- Update desires ---
to update-desires
  ; If the cop has not seen a thief yet, it should look for it
  ; Else it should try to catch the thief
  ; If the thief is caught, it should be escorted outside

  ask cops [
    ; SUUS: gedaan

    let seen_thief false
    ifelse belief_thieves = [] [; if you don't know any thieves yet, you want to patrol for thieves
      set desire look_for_thief

    ][; if someone did see thieves at one point

      ifelse caught_thief = true[ ;if you caught a thief, you want to escort him outside
        set desire escort_thief_outside

      ][; if someone saw a thief at one point and you haven't caught one now, go check each thief in beliefs

        foreach belief_thieves[
          if item 3 ? = "chasing" or item 3 ? = "catching" [ ;if there is a thief to chase and catch
              set desire catch_thief
              set seen_thief true
          ]
        ]
        if seen_thief = false[
          set desire look_for_thief
        ]
      ]
    ]
  ]


  ask thieves [
    ;if the thief has an item it will want to flee with it, else it will want to steal something
    ifelse items = true [
      set desire flight
    ][
      set desire steal
    ]
  ]
end

; --- Update intentions ---
to update-intentions-thieves
  ask thieves [
    ifelse intention = move_around [
      set intention observe_environment
    ]
    [ set intention move_around ]

    ifelse intention = [] [
      set intention move_around
    ]
    [
      ifelse desire = steal and belief_items != [] [
        ; do your stuff to steal an item: move to item OR observe environment
        ; no matter what, if you're at an item --> just steal it
        let item_to_steal item 0 belief_items
        ifelse distancexy item 0 item_to_steal item 1 item_to_steal < 0.5 [
          set intention steal_item
        ][ ; else: observe environment or move to item
          ifelse intention = move_to_item [
            set intention observe_environment
          ]
          [ set intention move_to_item ]
        ]
      ][ if desire != steal [; else: do your stuff to flee
           set intention escape
        ]
      ]
    ]
  ]


end

to update-intentions-cops
  ask cops [
    ifelse (desire = look_for_thief) [ ; hasn't seen thief
      ; your first intention is to move around
      ifelse ticks = 0 [
        set intention (list observe_environment)
      ][
        ifelse item 0 intention = observe_environment [
        set intention (list move_around)
      ][ set intention (list observe_environment) ]
      ]

    ]
    ; has seen thief, thus desire = catch thief
    [ ifelse desire = escort_thief_outside [
          set intention (list escort_thief)
        ]
        [ ifelse item 0 intention = chase_thief [
             set intention (list observe_environment)
          ][
            let index_thief 0
            foreach belief_thieves[
              if item 3 ? = "chasing"[
                set index_thief position ? belief_thieves
              ]
            ]
            let thief_x item 0 item index_thief belief_thieves
            let thief_y item 1 item index_thief belief_thieves
            ifelse distancexy thief_x thief_y < 2 [
              set intention (list catch_thief)
            ][ set intention (list chase_thief) ]
          ]
        ]
    ]
    ; if you saw a thief, you want to let your colleagues know
    ifelse messages != [][
      set intention lput inform_colleague intention
    ][ ; if you did not see one, remove the inform_colleague intention from your intention list
      if length intention = 2[
        set intention remove-item 1 intention
      ]
    ]
  ]
end

; --- Execute actions ---
to execute-actions-thieves
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

    if intention = escape and escaped = false [
      escape-now who
    ]

    if intention = escape and escaped = true [
      clear-vision-radius who
      die
      set num_escaped num_escaped + 1
    ]
  ]

end


to execute-actions-cops
  ask cops [
    if item 0 intention = move_around [
      move-around who
    ]

    if item 0 intention = observe_environment [
      observe-environment-cops who
    ]

    if item 0 intention = chase_thief [
      chase-thief who
    ]

    if item 0 intention = catch_thief [
      catch-thief who
    ]

    if item 0 intention = escort_thief [
      escort-thief who
    ]

    if length intention = 2 [
      if item 1 intention = inform_colleague[
        knowledge-thieves-update who
      ]
    ]
  ]
end

to execute-actions-customers [cust]
  ask customer cust [
    ask patch-ahead 1 [
      ifelse pcolor != black and not any? turtles-on self [
        ask customer cust [
           forward 0.1
        ]
      ]
      [ ask customer cust [
          lt random 360
        ]
      ]
    ]
    set cust cust + 1
  ]
end

to knowledge-thieves-update [c]          ; messages, a.k.a. status updates about thieves, are being placed in seen_thieves for every cop. This is your 'inbox'.
  foreach messages [
    ask cops [
      if not member? ? seen_thieves[
        set seen_thieves lput(?) seen_thieves
      ]
    ]
  ]
  set messages []
end

to move-around [i]
  ifelse ( pcolor = red) [
     lt 180
     forward 1
     set-vision-radii-cops i
   ][

  ; to check if turtle reaches a wall
    ask patch-ahead 1 [ ; to make sure that the cop does not reach the wall
      ifelse pcolor = black [
        if [breed] of turtle i = cops [
          ask cop i [ ; when you reach a wall, turn, forward 1 and make a new random turn --> only this avoids going through a wall
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
  ]
end


to clear-vision-radius [a] ; clear vision radius of agent
  ask turtle a[
    foreach vision_radius [
        let clean_x item 0 ?
        let clean_y item 1 ?
        ask patches with [pxcor = floor(clean_x) and pycor = floor(clean_y)] [
          if (pcolor != blue and pcolor != red and pcolor != orange) [
            set pcolor white
          ]
        ]
      ]
      set vision_radius []
  ]
end

to move-around-thief [i]

  ifelse ( pcolor = red) [
     lt 180
     forward 1
     set-vision-radii-cops i
   ][

  ; to check if turtle reaches a wall
  ask patch-ahead 1 [
    ifelse pcolor = black [
      if [breed] of turtle i = thieves [
        ask thief i [ ; when you reach a wall, turn, forward 1 and make a new random turn --> only this avoids going through a wall
          lt 180
          forward 1
          lt random 90
          set-vision-radii-thieves i
        ]
      ]
    ][ ifelse not any? customers-on self and [breed] of turtle i = thieves [
        ask thief i [
          forward 1
          set-vision-radii-thieves i
        ]
    ][ if [breed] of turtle i = thieves [
        ask thief i [
          lt 90
          set-vision-radii-thieves i
        ]
       ]
      ]
    ]
  ]
 ]
end

to observe-environment-cops [c]
   foreach vision_radius [
     let x_cor item 0 ?
     let y_cor item 1 ?
     ; if the patch in or around your vision radius patch contains a turtle
     ask patches with [distancexy x_cor y_cor < 1 and any? other thieves-here] [
       ask turtles with [breed = thieves] [
         let thief_x xcor
         let thief_y ycor
         let thiefID (list who)
         if distancexy x_cor y_cor < 1 [
           ask cop c [
              ; save which thief you saw and where to messages
              set messages lput (list floor(thief_x) floor(thief_y) thiefID "chasing" [-1]) messages
           ]
         ]
       ]
     ]
   ]

end

to observe-environment-thieves [t]
   foreach vision_radius [
     let x_cor item 0 ?
     let y_cor item 1 ?

     ; check whether you see an item
     ask patches with [pxcor = x_cor and pycor = y_cor] [
       if pcolor = orange[
         ask thief t[
           set belief_items lput(list x_cor y_cor) belief_items
         ]
       ]
     ]

     ; check whether you see an agent
     ask patches with [pxcor = x_cor and pycor = y_cor and any? other turtles-here] [
       ask turtles with [xcor = x_cor and ycor = y_cor] [
          if breed = cops [
            ask thief t [
              if (member? (list x_cor y_cor) seen_cops = false) [ ; check whether not in belief base already
                set seen_cops lput(list x_cor y_cor) seen_cops ; add coordinates of cop to belief base
              ]
            ]
          ]
       ]
     ]
   ]
end


to chase-thief [c]

  ; step 1: decide where to go based on belief and chase the thief
  let my_pos list floor(xcor) floor(ycor)

  ; assumption, if code is right you only get here if there is a thief to chase
  let index_thief 0
  foreach belief_thieves[
    if item 3 ? = "chasing"[
      set index_thief position ? belief_thieves
    ]
  ]

  let thief_x_belief item 0 item index_thief belief_thieves
  let thief_y_belief item 1 item index_thief belief_thieves
  let thief_ID_belief item 2 item index_thief belief_thieves

  let my_location (list xcor ycor)
  let thief_location (list thief_x_belief thief_y_belief)

  ; if that position is in your current room --> then just follow the thief, otherwise go to that room where the thief is
  let thief_room table:get room_dict list thief_x_belief thief_y_belief
  ifelse thief_room = current_room [
    let follow_pos list floor(thief_x_belief) floor(thief_y_belief)
    new-pos my_pos follow_pos


  ][ ; getting the route to the room where the thief is
     let route []
      if current_room = 1 or (list floor(xcor) floor(ycor) = coord_1 and from_two = false) [
        set route table:get chase_thief_dict 1
      ]

      if current_room = 2 or (list floor(xcor) floor(ycor) = coord_1 and from_two = true) or (list floor(xcor) floor(ycor) = coord_3 and from_two = true) or (list floor(xcor) floor(ycor) = coord_4 and from_two = true) or (list floor(xcor) floor(ycor) = coord_5 and from_two = true) or (list floor(xcor) floor(ycor) = coord_6 and from_two = true) or (list floor(xcor) floor(ycor) = coord_7 and from_two = true)[
        if thief_room != 0 [
          set route table:get chase_thief_dict list 2 thief_room
          set from_two true
        ]
      ]

      if current_room = 3 or (list floor(xcor) floor(ycor) = coord_3 and from_two = false) [
        set route table:get chase_thief_dict 3
      ]

      if current_room = 4 or (list floor(xcor) floor(ycor) = coord_4 and from_two = false) [
        set route table:get chase_thief_dict 4
      ]

      if current_room = 5 or (list floor(xcor) floor(ycor) = coord_5 and from_two = false) [
        set route table:get chase_thief_dict 5
      ]

      if current_room = 6 or (list floor(xcor) floor(ycor) = coord_6 and from_two = false) [
        set route table:get chase_thief_dict 6
      ]

      if current_room = 7 or (list floor(xcor) floor(ycor) = coord_7 and from_two = false) [
        set route table:get chase_thief_dict 7
      ]


    ; getting your new position
    ifelse route != [] [
      ifelse list floor(xcor) floor(ycor) != item 0 route and pcolor != blue [ ; in wrong room and not on patch in front of the door
        let follow_pos item 0 route
        facexy item 0 follow_pos item 1 follow_pos
      ]
      [ ; you are trying to leave the wrong room
        ifelse pcolor = blue [ ; you are in the door
        let follow_pos item 2 route
        facexy item 0 follow_pos item 1 follow_pos
      ]
      [ ; you are at the patch in front of the door
        let follow_pos item 1 route
        facexy item 0 follow_pos item 1 follow_pos]
      ]
    ]
    [ print "You want to go somewhere, but your route is empty :("
    ]
  ]

   ; move to your target
   ask patch-ahead 1 [
      ifelse not any? customers-on self and pcolor != black and pcolor != red [
        ask cop c [
          forward 1
          set-vision-radii-cops c
        ]
      ]
      [ ask cop c [
        lt 90
        forward 1
        set-vision-radii-cops c
      ]
      ]
    ]

  ; step 2: send message about that you are chasing the thief and where it is
  let thief_ID [-2]
  let thief_x 0
  let thief_y 0

  ask thieves [
    if distancexy item 0 my_pos item 1 my_pos <= radius-cops + 1[ ; if you are close enough, report that thief
      set thief_ID (list who)
      set thief_x xcor
      set thief_y ycor
      set-vision-radii-thieves who
    ]
  ]
  if thief_ID = [-2][   ; if you were not close enough, use your old belief
    set thief_ID item 2 item index_thief belief_thieves
    set thief_x item 0 item index_thief belief_thieves
    set thief_y item 1 item index_thief belief_thieves
  ]

  ; check whether you are not sending double messages
  let double false
  let index_double -1
  let j -1

  ifelse messages != [][
    foreach messages [
      set j j + 1
      if item 2 ? = thief_ID and item 3 ? = "chasing"[
        set double true
        set index_double j
      ]
    ]

    ifelse double = true[ ; if you had the chasing item without your ID, replace it with your ID
      set messages replace-item index_double messages (list floor(thief_x) floor(thief_y) thief_ID "chasing" (list who))
    ][ ; if you did not have a chasing status for this thief yet, add the message to your messages
      set messages lput (list floor(thief_x) floor(thief_y) thief_ID "chasing" (list who)) messages
    ]
  ][
    set messages lput (list floor(thief_x) floor(thief_y) thief_ID "chasing" (list who)) messages
  ]

end

to catch-thief [c]
  ask cop c[
    let cop_x xcor
    let cop_y ycor
    let thief_ID [-1]

    ask thieves[
     ; if the thief is close enough, catch it
     if distancexy cop_x cop_y < 4 [
       set thief_ID (list who)
     ]
    ]

    if thief_ID != [-1][
      ask thief item 0 thief_ID[
        clear-vision-radius who
        die
      ]
    ]

    ifelse thief_ID != [-1][
      set caught_thief true
      set messages lput (list floor(cop_x) floor(cop_y) thief_ID "catching" (list who)) messages
    ][; if thief ID is -1, there is no thief around: so check if your information is still valid, else report that you lost the thief
      let i 0
      foreach belief_thieves[
        let me_chasing false
        foreach item 4 ?[
          if ? = who[
            set me_chasing true]
        ]
        if item 3 ? = "chasing" and me_chasing = true and distancexy item 0 ? item 1 ? < radius-cops[
          if not any? thieves-on neighbors[
            ifelse messages != [] [
              set messages lput (list item 0 ? item 1 ? item 2 ? "unknown" [-1]) messages
            ][
              let new_message (list item 0 ? item 1 ? item 2 ? "unknown" [-1])
              set messages (list new_message)
            ]
          ]
        ]
        set i i + 1
      ]
    ]
  ]
end


to escort-thief [c]
  ask cop c [
    let door_x 0
    let door_y 0

    ; get your route how to get outside with the thief
    if route_outside = [] and caught_thief = true [
        set route_outside table:get escape_routes_cops current_room
    ]

    ifelse is-number? current_room [
      ifelse route_outside = [] [
      ; as then the thief's outside, you have put it in prison
        set thieves_active thieves_active - 1
        set num_thieves_in_prison num_thieves_in_prison + 1
        set caught_thief false
        lt 180                   ; the agent will head back into the environment to continue his work
        forward 1
        set-vision-radii-cops c
        set messages lput (list 0 0 [-1] "prison" (list who)) messages ; inform other that you put the thief in prison
      ][  ; if you are not in the hallway yet, try to get there
        set door_x item 0 item 0 route_outside
        set door_y item 1 item 0 route_outside

        ifelse distancexy door_x door_y < 1 [
          set route_outside remove-item 0 route_outside
          facexy door_x door_y
          forward 1

          ifelse pcolor = red [
            set caught_thief false
            set thieves_active thieves_active - 1
            set num_thieves_in_prison num_thieves_in_prison + 1
            lt 180
            forward 1
            set-vision-radii-cops c
            set messages lput (list 0 0 [-1] "prison" (list who)) messages ; inform other that you put the thief in prison
          ]
          [ set-vision-radii-cops c
            set messages lput (list xcor ycor [-1] "escorting" (list who)) messages ; inform other that you are escorting the thief
          ]
        ]
        [ facexy door_x door_y

          ask patch-ahead 1 [
            ifelse (not any? customers-on self and pcolor != black) or pcolor = blue [
              ask cop c [
                facexy door_x door_y
                forward 1
                ifelse pcolor = red [
                  set thieves_active thieves_active - 1
                  set num_thieves_in_prison num_thieves_in_prison + 1
                  set caught_thief false
                  lt 180
                  forward 1
                  set-vision-radii-cops c
                  set messages lput (list 0 0 [-1] "prison" (list who)) messages ; inform other that you put the thief in prison
                ]
                [ ifelse distancexy door_x door_y < 1[
                    set route_outside remove-item 0 route_outside
                ]
                [ set-vision-radii-cops c
                  set messages lput (list floor(xcor) floor(ycor) [-1] "escorting" (list who)) messages ; inform other that you are escorting the thief
                ]
                ]
              ]
            ]
            [ ask cop c [
                lt 180
                forward 1
                lt 15
                ifelse pcolor = red [
                  set thieves_active thieves_active - 1
                  set num_thieves_in_prison num_thieves_in_prison + 1
                  set caught_thief false
                  lt 180
                  forward 1
                  set-vision-radii-cops c
                  set messages lput (list 0 0 [-1] "prison" (list who)) messages ; inform other that you put the thief in prison
                ]
                [ set-vision-radii-cops c
                  set messages lput (list floor(xcor) floor(ycor) [-1] "escorting" (list who)) messages ; inform other that you are escorting the thief
                ]
              ]
            ]
          ]
        ]

      ]
    ]
    [ forward 1
      if pcolor = red [
        set thieves_active thieves_active - 1
        set num_thieves_in_prison num_thieves_in_prison + 1
        set caught_thief false
        set route_outside []
        lt 180
        forward 2
        set-vision-radii-cops c
        set messages lput (list 0 0 [-1] "prison" (list who)) messages ; inform other that you put the thief in prison
        ]]
  ]

end

to new-pos [my_pos follow_pos] ; function gets the position where to go next

  if item 1 my_pos != -1 [
    let my_room_patch table:get room_dict my_pos
    let follow_room_patch table:get room_dict follow_pos

    if my_room_patch = follow_room_patch [ ; if you're at the same room, you can simply move towards the position
      let x item 0 follow_pos
      let y item 1 follow_pos
      facexy x y
    ]
  ]
end

to move-to-item [t]
 ask thief t[
   let first_item item 0 belief_items ; this list is sorted, so move to the closest item
   let item_x item 0 first_item
   let item_y item 1 first_item

   facexy item_x item_y ; face in this direction
   forward 1
   set-vision-radii-thieves t
 ]
end

to steal-item [t]
  ; if you found an item, steal it
  if pcolor != white [
    set pcolor white
    ask thief t[
      set items true
    ]
  ]
end

to escape-now [t]
  ; same type of construction as escort-thief
  ask thief t [
    let door_x 0
    let door_y 0
    if route_outside = [] and escaped = false [
        set route_outside table:get escape_routes_thieves current_room
    ]

    ifelse is-number? current_room [
      ifelse route_outside = [] [
      ; as then the thief's outside
        set escaped true
        set thieves_active thieves_active - 1
        set num_stolen_items num_stolen_items + 1
      ][
        set door_x item 0 item 0 route_outside
        set door_y item 1 item 0 route_outside

        ifelse distancexy door_x door_y < 1 [
          set route_outside remove-item 0 route_outside
          facexy door_x door_y
          forward 1
          ifelse pcolor = red[
            set escaped true
            set thieves_active thieves_active - 1
            set num_stolen_items num_stolen_items + 1
          ][ set-vision-radii-thieves t ]
        ][ facexy door_x door_y

          ask patch-ahead 1 [
            ifelse (not any? customers-on self and pcolor != black) or pcolor = blue [
              ask thief t [
                facexy door_x door_y
                forward 1
                ifelse pcolor = red [
                  set escaped true
                  set thieves_active thieves_active - 1
                  set num_stolen_items num_stolen_items + 1
                ][ ifelse distancexy door_x door_y < 1 [
                  set route_outside remove-item 0 route_outside
                ][
                  set-vision-radii-thieves t ]]
              ]
            ][ ask thief t [
              lt 180
              forward 1
              lt 90
              ifelse pcolor = red [
                set escaped true
                set thieves_active thieves_active - 1
                set num_stolen_items num_stolen_items + 1
              ][ set-vision-radii-thieves t ]
            ]
            ]
          ]
        ]
      ]
    ][ forward 1
      if pcolor = red [
        set escaped true
        set thieves_active thieves_active - 1
        set num_stolen_items num_stolen_items + 1
        set route_outside []
      ]
    ]
  ]
end

to setup-rooms      ; hardcoded table with the different rooms and which patch belongs to which room
; Room numbering:
;7 |   | 5
;6 | 2 | 4
;1 |   | 3

  ; room 1 (left lower corner)
  ask patches with [pxcor > min-pxcor and pxcor < (max-pxcor - min-pxcor) / 2 - 3 and pycor > min-pycor and pycor < (max-pycor - min-pycor) / 2 ] [
    table:put room_dict list pxcor pycor 1
  ]

  ; room 2 (hallway)
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
  ; Hardcoded wayw of setting each patch to room, door or wall

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

  ; door outside up
  let k 0
  ask patches with [pxcor =  (max-pxcor - min-pxcor) / 2 and (pycor = max-pycor)] [ ; or pycor = min-pycor)] [
    set pcolor red
    table:put room_dict list pxcor pycor (list 2 0); in this version these two doors belong to the hall way and outside (0)
    set coord_2_1 list pxcor pycor
  ]

  ; door outside down
  ask patches with [pxcor =  (max-pxcor - min-pxcor) / 2 and (pycor = min-pycor)] [
    set pcolor red
    table:put room_dict list pxcor pycor (list 2 0); in this version these two doors belong to the hall way and outside (0)
    set coord_2_2 list pxcor pycor
  ]

  ; door inside - right (room 4 -> 2)
  ask patches with [pxcor = (max-pxcor - min-pxcor) / 2 + 3 and (pycor = (max-pycor - min-pycor) / 2)] [
    set pcolor blue
    table:put room_dict list pxcor pycor (list 4 2) ; this is the door from room 4 to room 2
    set coord_4 list pxcor pycor
  ]

  ; door inside - right (room 5 -> 2)
  ask patches with [pxcor = (max-pxcor - min-pxcor) / 2 + 3 and pycor = (max-pycor - min-pycor) / 2 + 10] [
    set pcolor blue
    table:put room_dict list pxcor pycor (list 5 2) ; this is the door from room 5 to room 2
    set coord_5 list pxcor pycor
  ]

  ; door inside - right (room 3 -> 2)
  ask patches with [pxcor = (max-pxcor - min-pxcor) / 2 + 3 and pycor = (max-pycor - min-pycor) / 2 - 10 ] [
    set pcolor blue
    table:put room_dict list pxcor pycor (list 3 2)
    set coord_3 list pxcor pycor  ; this is the door from room 3 to room 2
  ]

  ; door inside - left (room 6 -> 2)
  ask patches with [pxcor = (max-pxcor - min-pxcor) / 2 - 3 and pycor = (max-pycor - min-pycor) / 2 + 3] [
    set pcolor blue
    table:put room_dict list pxcor pycor (list 6 2)
    set coord_6 list pxcor pycor  ; this is the door from room 6 to room 2
  ]

  ; door inside - left (room 7 -> 2)
  ask patches with [pxcor = (max-pxcor - min-pxcor) / 2 - 3 and pycor = (max-pycor - min-pycor) / 2 + 14] [
    set pcolor blue
    table:put room_dict list pxcor pycor (list 7 2) ; this is the door from room 7 to room 2
    set coord_7 list pxcor pycor
  ]

  ; door inside - left (room 1 -> 2)
  ask patches with [pxcor = (max-pxcor - min-pxcor) / 2 - 3 and pycor = (max-pycor - min-pycor) / 2 - 10] [
    set pcolor blue
    table:put room_dict list pxcor pycor (list 1 2) ; this is the door from room 1 to room 2
    set coord_1 list pxcor pycor
  ]

  ; make escape route dictionary
  let l 1
  while [l < 8] [
    if l = 1 [
      let coord_before list 16 10
      let coord_after list 18 10
      table:put escape_dict 1 (list coord_before coord_1 coord_after coord_2_2)
    ]
    if l = 2 [
      let coord_before list 20 1
      table:put escape_dict 2 (list coord_before coord_2_2) ; for now I just chose an exit
    ]
    if l = 3 [
      let coord_before list 24 10
      let coord_after list 22 10
      table:put escape_dict 3 (list coord_before coord_3 coord_after  coord_2_2)
    ]
    if l = 4 [
      let coord_before list 24 20
      let coord_after list 22 20
      table:put escape_dict 4 (list coord_before coord_4 coord_after coord_2_2)
    ]
    if l = 5 [
      let coord_before list 24 30
      let coord_after list 22 30
      table:put escape_dict 5 (list coord_before coord_5 coord_after coord_2_1)
    ]
    if l = 6 [
      let coord_before list 16 23
      let coord_after list 18 23
      table:put escape_dict 6 (list coord_before coord_6 coord_after coord_2_1)
    ]
    if l = 7 [
      let coord_before list 16 34
      let coord_after list 18 34
      table:put escape_dict 7 (list coord_before coord_7 coord_after coord_2_1)
    ]
    set l l + 1
  ]

  ; make chasing thief dict
  let r 1
  while [r < 8] [

    if r = 1 [
      let coord_before list 16 10
      let coord_after list 18 10
      table:put chase_thief_dict 1 (list coord_before coord_1 coord_after)
    ]


    if r = 2 [
      let coord_before_1 list 18 10
      let coord_after_1 list 16 10
      table:put chase_thief_dict (list 2 1) (list coord_before_1 coord_1 coord_after_1)


      let coord_before_3 list 22 10
      let coord_after_3 list 24 10
      table:put chase_thief_dict (list 2 3) (list coord_before_3 coord_3 coord_after_3)

      let coord_before_4 list 22 20
      let coord_after_4 list 24 20
      table:put chase_thief_dict (list 2 4) (list coord_before_4 coord_4 coord_after_4)

      let coord_before_5 list 22 30
      let coord_after_5 list 24 30
      table:put chase_thief_dict (list 2 5) (list coord_before_5 coord_5 coord_after_5)

      let coord_before_6 list 18 23
      let coord_after_6 list 16 23
      table:put chase_thief_dict (list 2 6) (list coord_before_6 coord_6 coord_after_6)

      let coord_before_7 list 18 34
      let coord_after_7 list 16 34
      table:put chase_thief_dict (list 2 7) (list coord_before_7 coord_7 coord_after_7)
    ]

    if r = 3 [
      let coord_before list 24 10
      let coord_after list 22 10
      table:put chase_thief_dict 3 (list coord_before coord_3 coord_after)
    ]

    if r = 4 [
      let coord_before list 24 20
      let coord_after list 22 20
      table:put chase_thief_dict 4 (list coord_before coord_4 coord_after)
    ]

    if r = 5 [
      let coord_before list 24 30
      let coord_after list 22 30
      table:put chase_thief_dict 5 (list coord_before coord_5 coord_after)
    ]

    if r = 6 [
      let coord_before list 16 23
      let coord_after list 18 23
      table:put chase_thief_dict 6 (list coord_before coord_6 coord_after)
    ]

    if r = 7 [
      let coord_before list 16 34
      let coord_after list 18 34
      table:put chase_thief_dict 7 (list coord_before coord_7 coord_after)
    ]

    set r r + 1

  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
620
10
1163
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
11
47
78
80
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
260
47
432
80
num_customers
num_customers
0
300
0
1
1
NIL
HORIZONTAL

BUTTON
184
180
251
214
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
87
46
252
79
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
86
85
252
118
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
87
123
251
156
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

SLIDER
261
84
433
117
max-speed-thieves
max-speed-thieves
1
3
2
1
1
NIL
HORIZONTAL

SLIDER
440
47
612
80
radius-thieves
radius-thieves
0
10
5
1
1
NIL
HORIZONTAL

SLIDER
262
123
434
156
max-speed-cops
max-speed-cops
1
3
2
1
1
NIL
HORIZONTAL

SLIDER
440
87
612
120
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
265
180
360
213
one tick
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

TEXTBOX
11
10
296
52
First click on setup, than place items, cops and thieves. Ready? Start the simulation.
11
0.0
1

MONITOR
4
230
437
275
Beliefs about seeing thief of cop 1
[belief_thieves] of cop1
17
1
11

MONITOR
440
229
618
274
Desire of cop 1
[desire] of cop1
17
1
11

MONITOR
441
283
615
328
Intention of cop 1
[intention] of cop1
17
1
11

MONITOR
4
337
436
382
Beliefs about seeing thief of cop 2
[belief_thieves] of cop2
17
1
11

MONITOR
440
336
618
381
Desire of cop 2
[desire] of cop2
17
1
11

MONITOR
443
387
617
432
Intention of cop 2
[intention] of cop2
17
1
11

MONITOR
6
455
207
500
Beliefs about seeing cop of thief 1
[belief_seeing_cop] of thief1
17
1
11

MONITOR
214
455
435
500
Beliefs about seeing an item of thief 1
[belief_items] of thief1
17
1
11

MONITOR
443
455
605
500
Desire of thief 1
[desire] of thief1
17
1
11

MONITOR
7
504
176
549
Intention of thief 1
[intention] of thief1
17
1
11

MONITOR
7
557
208
602
Beliefs about seeing cop of thief 2
[belief_seeing_cop] of thief2
17
1
11

MONITOR
214
557
435
602
Beliefs about seeing an item of thief 2
[belief_items] of thief2
17
1
11

MONITOR
442
556
601
601
Desire of thief 2
[desire] of thief2
17
1
11

MONITOR
8
607
176
652
Intention of thief 2
[intention] of thief2
17
1
11

MONITOR
1183
43
1333
88
Number Cops
number_cops
17
1
11

MONITOR
1183
120
1334
165
Number Thieves
number_thieves
17
1
11

MONITOR
1181
200
1336
245
Number Escaped with Items
num_stolen_items
17
1
11

MONITOR
1181
278
1338
323
Number in Prison
num_thieves_in_prison
17
1
11

MONITOR
4
282
438
327
Messages of cop 1
[messages] of cop1
17
1
11

MONITOR
5
388
437
433
Messages of cop 2
[messages] of cop2
17
1
11

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
