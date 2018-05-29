REBOL [
    author: "Gregg Irwin" 
    date: 2011-03-19
    Purpose: {
        Task worker
        - Connects PULL socket to :5557
        - Collects workloads from ventilator via that socket
        - Connects PUSH socket to :5558
        - Sends results to sink via that socket
    }
]

do %zmq-helpers.r2


to-msec: func [string] [divide to integer! string 1000]

;-------------------------------------------------------------------------------

print "TaskWork"

ctx: zmq-init 1

receiver: zmq-socket ctx zmq-constants/pull
zmq-connect receiver "tcp://localhost:5557"

sender: zmq-socket ctx zmq-constants/push
zmq-connect sender "tcp://localhost:5558"

forever [
    string: z-recv-msg/options receiver ZMQ-CONSTANTS/NOBLOCK
    if string [
        print ["Received:" mold string]
        wait to-msec string
        z-send-msg sender ""
    ]
    wait .01
]

;zmq-msg-free msg
zmq-close receiver
zmq-close sender
zmq-term ctx

halt