
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Copyright 2016-2022 Indushree Banerjee, Delft University of Technology, Delft, Netherlanda ;;;;;;;;;;;;;;;;;
;; Permission is hereby granted, free of charge, to any person obtaining ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; a copy of this software and associated documentation files (the "Software"), ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; to deal in the Software without restriction, including without limitation the ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rights to use, copy, modify, merge, publish, distribute, sublicense, ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, ;;;;;;
;; subject to the following conditions: ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, ;;;;;;;;;;;;;;;;;;;;;;;;
;; INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, ;;;;
;; WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. ;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Network extension for Netlogo to store the MST;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
extensions [ nw csv ]
;;;;;going to do some experiment with link color;;;;;

globals [

  SIGNAL ; For fix MW
  giants-component-edges-number
  giant-component-nodes-number
  giant-component
  bridges

  stopticks                    ; Used for the stopping condition

  longeivity                   ; To calculate how long the network lasts
  total-energy                 ; To calculate the loss of total energy of all nodes over time
  node-participation           ; To calculate participation of nodes

  Sending                      ; Used for deducting the cost of sending a single SMS message
  Receiving                    ; Used for deducting the cost of receiving a single SMS message
  Relaying                     ;

  first_disconnect             ; To monitor the death of the first node (how long does the lowest energy can participate)
  half_disconnect              ; To monitor the time till half of the population can communicate
  seventy_percent_disconnect   ; To monitor the time till 75% of the participating population drops
  total_disconnect             ; To report the final disconnect when all nodes are dead

  nodes_mean
  nodes_SD
  cost_of_connection          ; Cost associated with connecting with another node
  cost_of_beacon_event        ; Cost associated with advertising presence
  disconnected-nodes          ; Nodes that are no longer connected to any network
  connected-nodes             ; Nodes that are connected to a network

  reported-energy
  total-undelivered-messages
  energy_list_list_turtles
  centrality_list_list_turtles
  energy-loss
  initial-energy

  count-end
  total_COS

   msg-num
   msg-delivered
   msg-not-delivered
   total-msg

 ; exhausted-node-list

  Deli_msg_list_list_nodes
  Undeli_msg_list_list_nodes
  global-dead-node-list
  average-node-degree

  beacon-cost
  connection-cost
  sending-cost
  receiving-cost
  relaying-cost
  relabling-subtree-cost

  total-participation

  failed_messages-if-sender-died
  failed_messages-if-receiver-died
  exhausted-nodes-list
]


turtles-own [


  energy                           ; The total energy of a node
  subtree                          ; The number to determine which subtree it is part of.

  ; For debugging
  pot-nodes                       ; nodes that are potentially connectable
  rad-nodes                       ; nodes in Transmission_range
  con-nodes                       ; connected nodes

  cost-of-connection               ; energy lost for getting connected to a node

  cost-of-relaying
  cost-of-snd        ; potential energy lost for sending message
  cost-of-rcv        ; energy lost for receiving messages
  cost-of-prep       ; energy lost for cost of preprocessing the BLE connection

  num-msg-snd        ; number of sent messages
  num-msg-rcv        ; number of received messages

  min-msg            ; potential number of minimum messages sent or received by a node

 pending?  ; if the message not delivered
 pending-receiver-list; the who of the receiver
 pending-receiver-list-with-no-dead-receiver
 secondary-pending-list ; list for resending

 failed_messages
 old-subtree-id
 relabeled?
 reconfig-frequency
 battery-almost-over


]

to setup-no-random
  random-seed Seed
  setup
end


