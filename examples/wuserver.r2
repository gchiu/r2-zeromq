REBOL [
    author:  ["Andreas Bolka" "Gregg Irwin"]
    email:   gregg_a_pointillistic_*_com
    date:    30-Mar-2011
    purpose: {
        Weather update server
        Binds PUB socket to tcp://*:5556
        Publishes random weather updates
    }
]

do %zmq-helpers.r2

print "WUServer"

ctx: zmq-init 1

publisher: zmq-socket ctx zmq-constants/pub
zmq-bind publisher "tcp://*:5556"
;zmq-bind publisher "ipc://weather.ipc"

; Initialise random number generator
random/seed now/precise

print "WUServer"

ask "Press a key when ready."

forever [
    ; Generate some random values
    zipcode: random 100'000
    temperature: (random 215) - 80 ; F
    rel-humidity: (random 50) + 10

    ; Send update to all subscribers
    weather: reform [zipcode temperature rel-humidity]
    print ["Sending" mold weather]

    z-send-msg publisher to binary! weather
    
    wait .1
]

zmq-close publisher
zmq-term ctx
