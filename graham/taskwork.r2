REBOL [
    author: "Gregg Irwin" 
    date:   [19-Mar-2011 7-Jun-2018]
    Purpose: {
        Task worker
        - Connects PULL socket to :5557
        - Collects workloads from ventilator via that socket
        - Connects PUSH socket to :5558
        - Sends results to sink via that socket
    }
    Notes: {Fixed to work with the current r2 zmq helpers - Graham}
]

do %zmq-load.r

to-msec: func [string] [divide to integer! string 1000]

;-------------------------------------------------------------------------------

print "TaskWork"

ctx: zmq-ctx-new ;zmq-init 1

receiver: zmq-socket ctx zmq_pull ;zmq-constants/pull
zmq-connect receiver "tcp://localhost:5557"

sender: zmq-socket ctx zmq_push ;zmq-constants/push
zmq-connect sender "tcp://localhost:5558"

forever [
    ; string: z-recv-msg/options receiver zmq_noblock ;ZMQ-CONSTANTS/NOBLOCK
    print "Get job"
    string: z-recv-msg/dont-wait receiver ; zmq_noblock ;ZMQ-CONSTANTS/NOBLOCK
    ?? string
    if string [
        print ["Received:" mold string]
        ; wait to-msec string
        string: to integer! string
        string: string * string
        z-send-msg sender form string
        
    ]
    wait 1
]

;zmq-msg-free msg
zmq-close receiver
zmq-close sender
zmq-term ctx

halt