to setup

  clear-all
  ask patches [ set pcolor 2  ]
  set msg-not-delivered 0
  set count-end 0

  set energy_list_list_turtles []
  set Deli_msg_list_list_nodes []
  set Undeli_msg_list_list_nodes []

  set SIGNAL false ; For fix MW
  set beacon-cost 0
  set connection-cost 0
  set sending-cost 0
  set receiving-cost 0
  set relaying-cost 0
  set relabling-subtree-cost 0

  set total_COS 0
  set stopticks false

  set failed_messages-if-sender-died 0
  set failed_messages-if-receiver-died 0

  set exhausted-nodes-list []

  set msg-num round ((Percentage-of-msg / 100) * num-nodes )


  set msg-delivered 0
  set total-msg 0
  set global-dead-node-list[]

  set node-participation num-nodes

  crt num-nodes
  [
    set shape "person"
    set color blue - 0.1
    set size 0.7
    set xcor random-xcor
    set ycor random-ycor
    set battery-almost-over false
    set relabeled? false
    set reconfig-frequency 0


    with-local-randomness
    [
      random-seed [ who ] of myself

      ;;Uniform distribution
      ;set energy round (( random (Battery) * (1 + random-normal 0.60  0.05 )) * 60)

      ;; Normal distribution
      ;set energy round (( (Battery) * (1 + random-normal 0.60  0.15 )) * 60)

      ;; We want a normal distribution with enough variation that there are some nodes with low energy (close to expiration before disaster),
      ;; but not so much variation that there are nodes with negative energy
      set energy round (( (Battery) * (1 + random-normal 0.60  0.36 )) * 60)

    ]
    set subtree who
    set old-subtree-id subtree

    set-transmission-energy

    ;; this cost-of-coonection is the amount I got from document BLE power calculation tool
    ;;This is the amount of energy lost when a BLE connects to another BLE and works as a connected peripheral
    ;; This is in milliAmpere, is refred as Activity 2: Connected as a Peripheral
    set cost-of-connection (0.511)


    ;; Advertising event where the BLE broadcasts informaion in order to either share information or
    ;;become connected to a BLE central device.
    ;; I got from document BLE power calculation tool is refered as Activity 1: Advertising
    ;set cost_of_beacon_event (1.007)
    ;set cost_of_beacon_event (100)


    set pending? false

    set pending-receiver-list[]

    set secondary-pending-list[]
    set pending-receiver-list-with-no-dead-receiver []
    set failed_messages 0
  ]

  set total-participation num-nodes

  set total-energy sum [energy] of turtles



  set first_disconnect 0
  set half_disconnect 0
  set seventy_percent_disconnect 0
  set total_disconnect 0
  set total-undelivered-messages 0
  set disconnected-nodes 0
  set energy-loss 0
  set initial-energy sum [energy] of turtles

  reset-ticks

  ask turtles [ reconfigure_tree color-turtles]


end

to print-node-value
 type who  type " " type " " type " " type " " print subtree
end

to print-energy-loss
 type connection-cost  type " " type " " type " " type " " type " " type " " type beacon-cost type " " type " " type " "type " " type " " type " "print relabling-subtree-cost
end

to go


  if stopticks = true
  [ stop]

  ask turtles [ set old-subtree-id subtree ]

  ;; Once the simulation starts, first exhausted nodes are removed.
  ;; Connected links fo the exhausted nodes are also removed and their subtree are relabled
  ;; Wander is for making nodes move aorund in the patches

  ifelse Mobility
  [
    ask turtles
    [
      remove-exhausted-nodes

      remove-links-and-relabel-subtrees

      wander

    ]
  ]

  [
    if mean [subtree] of turtles = [subtree] of (turtle 0)
    [stop]
  ]

  ;;; First pending messages are sent so that messages are in the next hop from the previous send and receive
  ;;; Hence before resending , if there is pending messages, those nodes are asked to recofigure at first

  let resending-turtles turtles with [ pending? = true AND battery-almost-over = false ]

  if any? resending-turtles[ ask resending-turtles [ reconfigure-to-resend-messages resend-pending-messages ]]

  ;; Now send new messages
  Send-Receive  msg-num

  set total-msg   total-msg + msg-num

  ;; After all the sending, receiving and resending,
  ;; to calculate the loss of energy in reconfiguring
  ;; The following function deducts energy by comapring Subtree,
  ;; If there is a change it means then the turtles deduct energy.

  if Calculate_COS
  [
    ask turtles with [energy > 1 and relabeled?] [ deduct-COS ]
  ]

  ask turtles with [length pending-receiver-list = 0 ] [set pending? false]

  ;; This function is for the gradual decay of battery life consisting of OS, android, mobile standby, mobile idle battery loss
  ;; every phone loses a fixed amount of energy
  ;; all nodes reduce 1 unit of energy for every tick
  ;; After reduction they are checked if they have extremely low energy
  ;; if battery is almost over, then that veriable is set to true
  ;; they are removed from the simulation in the next function

  ask turtles with [ energy > 1]
  [ set energy energy - 1
        if energy < Sending
        [set battery-almost-over true]
  ]

  ;;ask turtles with [energy > 1]
   map-data

 ;;;;because energy reporting is not working


  ;;;; Stop condition

  if  ( (count turtles) <= ( num-nodes * .10 ) )
  [
    set total_disconnect ticks
    ask turtles with [pending? = true] [ set msg-not-delivered msg-not-delivered + length pending-receiver-list ]
    set stopticks true
  ]

  ask turtles with [ count link-neighbors = 0 ] ; nice hack!
  [set subtree who]

  ask turtles with [ relabeled?] [set relabeled? false set reconfig-frequency 0]


  tick
end

