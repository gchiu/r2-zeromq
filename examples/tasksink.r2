REBOL [
    author: "Gregg Irwin" 
    date: 2011-03-19
    Purpose: {
        Task sink
        - Binds PULL socket to :5558
        - Collects results from workers via that socket
    }
]

do %zmq-helpers.r2

print "TaskSink"

ctx: zmq-init 1

; Prepare our context and socket
receiver: zmq-socket ctx zmq-constants/pull
zmq-bind receiver "tcp://*:5558"

; Wait for start of batch
string: z-recv-msg receiver

start-time: now/precise

num-tasks: 100
repeat i num-tasks [
    string: z-recv-msg receiver
    prin pick ":." zero? i // 10 
]
print ["^/Total elapsed time:" difference now/precise start-time]

zmq-close receiver
zmq-term ctx

halt