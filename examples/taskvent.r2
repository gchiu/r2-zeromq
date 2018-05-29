REBOL [
    author: "Gregg Irwin" 
    date: 2011-03-19
    Purpose: {
        Task ventilator
        - Binds PUSH socket to :5557
        - Sends batch of tasks to workers via that socket
    }
]

do %zmq-helpers.r2

print "TaskVent"

ctx: zmq-init 1

sender: zmq-socket ctx zmq-constants/push
zmq-bind sender "tcp://*:5557"

ask "Press Enter when the workers are ready."

print "Sending tasks to workers..."

res: z-send-msg sender "0"
print ["Batch start send result:" res]

; Initialise random number generator
random/seed now/precise


; Send tasks
num-tasks: 100
workload: none
total-msec: 0
repeat i num-tasks [
    workload: random 100
    total-msec: total-msec + workload
    res: z-send-msg sender form workload
    print ["Workload sent:" workload "result:" res]
]
print ["Total expected cost:" total-msec / 1000]
wait 1  ; only needed for 0MQ < 2.1

;zmq-msg-free msg
zmq-close sender

; See doc notes about pending outgoing messages and setting LINGER to 0 before
; calling zmq-term.
zmq-term ctx

halt