to deduct-COS
  if old-subtree-id != subtree
    [
     set energy energy - ( cost-of-connection * reconfig-frequency )
     set total_COS total_COS + ( cost-of-connection * reconfig-frequency )
     set relabling-subtree-cost relabling-subtree-cost + cost-of-connection
    ]
end


to reconfigure_tree

   remove-exhausted-nodes

   remove-links-and-relabel-subtrees

   build-tree

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; This function removes nodes from the simulation that have no energy left ;;;;;
;; This means it first asks all nodes with battery almost over = true ;;;;;;;;;;;
;; It also keeps track of all the messages that will no longer be delivered ;;;;;
;; Becacuse the sender died and it has pending messages to sent ;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to remove-exhausted-nodes

  if (energy < Sending) OR (battery-almost-over = true)
  [

    set exhausted-nodes-list lput [who] of self exhausted-nodes-list

    if pending? = true
      [
        set failed_messages-if-sender-died failed_messages-if-sender-died + length pending-receiver-list
      ]

      if first_disconnect = 0
      [
        set first_disconnect ticks
      ]

    ask my-links [die]
    die
   ]
end



to remove-pending-messages-for-dead-nodes [ dead-node-list ]
  let dead-nodes-agentset dead-node-list
  let dead-node-present false

 ; i have to remove the frequency of the messages. so find out how many messages to the same dead-nodes
  foreach dead-nodes-agentset
  [ ID ->
     set dead-node-present member? ID pending-receiver-list
     if dead-node-present = true
    [
      let every-dead-node-removed false
        while [every-dead-node-removed = false]
        [
           let pos position ID pending-receiver-list

           ifelse pos = false

           [
             set every-dead-node-removed true
           ]

           [
             set pending-receiver-list remove ID pending-receiver-list
             set failed_messages failed_messages + 1
           ]
       ]
     ]
  ]
end


to build-tree ; turtle procedure

  let potential-links remove-same-subtree subtree find-potential-links


  if not empty? potential-links
    [
      let pot-subtree (item 1 first potential-links)
      ;print "subtree number of the potential links"
      ;print pot-subtree

      let who-pot-link (item 2 first potential-links)
      ;print "who-id number of the potential links"
      ;print who-pot-link


      let my-subtree subtree ; subtree number of caller
      if subtree != pot-subtree ; checking if my subtree number is not equal to the best potential link
      [
        create-link-with (turtle who-pot-link)

           [   ; create link

            set color 87
            set thickness 0.06
            ask both-ends
             [ ; Cost of connecting is deducted from both ends
               ; this included cost of selforganisation because it does that everytime.
               set energy energy - cost-of-connection
               if energy < Sending
              [ set battery-almost-over true ]
               set connection-cost connection-cost + cost-of-connection
             ]
           ]
             ; change all subtree numbers to the same as caller, recursively
             change-subtree-number my-subtree
      ]
    ]
end

;; To find nodes in the transmission range that can be potentially be connected to,
;; rad-nodes reports all nodes in the tranmission range excluding the node calling it
;; con-nodes reports all nodes connected to this perticular node
;; pot-nodes reports the nodes in transmission range that are still not connected to this node
;; Then the number of pot-nodes is calculated to beacon them.
;; This is used to deduct the energy associated with finding before getting connected

to-report find-potential-links
  ;print "In potential link finding stage "
  ;print self

  let potential-links []
  ;print "Nodes in radius"
  set rad-nodes other turtles in-radius Transmission_range
  ;print rad-nodes
  ;set con-nodes link-neighbors
  set con-nodes other rad-nodes with [subtree = [subtree] of myself ]
  ;print "connected nodes"
  ;print con-nodes

  ;print "Potential nodes for connecting"
  set pot-nodes set-difference rad-nodes con-nodes
  ;print pot-nodes

  let number-of-beacon-sent count pot-nodes
  ;print "number of beacon "
  ;print number-of-beacon-sent
  set energy energy - (number-of-beacon-sent * cost_of_beacon_event)

  if energy < Sending [set battery-almost-over true]

  set beacon-cost (number-of-beacon-sent * cost_of_beacon_event) + beacon-cost

  if Calculate_cos
  [ set total_COS total_COS + number-of-beacon-sent * cost_of_beacon_event  ]


  if any? pot-nodes with [ battery-almost-over = false ]
    [
      ask pot-nodes with [ battery-almost-over = false]
      [
        set potential-links (sentence potential-links (list (list energy subtree who)))
        set potential-links (sort-with [ l -> item 0 l ] potential-links)

      ]
    ]

report potential-links

end


