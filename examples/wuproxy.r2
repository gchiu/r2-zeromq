REBOL [
    author:  "Gregg Irwin"
    email:   gregg_a_pointillistic_*_com
    date:    30-Mar-2011
    Purpose: "Weather proxy device"
]

do %zmq-helpers.r2

print "WUProxy"

ctx: zmq-init 1

; This is where the weather server sits
frontend: zmq-socket ctx ZMQ-CONSTANTS/SUB
zmq-connect frontend "tcp://localhost:5556"
;zmq-connect frontend "tcp://192.168.55.210:5556"

; This is our public endpoint for subscribers
backend: zmq-socket ctx ZMQ-CONSTANTS/PUB
zmq-bind backend "tcp://*:8100"
;zmq-bind backend "tcp://10.1.1.0:8100"

; Subscribe on everything
zmq-setsockopt-binary frontend ZMQ-CONSTANTS/SUBSCRIBE #{}
;z-subscribe frontend

; Shunt messages out to our own subscribers
forever [
    forever [
        ; Process all parts of the message
        msg: z-recv-msg/binary frontend
        either z-more-to-come? frontend [
            prin '+
            z-send-msg/more-to-come backend msg
        ][
            prin '.
            ; Last message part
            z-send-msg backend msg
            break
        ]
    ]
]

; We don't actually get here. If we did, we'd shut down neatly
zmq-close frontend
zmq-close backend
zmq-term ctx

halt