to wander ; turtle procedure
  ifelse (random 2 = 0)
   [rt random 45]
   [lt random 45]
  fd 1
end

to remove-links-and-relabel-subtrees ; turtle procedure
                             ;let oe (turtle 0) mw
  let oe no-turtles
  let my-node self ;
  if any? my-links
  [
    ask my-in-links
    [
      set oe other-end

        if link-length > Transmission_range
        [
          set SIGNAL true ; For fix MW
          die
        ]

      ;;;;;;;;;;;; This is the problem area - I think I fixed it :-) MW

      if SIGNAL ; For fix MW
      [
        ifelse [who] of my-node != [ subtree ] of oe
        [
          ask my-node
          [
            let my-who-number [who] of my-node
            change-subtree-number my-who-number ; make sure the resulting subtree is relabeled properly
            set relabeled? true
            set reconfig-frequency reconfig-frequency + 1

          ]
        ]

       [
          ask (turtle [who] of oe)
          [ change-subtree-number [who] of oe
            set relabeled? true
            set reconfig-frequency reconfig-frequency + 1
          ] ; make sure the resulting subtree is relabeled properly

       ]
        set SIGNAL false ; For fix MW
      ]

    ]
  ]


end



;; Utility procedurs
to-report sort-with [ key lst ]
  report sort-by [ [a b] -> (runresult key a) > (runresult key b) ] lst
end

to-report set-difference [ set1 set2 ]
  report set1 with [ not member? self set2 ]
end

to-report remove-same-subtree [subtree-num  l]; remove potential candiates that are already in the same subtree
  if empty? l
  [
    report l
  ]
  ifelse (item 1 first l) = subtree-num
  [
    report remove-same-subtree subtree-num (but-first l)
  ]
  [
    report sentence (list(first l)) remove-same-subtree subtree-num (but-first l)
  ]
end

to change-subtree-number [num] ; recursively change the subtree number of all connected nodes, assuming num = myself
  if any? link-neighbors
  [
    set subtree num
    ask link-neighbors [ if subtree != [subtree] of myself
      [  set subtree [subtree] of myself
        change-subtree-number num

      ]
    ]
  ]
end

to-report total-link-length
  let ttl 0
  ask links [ set ttl ttl + link-length ]
  report ttl
end

to set-transmission-energy

  ;; This is the ammount of power consumption while receiving a SMS in milliAmpere
  ;; https://ieeexplore.ieee.org/abstract/document/6215496
  set cost-of-rcv 2.45
  set cost-of-snd 2.85

  set cost-of-relaying 4.46

  set Receiving cost-of-rcv * Multiplier
  set Sending cost-of-snd * Multiplier
  set Relaying cost-of-relaying * Multiplier



end


to Send-Receive [ number-msg-exchanged ]


  if  number-msg-exchanged != 0 [

  let active-relay-nodes false
  let sender 0                  ;; will in later stage be used to send the who of a node as sender
  let receiver 0                ;; will in later stage be used to send the who of a node as sender

  ifelse count turtles with [ (energy > energy - Sending) AND (battery-almost-over = false) ] >= number-msg-exchanged
  [
  let communicating-subset n-of number-msg-exchanged turtles with [ (energy > energy - Sending) AND (battery-almost-over = false) ]

  if count communicating-subset <= 1
  [stop]

  ask communicating-subset
  [
    let n1 [ who ] of self

    let n2 [who] of one-of communicating-subset with [ who != n1]

   ifelse count turtles with [(energy - Sending) > 0 ] >= 2 ;; check if there are at least two nodes in this network that can still send (and receive) messages
   [
  ;;; This goes on to select a node that might have enough energy to send and stores the who number in n1
  ;; this follows the same concept as the sender but for the receiver and additonally ensures that receiver is different than sender,
  ;;;before sending messages, check if route is present or not.

  let routing-path is-route-available n1 n2

 ;; if there a path exists, send message and deduct cost"

  ifelse (routing-path != false)
      [

        let relayer-has-energy true
        let relay-node-list[]

        ask turtle n1 [ set relay-node-list nw:turtles-on-path-to turtle n2 ]

        let n3 [who] of item 1 relay-node-list

        ask turtle n3
        [ ifelse battery-almost-over = false
          [set relayer-has-energy true]
          [set relayer-has-energy false ]
         ]

        ifelse relayer-has-energy = true
        [
          deduct-sending-cost n1
          deduct-receiving-cost n3

          ifelse n2 = n3
           [
              set msg-delivered msg-delivered + 1
              ;print "yay msg delivered"
              ;print msg-delivered
           ]
           [ ask turtle n3
                         [
                            set pending? true
                            set pending-receiver-list lput n2 pending-receiver-list
                          ]
           ]

          ]  [ ask turtle n1
                              [
                                  set pending? true
                                  set pending-receiver-list lput n2 pending-receiver-list
                               ]
              ]

 ;;;otherwise, if no route present then save the message as pending and donot reduce cost

      ][
        ask turtle n1
        [
          set pending? true
          set pending-receiver-list lput n2 pending-receiver-list
        ]
       ]

       ][ if  ( (count turtles) <= ( num-nodes * .10 ) )

    [
           set total_disconnect ticks
           ask turtles with [pending? = true] [ set msg-not-delivered msg-not-delivered + length pending-receiver-list ]
           set stopticks true


       ]

    ]
    ]

  ]
  [
   ; case where there are more message send per tick then there are aviable turtles for sending messages
   let send-now count turtles with [ (energy > energy - Sending) AND (battery-almost-over = false) ]
    Send-Receive send-now
    Send-Receive ( number-msg-exchanged - send-now )

  ]
  ]
end

;;; to deduct sending cost from the sender
to deduct-sending-cost [sender-id]

  let S-id sender-id

  ask turtles with [who = S-id]
   [
    ifelse energy - Sending > 0
     [
        set energy energy - Sending

        set sending-cost sending-cost + Sending

        if energy < Sending [ set battery-almost-over true ]
      ]

     [ set battery-almost-over true ]
   ]

end


to deduct-receiving-cost [receiver-id]

  let R-id receiver-id

  ask turtles with [who = R-id]
  [
    ifelse energy - Receiving > 0
    [
      set energy energy - Receiving
      set receiving-cost receiving-cost + Receiving

      if energy < Receiving [set battery-almost-over true ]

   ]

   [ set battery-almost-over true ]

  ]

end


to-report is-connected-to-links [ who-id ]
  let sender-node who-id
  let num-links count [my-links] of sender-node
  ifelse num-links = 0
  [report false]
  [report true]
end

  ;; This function reports if there is a path in between sender and receiver.
  ;; the procedure relay list returns them a list of relaying nodes after checking if every node in the path has
  ;; enough energy for relaying, if there is a node with no energy it reconfigures the mst and finds a new path
  ;; with new relays but with the same sender and receiver.

to-report is-route-available [S-id R-id]
  let sender-id S-id
  let receiver-id R-id
  let route true

  ask turtle sender-id
  [ carefully [set route nw:distance-to turtle receiver-id ]
              [set route false]
  ]
  report route
end

to-report relays-have-energy [S-id R-id]
  let sender-id S-id
  let receiver-id R-id
  let all-relay-nodes-have-energy true
  let relay-route []
  ask turtle sender-id
  [ carefully [ set relay-route nw:turtles-on-path-to receiver-id

             ]
             [ set all-relay-nodes-have-energy false ]
  ]
  report all-relay-nodes-have-energy
end

to store-pending-message [ pending-transmit pending-receive ]

  let my-transmiter self
  if [ who ] of my-transmiter =  pending-transmit
  [
    set pending? true
    set pending-receiver-list lput  pending-receive pending-receiver-list

  ]

end

to reconfigure-to-resend-messages
    let my-agentset turtles with [ pending? = true]
    ;print self
    ask my-agentset
    [
      let my-agent self
      let check-route []
      let sender-id [who] of my-agent

          let sender-neighbours []


           ifelse (is-connected-to-links my-agent) = true
            [


              ask turtle sender-id

                [
                  set sender-neighbours turtle-set [other-end] of my-links ]
                 ; print "my neighbours"
                 ; print sender-neighbours
                if Reconfig_adaptive [ask sender-neighbours [
                 ; print "My neighbours are calling reconfiguring-tree "
                  reconfigure_tree ] ]
            ]

            [
               ; I have no connections, so I configure myself to build a tree
                if Reconfig_adaptive [ask turtle sender-id [ reconfigure_tree ] ]
            ]
    ]
end


to resend-pending-messages

        foreach pending-receiver-list
        [

          ID ->
        ifelse [battery-almost-over] of self = true
        [stop]
        [
          let sender-id [who] of self
          let receiver-id ID

          let routing-path is-route-available  sender-id receiver-id


         ifelse routing-path != false
         [

            let relayer-has-energy true
            let relay-node-list[]

            ask turtle sender-id [ set relay-node-list nw:turtles-on-path-to turtle receiver-id ]
            let relay-node [who] of item 1 relay-node-list



            ask turtle relay-node [
                             ifelse battery-almost-over = false
                                    [set relayer-has-energy true]
                                    [set relayer-has-energy false ]
                            ]

           ifelse relayer-has-energy = true
                                              [
                                                  deduct-sending-cost sender-id
                                                  deduct-receiving-cost relay-node

                                                   ifelse receiver-id = relay-node
                                                     [
                                                     set msg-delivered msg-delivered + 1


                                                     ]
                                                     [ ask turtle relay-node
                                                       [set pending? true
                                                        set pending-receiver-list lput receiver-id pending-receiver-list
                                                       ]

                                                     ]

                                               ]
                                               [ set pending? true
                                                 set secondary-pending-list lput receiver-id secondary-pending-list

                                               ]
 ;;;otherwise, if no route present then save the message as pending and donot reduce cost

                   ]
                   [      set pending? true
                          set secondary-pending-list lput receiver-id secondary-pending-list

                   ]

             ]
              ;;;otherwise, if no route present then save the message as pending and donot reduce cost
         ]


      set pending-receiver-list secondary-pending-list

      set secondary-pending-list[]

end


to map-data

  set total-energy sum [energy] of turtles
  let current-nodes-participate 0
  set current-nodes-participate count turtles

  if current-nodes-participate <= (node-participation * .5) and half_disconnect = 0
  [ set half_disconnect ticks ]


  if current-nodes-participate <= (node-participation * .25) and seventy_percent_disconnect = 0
  [ set seventy_percent_disconnect ticks ]

  ask turtles [ if energy < Receiving and first_disconnect = 0
               [ set first_disconnect ticks ]
              ]

  ask turtles with [ energy > 1 ] [
  if empty? exhausted-nodes-list = false [

  let exhausted-nodes-in-my-list []
  foreach exhausted-nodes-list
    [
      ID ->

      set exhausted-nodes-in-my-list filter [ID2 -> ID2 = ID] pending-receiver-list


      set failed_messages-if-receiver-died failed_messages-if-receiver-died + length exhausted-nodes-in-my-list

    ]

  set exhausted-nodes-list []
  ]
  ]

  if (ticks = 1 ) or (ticks mod 1 = 0) [
   set energy_list_list_turtles []
   set centrality_list_list_turtles []
   ask turtles with [energy > 1]
    [
      let energy_list_turtles 0

      set energy_list_turtles (list who energy)
      set energy_list_list_turtles lput energy_list_turtles energy_list_list_turtles


      let centrality_list_turtles 0
      set centrality_list_turtles ( list who nw:betweenness-centrality)
     ; show centrality_list_turtles
      set centrality_list_list_turtles lput centrality_list_turtles centrality_list_list_turtles
      ;show centrality_list_list_turtles
      ]
     ]

end

to-report total-energy1
  report total-energy
end

to-report full-disconnect
  report total_disconnect
end

to-report half-disconnect1
  report half_disconnect
end

to-report seventy-percent-disconnect1
  report seventy_percent_disconnect
end

to-report first-disconnect1
  report first_disconnect
end

to-report mean-nodes
  report nodes_mean
end

to-report SD-nodes
  report nodes_SD
end


to-report report-node-energy

   ifelse (ticks = 1) or (ticks mod 1 = 0)
   [ report energy_list_list_turtles ]
   [ report 0]

end

to-report turtles-with-undelivered-messages
  report count turtles with [ failed_messages > 0 ]
end

to-report undelivered-messages
report msg-not-delivered
end

to-report Cost-of-Self-organisation
  report total_COS
end


to-report total-msg-sent
  report (full-disconnect * msg-num )
end
to-report delivered-msg
  report total-msg-sent - undelivered-messages
end

to-report avg-node-degree
  report average-node-degree
end


to-report node-betweenness-centrality
  ifelse (ticks = 1) or ( ticks mod 1 = 0)
  [report centrality_list_list_turtles]
  [report 0]
end

to-report dead-nodes
  ifelse (ticks = 1) or (ticks mod 50 = 0)
  [report total-participation - count turtles]
  [report 0]
end

to-report FMRD
   ifelse (ticks = 1) or (ticks mod 5 = 0)
  [ report failed_messages-if-receiver-died]
  [ report 0]
end

to-report FMSD
   ifelse (ticks = 1) or (ticks mod 5 = 0)
   [ report failed_messages-if-sender-died ]
   [ report 0]
end

to-report Total-MSG-delivered
   ifelse (ticks = 1) or (ticks mod 5 = 0)
  [ report msg-delivered ]
  [ report 0]
end

to-report total-pending-msg
  let sum-pending-msg 0
  ask turtles with [ pending? = true ]
  [set sum-pending-msg length pending-receiver-list + sum-pending-msg ]
  report sum-pending-msg
end

to-report energy-lost-in-connection-event
  report connection-cost
end

to-report energy-lost-in-sending
  report sending-cost
end

to-report energy-lost-in-receiving
  report receiving-cost
end

to-report energy-lost-in-reconfiguration
  report total_COS
end

to color-turtles
  ; next code no longer assumes Battery = 1000 :-)
  ifelse (energy > (Battery * 1.6 * 60))
      [set color 65]

  [ ifelse (energy > (Battery * 60) AND energy < (Battery * 1.6 * 60))
    [set color 105]
    [ if (energy < (Battery * 60))
      [set color 15]
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
224
10
2732
2519
-1
-1
100.0
1
10
1
1
1
0
1
1
1
-12
12
-12
12
0
0
1
ticks
30.0

SLIDER
6
44
201
77
num-nodes
num-nodes
0
1000
600.0
1
1
NIL
HORIZONTAL

BUTTON
7
10
97
43
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
6
79
200
112
Transmission_range
Transmission_range
0
160
5.0
0.5
1
NIL
HORIZONTAL

BUTTON
99
10
201
43
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

SWITCH
5
225
103
258
Mobility
Mobility
0
1
-1000

SLIDER
6
185
201
218
Reconfiguration
Reconfiguration
1
500
1.0
10
1
NIL
HORIZONTAL

SLIDER
6
113
200
146
Battery
Battery
0
2500
500.0
1
1
NIL
HORIZONTAL

SWITCH
107
224
201
257
Reconfig
Reconfig
1
1
-1000

SLIDER
-3
457
191
490
Msg_exchange_fqn
Msg_exchange_fqn
0
1000
0.0
5
1
NIL
HORIZONTAL

SLIDER
4
261
202
294
Seed
Seed
0
100
42.0
1
1
NIL
HORIZONTAL

PLOT
970
196
1415
355
Nodes Participation
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles"

PLOT
903
703
1347
836
Cost of Self-Organisation
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sum [energy] of turtles"
"pen-1" 1.0 0 -955883 true "" "plot cost-of-self-organisation"

PLOT
969
363
1415
517
Nodes with undelivered messages
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot turtles-with-undelivered-messages"

SWITCH
6
303
153
336
Calculate_COS
Calculate_COS
0
1
-1000

PLOT
967
10
1414
186
Total Energy of the Network
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sum [energy] of turtles"

SLIDER
6
343
178
376
Multiplier
Multiplier
0
100
1.0
1
1
NIL
HORIZONTAL

SWITCH
7
382
158
415
Reconfig_adaptive
Reconfig_adaptive
0
1
-1000

BUTTON
10
423
95
456
go-once
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

PLOT
970
526
1415
722
Undelivered Messages
Ticks
Undelivered messages
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"pen-1" 1.0 0 -13840069 true "" "plot undelivered-messages"

SLIDER
7
149
199
182
Percentage-of-msg
Percentage-of-msg
1
500
800.0
1
1
NIL
HORIZONTAL

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
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="PHASE-DIAGRAM-25x25" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
      <value value="250"/>
      <value value="300"/>
      <value value="350"/>
      <value value="400"/>
      <value value="450"/>
      <value value="500"/>
      <value value="550"/>
      <value value="600"/>
      <value value="650"/>
      <value value="700"/>
      <value value="750"/>
      <value value="800"/>
      <value value="850"/>
      <value value="900"/>
      <value value="950"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
      <value value="250"/>
      <value value="300"/>
      <value value="350"/>
      <value value="400"/>
      <value value="450"/>
      <value value="500"/>
      <value value="550"/>
      <value value="600"/>
      <value value="650"/>
      <value value="700"/>
      <value value="750"/>
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Gini-BWC-500nodes-1msg-per-node" repetitions="50" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <final>if stopticks = true
  [ stop]</final>
    <metric>report-node-energy</metric>
    <metric>node-betweenness-centrality</metric>
    <metric>full-disconnect</metric>
    <metric>undelivered-messages</metric>
    <metric>total-msg-sent</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-50msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-100msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-150msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-200msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-250msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-300msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-350msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-400msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-450msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-500msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-550msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-600msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-650msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-700msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-750msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-800msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-850msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="850"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-900msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-950msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="950"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-50nodes-1000msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-50msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-100msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-150msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-200msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-250msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-300msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-350msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-400msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-450msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-500msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-550msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-600msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-650msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-700msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-750msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-800msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-850msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="850"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-900msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-950msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="950"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-100nodes-1000msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-50msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-100msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-150msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-200msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-250msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-300msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-350msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-400msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-450msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-500msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-550msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-600msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-650msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-700msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-750msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-800msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-850msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="850"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-900msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-950msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="950"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-150nodes-1000msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-50msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-100msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-150msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-200msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-250msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-300msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-350msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-400msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-450msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-500msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-550msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-600msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-650msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-700msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-750msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-800msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-850msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="850"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-900msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-950msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="950"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-200nodes-1000msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-50msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-100msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-150msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-200msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-250msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-300msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-350msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-400msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-450msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-500msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-550msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-600msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-650msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-700msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-750msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-800msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-850msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="850"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-900msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-950msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="950"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-250nodes-1000msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-50msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-100msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-150msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-200msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-250msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-300msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-350msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-400msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-450msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-500msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-550msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-600msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>full-disconnect</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-650msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-700msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-750msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-800msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-850msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="850"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-900msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-300nodes-1000msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-50msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-100msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-150msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-200msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-250msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-300msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-350msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-400msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-450msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-500msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-550msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-600msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-650msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-700msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-750msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-800msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-850msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="850"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-900msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-950msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="950"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-350nodes-1000msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-50msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-100msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-150msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-200msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-250msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-300msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-350msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-400msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-450msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-500msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-550msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-600msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-650msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-700msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-750msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-800msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-850msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="850"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-900msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-950msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="950"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-400nodes-1000msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-50msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-100msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-150msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-200msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-250msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-300msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-350msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-400msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-450msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-500msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-550msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-600msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-650msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-700msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-750msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-800msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-850msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="850"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-900msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-950msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="950"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-450nodes-1000msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-50msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-100msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-150msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-200msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-250msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-300msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-350msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-400msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-450msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-500msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-550msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-600msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-650msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-700msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-750msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-800msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-850msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="850"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-900msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-950msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="950"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-500nodes-1000msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-50msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-100msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-150msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-200msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-250msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-300msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-350msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-400msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-450msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-500msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-550msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-600msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-650msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-700msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-750msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-800msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-850msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="850"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-900msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-950msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="950"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-550nodes-1000msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-50msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-100msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-150msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-2msg-100runs" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>full-disconnect</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-250msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-300msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-350msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-400msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-450msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-500msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-550msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-600msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-650msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-700msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-750msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-8msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>full-disconnect</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-850msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="850"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-900msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-950msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="950"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-600nodes-1000msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-50msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-100msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-200msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-250msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-300msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-350msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-400msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-450msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-500msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-550msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-600msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-650msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-700msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-750msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-800msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-850msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="850"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-900msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-950msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="950"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-650nodes-1000msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-50msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-100msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-150msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-2msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>full-disconnect</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-250msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-300msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-350msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-400msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-450msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-500msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-550msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-600msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-650msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-700msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-750msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-800msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-850msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="850"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-900msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-950msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="950"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-700nodes-1000msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-50msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-100msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-150msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-200msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-250msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-300msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-350msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-400msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-450msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-500msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-550msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-600msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-650msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-700msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-750msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-800msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-850msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="850"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-900msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-950msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="950"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-750nodes-1000msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-50msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-100msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-150msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-200msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-250msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-300msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-350msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-400msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-450msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="450"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-500msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-550msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="550"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-600msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-650msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="650"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-700msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-750msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-800msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-850msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="850"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-900msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="PHASE-DIAGRAM-800nodes-1000msg" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-energy1</metric>
    <metric>first-disconnect1</metric>
    <metric>half-disconnect1</metric>
    <metric>seventy-percent-disconnect1</metric>
    <metric>full-disconnect</metric>
    <metric>total-msg-sent</metric>
    <metric>undelivered-messages</metric>
    <metric>delivered-msg</metric>
    <enumeratedValueSet variable="Reconfig_Adaptive">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-msg">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Battery">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Seed">
      <value value="42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Mobility">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Transmission_range">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Reconfig">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Calculate_COS">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Multiplier">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
